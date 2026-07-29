import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/constants/letter_paths.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';

class TracingScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const TracingScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<TracingScreen> createState() => _TracingScreenState();
}

class _TracingScreenState extends ConsumerState<TracingScreen>
    with TickerProviderStateMixin, TimedGameMixin, GamePauseMixin {
  /// Difficulty-based item count
  int get _totalItems => switch (widget.difficulty) {
    GameDifficulty.easy => 3,
    GameDifficulty.medium => 5,
    GameDifficulty.hard => 7,
  };

  /// Proximity threshold in logical pixels for scoring
  double get _proximityThreshold => switch (widget.difficulty) {
    GameDifficulty.easy => 30.0,
    GameDifficulty.medium => 22.0,
    GameDifficulty.hard => 15.0,
  };

  /// Whether to show full guide dots
  bool get _showGuide => widget.difficulty != GameDifficulty.hard;

  /// Guide dot density
  int get _guideDensity => switch (widget.difficulty) {
    GameDifficulty.easy => 12,
    GameDifficulty.medium => 8,
    GameDifficulty.hard => 4,
  };

  late List<Flashcard> _flashcards;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];

  // Per-word tracing state
  List<List<Offset>> _drawnStrokes = [];
  List<Offset> _currentStroke = [];
  bool _wordCompleted = false;
  double _currentAccuracy = 0.0;
  final Map<String, bool> _wordResults = {}; // cardId → correct

  @override
  void initState() {
    super.initState();
    _startGame();
    initPause();
  }

  void _startGame() {
    var all = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      all = all.where((c) => widget.categories.contains(c.category)).toList();
    }
    _flashcards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: all,
      count: _totalItems,
    );
    _currentIndex = 0;
    _correctCount = 0;
    _showResult = false;
    _wordResults.clear();
    _newAchievements = [];
    _resetDrawing();
    startTimerIfNeeded(widget.timedMode);
  }

  void _resetDrawing() {
    _drawnStrokes = [];
    _currentStroke = [];
    _wordCompleted = false;
    _currentAccuracy = 0.0;
  }

  Flashcard get _currentCard => _flashcards[_currentIndex];

  /// The text to trace depends on difficulty:
  /// Easy: first letter only, Medium: first 3 chars, Hard: full word
  String get _traceText => switch (widget.difficulty) {
    GameDifficulty.easy => _currentCard.wordEnglish.substring(0, 1).toUpperCase(),
    GameDifficulty.medium => _currentCard.wordEnglish
        .substring(0, min(3, _currentCard.wordEnglish.length))
        .toUpperCase(),
    GameDifficulty.hard => _currentCard.wordEnglish.toUpperCase(),
  };

  @override
  void dispose() {
    disposePause();
    disposeTimer();
    super.dispose();
  }

  @override
  Future<void> savePartialProgress() async {
    if (_flashcards.isEmpty) return;
    _saveProgress();
  }

  @override
  void onTimeUp() {
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _onPanStart(DragStartDetails details) {
    if (_wordCompleted) return;
    setState(() {
      _currentStroke = [details.localPosition];
    });
    ref.read(soundServiceProvider).playTap();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_wordCompleted) return;
    setState(() {
      _currentStroke = [..._currentStroke, details.localPosition];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_wordCompleted) return;
    if (_currentStroke.isNotEmpty) {
      setState(() {
        _drawnStrokes = [..._drawnStrokes, _currentStroke];
        _currentStroke = [];
      });
    }
  }

  void _checkTracing(Size canvasSize) {
    final text = _traceText;
    final wordStrokes = LetterPaths.forWord(text);
    final guideDots = LetterPaths.guideDots(wordStrokes, density: _guideDensity);

    // Scale guide dots to canvas size
    final scaledDots = guideDots
        .map((d) => Offset(d.dx * canvasSize.width, d.dy * canvasSize.height))
        .toList();

    if (scaledDots.isEmpty) {
      // No guides for this word, auto pass
      _handleWordResult(true, 1.0);
      return;
    }

    // Flatten all drawn points
    final allDrawn = [
      for (final stroke in _drawnStrokes) ...stroke,
    ];

    if (allDrawn.isEmpty) {
      _handleWordResult(false, 0.0);
      return;
    }

    // Count how many guide dots are within proximity of any drawn point
    int covered = 0;
    for (final dot in scaledDots) {
      final isClose = allDrawn.any((drawn) {
        final dx = drawn.dx - dot.dx;
        final dy = drawn.dy - dot.dy;
        return sqrt(dx * dx + dy * dy) <= _proximityThreshold;
      });
      if (isClose) covered++;
    }

    final accuracy = covered / scaledDots.length;
    final isCorrect = accuracy >= 0.6;

    _handleWordResult(isCorrect, accuracy);
  }

  void _handleWordResult(bool isCorrect, double accuracy) {
    final sound = ref.read(soundServiceProvider);

    setState(() {
      _wordCompleted = true;
      _currentAccuracy = accuracy;
      _wordResults[_currentCard.id] = isCorrect;

      if (isCorrect) {
        _correctCount++;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });

    // Auto advance after a delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIndex < _totalItems - 1) {
        setState(() {
          _currentIndex++;
          _resetDrawing();
        });
      } else {
        _saveProgress();
        AccessibleCelebrationOverlay.show(
          context: context, ref: ref, type: CelebrationType.gameComplete,
        );
        setState(() => _showResult = true);
      }
    });
  }

  int get _starsEarned {
    final pct = _correctCount / _totalItems;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories =
        _flashcards.map((c) => c.category).toSet().toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.tracing,
      score: _correctCount,
      total: _totalItems,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
      correctWordIds: _wordResults.correctWordIds,
    );
    _newAchievements =
        ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      SpacedRepetitionService.recordBatch(
          profileId: profile.id, results: _wordResults);
    }
  }

  List<GameReviewItem> get _reviewItems => _flashcards
      .map((c) => GameReviewItem(
            wordEnglish: c.wordEnglish,
            wordFilipino: c.wordFilipino,
            category: c.category,
            isCorrect: _wordResults[c.id] ?? false,
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _correctCount,
                  total: _totalItems,
                  starsEarned: _starsEarned,
                  onPlayAgain: () => setState(() => _startGame()),
                  onExit: () => context.go('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Tracing',
                  ),
                ),
              ),
            ),
          ),
          if (_newAchievements.isNotEmpty)
            AchievementUnlockedOverlay(
              achievements: _newAchievements,
              onDismiss: () => setState(() => _newAchievements = []),
            ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pauseGame();
      },
      child: Stack(children: [
        Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: pauseGame,
        ),
        title: Text(AppLocalizations.of(context)!.tracing),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline_rounded),
            tooltip: 'Pause',
            onPressed: pauseGame,
          ),
          if (isTimedMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GameTimerWidget(
                remainingSeconds: remainingSeconds,
                totalSeconds: totalTimerSeconds,
                size: 44,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / $_totalItems',
                style: AppTypography.titleMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Word info card
            _buildWordInfoCard()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 12),

            // Tracing canvas
            Expanded(
              child: _buildTracingCanvas()
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms),
            ),

            const SizedBox(height: 12),

            // Action buttons
            _buildActionButtons()
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms)
                .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    ),
        GameBreakButton(
          onHold: holdForBreak,
          onResume: resumeFromBreak,
        ),
        if (isPaused)
          PauseOverlay(
            onResume: resumeGame,
            onRestart: () {
              resumeGame();
              setState(_startGame);
            },
            onQuit: () async {
              await savePartialProgress();
              if (context.mounted) context.go('/games');
            },
          ),
      ]),
    );
  }

  Widget _buildWordInfoCard() {
    final card = _currentCard;
    final emoji = FlashcardEmojis.forId(card.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card.category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.category.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trace: $_traceText',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: card.category.darkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${card.wordEnglish} = ${card.wordFilipino}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_wordCompleted)
            Icon(
              (_wordResults[card.id] ?? false)
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 32,
              color: (_wordResults[card.id] ?? false)
                  ? AppColors.success
                  : AppColors.error,
            ),
        ],
      ),
    );
  }

  Widget _buildTracingCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final text = _traceText;
        final wordStrokes = LetterPaths.forWord(text);
        final guideDots =
            LetterPaths.guideDots(wordStrokes, density: _guideDensity);

        return Container(
          decoration: BoxDecoration(
            color: HCColor.of(context).surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _wordCompleted
                  ? ((_wordResults[_currentCard.id] ?? false)
                      ? AppColors.success
                      : AppColors.error)
                  : AppColors.primary.withValues(alpha: 0.3),
              width: _wordCompleted ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                size: canvasSize,
                painter: _TracingPainter(
                  guideStrokes: wordStrokes,
                  guideDots: guideDots,
                  drawnStrokes: _drawnStrokes,
                  currentStroke: _currentStroke,
                  showGuide: _showGuide,
                  primaryColor: _currentCard.category.darkColor,
                  guideColor: _currentCard.category.color,
                  completed: _wordCompleted,
                  correct: _wordResults[_currentCard.id] ?? false,
                  accuracy: _currentAccuracy,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    // OverflowBar lays Clear + Check side-by-side at normal scale and stacks
    // them vertically at XL font scaling so neither overflows the screen.
    return OverflowBar(
      spacing: 16,
      overflowSpacing: 8,
      alignment: MainAxisAlignment.center,
      overflowAlignment: OverflowBarAlignment.center,
      children: [
        // Clear button
        OutlinedButton.icon(
          onPressed: _wordCompleted ? null : () => setState(_resetDrawing),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(AppLocalizations.of(context)!.clear),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        // Check button
        FilledButton.icon(
          onPressed: _wordCompleted
              ? null
              : () {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  // Use current layout constraints for the canvas size
                  // We need the canvas size which is the Expanded area
                  _checkTracing(Size(
                    renderBox.size.width - 32,
                    renderBox.size.height - 250,
                  ));
                },
          icon: const Icon(Icons.check_rounded),
          label: Text(AppLocalizations.of(context)!.check),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the tracing canvas.
class _TracingPainter extends CustomPainter {
  final List<List<Offset>> guideStrokes;
  final List<Offset> guideDots;
  final List<List<Offset>> drawnStrokes;
  final List<Offset> currentStroke;
  final bool showGuide;
  final Color primaryColor;
  final Color guideColor;
  final bool completed;
  final bool correct;
  final double accuracy;

  _TracingPainter({
    required this.guideStrokes,
    required this.guideDots,
    required this.drawnStrokes,
    required this.currentStroke,
    required this.showGuide,
    required this.primaryColor,
    required this.guideColor,
    required this.completed,
    required this.correct,
    required this.accuracy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Light background grid
    _drawGrid(canvas, size);

    // 2. Guide letter outlines (dotted)
    if (showGuide) {
      _drawGuide(canvas, size);
    }

    // 3. Guide dots
    _drawGuideDots(canvas, size);

    // 4. User's drawn strokes
    _drawUserStrokes(canvas, size);

    // 5. Accuracy overlay when completed
    if (completed) {
      _drawResultOverlay(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    // Horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Vertical guidelines for each character area
    final charCount = guideStrokes.isEmpty ? 1 : _estimateCharCount(size);
    if (charCount > 1) {
      for (var i = 1; i < charCount; i++) {
        final x = size.width * i / charCount;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height),
            paint..color = Colors.grey.withValues(alpha: 0.05));
      }
    }
  }

  int _estimateCharCount(Size size) {
    if (guideStrokes.isEmpty) return 1;
    // Estimate from stroke positions
    final maxX = guideStrokes
        .expand((s) => s)
        .map((o) => o.dx)
        .fold(0.0, (a, b) => a > b ? a : b);
    if (maxX <= 0) return 1;
    return (1 / maxX * guideStrokes.length).clamp(1, 20).round();
  }

  void _drawGuide(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = guideColor.withValues(alpha: 0.25)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in guideStrokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      final scaled = stroke
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      path.moveTo(scaled.first.dx, scaled.first.dy);
      for (var i = 1; i < scaled.length; i++) {
        path.lineTo(scaled[i].dx, scaled[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawGuideDots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = guideColor.withValues(alpha: showGuide ? 0.4 : 0.2)
      ..style = PaintingStyle.fill;

    final dotRadius = showGuide ? 3.0 : 2.0;

    for (final dot in guideDots) {
      canvas.drawCircle(
        Offset(dot.dx * size.width, dot.dy * size.height),
        dotRadius,
        paint,
      );
    }
  }

  void _drawUserStrokes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in drawnStrokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current stroke
    if (currentStroke.length >= 2) {
      final path = Path();
      path.moveTo(currentStroke.first.dx, currentStroke.first.dy);
      for (var i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint..color = primaryColor.withValues(alpha: 0.7));
    }
  }

  void _drawResultOverlay(Canvas canvas, Size size) {
    // Semi-transparent overlay
    final overlayPaint = Paint()
      ..color = (correct ? Colors.green : Colors.red).withValues(alpha: 0.08);
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // Accuracy text
    final pct = (accuracy * 100).round();
    final textSpan = TextSpan(
      text: correct ? '✓ $pct%' : '✗ $pct%',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: correct ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - textPainter.height - 16,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}
