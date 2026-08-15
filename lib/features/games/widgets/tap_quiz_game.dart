import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../break_time/break_time.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../game_pause_mixin.dart';
import '../timed_game_mixin.dart';
import 'pause_overlay.dart';
import '../../../widgets/fullscreen_host.dart';

/// One tappable answer in a [TapQuizRound].
class TapChoice {
  /// Main text on the button.
  final String label;

  /// Optional second line (e.g. the Filipino word).
  final String? sublabel;

  /// Optional leading icon, used by the two-button Yes-or-No layout.
  final IconData? icon;

  /// Optional tint for the button's resting state. Answer feedback (green /
  /// red) always overrides it once the round is answered.
  final Color? tint;

  const TapChoice({required this.label, this.sublabel, this.icon, this.tint});
}

/// One question: a prompt built from [card], plus the answers to tap.
class TapQuizRound {
  /// The vocabulary card this round teaches. Drives the review sheet and the
  /// spaced-repetition record, so it is the word the learner is practising —
  /// not necessarily the word shown in a distractor.
  final Flashcard card;
  final List<TapChoice> choices;
  final int correctIndex;

  /// Extra payload a game needs to render its prompt (e.g. the decoy word the
  /// Yes-or-No round is asking about).
  final Object? payload;

  const TapQuizRound({
    required this.card,
    required this.choices,
    required this.correctIndex,
    this.payload,
  });
}

/// Base widget for the tap-and-choose games (Yes or No, Odd One Out, First
/// Letter).
///
/// These three exist so every accessibility category can be offered a full
/// roster of ten games — see `GameCatalog`. They share one interaction: read a
/// prompt, tap one of a few large targets. No drag, no swipe, no stroke
/// precision, and nothing that depends on hearing, which is what makes them
/// usable by the categories with the tightest input and perception limits.
abstract class TapQuizScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const TapQuizScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });
}

/// Shared state machine + chrome for [TapQuizScreen] subclasses.
///
/// Handles rounds, scoring, stars, the review sheet, spaced repetition,
/// achievements, the timer, pause / break and the hands-free gaze cursor, so a
/// concrete game only supplies its rounds and its prompt.
abstract class TapQuizState<T extends TapQuizScreen> extends ConsumerState<T>
    with TimedGameMixin, GamePauseMixin {
  // ─── Subclass hooks ───────────────────────────────────

  /// Which game this is — recorded against progress and achievements.
  GameType get gameType;

  /// Title shown in the app bar and the review sheet.
  String get gameTitle;

  /// Build one round for [card], drawing distractors from [pool] (which
  /// excludes [card]). Return `null` to skip the card when no valid round can
  /// be made from it.
  TapQuizRound? buildRound(Flashcard card, List<Flashcard> pool, Random random);

  /// The question area above the answer buttons.
  Widget buildPrompt(BuildContext context, TapQuizRound round);

  /// Screen-reader description of the prompt, so the question is spoken even
  /// when it is drawn as an image or a letter tile.
  String promptSemantics(TapQuizRound round);

  /// Columns in the answer grid. Two by default; Yes-or-No keeps two large
  /// targets, First Letter uses more.
  int get choiceColumns => 2;

  /// Flex weight of the prompt area against the answer area (3 : 3 default).
  int get promptFlex => 3;
  int get choicesFlex => 3;

  /// Rounds per playthrough, by difficulty.
  int get totalRounds => switch (widget.difficulty) {
    GameDifficulty.easy => 6,
    GameDifficulty.medium => 10,
    GameDifficulty.hard => 14,
  };

  // ─── State ────────────────────────────────────────────

  late List<Flashcard> _allCards;
  late List<TapQuizRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  int _cursorIndex = 0;
  bool _answered = false;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final Map<String, bool> _cardResults = {};
  final random = Random();

  /// Cards in play this session, category-filtered. Available to subclasses
  /// that need a wider pool than the round's own distractors.
  List<Flashcard> get allCards => _allCards;

  List<TapQuizRound> get rounds => _rounds;
  bool get answered => _answered;

  @override
  void initState() {
    super.initState();
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }
    _allCards = source..shuffle(random);
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

  void _generateRounds() {
    _rounds = [];
    final picked = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: _allCards,
      count: totalRounds,
      random: random,
    );
    for (final card in picked) {
      final pool = _allCards.where((c) => c.id != card.id).toList()
        ..shuffle(random);
      final round = buildRound(card, pool, random);
      if (round != null) _rounds.add(round);
      if (_rounds.length >= totalRounds) break;
    }
  }

  @override
  Future<void> savePartialProgress() async {
    if (_rounds.isEmpty) return;
    _saveProgress();
  }

  @override
  void onTimeUp() {
    _finish();
  }

  void _selectAnswer(int index) {
    if (_answered || isPaused) return;
    final sound = ref.read(soundServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    // Confirm the tap landed before the answer is judged — otherwise a fast
    // tap feels inert for ~150 ms.
    haptic.lightTap();
    sound.playTap();
    setState(() {
      _selectedIndex = index;
      _answered = true;
      final round = _rounds[_currentRound];
      final isCorrect = index == round.correctIndex;
      _reviewItems.add(
        GameReviewItem(
          wordEnglish: round.card.wordEnglish,
          wordFilipino: round.card.wordFilipino,
          category: round.card.category,
          isCorrect: isCorrect,
          userAnswer: isCorrect ? null : round.choices[index].label,
        ),
      );
      // A word only counts as known if every round that asked about it was
      // right, so a later miss can't overwrite an earlier hit.
      _cardResults[round.card.id] =
          (_cardResults[round.card.id] ?? true) && isCorrect;
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
        _finish();
      }
    });
  }

  void _finish() {
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

  void _restart() {
    setState(() {
      _currentRound = 0;
      _score = 0;
      _selectedIndex = null;
      _cursorIndex = 0;
      _answered = false;
      _showResult = false;
      _reviewItems.clear();
      _cardResults.clear();
      _allCards.shuffle(random);
      _generateRounds();
      startTimerIfNeeded(widget.timedMode);
    });
  }

  int get _starsEarned {
    if (_rounds.isEmpty) return 0;
    final pct = _score / _rounds.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories = _rounds.map((r) => r.card.category).toSet().toList();
    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: gameType,
          score: _score,
          total: _rounds.length,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: _cardResults.correctWordIds,
        );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    final profile = ref.read(profileProvider);
    if (profile != null) {
      SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: _cardResults,
      );
    }
  }

  // ─── Gaze cursor (hands-free) ─────────────────────────
  // Look left / right to move the highlight, down or blink to choose. Inert
  // unless the learner turned Gaze Control on.

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
    final canMove = !_answered && !isPaused;
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
        label: 'Choose',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        enabled: canMove,
        onSelect: _selectCursor,
      ),
    ];
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No card in the chosen categories could produce a round (e.g. a category
    // with too few words for distractors). Say so rather than crashing on an
    // empty round list.
    if (_rounds.isEmpty) return _buildEmptyState(context);
    if (_showResult) return _buildResultScreen(context);
    return _buildGameScreen(context);
  }

  Widget _buildEmptyState(BuildContext context) {
    final hc = HCColor.of(context);
    return Scaffold(
      appBar: fullscreenBar(
        ref,
        AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => context.popOrGo('/games'),
          ),
          title: Text(gameTitle),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_outlined, size: 64, color: hc.textSecondary),
              const SizedBox(height: 16),
              Text(
                'Not enough words',
                style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick more categories to play $gameTitle.',
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.popOrGo('/games'),
                child: const Text('Back to Games'),
              ),
            ],
          ),
        ),
      ),
    );
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
                  onExit: () => context.popOrGo('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: gameTitle,
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
                    tooltip: 'Close',
                    onPressed: pauseGame,
                  ),
                  title: Text(
                    '$gameTitle  •  ${_currentRound + 1}/${_rounds.length}',
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Round ${_currentRound + 1} of ${_rounds.length}',
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

                    // ─── Prompt ───────────────────────────
                    Expanded(
                      flex: promptFlex,
                      child:
                          Semantics(
                                label: promptSemantics(round),
                                child: buildPrompt(context, round),
                              )
                              .animate(key: ValueKey(_currentRound))
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: 0.1, end: 0),
                    ),
                    const SizedBox(height: 24),

                    // ─── Answers ──────────────────────────
                    Expanded(
                      flex: choicesFlex,
                      child: _buildChoices(context, round, showCursor),
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

  Widget _buildChoices(
    BuildContext context,
    TapQuizRound round,
    bool showCursor,
  ) {
    final hc = HCColor.of(context);
    final columns = choiceColumns;
    final spacing = context.gridSpacing * 0.75;
    final rows = (round.choices.length / columns).ceil();
    // Size the cells from the space actually available rather than from a
    // fixed aspect ratio. A non-scrolling grid does not paint an overflow
    // stripe when its rows don't fit — it silently clips them off the bottom,
    // which put Hard's fifth and sixth letter tiles out of reach. Deriving the
    // ratio from the real box makes every row fit by construction, at any
    // device size and any font scale.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight =
            (constraints.maxHeight - spacing * (rows - 1)) / rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cellHeight <= 0
                ? 1.0
                : (cellWidth / cellHeight).clamp(0.4, 6.0),
          ),
          itemCount: round.choices.length,
          itemBuilder: (context, index) =>
              _buildChoice(context, round, index, hc, showCursor),
        );
      },
    );
  }

  Widget _buildChoice(
    BuildContext context,
    TapQuizRound round,
    int index,
    HCColor hc,
    bool showCursor,
  ) {
    final choice = round.choices[index];
    final isSelected = _selectedIndex == index;
    final isCorrect = index == round.correctIndex;
    final showCorrect = _answered && isCorrect;
    final showWrong = _answered && isSelected && !isCorrect;
    final highlighted = showCursor && index == _cursorIndex;

    Color bgColor = choice.tint ?? hc.surface;
    Color borderColor = choice.tint == null
        ? AppColors.primary.withValues(alpha: 0.2)
        : AppColors.primary.withValues(alpha: 0.35);
    Color textColor = hc.textPrimary;

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

    Widget card = Semantics(
      button: true,
      label:
          'Answer: ${choice.label}'
          '${showCorrect ? ', correct answer' : ''}'
          '${showWrong ? ', wrong answer' : ''}',
      child: GestureDetector(
        onTap: () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: highlighted ? 4 : 2),
            boxShadow: AppColors.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (choice.icon != null) ...[
                      Icon(choice.icon, size: 34, color: textColor),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      choice.label,
                      style: AppTypography.titleMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (choice.sublabel != null)
                      Text(
                        choice.sublabel!,
                        style: AppTypography.bodySmall.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (showWrong) {
      card = card.animate().shakeX(hz: 6, amount: 4, duration: 400.ms);
    }
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
  }

  /// Standard bordered prompt panel — matches the question area the other
  /// games use. [tint] is normally the category colour of the word on show;
  /// Odd One Out passes the *group's* colour instead, so the panel can't tint
  /// itself to the answer and give it away.
  Widget promptPanel(BuildContext context, Color tint, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tint.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          // Scale down rather than overflow on a short viewport or a large
          // text scale.
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }
}
