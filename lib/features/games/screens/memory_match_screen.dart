import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';

class MemoryMatchScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;
  const MemoryMatchScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen>
    with TimedGameMixin, GamePauseMixin {
  /// Difficulty-based pair count
  int get _pairs => switch (widget.difficulty) {
    GameDifficulty.easy => 4, // 4×2 grid (8 cards)
    GameDifficulty.medium => 6, // 4×3 grid (12 cards)
    GameDifficulty.hard => 8, // 4×4 grid (16 cards)
  };

  int get _gridColumns {
    // Adapt column count for wider screens so cards fill the space.
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    return 4;
  }

  late List<_MemoryCard> _cards;
  late List<Flashcard> _sourceCards;
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  int _moves = 0;
  int _matchedPairs = 0;
  bool _isChecking = false;
  int _cursorIndex = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupGame();
    initPause();
  }

  @override
  void dispose() {
    disposePause();
    _timer?.cancel();
    disposeTimer();
    super.dispose();
  }

  @override
  void onPause() {
    _timer?.cancel();
  }

  @override
  void onResume() {
    if (_showResult) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  Future<void> savePartialProgress() async {
    if (_cards.isEmpty) return;
    _saveProgress();
  }

  @override
  void onTimeUp() {
    _timer?.cancel();
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context,
      ref: ref,
      type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _setupGame() {
    var allCards = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      allCards = allCards
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }
    _sourceCards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: allCards,
      count: _pairs,
    );

    _cards = [];
    for (final card in _sourceCards) {
      // Word card
      _cards.add(
        _MemoryCard(
          id: '${card.id}_word',
          pairId: card.id,
          displayText: card.wordEnglish,
          isImage: false,
          card: card,
          icon: card.category.icon,
          color: card.category.color,
        ),
      );
      // Image/emoji card
      _cards.add(
        _MemoryCard(
          id: '${card.id}_img',
          pairId: card.id,
          displayText: card.wordFilipino,
          isImage: true,
          card: card,
          icon: card.category.icon,
          color: card.category.color,
        ),
      );
    }
    _cards.shuffle(Random());
    _firstFlippedIndex = null;
    _secondFlippedIndex = null;
    _moves = 0;
    _matchedPairs = 0;
    _isChecking = false;
    _showResult = false;
    _elapsedSeconds = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    startTimerIfNeeded(widget.timedMode);
  }

  // ─── Gaze cursor (hands-free) ────────────────────
  // Memory Match is on the Motor Impairment roster. Look ◀ ▶ to walk the
  // highlight through the cards in reading order (wrapping, so every card is
  // reachable), then look ▼ or blink to turn the highlighted one over. Matched
  // and already-flipped cards are skipped, so the cursor never parks somewhere
  // a commit would do nothing. Inert unless Gaze Control is on.

  /// Steps [delta] cards at a time, skipping cards that can no longer be
  /// flipped. Gives up after a full lap so an all-matched board can't spin.
  void _moveCursor(int delta) {
    final n = _cards.length;
    if (n <= 0) return;
    var index = _cursorIndex;
    for (var step = 0; step < n; step++) {
      index = (((index + delta) % n) + n) % n;
      if (!_cards[index].isMatched && !_cards[index].isFlipped) break;
    }
    setState(() => _cursorIndex = index);
  }

  void _selectCursor() {
    if (_isChecking || isPaused) return;
    if (_cursorIndex < 0 || _cursorIndex >= _cards.length) return;
    _flipCard(_cursorIndex);
    // Land the highlight on the next still-playable card so the learner is
    // already aimed at their second pick.
    if (!_isChecking) _moveCursor(1);
  }

  List<GazeAction> _gazeActions() {
    final canMove = !_isChecking && !isPaused;
    return [
      GazeAction(
        zone: GazeZone.left,
        label: 'Prev',
        icon: Icons.chevron_left_rounded,
        color: AppColors.secondary,
        enabled: canMove,
        onSelect: () => _moveCursor(-1),
      ),
      GazeAction(
        zone: GazeZone.right,
        label: 'Next',
        icon: Icons.chevron_right_rounded,
        color: AppColors.secondary,
        enabled: canMove,
        onSelect: () => _moveCursor(1),
      ),
      GazeAction(
        zone: GazeZone.down,
        label: 'Flip',
        icon: Icons.flip_rounded,
        color: AppColors.success,
        enabled: canMove,
        onSelect: _selectCursor,
      ),
    ];
  }

  void _flipCard(int index) {
    if (_isChecking) return;
    if (_cards[index].isMatched || _cards[index].isFlipped) return;

    ref.read(soundServiceProvider).playFlip();
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _cards[index].isFlipped = true;

      if (_firstFlippedIndex == null) {
        _firstFlippedIndex = index;
      } else {
        _secondFlippedIndex = index;
        _moves++;
        _isChecking = true;
        _checkMatch();
      }
    });
  }

  void _checkMatch() {
    final first = _cards[_firstFlippedIndex!];
    final second = _cards[_secondFlippedIndex!];
    final sound = ref.read(soundServiceProvider);

    if (first.pairId == second.pairId) {
      // Match!
      sound.playMatch();
      ref.read(hapticServiceProvider).success();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          first.isMatched = true;
          second.isMatched = true;
          _matchedPairs++;
          _firstFlippedIndex = null;
          _secondFlippedIndex = null;
          _isChecking = false;

          if (_matchedPairs == _pairs) {
            _timer?.cancel();
            _saveProgress();
            AccessibleCelebrationOverlay.show(
              context: context,
              ref: ref,
              type: CelebrationType.gameComplete,
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _showResult = true);
            });
          }
        });
      });
    } else {
      // No match — flip back
      sound.playWrong();
      ref.read(hapticServiceProvider).error();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          first.isFlipped = false;
          second.isFlipped = false;
          _firstFlippedIndex = null;
          _secondFlippedIndex = null;
          _isChecking = false;
        });
      });
    }
  }

  void _saveProgress() {
    final categories = _sourceCards.map((c) => c.category).toSet().toList();
    // Per-word results (all correct in memory match) — feeds both
    // wordsLearned and spaced repetition.
    final srResults = <String, bool>{};
    for (final c in _sourceCards) {
      srResults[c.id] = true;
    }

    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.memoryMatch,
          score: _pairs,
          total: _pairs,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: srResults.correctWordIds,
        );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    final profile = ref.read(profileProvider);
    if (profile != null) {
      SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: srResults,
      );
    }
  }

  List<GameReviewItem> get _reviewItems => _sourceCards
      .map(
        (c) => GameReviewItem(
          wordEnglish: c.wordEnglish,
          wordFilipino: c.wordFilipino,
          category: c.category,
          isCorrect: true,
        ),
      )
      .toList();

  void _restart() {
    setState(() => _setupGame());
  }

  int get _starsEarned {
    // Scale star thresholds by difficulty
    final threshold3 = switch (widget.difficulty) {
      GameDifficulty.easy => _pairs + 2,
      GameDifficulty.medium => _pairs + 3,
      GameDifficulty.hard => _pairs + 4,
    };
    if (_moves <= threshold3) return 3;
    if (_moves <= _pairs * 2) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _pairs,
                  total: _pairs,
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.popOrGo('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Memory Match',
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

    // The highlight only means something while a card can still be turned.
    final showCursor =
        ref.watch(gazeSettingsProvider.select((s) => s.enabled)) &&
        !_isChecking;

    return GazeScope(
      actions: _gazeActions(),
      onBlink: _selectCursor,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) pauseGame();
        },
        child: Stack(
          children: [
            Scaffold(
              appBar: fullscreenBar(
                ref,
                AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: pauseGame,
                  ),
                  title: Text(AppLocalizations.of(context)!.memoryMatch),
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
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 18,
                              color: hc.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_moves moves',
                              style: AppTypography.labelMedium.copyWith(
                                color: hc.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 18,
                              color: hc.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_elapsedSeconds}s',
                              style: AppTypography.labelMedium.copyWith(
                                color: hc.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Matches counter
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        label:
                            'Matched $_matchedPairs of $_pairs pairs in $_moves moves, $_elapsedSeconds seconds elapsed',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Matched: $_matchedPairs / $_pairs',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Card Grid ────────────────────────
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridColumns,
                          mainAxisSpacing: context.gridSpacing * 0.625,
                          crossAxisSpacing: context.gridSpacing * 0.625,
                          childAspectRatio:
                              (0.78 /
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1.0))
                                  .clamp(0.55, 0.95),
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          return _MemoryCardWidget(
                            card: card,
                            highlighted: showCursor && index == _cursorIndex,
                            onTap: () => _flipCard(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GameBreakButton(onHold: holdForBreak, onResume: resumeFromBreak),
            if (isPaused)
              PauseOverlay(
                onResume: resumeGame,
                onRestart: () {
                  resumeGame();
                  _restart();
                },
                onQuit: () async {
                  await savePartialProgress();
                  if (context.mounted) context.popOrGo('/games');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard {
  final String id;
  final String pairId;
  final String displayText;
  final bool isImage;
  final Flashcard card;
  final IconData icon;
  final Color color;
  bool isFlipped = false;
  bool isMatched = false;

  _MemoryCard({
    required this.id,
    required this.pairId,
    required this.displayText,
    required this.isImage,
    required this.card,
    required this.icon,
    required this.color,
  });
}

class _MemoryCardWidget extends StatelessWidget {
  final _MemoryCard card;

  /// The hands-free cursor is resting on this card — ring it the way the hub
  /// tiles and the other gaze games do.
  final bool highlighted;
  final VoidCallback onTap;

  const _MemoryCardWidget({
    required this.card,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      button: true,
      label: card.isMatched
          ? 'Matched card: ${card.displayText}'
          : card.isFlipped
          ? 'Card showing: ${card.displayText}'
          : 'Face-down card, tap to flip',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: card.isFlipped || card.isMatched ? pi : 0,
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          builder: (context, angle, child) {
            final isFront = angle < pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isFront ? _buildBack(context) : _buildFront(context),
            );
          },
        ),
      ),
    );

    if (!highlighted) return content;
    // Ring sits outside the flip transform so it stays square while the card
    // turns — the highlight marks the *slot*, not the animating face.
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBack(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Center(
        child: Icon(
          Icons.question_mark_rounded,
          size: context.scaleIcon(32),
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: card.isMatched
              ? AppColors.successLight
              : card.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.isMatched ? AppColors.success : card.color,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (card.isImage) ...[
              FlashcardPicture(card: card.card, extent: 32),
              const SizedBox(height: 4),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                card.displayText,
                style: AppTypography.labelMedium.copyWith(
                  color: card.isMatched
                      ? AppColors.successDark
                      : HCColor.of(context).textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
