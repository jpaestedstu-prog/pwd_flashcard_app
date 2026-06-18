import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/stt_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../object_scan/services/object_scan_discovery_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../widgets/accessibility_visual_feedback.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';

/// Pronunciation Practice — an audio-first game.
///
/// The app speaks a word using TTS, and the student must pick
/// the correct match from visual choices (emoji + text).
/// Supports English ➜ pick Filipino, and Filipino ➜ pick English rounds.
class PronunciationScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  /// Focus mode (Word Hunt): play exactly one round with this seed word.
  /// A correct answer earns exactly 1 star, and exits pop back to the
  /// launcher instead of going to the games hub.
  final String? focusWordId;

  const PronunciationScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
    this.focusWordId,
  });

  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen>
    with TimedGameMixin, GamePauseMixin {
  late List<_PronunciationRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;
  bool _showResult = false;
  bool _isListening = false;
  String _voiceHint = '';
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  /// Resolved focus card when [PronunciationScreen.focusWordId] matches a
  /// seed word; null runs the normal multi-round game.
  Flashcard? _focusCard;
  bool get _isFocusMode => _focusCard != null;

  /// Stars actually persisted for this game, computed once at finish time
  /// (the daily focus-mode cap can zero out [_starsEarned]).
  int _finalStars = 0;

  Flashcard? _resolveFocusCard() {
    final id = widget.focusWordId;
    if (id == null) return null;
    for (final c in SeedData.allFlashcards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Difficulty-based configuration. Focus mode is always a single round.
  int get _totalRounds => _isFocusMode
      ? 1
      : switch (widget.difficulty) {
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
    _startGame();
    initPause();
  }

  void _startGame() {
    _focusCard = _resolveFocusCard();
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source =
          source.where((c) => widget.categories.contains(c.category)).toList();
    }
    // Full adaptive reorder, no count cap: rounds take the weak words from
    // the front while the whole pool stays available for distractors.
    final ordered = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: source,
      random: _random,
    );
    // Focus mode plays exactly one round with the focus word; the rest of
    // the pool still supplies the wrong choices.
    final focus = _focusCard;
    if (focus != null) {
      ordered.removeWhere((c) => c.id == focus.id);
      ordered.insert(0, focus);
    }
    _generateRounds(ordered);
    _currentRound = 0;
    _score = 0;
    _showResult = false;
    _answered = false;
    _selectedIndex = null;
    _reviewItems.clear();
    _newAchievements = [];
    // Speak the first word after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrentWord());
    startTimerIfNeeded(widget.timedMode);
  }

  @override
  void dispose() {
    disposePause();
    disposeTimer();
    super.dispose();
  }

  @override
  void onPause() {
    if (_isListening) {
      final stt = ref.read(sttServiceProvider);
      stt.stopListening();
      _isListening = false;
    }
    final tts = ref.read(ttsServiceProvider);
    tts.stop();
  }

  @override
  Future<void> savePartialProgress() async {
    if (_rounds.isEmpty) return;
    _finishGame();
  }

  @override
  void onTimeUp() {
    _finishGame();
  }

  void _generateRounds(List<Flashcard> source) {
    _rounds = [];
    for (int i = 0; i < _totalRounds && i < source.length; i++) {
      final correct = source[i];
      final others =
          source.where((c) => c.id != correct.id).toList()..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);

      // Alternate between "hear English → pick Filipino"
      // and "hear Filipino → pick English" for variety.
      final isEnglishPrompt = i.isEven;

      _rounds.add(_PronunciationRound(
        correctCard: correct,
        choices: choices,
        correctIndex: choices.indexOf(correct),
        isEnglishPrompt: isEnglishPrompt,
      ));
    }
  }

  Future<void> _speakCurrentWord() async {
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(settingsProvider);
    if (!settings.ttsEnabled) {
      return;
    }
    final round = _rounds[_currentRound];
    if (round.isEnglishPrompt) {
      await tts.speakEnglish(round.correctCard.wordEnglish);
    } else {
      await tts.speakFilipino(round.correctCard.wordFilipino);
    }
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final round = _rounds[_currentRound];
    final isCorrect = index == round.correctIndex;
    final sound = ref.read(soundServiceProvider);
    final haptic = ref.read(hapticServiceProvider);

    _reviewItems.add(GameReviewItem(
      wordEnglish: round.correctCard.wordEnglish,
      wordFilipino: round.correctCard.wordFilipino,
      category: round.correctCard.category,
      isCorrect: isCorrect,
      userAnswer:
          isCorrect ? null : round.choices[index].wordEnglish,
    ));

    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (isCorrect) _score++;
    });

    if (isCorrect) {
      sound.playCorrect();
      haptic.success();
    } else {
      sound.playWrong();
      haptic.error();
    }

    // Auto-advance after delay
    Future.delayed(const Duration(milliseconds: 1400), _nextRound);
  }

  /// Speech-to-text: student speaks the answer instead of tapping.
  Future<void> _handleVoiceAnswer() async {
    if (_answered || _isListening) return;
    final stt = ref.read(sttServiceProvider);
    if (!stt.isAvailable) {
      await stt.init();
      if (!stt.isAvailable) return;
    }

    final round = _rounds[_currentRound];
    // Determine which language the student should say
    final isEnglish = round.isEnglishPrompt; // prompt is English → answer is Filipino
    final locale = isEnglish ? 'fil-PH' : 'en-US';
    final expected = isEnglish
        ? round.correctCard.wordFilipino
        : round.correctCard.wordEnglish;

    setState(() {
      _isListening = true;
      _voiceHint = 'Listening…';
    });

    await stt.startListening(
      locale: locale,
      onResult: (spoken, isFinal) {
        if (!mounted || !isFinal) return;
        if (SttService.isFuzzyMatch(spoken, expected)) {
          setState(() {
            _isListening = false;
            _voiceHint = '';
          });
          _selectAnswer(round.correctIndex);
        } else {
          setState(() {
            _isListening = false;
            _voiceHint = 'Heard: "$spoken" — try again!';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _voiceHint = '');
          });
        }
      },
    );
  }

  void _nextRound() {
    if (!mounted) return;
    if (_currentRound < _rounds.length - 1) {
      setState(() {
        _currentRound++;
        _answered = false;
        _selectedIndex = null;
      });
      _speakCurrentWord();
    } else {
      _finishGame();
    }
  }

  void _finishGame() {
    // Record progress
    final categories = _rounds.map((r) => r.correctCard.category).toSet().toList();
    var stars = _starsEarned;
    if (_isFocusMode && stars > 0) {
      // Once-per-day star per word: replays still celebrate (3/3 rating)
      // but "Play Again" can't farm the balance.
      final awarded = ObjectScanDiscoveryService.tryAwardGameStar(
        ref.read(profileProvider)?.id,
        _focusCard!.id,
      );
      if (!awarded) stars = 0;
    }
    _finalStars = stars;
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.pronunciation,
      score: _score,
      total: _rounds.length,
      starsEarned: _finalStars,
      categoriesPlayed: categories,
    );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final sr = <String, bool>{};
      for (final r in _reviewItems) {
        final card = _rounds
            .map((rd) => rd.correctCard)
            .where((c) => c.wordEnglish == r.wordEnglish)
            .firstOrNull;
        if (card != null) sr[card.id] = r.isCorrect;
      }
      SpacedRepetitionService.recordBatch(profileId: profile.id, results: sr);
    }

    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  int get _starsEarned {
    // Focus mode is a single round: exactly 1 star for a correct answer.
    if (_isFocusMode) return _score.clamp(0, 1);
    final pct = _score / _rounds.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _restart() => setState(() => _startGame());

  /// Exits return to the launcher (Word Hunt sheet) in focus mode, the
  /// games hub otherwise.
  void _exitGame() {
    if (_isFocusMode) {
      context.pop();
    } else {
      context.go('/games');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // ─── Result Screen ──────────────────────
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _score,
                  total: _rounds.length,
                  starsEarned: _finalStars,
                  // Focus mode: a correct single word is a perfect round —
                  // full 3/3 rating (the ⭐ earned shows separately).
                  rating: _isFocusMode ? (_score >= 1 ? 3 : 0) : null,
                  footnote: _isFocusMode
                      ? '📷 You\'ve found '
                          '${ObjectScanDiscoveryService.discoveredWordIds(ref.read(profileProvider)?.id).length} '
                          'words with your camera!'
                      : null,
                  onPlayAgain: _restart,
                  onExit: _exitGame,
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Pronunciation Practice',
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
          'Listen & Pick  •  ${_currentRound + 1}/${_rounds.length}',
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            // ─── Progress Bar ────────────────
            Semantics(
              label: 'Round ${_currentRound + 1} of ${_rounds.length}, score $_score',
              child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentRound + 1) / _rounds.length,
                minHeight: 6,
                backgroundColor: AppColors.infoLight.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(AppColors.info),
              ),
            ),
            ),
            const SizedBox(height: 28),

            // ─── Prompt Area ─────────────────
            Expanded(
              flex: 3,
              child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: round.correctCard.category.color
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: round.correctCard.category.color
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    // Keep the prompt centred when there's room, but scroll it
                    // instead of overflowing on a short viewport / large font.
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Big speaker button
                        Semantics(
                          button: true,
                          label: 'Play sound: tap to hear the ${round.isEnglishPrompt ? 'English' : 'Filipino'} word',
                          child: GestureDetector(
                          onTap: _speakCurrentWord,
                          child: Container(
                            width: context.responsiveSize(88),
                            height: context.responsiveSize(88),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: context.responsiveSize(44),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          round.isEnglishPrompt
                              ? AppLocalizations.of(context)!.listenEnglish
                              : AppLocalizations.of(context)!.listenFilipino,
                          style: AppTypography.titleMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          round.isEnglishPrompt
                              ? AppLocalizations.of(context)!.pickFilipino
                              : AppLocalizations.of(context)!.pickEnglish,
                          style: AppTypography.bodyMedium.copyWith(
                            color: round.correctCard.category.darkColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tap to replay hint
                        Text(
                          AppLocalizations.of(context)!.tapSpeakerReplay,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                        // Voice answer mic button
                        if (ref.watch(settingsProvider).speechToText) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _answered ? null : _handleVoiceAnswer,
                                child: MicrophoneWaveform(
                                  isListening: _isListening,
                                  size: 48,
                                  color: _isListening
                                      ? AppColors.error
                                      : AppColors.accent,
                                ),
                              ),
                              if (_voiceHint.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _voiceHint,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: _isListening ? AppColors.info : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

            // ─── Answer Choices ──────────────
            Expanded(
              flex: 4,
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
                  // Shrink aspect ratio as text scales up so cells stay
                  // tall enough to hold scaled label text at XL font.
                  childAspectRatio: ((_numChoices <= 3 ? 1.3 : 1.1) /
                          MediaQuery.textScalerOf(context).scale(1.0))
                      .clamp(0.7, 1.3),
                ),
                itemCount: round.choices.length,
                itemBuilder: (context, index) {
                  final choice = round.choices[index];
                  final isSelected = _selectedIndex == index;
                  final isCorrect = index == round.correctIndex;
                  final showCorrect = _answered && isCorrect;
                  final showWrong = _answered && isSelected && !isCorrect;

                  Color bgColor = hc.surface;
                  Color borderColor = AppColors.primary.withValues(alpha: 0.2);
                  Color textColor = hc.textPrimary;

                  if (showCorrect) {
                    bgColor = AppColors.successLight;
                    borderColor = AppColors.success;
                    textColor = AppColors.successDark;
                  } else if (showWrong) {
                    bgColor = AppColors.errorLight;
                    borderColor = AppColors.error;
                    textColor = AppColors.errorDark;
                  }

                  // Show the answer language (opposite of prompt)
                  final choiceText = round.isEnglishPrompt
                      ? choice.wordFilipino
                      : choice.wordEnglish;

                  Widget card = Semantics(
                    button: true,
                    label: 'Answer choice: $choiceText${showCorrect ? ', correct answer' : showWrong ? ', wrong answer' : ''}',
                    child: GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 2),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            FlashcardEmojis.forId(choice.id),
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              choiceText,
                              style: AppTypography.titleSmall.copyWith(
                                color: textColor,
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
                    ),
                  );

                  // Shake animation for wrong answer
                  if (showWrong) {
                    card = card
                        .animate()
                        .shakeX(hz: 6, amount: 4, duration: 400.ms);
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
        GameBreakButton(
          onHold: holdForBreak,
          onResume: resumeFromBreak,
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
              if (context.mounted) _exitGame();
            },
          ),
      ]),
    );
  }
}

// ────────────────────────────────────────
// Round data class
// ────────────────────────────────────────

class _PronunciationRound {
  final Flashcard correctCard;
  final List<Flashcard> choices;
  final int correctIndex;

  /// If true, TTS speaks English and the student picks the Filipino answer.
  /// If false, TTS speaks Filipino and the student picks the English answer.
  final bool isEnglishPrompt;

  _PronunciationRound({
    required this.correctCard,
    required this.choices,
    required this.correctIndex,
    required this.isEnglishPrompt,
  });
}
