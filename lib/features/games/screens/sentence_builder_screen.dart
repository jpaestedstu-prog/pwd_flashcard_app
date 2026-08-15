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
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../widgets/flashcard_image.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';

class SentenceBuilderScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const SentenceBuilderScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<SentenceBuilderScreen> createState() =>
      _SentenceBuilderScreenState();
}

class _SentenceBuilderScreenState extends ConsumerState<SentenceBuilderScreen>
    with TimedGameMixin, GamePauseMixin {
  late List<Flashcard> _cards;
  int _currentIndex = 0;
  int _score = 0;
  bool _showResult = false;
  bool _answered = false;
  String? _selectedAnswer;
  int _cursorIndex = 0;
  List<String> _choices = [];
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  /// Difficulty-based config
  int get _totalWords => switch (widget.difficulty) {
    GameDifficulty.easy => 5,
    GameDifficulty.medium => 8,
    GameDifficulty.hard => 12,
  };

  int get _choiceCount => switch (widget.difficulty) {
    GameDifficulty.easy => 3,
    GameDifficulty.medium => 4,
    GameDifficulty.hard => 4,
  };

  @override
  void initState() {
    super.initState();
    _initCards();
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
    if (_cards.isEmpty) return;
    _saveProgress();
  }

  @override
  void onTimeUp() {
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context,
      ref: ref,
      type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _initCards() {
    var source = List.of(SeedData.allFlashcards);
    // Only use cards that have an example sentence
    source = source
        .where(
          (c) => c.exampleSentence != null && c.exampleSentence!.isNotEmpty,
        )
        .toList();
    if (widget.categories.isNotEmpty) {
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }
    _cards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: source,
      count: _totalWords,
      random: _random,
    );
    _generateChoices();
  }

  void _generateChoices() {
    final card = _cards[_currentIndex];
    final correctAnswer = card.wordEnglish;

    // Get distractors from same category first, then other categories
    final sameCategoryCards =
        SeedData.allFlashcards
            .where((c) => c.category == card.category && c.id != card.id)
            .toList()
          ..shuffle(_random);

    final otherCards =
        SeedData.allFlashcards
            .where((c) => c.id != card.id && c.category != card.category)
            .toList()
          ..shuffle(_random);

    final distractors = <String>[];
    // Prefer same-category distractors for harder challenge
    for (final c in sameCategoryCards) {
      if (distractors.length >= _choiceCount - 1) break;
      if (!distractors.contains(c.wordEnglish) &&
          c.wordEnglish != correctAnswer) {
        distractors.add(c.wordEnglish);
      }
    }
    // Fill remaining from other categories
    for (final c in otherCards) {
      if (distractors.length >= _choiceCount - 1) break;
      if (!distractors.contains(c.wordEnglish) &&
          c.wordEnglish != correctAnswer) {
        distractors.add(c.wordEnglish);
      }
    }

    _choices = [correctAnswer, ...distractors]..shuffle(_random);
    _answered = false;
    _selectedAnswer = null;
    _cursorIndex = 0;
  }

  /// Creates the sentence with a blank replacing the target word.
  String _buildSentenceWithBlank(Flashcard card) {
    final sentence = card.exampleSentence ?? '';
    final word = card.wordEnglish;
    // Case-insensitive replacement of the word with a blank
    final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    return sentence.replaceAll(pattern, '______');
  }

  // ─── Gaze cursor (hands-free) ────────────────────
  // Sentence Builder is on the Motor Impairment roster, so it has to be
  // playable without tapping: look ◀ ▶ to move the highlight across the word
  // choices, then look ▼ or blink to fill the blank with it. Inert unless
  // Gaze Control is on.

  void _moveCursor(int delta) {
    final n = _choices.length;
    if (n <= 0) return;
    setState(() => _cursorIndex = (((_cursorIndex + delta) % n) + n) % n);
  }

  void _selectCursor() {
    if (_answered || isPaused) return;
    if (_cursorIndex < 0 || _cursorIndex >= _choices.length) return;
    _onChoiceTapped(_choices[_cursorIndex]);
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

  void _onChoiceTapped(String choice) {
    if (_answered) return;
    final card = _cards[_currentIndex];
    final isCorrect = choice.toLowerCase() == card.wordEnglish.toLowerCase();
    final sound = ref.read(soundServiceProvider);

    setState(() {
      _selectedAnswer = choice;
      _answered = true;
      if (isCorrect) {
        _score++;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });

    _reviewItems.add(
      GameReviewItem(
        wordEnglish: card.wordEnglish,
        wordFilipino: card.wordFilipino,
        category: card.category,
        isCorrect: isCorrect,
        userAnswer: isCorrect ? null : choice,
      ),
    );

    // Auto-advance after a delay
    Future.delayed(const Duration(milliseconds: 1800), _nextWord);
  }

  void _nextWord() {
    if (!mounted) return;
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _generateChoices();
      });
    } else {
      _saveProgress();
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: CelebrationType.gameComplete,
      );
      setState(() => _showResult = true);
    }
  }

  void _saveProgress() {
    final categories = _cards.map((c) => c.category).toSet().toList();
    // Per-word results — feeds both wordsLearned and spaced repetition.
    final srResults = <String, bool>{};
    for (final r in _reviewItems) {
      final card = _cards
          .where((c) => c.wordEnglish == r.wordEnglish)
          .firstOrNull;
      if (card != null) srResults[card.id] = r.isCorrect;
    }

    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.sentenceBuilder,
          score: _score,
          total: _cards.length,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: srResults.correctWordIds,
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

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _showResult = false;
      _reviewItems.clear();
      _initCards();
    });
  }

  int get _starsEarned {
    final pct = _score / _cards.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
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
                  score: _score,
                  total: _cards.length,
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.popOrGo('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Sentence Builder',
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
    final sentenceWithBlank = _buildSentenceWithBlank(card);
    // The highlight belongs to the choosing phase; once answered the
    // correct/wrong colours own the chips.
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
                    'Sentence Builder  •  ${_currentIndex + 1}/${_cards.length}',
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
                  ],
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _cards.length,
                        minHeight: 6,
                        backgroundColor: AppColors.accentLight.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Sentence Card ────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Emoji & Filipino word hint
                            Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: card.category.color.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: card.category.color.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      FlashcardPicture(card: card, extent: 56),
                                      const SizedBox(height: 8),
                                      Text(
                                        card.wordFilipino,
                                        style: AppTypography.titleLarge
                                            .copyWith(
                                              color: card.category.darkColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fill in the blank',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: hc.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate(key: ValueKey(_currentIndex))
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: -0.05, end: 0),

                            const SizedBox(height: 24),

                            // ─── Sentence with Blank ────────
                            Semantics(
                                  label:
                                      'Sentence: ${sentenceWithBlank.replaceAll('______', 'blank')}',
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: hc.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      boxShadow: AppColors.softShadow,
                                    ),
                                    child: _buildSentenceRichText(
                                      sentenceWithBlank,
                                      card,
                                    ),
                                  ),
                                )
                                .animate(key: ValueKey('sent_$_currentIndex'))
                                .fadeIn(duration: 400.ms, delay: 100.ms),

                            const SizedBox(height: 28),

                            // ─── Answer Choices ──────────────
                            ...List.generate(_choices.length, (i) {
                              final choice = _choices[i];
                              final isCorrectChoice =
                                  choice.toLowerCase() ==
                                  card.wordEnglish.toLowerCase();
                              final isSelected = _selectedAnswer == choice;

                              Color bgColor;
                              Color borderColor;
                              Color textColor;
                              IconData? trailingIcon;

                              if (_answered) {
                                if (isCorrectChoice) {
                                  bgColor = AppColors.successLight;
                                  borderColor = AppColors.success;
                                  textColor = AppColors.successDark;
                                  trailingIcon = Icons.check_circle_rounded;
                                } else if (isSelected) {
                                  bgColor = AppColors.errorLight;
                                  borderColor = AppColors.error;
                                  textColor = AppColors.errorDark;
                                  trailingIcon = Icons.cancel_rounded;
                                } else {
                                  bgColor = hc.surfaceVariant;
                                  borderColor = AppColors.border;
                                  textColor = hc.textSecondary;
                                  trailingIcon = null;
                                }
                              } else {
                                bgColor = AppColors.primaryLight.withValues(
                                  alpha: 0.3,
                                );
                                borderColor = AppColors.primary.withValues(
                                  alpha: 0.3,
                                );
                                textColor = hc.textPrimary;
                                trailingIcon = null;
                              }

                              final highlighted =
                                  showCursor && i == _cursorIndex;
                              if (highlighted) borderColor = AppColors.accent;

                              return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Semantics(
                                      button: true,
                                      label:
                                          '${_answered ? (isCorrectChoice ? "Correct answer" : (isSelected ? "Your wrong answer" : "")) : "Option"}: $choice',
                                      child: GestureDetector(
                                        onTap: () => _onChoiceTapped(choice),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                              width: highlighted ? 4 : 2,
                                            ),
                                            boxShadow: highlighted
                                                ? [
                                                    BoxShadow(
                                                      color: AppColors.accent
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      blurRadius: 14,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              // Letter prefix
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: borderColor.withValues(
                                                    alpha: 0.2,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    String.fromCharCode(
                                                      65 + i,
                                                    ), // A, B, C, D
                                                    style: AppTypography
                                                        .labelLarge
                                                        .copyWith(
                                                          color: textColor,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  choice,
                                                  style: AppTypography
                                                      .titleMedium
                                                      .copyWith(
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              if (trailingIcon != null)
                                                Icon(
                                                  trailingIcon,
                                                  color: isCorrectChoice
                                                      ? AppColors.success
                                                      : AppColors.error,
                                                  size: 24,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate(
                                    key: ValueKey('choice_${_currentIndex}_$i'),
                                  )
                                  .fadeIn(
                                    duration: 300.ms,
                                    delay: (200 + i * 80).ms,
                                  )
                                  .slideX(begin: 0.05, end: 0);
                            }),

                            const SizedBox(height: 16),
                          ],
                        ),
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

  /// Builds a rich text widget that highlights the blank in the sentence.
  Widget _buildSentenceRichText(String sentenceWithBlank, Flashcard card) {
    final parts = sentenceWithBlank.split('______');
    final spans = <InlineSpan>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: AppTypography.titleMedium.copyWith(
              color: HCColor.of(context).textPrimary,
              height: 1.6,
            ),
          ),
        );
      }
      // Insert blank/answer between parts (not after the last one)
      if (i < parts.length - 1) {
        if (_answered) {
          final isCorrect =
              _selectedAnswer?.toLowerCase() == card.wordEnglish.toLowerCase();
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.successLight
                      : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Text(
                  card.wordEnglish,
                  style: AppTypography.titleMedium.copyWith(
                    color: isCorrect
                        ? AppColors.successDark
                        : AppColors.errorDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        } else {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 80,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: card.category.darkColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }
      }
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }
}
