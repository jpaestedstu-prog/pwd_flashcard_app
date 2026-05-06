import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
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
import '../../../core/constants/flashcard_emojis.dart';
import '../timed_game_mixin.dart';
import '../../../l10n/app_localizations.dart';

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
    with TimedGameMixin {
  /// Difficulty-based pair count
  int get _pairs => switch (widget.difficulty) {
    GameDifficulty.easy => 4,   // 4×2 grid (8 cards)
    GameDifficulty.medium => 6, // 4×3 grid (12 cards)
    GameDifficulty.hard => 8,   // 4×4 grid (16 cards)
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
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    disposeTimer();
    super.dispose();
  }

  @override
  void onTimeUp() {
    _timer?.cancel();
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _setupGame() {
    var allCards = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      allCards = allCards.where((c) => widget.categories.contains(c.category)).toList();
    }
    allCards.shuffle();
    _sourceCards = allCards.take(_pairs).toList();

    _cards = [];
    for (final card in _sourceCards) {
      // Word card
      _cards.add(_MemoryCard(
        id: '${card.id}_word',
        pairId: card.id,
        displayText: card.wordEnglish,
        isImage: false,
        emoji: FlashcardEmojis.forId(card.id),
        icon: card.category.icon,
        color: card.category.color,
      ));
      // Image/emoji card
      _cards.add(_MemoryCard(
        id: '${card.id}_img',
        pairId: card.id,
        displayText: card.wordFilipino,
        isImage: true,
        emoji: FlashcardEmojis.forId(card.id),
        icon: card.category.icon,
        color: card.category.color,
      ));
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
              context: context, ref: ref, type: CelebrationType.gameComplete,
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
    final categories = _sourceCards
        .map((c) => c.category)
        .toSet()
        .toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.memoryMatch,
      score: _pairs,
      total: _pairs,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition (all correct in memory match)
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final c in _sourceCards) {
        srResults[c.id] = true;
      }
      SpacedRepetitionService.recordBatch(profileId: profile.id, results: srResults);
    }
  }

  List<GameReviewItem> get _reviewItems => _sourceCards
      .map((c) => GameReviewItem(
            wordEnglish: c.wordEnglish,
            wordFilipino: c.wordFilipino,
            category: c.category,
            isCorrect: true,
          ))
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
                  onExit: () => context.go('/games'),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.go('/games'),
        ),
        title: Text(AppLocalizations.of(context)!.memoryMatch),
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
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 18, color: hc.textSecondary),
                  const SizedBox(width: 4),
                  Text('$_moves moves',
                      style: AppTypography.labelMedium
                          .copyWith(color: hc.textSecondary)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.timer_rounded,
                      size: 18, color: hc.textSecondary),
                  const SizedBox(width: 4),
                  Text('${_elapsedSeconds}s',
                      style: AppTypography.labelMedium
                          .copyWith(color: hc.textSecondary)),
                ],
              ),
            ),
          ),
        ],
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
                label: 'Matched $_matchedPairs of $_pairs pairs in $_moves moves, $_elapsedSeconds seconds elapsed',
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
                  childAspectRatio: 0.78,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return _MemoryCardWidget(
                    card: card,
                    onTap: () => _flipCard(index),
                  );
                },
              ),
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
  final String emoji;
  final IconData icon;
  final Color color;
  bool isFlipped = false;
  bool isMatched = false;

  _MemoryCard({
    required this.id,
    required this.pairId,
    required this.displayText,
    required this.isImage,
    required this.emoji,
    required this.icon,
    required this.color,
  });
}

class _MemoryCardWidget extends StatelessWidget {
  final _MemoryCard card;
  final VoidCallback onTap;

  const _MemoryCardWidget({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
            child: isFront ? _buildBack() : _buildFront(context),
          );
        },
      ),
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Center(
        child: Icon(
          Icons.question_mark_rounded,
          size: 32,
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
              Text(card.emoji, style: const TextStyle(fontSize: 28)),
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
