import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
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
import '../../../widgets/flashcard_image.dart';
import '../timed_game_mixin.dart';
import '../../../l10n/app_localizations.dart';

class FlashcardQuizScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;
  const FlashcardQuizScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<FlashcardQuizScreen> createState() =>
      _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends ConsumerState<FlashcardQuizScreen>
    with SingleTickerProviderStateMixin, TimedGameMixin {
  /// Difficulty-based card count
  int get _totalCards => switch (widget.difficulty) {
    GameDifficulty.easy => 6,
    GameDifficulty.medium => 10,
    GameDifficulty.hard => 15,
  };

  late List<Flashcard> _cards;
  int _currentIndex = 0;
  int _knowCount = 0;
  int _learningCount = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];

  // Swipe state
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    var all = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      all = all.where((c) => widget.categories.contains(c.category)).toList();
    }
    all.shuffle();
    _cards = all.take(_totalCards).toList();
    _currentIndex = 0;
    _knowCount = 0;
    _learningCount = 0;
    _showResult = false;
    _reviewItems.clear();
    _dragOffset = Offset.zero;
    _dragRotation = 0;
    startTimerIfNeeded(widget.timedMode);
  }

  @override
  void dispose() {
    disposeTimer();
    super.dispose();
  }

  @override
  void onTimeUp() {
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragRotation = _dragOffset.dx * 0.001;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragOffset.dx.abs() > 100) {
      final isRight = _dragOffset.dx > 0;
      _handleSwipe(isRight);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragRotation = 0;
      });
    }
  }

  /// Tracks the running streak of "I know it" answers so we can trigger
  /// a small extra celebration every 3 in a row — a low-cost dopamine
  /// hit that doesn't compete with the end-of-game confetti.
  int _knowStreak = 0;

  void _handleSwipe(bool isKnow) {
    final sound = ref.read(soundServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    final card = _cards[_currentIndex];
    _reviewItems.add(GameReviewItem(
      wordEnglish: card.wordEnglish,
      wordFilipino: card.wordFilipino,
      category: card.category,
      isCorrect: isKnow,
    ));
    setState(() {
      if (isKnow) {
        _knowCount++;
        _knowStreak++;
        sound.playCorrect();
        // Every 3rd correct answer in a row, layer a star sound + a
        // celebration haptic on top of the regular success feedback.
        if (_knowStreak % 3 == 0) {
          sound.playStar();
          haptic.celebration();
        } else {
          haptic.success();
        }
      } else {
        _learningCount++;
        _knowStreak = 0;
        sound.playFlip();
        haptic.error();
      }
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _saveProgress();
        AccessibleCelebrationOverlay.show(
          context: context, ref: ref, type: CelebrationType.gameComplete,
        );
        _showResult = true;
      }
    });
  }

  int get _starsEarned {
    final pct = _knowCount / _totalCards;
    if (pct >= 0.9) return 3;
    if (pct >= 0.6) return 2;
    return 1;
  }

  void _saveProgress() {
    final categories = _cards
        .map((c) => c.category)
        .toSet()
        .toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.flashcardQuiz,
      score: _knowCount,
      total: _totalCards,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final r in _reviewItems) {
        final card = _cards.where((c) => c.wordEnglish == r.wordEnglish).firstOrNull;
        if (card != null) srResults[card.id] = r.isCorrect;
      }
      SpacedRepetitionService.recordBatch(profileId: profile.id, results: srResults);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: _ResultView(
                  know: _knowCount,
                  learning: _learningCount,
                  total: _totalCards,
                  starsEarned: _starsEarned,
                  onPlayAgain: () => setState(() => _startGame()),
                  onExit: () => context.go('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Flashcard Quiz',
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

    final card = _cards[_currentIndex];
    final swipeColor = _dragOffset.dx > 40
        ? AppColors.success.withValues(alpha: 0.3)
        : _dragOffset.dx < -40
            ? AppColors.error.withValues(alpha: 0.3)
            : Colors.transparent;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.go('/games'),
        ),
        title: Text('${_currentIndex + 1} / $_totalCards'),
        actions: [
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
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 4),
                Text('$_knowCount',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.success)),
                const SizedBox(width: 12),
                const Icon(Icons.school_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 4),
                Text('$_learningCount',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.warning)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Semantics(
            label: 'Card ${_currentIndex + 1} of $_totalCards, $_knowCount known, $_learningCount still learning',
            child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _totalCards,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
            minHeight: 4,
          ),
          ),

          const Spacer(),

          // Swipe hints
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(AppLocalizations.of(context)!.stillLearningSwipe,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.error),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(AppLocalizations.of(context)!.iKnowThisSwipe,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.success),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Swipeable Card ───────────────────
          Semantics(
            label: 'Flashcard: ${card.wordEnglish}, ${card.wordFilipino}, category ${card.category.label}. Swipe right for I Know, left for Still Learning',
            child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.identity()
                ..storage[12] = _dragOffset.dx
                ..storage[13] = _dragOffset.dy
                ..rotateZ(_dragRotation),
              transformAlignment: Alignment.center,
              child: SizedBox(
                width: 300,
                height: 400,
                child: Stack(
                  children: [
                    // Swipe color overlay
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: swipeColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    // Card
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color:
                              card.category.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              card.category.color
                                  .withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: card.category.color
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(card.category.icon,
                                      size: 16, color: card.category.color),
                                  const SizedBox(width: 6),
                                  Text(
                                    card.category.label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: card.category.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Per-word image
                            FlashcardImage(
                              card: card,
                              size: 48,
                              borderRadius: 16,
                            ),
                            const SizedBox(height: 20),

                            // English word
                            Text(
                              card.wordEnglish,
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: HCColor.of(context).textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Filipino word
                            Text(
                              card.wordFilipino,
                              style: AppTypography.titleLarge.copyWith(
                                color: card.category.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Example sentence
                            if (card.exampleSentence != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '"${card.exampleSentence}"',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: HCColor.of(context).textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),

          const SizedBox(height: 32),

          // ─── Action Buttons ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Still learning
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: AppLocalizations.of(context)!.learning,
                  color: AppColors.error,
                  onTap: () => _handleSwipe(false),
                ),
                // Know it
                _ActionButton(
                  icon: Icons.check_rounded,
                  label: AppLocalizations.of(context)!.iKnow,
                  color: AppColors.success,
                  onTap: () => _handleSwipe(true),
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Action Button
// ────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '$label button',
        child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: color)),
        ],
      ),
      ),
    );
  }
}

// ────────────────────────────────────────
// Result View
// ────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final int know;
  final int learning;
  final int total;
  final int starsEarned;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final VoidCallback? onReview;

  const _ResultView({
    required this.know,
    required this.learning,
    required this.total,
    required this.starsEarned,
    required this.onPlayAgain,
    required this.onExit,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRating(stars: starsEarned)
              .animate()
              .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut),

          const SizedBox(height: 16),
          Text(
            know >= total * 0.8 ? '🎉 Amazing!' : '💪 Keep Going!',
            style: AppTypography.headlineSmall
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBubble(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                label: 'I Know',
                value: '$know',
              ),
              _StatBubble(
                icon: Icons.school_rounded,
                color: AppColors.warning,
                label: 'Learning',
                value: '$learning',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: know / total,
              minHeight: 12,
              backgroundColor: AppColors.error.withValues(alpha: 0.2),
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(know / total * 100).round()}% mastered',
            style: AppTypography.labelMedium
                .copyWith(color: HCColor.of(context).textSecondary),
          ),
          if (onReview != null) ...[            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.rate_review_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.reviewWords),
            ),
          ],

          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExit,
                  child: Text(AppLocalizations.of(context)!.exit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlayAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppLocalizations.of(context)!.again),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _StatBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatBubble({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(value,
            style:
                AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800)),
        Text(label,
            style: AppTypography.labelSmall
                .copyWith(color: HCColor.of(context).textSecondary)),
      ],
    );
  }
}
