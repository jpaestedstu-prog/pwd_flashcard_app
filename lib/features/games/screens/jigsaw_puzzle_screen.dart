import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/flashcard_image.dart';
import '../jigsaw/jigsaw_piece_widget.dart';
import '../jigsaw/jigsaw_piece_clipper.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';

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
  ConsumerState<JigsawPuzzleScreen> createState() => _JigsawPuzzleScreenState();
}

class _JigsawPuzzleScreenState extends ConsumerState<JigsawPuzzleScreen>
    with TimedGameMixin, GamePauseMixin {
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

  /// Jigsaw tab/blank edge shapes for the current grid size (constant for the
  /// whole game since difficulty is fixed). Indexed [row][col]; adjacent pieces
  /// share matching tab/blank edges so they interlock visually.
  late final List<List<JigsawPieceClipper>> _clipperGrid;

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
    _clipperGrid = JigsawPieceClipper.generateGrid(_gridSize, _gridSize);
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }
    _allCards = source;
    _puzzleCards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: _allCards,
      count: _totalPuzzles,
      random: _random,
    );
    _initPuzzle();
    startTimerIfNeeded(widget.timedMode);
    initPause();
  }

  @override
  void dispose() {
    disposePause();
    disposeTimer();
    super.dispose();
  }

  @override
  Future<void> savePartialProgress() async {
    if (_puzzleCards.isEmpty) return;
    _saveProgress();
  }

  @override
  void onTimeUp() {
    _saveProgress();
    final celebType = _starsEarned >= 3
        ? CelebrationType.perfectScore
        : CelebrationType.gameComplete;
    AccessibleCelebrationOverlay.show(
      context: context,
      ref: ref,
      type: celebType,
    );
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
    _reviewItems.add(
      GameReviewItem(
        wordEnglish: card.wordEnglish,
        wordFilipino: card.wordFilipino,
        category: card.category,
        isCorrect: true,
      ),
    );
    _score++;

    if (_currentPuzzle < _totalPuzzles - 1) {
      // Move to next puzzle after a short celebration
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: CelebrationType.correctAnswer,
      );
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
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: celebType,
      );
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
    final categories = _puzzleCards.map((c) => c.category).toSet().toList();
    // Per-word results — feeds both wordsLearned and spaced repetition.
    final srResults = <String, bool>{};
    for (final card in _puzzleCards) {
      srResults[card.id] = true; // completed puzzles count as correct
    }

    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.jigsawPuzzle,
          score: _score,
          total: _totalPuzzles,
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

  void _restart() {
    setState(() {
      _currentPuzzle = 0;
      _score = 0;
      _movesUsed = 0;
      _showResult = false;
      _reviewItems.clear();
      _newAchievements = [];
      _puzzleCards = AdaptiveDifficultyService.pickGameCards(
        profileId: ref.read(profileProvider)?.id,
        cards: _allCards,
        count: _totalPuzzles,
        random: _random,
      );
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
                  onExit: () => context.popOrGo('/games'),
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

    return PopScope(
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
                title: Text(
                  'Jigsaw Puzzle  •  ${_currentPuzzle + 1}/$_totalPuzzles',
                ),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 20,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_score',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
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
                  // ─── Progress bar ─────────────────────
                  Semantics(
                    label: 'Puzzle ${_currentPuzzle + 1} of $_totalPuzzles',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPuzzle + 1) / _totalPuzzles,
                        minHeight: 6,
                        backgroundColor: AppColors.primaryLight.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Word hint ────────────────────────
                  Semantics(
                    label:
                        'Complete the puzzle for: ${card.wordEnglish}, ${card.wordFilipino}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HCColor.of(
                                context,
                              ).surface.withValues(alpha: 0.7),
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
                  ).animate(key: ValueKey(_currentPuzzle)).fadeIn(duration: 300.ms),
                  const SizedBox(height: 16),

                  // ─── Puzzle Grid (target) ─────────────
                  Expanded(flex: 5, child: _buildPuzzleGrid(card)),
                  const SizedBox(height: 12),
                  Text(
                    'Tap a piece, then tap a grid slot',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ─── Piece Tray (unplaced pieces) ─────
                  Expanded(flex: 2, child: _buildPieceTray(card)),
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
    );
  }

  /// Builds the full square "picture" that gets sliced into pieces. Seed cards
  /// have no photo (`imageAsset` is always null), so we fill the square
  /// edge-to-edge with the category gradient + a large centred emoji — that way
  /// every piece (corners included) carries distinguishable content.
  Widget _buildPuzzlePanel(Flashcard card, double extent) {
    final cat = card.category;
    return SizedBox(
      width: extent,
      height: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cat.color.withValues(alpha: 0.9),
              cat.darkColor.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Center(
          child: FlashcardPicture(card: card, extent: extent * 0.6),
        ),
      ),
    );
  }

  Widget _buildPuzzleGrid(Flashcard card) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridExtent = min(constraints.maxWidth, constraints.maxHeight);
        final pieceW = gridExtent / _gridSize;
        final pieceH = gridExtent / _gridSize;
        // One source panel, reused (an immutable config) by the faint guide and
        // every placed piece so the fragments line up into the same image.
        final panel = _buildPuzzlePanel(card, gridExtent);

        return Center(
          child: SizedBox(
            width: gridExtent,
            height: gridExtent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Faint full-image guide (placement aid) ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Opacity(opacity: 0.15, child: panel),
                    ),
                  ),
                ),
                // ── Rounded frame ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: card.category.color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Empty-slot tap targets ──
                ...List.generate(_totalPieces, (index) {
                  if (_placedPieces[index]) return const SizedBox.shrink();
                  final r = index ~/ _gridSize;
                  final c = index % _gridSize;
                  final isSelected = _selectedGridSlot == index;
                  return Positioned(
                    left: c * pieceW,
                    top: r * pieceH,
                    width: pieceW,
                    height: pieceH,
                    child: GestureDetector(
                      onTap: () => _selectGridSlot(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : card.category.color.withValues(alpha: 0.25),
                            width: isSelected ? 3 : 1,
                          ),
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }),
                // ── Placed pieces (assemble the picture) ──
                ...List.generate(_totalPieces, (index) {
                  if (!_placedPieces[index]) return const SizedBox.shrink();
                  final r = index ~/ _gridSize;
                  final c = index % _gridSize;
                  return Positioned(
                    // Core sits exactly in the slot; the piece's tabs overflow
                    // into neighbours (the Stack uses Clip.none) like a real
                    // jigsaw, and align seamlessly since every piece samples the
                    // same source panel.
                    left: c * pieceW,
                    top: r * pieceH,
                    child: IgnorePointer(
                      child: JigsawPieceWidget(
                        row: r,
                        col: c,
                        rows: _gridSize,
                        cols: _gridSize,
                        clipper: _clipperGrid[r][c],
                        sourceImage: panel,
                        pieceWidth: pieceW,
                        pieceHeight: pieceH,
                        isPlaced: true,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      // Pieces only — the "tap a piece" instruction lives above the tray in
      // the body so a short tray never has to host a fixed header that would
      // squeeze (and overflow) the piece row.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Size each piece to the tray height. The widget adds 18% tab
          // padding around the core, so total height ≈ core × 1.36.
          // Cap at the available height (never a fixed 44 floor) so a short
          // tray on a landscape phone / large font scale doesn't overflow.
          final pieceExtent = min(constraints.maxHeight, 96.0);
          final core = pieceExtent / 1.36;
          final panel = _buildPuzzlePanel(card, core * _gridSize);

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: unplacedIndices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final shuffledIdx = unplacedIndices[i];
              final gridIdx = _shuffledPieceOrder[shuffledIdx];
              final r = gridIdx ~/ _gridSize;
              final c = gridIdx % _gridSize;
              final isSelected = _selectedPieceIndex == shuffledIdx;

              // Item box reserves the tab margin (core × 1.36 ≈ pieceExtent)
              // so the overflowing tabs stay inside the tile's footprint.
              return SizedBox(
                width: pieceExtent,
                height: pieceExtent,
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: JigsawPieceWidget(
                        row: r,
                        col: c,
                        rows: _gridSize,
                        cols: _gridSize,
                        clipper: _clipperGrid[r][c],
                        sourceImage: panel,
                        pieceWidth: core,
                        pieceHeight: core,
                        onTap: () => _selectPiece(shuffledIdx),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
