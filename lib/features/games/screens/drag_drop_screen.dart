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
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';

class DragDropScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;
  const DragDropScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends ConsumerState<DragDropScreen>
    with TickerProviderStateMixin, TimedGameMixin, GamePauseMixin {
  /// Difficulty-based item count
  int get _totalItems => switch (widget.difficulty) {
    GameDifficulty.easy => 3,
    GameDifficulty.medium => 5,
    GameDifficulty.hard => 7,
  };

  late List<Flashcard> _flashcards;
  late List<String> _draggables; // English words – shuffled
  late List<_DropTarget> _targets; // Filipino words – original order
  int _correctCount = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final Map<String, String?> _matches = {}; // targetId → draggable word

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
    _targets = _flashcards
        .map((f) => _DropTarget(
              id: f.id,
              filipino: f.wordFilipino,
              englishAnswer: f.wordEnglish,
              emoji: FlashcardEmojis.forId(f.id),
              icon: f.category.icon,
              color: f.category.color,
            ))
        .toList();
    _draggables = _flashcards.map((f) => f.wordEnglish).toList()..shuffle();
    _matches.clear();
    _correctCount = 0;
    _showResult = false;
    startTimerIfNeeded(widget.timedMode);
  }

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

  void _onAccept(String targetId, String englishWord) {
    final idx = _targets.indexWhere((t) => t.id == targetId);
    if (idx == -1) return; // target not found — ignore
    final target = _targets[idx];
    final sound = ref.read(soundServiceProvider);

    // Remove from previous target if already placed
    _matches.forEach((key, value) {
      if (value == englishWord) _matches[key] = null;
    });

    setState(() {
      _matches[targetId] = englishWord;
      if (englishWord == target.englishAnswer) {
        target.isCorrect = true;
        _correctCount = _targets.where((t) => t.isCorrect).length;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();

        if (_correctCount == _totalItems) {
          _saveProgress();
          AccessibleCelebrationOverlay.show(
            context: context, ref: ref, type: CelebrationType.gameComplete,
          );
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _showResult = true);
          });
        }
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });
  }

  bool _isPlaced(String word) {
    return _matches.containsValue(word) &&
        _targets.any(
            (t) => t.isCorrect && _matches[t.id] == word);
  }

  int get _starsEarned => 3; // completed the puzzle

  void _saveProgress() {
    final categories = _flashcards
        .map((c) => c.category)
        .toSet()
        .toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.dragAndDrop,
      score: _correctCount,
      total: _totalItems,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final c in _flashcards) {
        srResults[c.id] = true;
      }
      SpacedRepetitionService.recordBatch(profileId: profile.id, results: srResults);
    }
  }

  List<GameReviewItem> get _reviewItems => _flashcards
      .map((c) => GameReviewItem(
            wordEnglish: c.wordEnglish,
            wordFilipino: c.wordFilipino,
            category: c.category,
            isCorrect: true,
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
                    gameTitle: 'Drag & Drop',
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
        title: Text(AppLocalizations.of(context)!.dragAndDrop),
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
                '$_correctCount / $_totalItems',
                style: AppTypography.titleMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        // Scroll the whole board so a short (landscape) viewport or large font
        // scale never overflows — on a tablet it all fits without scrolling.
        child: SingleChildScrollView(
        child: Column(
          children: [
            // Instructions
            Text(
              AppLocalizations.of(context)!.dragInstruction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: HCColor.of(context).textSecondary),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.2, end: 0),

            const SizedBox(height: 20),

            // ─── Draggable Words (top) ────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _draggables.map((word) {
                final placed = _isPlaced(word);
                if (placed) {
                  // Placeholder for placed word — IgnorePointer
                  // so faded chips don't block taps on items behind them
                  return IgnorePointer(
                    child: Opacity(
                      opacity: 0.3,
                      child: Chip(
                        label: Text(word,
                            style: AppTypography.labelMedium
                                .copyWith(color: HCColor.of(context).textSecondary)),
                        backgroundColor: HCColor.of(context).surfaceLight,
                        side: BorderSide.none,
                      ),
                    ),
                  );
                }
                return Semantics(
                  button: true,
                  label: 'Draggable word: $word, drag to matching Filipino word',
                  child: Draggable<String>(
                  data: word,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        word,
                        style: AppTypography.labelLarge
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _WordChip(word: word),
                  ),
                  child: _WordChip(word: word),
                ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),

            // ─── Drop Targets (bottom list) ───────
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _targets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final target = _targets[index];
                return _DropTargetRow(
                  target: target,
                  matchedWord: _matches[target.id],
                  onAccept: (word) => _onAccept(target.id, word),
                )
                    .animate()
                    .fadeIn(
                        duration: 400.ms,
                        delay: Duration(milliseconds: 80 * index))
                    .slideX(begin: 0.15, end: 0);
              },
            ),
          ],
        ),
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
}

// ────────────────────────────────────────
// Supporting types & widgets
// ────────────────────────────────────────

class _DropTarget {
  final String id;
  final String filipino;
  final String englishAnswer;
  final String emoji;
  final IconData icon;
  final Color color;
  bool isCorrect = false;

  _DropTarget({
    required this.id,
    required this.filipino,
    required this.englishAnswer,
    required this.emoji,
    required this.icon,
    required this.color,
  });
}

class _WordChip extends StatelessWidget {
  final String word;
  const _WordChip({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        word,
        style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _DropTargetRow extends StatelessWidget {
  final _DropTarget target;
  final String? matchedWord;
  final ValueChanged<String> onAccept;

  const _DropTargetRow({
    required this.target,
    required this.matchedWord,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: target.isCorrect
          ? 'Matched: ${target.filipino} is ${target.englishAnswer}'
          : 'Drop target: ${target.filipino}, ${matchedWord != null ? 'currently has $matchedWord (wrong)' : 'empty, drop English match here'}',
      child: DragTarget<String>(
      onWillAcceptWithDetails: (_) => !target.isCorrect,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: target.isCorrect
                ? AppColors.successLight
                : isHovering
                    ? target.color.withValues(alpha: 0.15)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: target.isCorrect
                  ? AppColors.success
                  : isHovering
                      ? target.color
                      : AppColors.border,
              width: target.isCorrect || isHovering ? 2 : 1,
            ),
            boxShadow: isHovering ? AppColors.softShadow : [],
          ),
          child: Row(
            children: [
              // Per-word emoji
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: target.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(target.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),

              // Filipino word
              Expanded(
                child: Text(
                  target.filipino,
                  style: AppTypography.titleMedium.copyWith(
                    color: HCColor.of(context).textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Drop zone / matched word
              if (target.isCorrect) ...[
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24),
                const SizedBox(width: 8),
                Text(
                  matchedWord ?? '',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: HCColor.of(context).surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHovering
                          ? target.color
                          : HCColor.of(context).border,
                    ),
                  ),
                  child: Text(
                    matchedWord ?? '???',
                    style: AppTypography.labelMedium.copyWith(
                      color: matchedWord != null
                          ? AppColors.error
                          : AppColors.textHint,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
    );
  }
}
