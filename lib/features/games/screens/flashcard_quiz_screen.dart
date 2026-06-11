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
import '../../../widgets/flashcard_image.dart';
import '../../../core/utils/responsive_utils.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
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
    with SingleTickerProviderStateMixin, TimedGameMixin, GamePauseMixin {
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
    initPause();
  }

  void _startGame() {
    var all = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      all = all.where((c) => widget.categories.contains(c.category)).toList();
    }
    _cards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: all,
      count: _totalCards,
    );
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
    disposePause();
    disposeTimer();
    super.dispose();
  }

  @override
  Future<void> savePartialProgress() async {
    if (_cards.isEmpty) return;
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

  // Horizontal-only drag: the card tracks left/right (Tinder-style) and
  // never moves vertically, keeping the swipe clean and unambiguous.
  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += Offset(details.delta.dx, 0);
      _dragRotation = _dragOffset.dx * 0.001;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset.dx.abs() > 100) {
      _handleSwipe(_dragOffset.dx > 0);
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
        title: Text('${_currentIndex + 1} / $_totalCards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline_rounded),
            tooltip: 'Pause',
            onPressed: pauseGame,
          ),
          if (isTimedMode)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GameTimerWidget(
                remainingSeconds: remainingSeconds,
                totalSeconds: totalTimerSeconds,
                size: 44,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Single status block: rounded progress + score chips ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Semantics(
              label:
                  'Card ${_currentIndex + 1} of $_totalCards, $_knowCount known, $_learningCount still learning',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _totalCards,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                value: _knowCount,
                semanticLabel: '$_knowCount known',
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.school_rounded,
                color: AppColors.warning,
                value: _learningCount,
                semanticLabel: '$_learningCount still learning',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Swipeable Card ───────────────────
          // ConstrainedBox + AspectRatio keep a stable card footprint; the
          // card body sizes its words consistently (see [_QuizCard]) so every
          // card looks the same regardless of content length.
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive(phone: 320, tablet: 420),
                  maxHeight: context.responsive(phone: 440, tablet: 560),
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Semantics(
                    label:
                        'Flashcard: ${card.wordEnglish}, ${card.wordFilipino}, category ${card.category.label}. Swipe right for I Know, left for Still Learning',
                    child: GestureDetector(
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        transform: Matrix4.identity()
                          ..storage[12] = _dragOffset.dx
                          ..rotateZ(_dragRotation),
                        transformAlignment: Alignment.center,
                        child: _QuizCard(card: card, dragX: _dragOffset.dx),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: context.responsive(phone: 16, tablet: 24)),

          // ─── Action Buttons (carry the directional swipe hints) ──────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: AppLocalizations.of(context)!.stillLearningSwipe,
                  color: AppColors.error,
                  onTap: () => _handleSwipe(false),
                ),
                _ActionButton(
                  icon: Icons.check_rounded,
                  label: AppLocalizations.of(context)!.iKnowThisSwipe,
                  color: AppColors.success,
                  onTap: () => _handleSwipe(true),
                ),
              ],
            ),
          ),

          SizedBox(height: context.responsive(phone: 12, tablet: 20)),
        ],
      ),
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
        child: Builder(builder: (context) {
          final size = context.responsiveSize(60);
          return Column(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: size * 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────
// Status chip (known / still-learning count)
// ────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String semanticLabel;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: AppTypography.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// Quiz Card (front face + swipe stamps)
// ────────────────────────────────────────
class _QuizCard extends StatelessWidget {
  final Flashcard card;
  final double dragX;

  const _QuizCard({required this.card, required this.dragX});

  @override
  Widget build(BuildContext context) {
    final cat = card.category;
    final swiping = dragX.abs() > 40;
    // Card border tints toward the decision colour as you drag.
    final borderColor = dragX > 40
        ? AppColors.success
        : dragX < -40
            ? AppColors.error
            : cat.color.withValues(alpha: 0.3);

    return Stack(
      fit: StackFit.expand,
      children: [
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor, width: swiping ? 2.5 : 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HCColor.of(context).surface,
                  cat.color.withValues(alpha: 0.08),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Category badge (fixed at top)
                _CategoryBadge(category: cat),
                const SizedBox(height: 12),
                // Hero image (upper area) scales down to share the card.
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FlashcardImage(
                        card: card,
                        size: context.responsive(phone: 104, tablet: 132),
                        borderRadius: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Word block (lower area). The width constraint keeps the
                // example wrapping at the default font scale (so text stays a
                // consistent size card-to-card), while the FittedBox scales the
                // whole group down only when a large font scale would otherwise
                // overflow the card — never truncating the word being learned.
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, c) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.wordEnglish,
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: HCColor.of(context).textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card.wordFilipino,
                              textAlign: TextAlign.center,
                              style: AppTypography.titleLarge.copyWith(
                                color: cat.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (card.exampleSentence != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '"${card.exampleSentence}"',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: HCColor.of(context).textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // On-card swipe stamps — visible decision feedback while dragging.
        Positioned(
          top: 18,
          left: 18,
          child: _SwipeStamp(
            label: AppLocalizations.of(context)!.iKnow,
            icon: Icons.check_rounded,
            color: AppColors.success,
            angle: -0.22,
            opacity: (dragX / 90).clamp(0.0, 1.0),
          ),
        ),
        Positioned(
          top: 18,
          right: 18,
          child: _SwipeStamp(
            label: AppLocalizations.of(context)!.learning,
            icon: Icons.school_rounded,
            color: AppColors.error,
            angle: 0.22,
            opacity: (-dragX / 90).clamp(0.0, 1.0),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// Category Badge
// ────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  final FlashcardCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 16, color: category.color),
          const SizedBox(width: 6),
          // Ellipsise a long category name at a large font scale rather than
          // pushing the pill past the card's width.
          Flexible(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(color: category.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Swipe Stamp (fades in over the card while dragging)
// ────────────────────────────────────────
class _SwipeStamp extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double angle;
  final double opacity;

  const _SwipeStamp({
    required this.label,
    required this.icon,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
