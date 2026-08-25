import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/action_clip_service.dart';
import '../../flashcards/widgets/show_me_button.dart';
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
import '../game_resume_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';
import '../../../l10n/app_localizations.dart';

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

  /// Pick up the unfinished run the learner left behind rather than dealing a
  /// fresh one. Set by the Games hub after asking.
  final bool resume;

  const PictureWordScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
    this.resume = false,
  });

  @override
  ConsumerState<PictureWordScreen> createState() => _PictureWordScreenState();
}

class _PictureWordScreenState extends ConsumerState<PictureWordScreen>
    with TimedGameMixin, GamePauseMixin, GameResumeMixin {
  // ─── Resume wiring ───────────────────────────────
  @override
  GameType get resumeGameType => GameType.pictureWord;
  @override
  GameDifficulty get resumeDifficulty => widget.difficulty;
  @override
  List<FlashcardCategory> get resumeCategories => widget.categories;
  @override
  bool get resumeTimedMode => widget.timedMode;
  @override
  String? get resumeProfileId => ref.read(profileProvider)?.id;
  @override
  List<String> get resumeDeckIds =>
      _rounds.map((r) => r.correctCard.id).toList();
  @override
  int get resumeIndex => _currentRound;
  @override
  int get resumeScore => _score;
  @override
  bool get resumeFinished => _showResult;

  /// Re-deal the run the learner walked away from. The snapshot holds the deck
  /// and how far in they got; the choices are drawn fresh here. The picture /
  /// word alternation is positional, so rebuilding in order keeps each round
  /// in the mode it was originally shown in.
  void _restoreSaved() {
    final snapshot = readResumePoint();
    if (snapshot == null) return;
    final byId = {for (final c in SeedData.allFlashcards) c.id: c};
    final deck = snapshot.cardIds
        .map((id) => byId[id])
        .whereType<Flashcard>()
        .toList();
    if (deck.length != snapshot.cardIds.length) return;

    final rebuilt = <_PictureWordRound>[];
    for (var i = 0; i < deck.length; i++) {
      final correct = deck[i];
      final others = _allCards.where((c) => c.id != correct.id).toList()
        ..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);
      rebuilt.add(
        _PictureWordRound(
          correctCard: correct,
          choices: choices,
          correctIndex: choices.indexOf(correct),
          isPictureMode: i % 2 == 0,
        ),
      );
    }
    setState(() {
      _rounds = rebuilt;
      _currentRound = snapshot.roundIndex;
      _score = snapshot.score;
    });
  }

  late List<Flashcard> _allCards;
  late List<_PictureWordRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;

  /// Gaze cursor: index of the highlighted choice. Only used/visible when Gaze
  /// Control is enabled; touch ignores it.
  int _cursorIndex = 0;
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
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }
    _allCards = source..shuffle(_random);
    _generateRounds();
    if (widget.resume) _restoreSaved();
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
    _saveProgress(completed: false);
    // Quitting is the moment worth remembering: the hub can offer to bring
    // the learner straight back to this round.
    saveResumePoint();
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
    clearResumePoint();
    setState(() => _showResult = true);
  }

  void _generateRounds() {
    _rounds = [];
    final shuffled = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: _allCards,
      count: _totalRounds,
      random: _random,
    );
    for (int i = 0; i < _totalRounds && i < shuffled.length; i++) {
      final correct = shuffled[i];
      final others = _allCards.where((c) => c.id != correct.id).toList()
        ..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);
      _rounds.add(
        _PictureWordRound(
          correctCard: correct,
          choices: choices,
          correctIndex: choices.indexOf(correct),
          isPictureMode: i % 2 == 0, // alternate modes
        ),
      );
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
      _reviewItems.add(
        GameReviewItem(
          wordEnglish: round.correctCard.wordEnglish,
          wordFilipino: round.correctCard.wordFilipino,
          category: round.correctCard.category,
          isCorrect: isCorrect,
          userAnswer: isCorrect ? null : round.choices[index].wordEnglish,
        ),
      );
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
          _cursorIndex = 0;
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
        clearResumePoint();
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
      _cursorIndex = 0;
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

  /// [completed] is false only on the "Quit to Games" path — an abandoned run
  /// still counts toward stats but is not fed to the adaptive engine as if
  /// every unplayed round were a miss.
  void _saveProgress({bool completed = true}) {
    final categories = _rounds
        .map((r) => r.correctCard.category)
        .toSet()
        .toList();
    // Per-word results — feeds both wordsLearned and spaced repetition.
    final srResults = <String, bool>{};
    for (final r in _reviewItems) {
      final card = _allCards
          .where((c) => c.wordEnglish == r.wordEnglish)
          .firstOrNull;
      if (card != null) srResults[card.id] = r.isCorrect;
    }

    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.pictureWord,
          score: _score,
          total: _rounds.length,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: srResults.correctWordIds,
          durationSeconds: elapsedSeconds,
          playedDifficulty: completed ? widget.difficulty : null,
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

  // ─── Gaze cursor (hands-free) ────────────────────
  // Look left/right to move the highlight across the answer choices, then look
  // down or blink to choose. Disabled while a result is showing or paused.
  // Inert unless the learner enabled Gaze Control.

  void _moveCursor(int delta) {
    final n = _rounds[_currentRound].choices.length;
    if (n <= 0) return;
    setState(() => _cursorIndex = (((_cursorIndex + delta) % n) + n) % n);
  }

  void _selectCursor() {
    if (_answered || isPaused) return;
    _selectAnswer(_cursorIndex);
  }

  List<GazeAction> _gazeActions() {
    final l10n = AppLocalizations.of(context)!;
    final canMove = !_answered && !isPaused;
    return [
      GazeAction(
        zone: GazeZone.left,
        label: l10n.gazePrev,
        icon: Icons.chevron_left_rounded,
        color: AppColors.secondary,
        enabled: canMove,
        onSelect: () => _moveCursor(-1),
      ),
      GazeAction(
        zone: GazeZone.right,
        label: l10n.gazeNext,
        icon: Icons.chevron_right_rounded,
        color: AppColors.secondary,
        enabled: canMove,
        onSelect: () => _moveCursor(1),
      ),
      GazeAction(
        zone: GazeZone.down,
        label: l10n.gazeChoose,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        enabled: canMove,
        onSelect: _selectCursor,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultScreen(context);
    }
    return _buildGameScreen(context);
  }

  Widget _buildResultScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  onExit: () => context.popOrGo('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: GameType.pictureWord.labelOf(l10n),
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
    final l10n = AppLocalizations.of(context)!;
    final round = _rounds[_currentRound];
    // Show the gaze cursor only when hands-free control is on and the round
    // hasn't been answered yet (the answer colours take over after that).
    final showCursor =
        ref.watch(gazeSettingsProvider.select((s) => s.enabled)) && !_answered;

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
                    tooltip: l10n.close,
                    onPressed: pauseGame,
                  ),
                  title: Text(
                    l10n.gameRoundHeader(
                      GameType.pictureWord.labelOf(l10n),
                      _currentRound + 1,
                      _rounds.length,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.pause_circle_outline_rounded),
                      tooltip: l10n.pauseLabel,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // ─── Progress bar ─────────────────────
                    Semantics(
                      label: l10n.resumeRoundProgress(
                        _currentRound + 1,
                        _rounds.length,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentRound + 1) / _rounds.length,
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
                    const SizedBox(height: 20),

                    if (round.isPictureMode)
                      _buildPictureMode(round, showCursor)
                    else
                      _buildWordMode(round, showCursor),
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

  /// Mode A: Show word prompt at top, show 4 pictures as choices
  Widget _buildPictureMode(_PictureWordRound round, bool showCursor) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: Column(
        children: [
          // ─── Word prompt ────────────────────
          Semantics(
                label: l10n.findPictureForSemantics(
                  round.correctCard.wordEnglish,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: round.correctCard.category.color.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: round.correctCard.category.color.withValues(
                        alpha: 0.3,
                      ),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.findPictureFor,
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
          // Optional "Show Me" action demo for verb cards. Adds nothing to
          // the layout unless a clip is actually configured for this word.
          if (ActionClipService.hasClip(round.correctCard)) ...[
            const SizedBox(height: 12),
            Center(child: ShowMeButton(card: round.correctCard)),
          ],
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
                final highlighted = showCursor && index == _cursorIndex;

                Color borderColor = AppColors.primary.withValues(alpha: 0.2);
                if (highlighted) borderColor = AppColors.primary;
                if (showCorrect) borderColor = AppColors.success;
                if (showWrong) borderColor = AppColors.error;

                return Semantics(
                  button: true,
                  label:
                      '${l10n.pictureOfSemantics(choice.wordEnglish)}'
                      '${showCorrect ? l10n.correctAnswerSuffix : ''}'
                      '${showWrong ? l10n.wrongAnswerSuffix : ''}',
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
                        border: Border.all(
                          color: borderColor,
                          width: highlighted ? 4 : 3,
                        ),
                        boxShadow: [
                          if ((isSelected || highlighted) && !_answered)
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: highlighted ? 0.35 : 0.2,
                              ),
                              blurRadius: highlighted ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: FlashcardImage(
                          card: choice,
                          expand: true,
                          borderRadius: 16,
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
  Widget _buildWordMode(_PictureWordRound round, bool showCursor) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: Column(
        children: [
          // ─── Picture prompt ─────────────────
          Expanded(
            flex: 3,
            child:
                Semantics(
                      label: l10n.whichWordMatchesSemantics(
                        round.correctCard.wordEnglish,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: round.correctCard.category.color.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: round.correctCard.category.color.withValues(
                              alpha: 0.3,
                            ),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FlashcardImage(
                                  card: round.correctCard,
                                  size: 112,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.whichWordMatches,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: HCColor.of(context).textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                childAspectRatio:
                    ((context.isLargeTablet ? 3.0 : 2.5) /
                            MediaQuery.textScalerOf(context).scale(1.0))
                        .clamp(1.4, 3.0),
              ),
              itemCount: round.choices.length,
              itemBuilder: (context, index) {
                final choice = round.choices[index];
                final isSelected = _selectedIndex == index;
                final isCorrect = index == round.correctIndex;
                final showCorrect = _answered && isCorrect;
                final showWrong = _answered && isSelected && !isCorrect;
                final highlighted = showCursor && index == _cursorIndex;

                Color bgColor = HCColor.of(context).surface;
                Color borderColor = AppColors.primary.withValues(alpha: 0.2);
                Color textColor = HCColor.of(context).textPrimary;

                if (showCorrect) {
                  bgColor = AppColors.successLight;
                  borderColor = AppColors.success;
                  textColor = AppColors.successDark;
                } else if (showWrong) {
                  bgColor = AppColors.errorLight;
                  borderColor = AppColors.error;
                  textColor = AppColors.errorDark;
                } else if (highlighted) {
                  borderColor = AppColors.primary;
                }

                return Semantics(
                  button: true,
                  label:
                      '${l10n.answerSemantics(choice.wordEnglish)}'
                      '${showCorrect ? l10n.correctAnswerSuffix : ''}'
                      '${showWrong ? l10n.wrongAnswerSuffix : ''}',
                  child: GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor,
                          width: highlighted ? 4 : 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              choice.wordEnglish,
                              style: AppTypography.titleMedium.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              choice.wordFilipino,
                              style: AppTypography.bodySmall.copyWith(
                                color: textColor.withValues(alpha: 0.7),
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
