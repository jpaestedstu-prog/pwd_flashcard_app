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
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../widgets/flashcard_image.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../game_resume_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';

class WordMatchScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  /// Pick up the unfinished run the learner left behind rather than dealing a
  /// fresh one. Set by the Games hub after asking.
  final bool resume;

  const WordMatchScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
    this.resume = false,
  });

  @override
  ConsumerState<WordMatchScreen> createState() => _WordMatchScreenState();
}

class _WordMatchScreenState extends ConsumerState<WordMatchScreen>
    with TimedGameMixin, GamePauseMixin, GameResumeMixin {
  // ─── Resume wiring ───────────────────────────────
  @override
  GameType get resumeGameType => GameType.wordMatch;
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
  Map<String, bool> get resumeResults => {
    for (var i = 0; i < _currentRound && i < _rounds.length; i++)
      _rounds[i].correctCard.id:
          _reviewItems.length > i && _reviewItems[i].isCorrect,
  };
  @override
  bool get resumeFinished => _showResult;

  late List<Flashcard> _allCards;
  late List<_WordMatchRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  int _cursorIndex = 0;
  bool _answered = false;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  /// Difficulty-based config
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
    _allCards = source..shuffle();
    _generateRounds();
    if (widget.resume) _restoreSaved();
    startTimerIfNeeded(widget.timedMode);
    initPause();
  }

  /// Re-deal the run the learner walked away from. The snapshot holds the deck
  /// and how far in they got, not the rendered rounds — choices are drawn
  /// fresh. Any mismatch falls back to the fresh deal rather than resuming
  /// into a half-broken state.
  void _restoreSaved() {
    final snapshot = readResumePoint();
    if (snapshot == null) return;

    final byId = {for (final c in SeedData.allFlashcards) c.id: c};
    final deck = snapshot.cardIds
        .map((id) => byId[id])
        .whereType<Flashcard>()
        .toList();
    if (deck.length != snapshot.cardIds.length) return;

    final rebuilt = <_WordMatchRound>[];
    for (final correct in deck) {
      final others = _allCards.where((c) => c.id != correct.id).toList()
        ..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);
      rebuilt.add(
        _WordMatchRound(
          correctCard: correct,
          choices: choices,
          correctIndex: choices.indexOf(correct),
        ),
      );
    }

    setState(() {
      _rounds = rebuilt;
      _currentRound = snapshot.roundIndex;
      _score = snapshot.score;
      // Per-word verdicts survive for the review sheet; the exact wrong answer
      // tapped before the break does not, and is not worth persisting.
      _reviewItems.clear();
      for (final card in deck.take(snapshot.roundIndex)) {
        _reviewItems.add(
          GameReviewItem(
            wordEnglish: card.wordEnglish,
            wordFilipino: card.wordFilipino,
            category: card.category,
            isCorrect: snapshot.cardResults[card.id] ?? false,
          ),
        );
      }
    });
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
    clearResumePoint();
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
        _WordMatchRound(
          correctCard: correct,
          choices: choices,
          correctIndex: choices.indexOf(correct),
        ),
      );
    }
  }

  // ─── Gaze cursor (hands-free) ────────────────────
  // Word Match is on the Motor Impairment roster, so a learner who cannot tap
  // is offered it by name — it has to be playable without tapping. Same model
  // as Picture-Word: look ◀ ▶ to move the highlight across the choices, then
  // look ▼ or blink to choose. Inert unless Gaze Control is on.

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

  void _selectAnswer(int index) {
    if (_answered) return;
    final sound = ref.read(soundServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    // Tactile + audio confirmation that the tap registered, *before* the
    // success/error pattern fires. Without this, fast taps feel inert
    // until ~150 ms later when the answer is judged.
    haptic.lightTap();
    sound.playTap();
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
        haptic.success();
      } else {
        sound.playWrong();
        haptic.error();
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentRound < _rounds.length - 1) {
        setState(() {
          _currentRound++;
          _selectedIndex = null;
          _cursorIndex = 0;
          _answered = false;
        });
      } else {
        // The run is over, so there is nothing left to come back to.
        clearResumePoint();
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
    });
  }

  void _restart() {
    // "Play Again" deals a new run, which supersedes whatever was saved.
    clearResumePoint();
    setState(() {
      _currentRound = 0;
      _score = 0;
      _selectedIndex = null;
      _cursorIndex = 0;
      _answered = false;
      _showResult = false;
      _reviewItems.clear();
      _allCards.shuffle();
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

  /// [completed] is false only for the "Quit to Games" path, where the run
  /// ended early. The score still counts toward stats exactly as before, but
  /// the adaptive engine is not fed an accuracy that scores every unplayed
  /// round as a miss — that would read as a struggling learner and push the
  /// suggested difficulty down for quitting rather than for missing.
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
          gameType: GameType.wordMatch,
          score: _score,
          total: _rounds.length,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: srResults.correctWordIds,
          durationSeconds: elapsedSeconds,
          playedDifficulty: completed ? widget.difficulty : null,
        );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: srResults,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    if (_showResult) {
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
                      gameTitle: GameType.wordMatch.labelOf(l10n),
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

    final round = _rounds[_currentRound];
    // The gaze highlight only makes sense while a choice can still be made —
    // once answered, the correct/wrong colours own the cards.
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
                      GameType.wordMatch.labelOf(l10n),
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
                    const SizedBox(height: 28),

                    // ─── Question Image Area ──────────────
                    Expanded(
                      flex: 3,
                      child:
                          Semantics(
                                label: l10n.questionEnglishFor(
                                  round.correctCard.wordFilipino,
                                ),
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
                                  // Scale the prompt down to fit a short (landscape) viewport or
                                  // a large font scale rather than overflowing the flex region.
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FlashcardImage(
                                              card: round.correctCard,
                                              size: 84,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.whatIsThisWord,
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                    color: hc.textSecondary,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              round.correctCard.wordFilipino,
                                              style: AppTypography
                                                  .headlineMedium
                                                  .copyWith(
                                                    color: round
                                                        .correctCard
                                                        .category
                                                        .darkColor,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                        ),
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

                    // ─── Answer Choices ───────────────────
                    Expanded(
                      flex: 3,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.isLargeTablet ? 4 : 2,
                          mainAxisSpacing: context.gridSpacing * 0.75,
                          crossAxisSpacing: context.gridSpacing * 0.75,
                          // Shrink aspect ratio as text scales up so answer cells
                          // stay tall enough to hold scaled label text at XL font.
                          childAspectRatio:
                              ((context.isLargeTablet ? 2.2 : 2.5) /
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1.0))
                                  .clamp(1.2, 2.5),
                        ),
                        itemCount: round.choices.length,
                        itemBuilder: (context, index) {
                          final choice = round.choices[index];
                          final isSelected = _selectedIndex == index;
                          final isCorrect = index == round.correctIndex;
                          final showCorrect = _answered && isCorrect;
                          final showWrong =
                              _answered && isSelected && !isCorrect;

                          final highlighted =
                              showCursor && index == _cursorIndex;

                          Color bgColor = hc.surface;
                          Color borderColor = AppColors.primary.withValues(
                            alpha: 0.2,
                          );
                          Color textColor = hc.textPrimary;

                          if (highlighted) {
                            // Same bright ring the hub tiles use, so the hands-free
                            // highlight reads identically everywhere in the app.
                            borderColor = AppColors.accent;
                          }
                          if (showCorrect) {
                            bgColor = AppColors.successLight;
                            borderColor = AppColors.success;
                            textColor = AppColors.successDark;
                          } else if (showWrong) {
                            bgColor = AppColors.errorLight;
                            borderColor = AppColors.error;
                            textColor = AppColors.errorDark;
                          }

                          Widget card = Semantics(
                            button: true,
                            label:
                                '${l10n.answerChoiceSemantics(choice.wordEnglish)}'
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
                                  boxShadow: highlighted
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 14,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : AppColors.softShadow,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        choice.wordEnglish,
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );

                          // Shake animation for wrong answer
                          if (showWrong) {
                            card = card.animate().shakeX(
                              hz: 6,
                              amount: 4,
                              duration: 400.ms,
                            );
                          }
                          // Scale up for correct
                          if (showCorrect) {
                            card = card
                                .animate()
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.05, 1.05),
                                  duration: 300.ms,
                                )
                                .then()
                                .scale(
                                  begin: const Offset(1.05, 1.05),
                                  end: const Offset(1, 1),
                                  duration: 200.ms,
                                );
                          }

                          return card
                              .animate(key: ValueKey('$_currentRound-$index'))
                              .fadeIn(duration: 300.ms, delay: (index * 80).ms)
                              .slideY(begin: 0.1, end: 0);
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

class _WordMatchRound {
  final Flashcard correctCard;
  final List<Flashcard> choices;
  final int correctIndex;

  _WordMatchRound({
    required this.correctCard,
    required this.choices,
    required this.correctIndex,
  });
}
