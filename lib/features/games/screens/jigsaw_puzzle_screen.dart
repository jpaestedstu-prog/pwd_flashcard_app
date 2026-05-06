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
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../timed_game_mixin.dart';

class JigsawPuzzleScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const JigsawPuzzleScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<JigsawPuzzleScreen> createState() =>
      _JigsawPuzzleScreenState();
}

class _JigsawPuzzleScreenState extends ConsumerState<JigsawPuzzleScreen>
    with TimedGameMixin {
  late List<Flashcard> _allCards;
  late List<Flashcard> _puzzleCards;
  int _currentPuzzle = 0;
  int _score = 0;
  int _movesUsed = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  // Puzzle state for current card
  late List<int> _shuffledPieceOrder; // indices into flattened grid
  late List<bool> _placedPieces; // which pieces are in correct position
  int? _selectedPieceIndex; // index in shuffled list
  int? _selectedGridSlot; // index in grid (flattened)

  /// Difficulty-based grid size
  int get _gridSize => switch (widget.difficulty) {
    GameDifficulty.easy => 2,
    GameDifficulty.medium => 3,
    GameDifficulty.hard => 4,
  };

  int get _totalPieces => _gridSize * _gridSize;

  int get _totalPuzzles => switch (widget.difficulty) {
    GameDifficulty.easy => 4,
    GameDifficulty.medium => 3,
    GameDifficulty.hard => 2,
  };

  /// Optimal moves = number of pieces (best case each piece placed once)
  int get _optimalMoves => _totalPieces * _totalPuzzles;

  @override
  void initState() {
    super.initState();
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source =
          source.where((c) => widget.categories.contains(c.category)).toList();
    }
    _allCards = source..shuffle(_random);
    _puzzleCards = _allCards.take(_totalPuzzles).toList();
    _initPuzzle();
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
    final celebType = _starsEarned >= 3
        ? CelebrationType.perfectScore
        : CelebrationType.gameComplete;
    AccessibleCelebrationOverlay.show(context: context, ref: ref, type: celebType);
    ref.read(hapticServiceProvider).gameComplete();
    setState(() => _showResult = true);
  }

  void _initPuzzle() {
    _shuffledPieceOrder = List.generate(_totalPieces, (i) => i)
      ..shuffle(_random);
    _placedPieces = List.filled(_totalPieces, false);
    _selectedPieceIndex = null;
    _selectedGridSlot = null;
  }

  void _selectPiece(int shuffledIndex) {
    if (_placedPieces[_shuffledPieceOrder[shuffledIndex]]) return;
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _selectedPieceIndex = shuffledIndex;
      _selectedGridSlot = null;
    });
  }

  void _selectGridSlot(int gridIndex) {
    if (_placedPieces[gridIndex]) return;

    if (_selectedPieceIndex == null) {
      // Select a grid slot first (no piece selected yet)
      ref.read(hapticServiceProvider).lightTap();
      setState(() => _selectedGridSlot = gridIndex);
      return;
    }

    final sound = ref.read(soundServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    final actualPieceIndex = _shuffledPieceOrder[_selectedPieceIndex!];

    setState(() {
      _movesUsed++;
      if (actualPieceIndex == gridIndex) {
        // Correct placement!
        _placedPieces[gridIndex] = true;
        _selectedPieceIndex = null;
        _selectedGridSlot = null;
        sound.playCorrect();
        haptic.success();

        // Check if puzzle is complete
        if (_placedPieces.every((p) => p)) {
          _onPuzzleComplete();
        }
      } else {
        // Wrong placement
        _selectedPieceIndex = null;
        _selectedGridSlot = null;
        sound.playWrong();
        haptic.error();
      }
    });
  }

  void _onPuzzleComplete() {
    final card = _puzzleCards[_currentPuzzle];
    _reviewItems.add(GameReviewItem(
      wordEnglish: card.wordEnglish,
      wordFilipino: card.wordFilipino,
      category: card.category,
      isCorrect: true,
    ));
    _score++;

    if (_currentPuzzle < _totalPuzzles - 1) {
      // Move to next puzzle after a short celebration
      AccessibleCelebrationOverlay.show(context: context, ref: ref, type: CelebrationType.correctAnswer);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          _currentPuzzle++;
          _initPuzzle();
        });
      });
    } else {
      _saveProgress();
      final celebType = _starsEarned >= 3
          ? CelebrationType.perfectScore
          : CelebrationType.gameComplete;
      AccessibleCelebrationOverlay.show(context: context, ref: ref, type: celebType);
      ref.read(hapticServiceProvider).gameComplete();
      setState(() => _showResult = true);
    }
  }

  int get _starsEarned {
    // Stars based on efficiency (fewer moves = better score)
    final efficiency = _optimalMoves / max(_movesUsed, 1);
    if (efficiency >= 0.9) return 3;
    if (efficiency >= 0.7) return 2;
    if (efficiency >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories =
        _puzzleCards.map((c) => c.category).toSet().toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.jigsawPuzzle,
      score: _score,
      total: _totalPuzzles,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements =
        ref.read(progressProvider.notifier).checkAchievements();

    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final card in _puzzleCards) {
        srResults[card.id] = true; // completed puzzles count as correct
      }
      SpacedRepetitionService.recordBatch(
          profileId: profile.id, results: srResults);
    }
  }

  void _restart() {
    setState(() {
      _currentPuzzle = 0;
      _score = 0;
      _movesUsed = 0;
      _showResult = false;
      _reviewItems.clear();
      _newAchievements = [];
      _allCards.shuffle(_random);
      _puzzleCards = _allCards.take(_totalPuzzles).toList();
      _initPuzzle();
      startTimerIfNeeded(widget.timedMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultScreen(context);
    }
    return _buildGameScreen(context);
  }

  Widget _buildResultScreen(BuildContext context) {
    final celebration = ref.read(celebrationServiceProvider);
    final celebType = _starsEarned >= 3
        ? CelebrationType.perfectScore
        : CelebrationType.gameComplete;

    return LottieCelebrationOverlay(
      show: true,
      lottieAsset: celebration.lottieAssetFor(celebType),
      child: Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _score,
                  total: _totalPuzzles,
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.go('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Jigsaw Puzzle',
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
      ),
    );
  }

  Widget _buildGameScreen(BuildContext context) {
    final card = _puzzleCards[_currentPuzzle];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.go('/games'),
        ),
        title: Text(
            'Jigsaw Puzzle  •  ${_currentPuzzle + 1}/$_totalPuzzles'),
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
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Progress bar ─────────────────────
            Semantics(
              label:
                  'Puzzle ${_currentPuzzle + 1} of $_totalPuzzles',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentPuzzle + 1) / _totalPuzzles,
                  minHeight: 6,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Word hint ────────────────────────
            Semantics(
              label: 'Complete the puzzle for: ${card.wordEnglish}, ${card.wordFilipino}',
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: card.category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: card.category.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlashcardImage(card: card, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.wordEnglish,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: card.category.darkColor,
                          ),
                        ),
                        Text(
                          card.wordFilipino,
                          style: AppTypography.bodySmall.copyWith(
                            color: HCColor.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Moves: $_movesUsed',
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate(key: ValueKey(_currentPuzzle))
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 16),

            // ─── Puzzle Grid (target) ─────────────
            Expanded(
              flex: 5,
              child: _buildPuzzleGrid(card),
            ),
            const SizedBox(height: 12),

            // ─── Piece Tray (unplaced pieces) ─────
            Expanded(
              flex: 2,
              child: _buildPieceTray(card),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleGrid(Flashcard card) {
    return LayoutBuilder(builder: (context, constraints) {
      final gridExtent =
          min(constraints.maxWidth, constraints.maxHeight);
      final pieceW = gridExtent / _gridSize;
      final pieceH = gridExtent / _gridSize;

      return Center(
        child: SizedBox(
          width: gridExtent,
          height: gridExtent,
          child: Stack(
            children: [
              // Background grid outline
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: card.category.color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  color: card.category.color.withValues(alpha: 0.05),
                ),
              ),
              // Grid slots
              ...List.generate(_totalPieces, (index) {
                final r = index ~/ _gridSize;
                final c = index % _gridSize;
                final isPlaced = _placedPieces[index];
                final isSelected = _selectedGridSlot == index;

                return Positioned(
                  left: c * pieceW,
                  top: r * pieceH,
                  width: pieceW,
                  height: pieceH,
                  child: GestureDetector(
                    onTap: isPlaced ? null : () => _selectGridSlot(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : card.category.color.withValues(alpha: 0.2),
                          width: isSelected ? 3 : 1,
                        ),
                        color: isPlaced
                            ? Colors.transparent
                            : isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : card.category.color
                                    .withValues(alpha: 0.03),
                      ),
                      child: isPlaced
                          ? ClipRect(
                              child: Align(
                                alignment: Alignment(
                                  -1.0 +
                                      2.0 * c / (_gridSize - 1),
                                  -1.0 +
                                      2.0 * r / (_gridSize - 1),
                                ),
                                widthFactor: 1.0 / _gridSize,
                                heightFactor: 1.0 / _gridSize,
                                child: FlashcardImage(
                                  card: card,
                                  size: gridExtent * 0.5,
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                '${r * _gridSize + c + 1}',
                                style:
                                    AppTypography.bodySmall.copyWith(
                                  color: HCColor.of(context).textSecondary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPieceTray(Flashcard card) {
    final unplacedIndices = <int>[];
    for (int i = 0; i < _shuffledPieceOrder.length; i++) {
      if (!_placedPieces[_shuffledPieceOrder[i]]) {
        unplacedIndices.add(i);
      }
    }

    if (unplacedIndices.isEmpty) {
      return Center(
        child: Text(
          'All pieces placed! 🎉',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn().scale(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap a piece, then tap a grid slot',
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: unplacedIndices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final shuffledIdx = unplacedIndices[i];
                final gridIdx = _shuffledPieceOrder[shuffledIdx];
                final r = gridIdx ~/ _gridSize;
                final c = gridIdx % _gridSize;
                final isSelected = _selectedPieceIndex == shuffledIdx;

                return GestureDetector(
                  onTap: () => _selectPiece(shuffledIdx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : card.category.color
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : card.category.color
                                .withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: card.category.color
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${r + 1},${c + 1}',
                            style: AppTypography.labelMedium.copyWith(
                              color: card.category.darkColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
