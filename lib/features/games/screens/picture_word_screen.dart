import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';

/// Picture-Word Association Game
///
/// Mode A: Show 4 pictures → read a word → tap the matching picture.
/// Mode B: Show 1 picture → display 4 words → tap the correct word.
/// Alternates between modes each round for variety.
/// Especially effective for visual/cognitive learners and non-readers.
class PictureWordScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const PictureWordScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<PictureWordScreen> createState() => _PictureWordScreenState();
}

class _PictureWordScreenState extends ConsumerState<PictureWordScreen>
    with TimedGameMixin, GamePauseMixin {
  late List<Flashcard> _allCards;
  late List<_PictureWordRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  int get _totalRounds => switch (widget.difficulty) {
    GameDifficulty.easy => 6,
    GameDifficulty.medium => 10,
    GameDifficulty.hard => 14,
  };

  int get _numChoices => switch (widget.difficulty) {
    GameDifficulty.easy => 3,
    GameDifficulty.medium => 4,
    GameDifficulty.hard => 4,
  };

  @override
  void initState() {
    super.initState();
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source =
          source.where((c) => widget.categories.contains(c.category)).toList();
    }
    _allCards = source..shuffle(_random);
    _generateRounds();
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
    if (_rounds.isEmpty) return;
    _saveProgress();
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

  void _generateRounds() {
    _rounds = [];
    final shuffled = List.of(_allCards)..shuffle(_random);
    for (int i = 0; i < _totalRounds && i < shuffled.length; i++) {
      final correct = shuffled[i];
      final others = _allCards.where((c) => c.id != correct.id).toList()
        ..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);
      _rounds.add(_PictureWordRound(
        correctCard: correct,
        choices: choices,
        correctIndex: choices.indexOf(correct),
        isPictureMode: i % 2 == 0, // alternate modes
      ));
    }
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final sound = ref.read(soundServiceProvider);
    setState(() {
      _selectedIndex = index;
      _answered = true;
      final round = _rounds[_currentRound];
      final isCorrect = index == round.correctIndex;
      _reviewItems.add(GameReviewItem(
        wordEnglish: round.correctCard.wordEnglish,
        wordFilipino: round.correctCard.wordFilipino,
        category: round.correctCard.category,
        isCorrect: isCorrect,
        userAnswer: isCorrect ? null : round.choices[index].wordEnglish,
      ));
      if (isCorrect) {
        _score++;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentRound < _rounds.length - 1) {
        setState(() {
          _currentRound++;
          _selectedIndex = null;
          _answered = false;
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
    });
  }

  void _restart() {
    setState(() {
      _currentRound = 0;
      _score = 0;
      _selectedIndex = null;
      _answered = false;
      _showResult = false;
      _reviewItems.clear();
      _allCards.shuffle(_random);
      _generateRounds();
      startTimerIfNeeded(widget.timedMode);
    });
  }

  int get _starsEarned {
    final pct = _score / _rounds.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories =
        _rounds.map((r) => r.correctCard.category).toSet().toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.pictureWord,
      score: _score,
      total: _rounds.length,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements =
        ref.read(progressProvider.notifier).checkAchievements();

    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final r in _reviewItems) {
        final card =
            _allCards.where((c) => c.wordEnglish == r.wordEnglish).firstOrNull;
        if (card != null) srResults[card.id] = r.isCorrect;
      }
      SpacedRepetitionService.recordBatch(
          profileId: profile.id, results: srResults);
    }
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
                  total: _rounds.length,
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.go('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Picture-Word',
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
    final round = _rounds[_currentRound];

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
        title: Text(
            'Picture-Word  •  ${_currentRound + 1}/${_rounds.length}'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── Progress bar ─────────────────────
            Semantics(
              label: 'Round ${_currentRound + 1} of ${_rounds.length}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentRound + 1) / _rounds.length,
                  minHeight: 6,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (round.isPictureMode)
              _buildPictureMode(round)
            else
              _buildWordMode(round),
          ],
        ),
      ),
    ),
        if (isPaused)
          PauseOverlay(
            onResume: resumeGame,
            onRestart: () {
              resumeGame();
              _restart();
            },
            onQuit: () async {
              await savePartialProgress();
              if (context.mounted) context.go('/games');
            },
          ),
      ]),
    );
  }

  /// Mode A: Show word prompt at top, show 4 pictures as choices
  Widget _buildPictureMode(_PictureWordRound round) {
    return Expanded(
      child: Column(
        children: [
          // ─── Word prompt ────────────────────
          Semantics(
            label: 'Find the picture for: ${round.correctCard.wordEnglish}',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: round.correctCard.category.color
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: round.correctCard.category.color
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Find the picture for:',
                    style: AppTypography.bodyMedium.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    round.correctCard.wordEnglish,
                    style: AppTypography.headlineMedium.copyWith(
                      color: round.correctCard.category.darkColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    round.correctCard.wordFilipino,
                    style: AppTypography.titleSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate(key: ValueKey(_currentRound))
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.1, end: 0),
          const SizedBox(height: 24),

          // ─── Picture choices grid ───────────
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.isLargeTablet ? 4 : 2,
                mainAxisSpacing: context.gridSpacing * 0.75,
                crossAxisSpacing: context.gridSpacing * 0.75,
              ),
              itemCount: round.choices.length,
              itemBuilder: (context, index) {
                final choice = round.choices[index];
                final isSelected = _selectedIndex == index;
                final isCorrect = index == round.correctIndex;
                final showCorrect = _answered && isCorrect;
                final showWrong = _answered && isSelected && !isCorrect;

                Color borderColor = AppColors.primary.withValues(alpha: 0.2);
                if (showCorrect) borderColor = AppColors.success;
                if (showWrong) borderColor = AppColors.error;

                return Semantics(
                  button: true,
                  label: 'Picture of ${choice.wordEnglish}'
                      '${showCorrect ? ', correct answer' : ''}'
                      '${showWrong ? ', wrong answer' : ''}',
                  child: GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: showCorrect
                            ? AppColors.successLight
                            : showWrong
                                ? AppColors.errorLight
                                : HCColor.of(context).surface,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: borderColor, width: 3),
                        boxShadow: [
                          if (isSelected && !_answered)
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Center(
                        child: FlashcardImage(
                          card: choice,
                          size: 56,
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

  /// Mode B: Show 1 picture at top, show 4 word choices at bottom
  Widget _buildWordMode(_PictureWordRound round) {
    return Expanded(
      child: Column(
        children: [
          // ─── Picture prompt ─────────────────
          Expanded(
            flex: 3,
            child: Semantics(
              label:
                  'Which word matches this picture? ${round.correctCard.wordEnglish}',
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: round.correctCard.category.color
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: round.correctCard.category.color
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FlashcardImage(card: round.correctCard),
                    const SizedBox(height: 12),
                    Text(
                      'Which word matches?',
                      style: AppTypography.titleMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate(key: ValueKey(_currentRound))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.1, end: 0),
          ),
          const SizedBox(height: 24),

          // ─── Word choices ───────────────────
          Expanded(
            flex: 3,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.responsiveTier<int>(
                  phone: 2,
                  tablet: 2,
                  large: 3,
                  xl: 4,
                ),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Shrink aspect ratio as text scales up so answer cells
                // stay tall enough to hold scaled label text at XL font.
                childAspectRatio: ((context.isLargeTablet ? 3.0 : 2.5) /
                        MediaQuery.textScalerOf(context).scale(1.0))
                    .clamp(1.4, 3.0),
              ),
              itemCount: round.choices.length,
              itemBuilder: (context, index) {
                final choice = round.choices[index];
                final isSelected = _selectedIndex == index;
                final isCorrect = index == round.correctIndex;
                final showCorrect = _answered && isCorrect;
                final showWrong =
                    _answered && isSelected && !isCorrect;

                Color bgColor = HCColor.of(context).surface;
                Color borderColor =
                    AppColors.primary.withValues(alpha: 0.2);
                Color textColor = HCColor.of(context).textPrimary;

                if (showCorrect) {
                  bgColor = AppColors.successLight;
                  borderColor = AppColors.success;
                  textColor = AppColors.successDark;
                } else if (showWrong) {
                  bgColor = AppColors.errorLight;
                  borderColor = AppColors.error;
                  textColor = AppColors.errorDark;
                }

                return Semantics(
                  button: true,
                  label: 'Answer: ${choice.wordEnglish}'
                      '${showCorrect ? ', correct' : ''}'
                      '${showWrong ? ', wrong' : ''}',
                  child: GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: borderColor, width: 2),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              choice.wordEnglish,
                              style:
                                  AppTypography.titleMedium.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              choice.wordFilipino,
                              style:
                                  AppTypography.bodySmall.copyWith(
                                color: textColor
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
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

class _PictureWordRound {
  final Flashcard correctCard;
  final List<Flashcard> choices;
  final int correctIndex;
  final bool isPictureMode;

  const _PictureWordRound({
    required this.correctCard,
    required this.choices,
    required this.correctIndex,
    required this.isPictureMode,
  });
}
