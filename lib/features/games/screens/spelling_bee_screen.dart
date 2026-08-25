import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/stt_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../object_scan/services/object_scan_discovery_service.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../widgets/accessibility_visual_feedback.dart';
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

class SpellingBeeScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  /// Pick up the unfinished run the learner left behind rather than dealing a
  /// fresh one. Set by the Games hub after asking.
  final bool resume;

  /// Focus mode (Word Hunt): play exactly one round with this seed word.
  /// A correct answer earns exactly 1 star, and exits pop back to the
  /// launcher instead of going to the games hub.
  final String? focusWordId;

  const SpellingBeeScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
    this.resume = false,
    this.focusWordId,
  });

  @override
  ConsumerState<SpellingBeeScreen> createState() => _SpellingBeeScreenState();
}

class _SpellingBeeScreenState extends ConsumerState<SpellingBeeScreen>
    with TimedGameMixin, GamePauseMixin, GameResumeMixin {
  // ─── Resume wiring ───────────────────────────────
  @override
  GameType get resumeGameType => GameType.spellingBee;
  @override
  GameDifficulty get resumeDifficulty => widget.difficulty;
  @override
  List<FlashcardCategory> get resumeCategories => widget.categories;
  @override
  bool get resumeTimedMode => widget.timedMode;
  @override
  String? get resumeProfileId => ref.read(profileProvider)?.id;
  @override
  List<String> get resumeDeckIds => _cards.map((c) => c.id).toList();
  @override
  int get resumeIndex => _currentIndex;
  @override
  int get resumeScore => _score;
  @override
  bool get resumeFinished => _showResult;

  /// Re-deal the run the learner walked away from. This game's deck is a plain
  /// card list, so restoring is just reordering it to the saved ids and
  /// jumping the index. A deck that no longer lines up (a card dropped from
  /// the seed data) falls back to the fresh deal.
  void _restoreSaved() {
    final snapshot = readResumePoint();
    if (snapshot == null) return;
    // Look the saved ids up in the whole pool, not in the deck that was
    // just dealt — the fresh deal is a different random hand, so a lookup
    // against it would miss every card and always fall back.
    final byId = {for (final c in SeedData.allFlashcards) c.id: c};
    final deck = snapshot.cardIds
        .map((id) => byId[id])
        .whereType<Flashcard>()
        .toList();
    if (deck.length != snapshot.cardIds.length) return;
    setState(() {
      _cards = deck;
      _currentIndex = snapshot.roundIndex;
      _score = snapshot.score;
      // The scrambled letter bank is derived per word, so it has to be
      // rebuilt for the round we are jumping to.
      _setupWord();
    });
  }

  late List<Flashcard> _cards;
  int _currentIndex = 0;
  int _score = 0;
  List<String> _scrambledLetters = [];
  List<String?> _answerSlots = [];
  List<bool> _letterUsed = [];
  int _cursorIndex = 0;
  bool _showResult = false;
  bool _wordComplete = false;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  int _hintsUsed = 0;
  final _random = Random();
  bool _isListening = false;
  String _voiceHint = '';

  /// Difficulty-based config
  int get _totalWords => switch (widget.difficulty) {
    GameDifficulty.easy => 6,
    GameDifficulty.medium => 10,
    GameDifficulty.hard => 12,
  };

  int get _maxHints => switch (widget.difficulty) {
    GameDifficulty.easy => 4,
    GameDifficulty.medium => 3,
    GameDifficulty.hard => 1,
  };

  /// Resolved focus card when [SpellingBeeScreen.focusWordId] matches a
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

  @override
  void initState() {
    super.initState();
    _focusCard = _resolveFocusCard();
    if (_isFocusMode) {
      _cards = [_focusCard!];
    } else {
      var source = List.of(SeedData.allFlashcards);
      if (widget.categories.isNotEmpty) {
        source = source
            .where((c) => widget.categories.contains(c.category))
            .toList();
      }
      // Exclude multi-word entries — spaces/hyphens produce invisible tiles
      source.removeWhere(
        (c) => c.wordEnglish.contains(' ') || c.wordEnglish.contains('-'),
      );
      _cards = AdaptiveDifficultyService.pickGameCards(
        profileId: ref.read(profileProvider)?.id,
        cards: source,
        count: _totalWords,
        random: _random,
      );
    }
    if (_cards.isEmpty) {
      // Schedule navigation back; build() will show a safe placeholder
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.warning(
            context,
            message: AppLocalizations.of(context)!.noWordsAvailable,
          );
          context.popOrGo('/games');
        }
      });
      return;
    }
    _setupWord();
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
    if (_cards.isEmpty) return;
    _saveProgress(completed: false);
    // Quitting is the moment worth remembering: the hub can offer to
    // bring the learner straight back to this round.
    saveResumePoint();
  }

  @override
  void onTimeUp() {
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context,
      ref: ref,
      type: CelebrationType.gameComplete,
    );
    clearResumePoint();
    setState(() => _showResult = true);
  }

  void _setupWord() {
    final word = _cards[_currentIndex].wordEnglish.toUpperCase();
    _answerSlots = List.filled(word.length, null);
    _scrambledLetters = word.split('')..shuffle(_random);
    _letterUsed = List.filled(word.length, false);
    _wordComplete = false;
    _hintsUsed = 0;
    _cursorIndex = 0;
  }

  // ─── Gaze cursor (hands-free) ────────────────────
  // Spelling Bee is on the Motor Impairment roster. The letter bank is the only
  // thing a learner has to reach: look ◀ ▶ to move along it (skipping letters
  // already placed, so the cursor never rests on a dead tile), look ▼ or blink
  // to place the highlighted letter in the next slot, and look ▲ to take the
  // last letter back — the hands-free equivalent of tapping a filled slot.

  void _moveCursor(int delta) {
    final n = _scrambledLetters.length;
    if (n <= 0) return;
    var index = _cursorIndex;
    for (var step = 0; step < n; step++) {
      index = (((index + delta) % n) + n) % n;
      if (!_letterUsed[index]) break;
    }
    setState(() => _cursorIndex = index);
  }

  void _selectCursor() {
    if (_wordComplete || isPaused) return;
    if (_cursorIndex < 0 || _cursorIndex >= _scrambledLetters.length) return;
    if (_letterUsed[_cursorIndex]) return;
    _placeLetter(_cursorIndex);
    // Move on to a letter that can still be placed, so the learner is aimed at
    // a live tile for the next pick.
    if (!_wordComplete) _moveCursor(1);
  }

  /// Undo: clears the last filled slot, mirroring a tap on it.
  void _undoLastLetter() {
    if (_wordComplete || isPaused) return;
    final lastFilled = _answerSlots.lastIndexWhere((slot) => slot != null);
    if (lastFilled < 0) return;
    _removeLetterAtSlot(lastFilled);
  }

  List<GazeAction> _gazeActions() {
    final l10n = AppLocalizations.of(context)!;
    final canPlay = !_wordComplete && !isPaused;
    return [
      GazeAction(
        zone: GazeZone.left,
        label: l10n.gazePrev,
        icon: Icons.chevron_left_rounded,
        color: AppColors.secondary,
        enabled: canPlay,
        onSelect: () => _moveCursor(-1),
      ),
      GazeAction(
        zone: GazeZone.right,
        label: l10n.gazeNext,
        icon: Icons.chevron_right_rounded,
        color: AppColors.secondary,
        enabled: canPlay,
        onSelect: () => _moveCursor(1),
      ),
      GazeAction(
        zone: GazeZone.up,
        label: l10n.gazeUndo,
        icon: Icons.backspace_rounded,
        color: AppColors.warning,
        enabled: canPlay && _answerSlots.any((s) => s != null),
        onSelect: _undoLastLetter,
      ),
      GazeAction(
        zone: GazeZone.down,
        label: l10n.gazePlace,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        enabled: canPlay,
        onSelect: _selectCursor,
      ),
    ];
  }

  void _placeLetter(int letterIndex) {
    if (_letterUsed[letterIndex] || _wordComplete) return;
    final nextSlot = _answerSlots.indexOf(null);
    if (nextSlot == -1) return;

    ref.read(soundServiceProvider).playLetter();
    setState(() {
      _answerSlots[nextSlot] = _scrambledLetters[letterIndex];
      _letterUsed[letterIndex] = true;
    });

    // Check if word is complete
    if (!_answerSlots.contains(null)) {
      _checkWord();
    }
  }

  void _removeLetterAtSlot(int slotIndex) {
    if (_answerSlots[slotIndex] == null || _wordComplete) return;
    final letter = _answerSlots[slotIndex]!;
    // Find the first used index matching the letter
    for (int i = 0; i < _scrambledLetters.length; i++) {
      if (_scrambledLetters[i] == letter && _letterUsed[i]) {
        setState(() {
          _answerSlots[slotIndex] = null;
          _letterUsed[i] = false;
        });
        break;
      }
    }
  }

  void _checkWord() {
    final word = _cards[_currentIndex].wordEnglish.toUpperCase();
    final answer = _answerSlots.join();
    final sound = ref.read(soundServiceProvider);
    if (answer == word) {
      sound.playCorrect();
      ref.read(hapticServiceProvider).success();
      _reviewItems.add(
        GameReviewItem(
          wordEnglish: _cards[_currentIndex].wordEnglish,
          wordFilipino: _cards[_currentIndex].wordFilipino,
          category: _cards[_currentIndex].category,
          isCorrect: true,
        ),
      );
      setState(() {
        _wordComplete = true;
        _score++;
      });
      Future.delayed(const Duration(milliseconds: 1500), _nextWord);
    } else {
      sound.playWrong();
      ref.read(hapticServiceProvider).error();
      // Track wrong review only on first failed attempt per word
      if (!_reviewItems.any(
        (r) => r.wordEnglish == _cards[_currentIndex].wordEnglish,
      )) {
        _reviewItems.add(
          GameReviewItem(
            wordEnglish: _cards[_currentIndex].wordEnglish,
            wordFilipino: _cards[_currentIndex].wordFilipino,
            category: _cards[_currentIndex].category,
            isCorrect: false,
            userAnswer: answer,
          ),
        );
      }
      // Wrong — reset
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _answerSlots = List.filled(word.length, null);
          _letterUsed = List.filled(word.length, false);
        });
      });
    }
  }

  void _useHint() {
    if (_hintsUsed >= _maxHints || _wordComplete) return;
    final word = _cards[_currentIndex].wordEnglish.toUpperCase();
    final nextSlot = _answerSlots.indexOf(null);
    if (nextSlot == -1) return;

    final correctLetter = word[nextSlot];
    for (int i = 0; i < _scrambledLetters.length; i++) {
      if (_scrambledLetters[i] == correctLetter && !_letterUsed[i]) {
        setState(() {
          _answerSlots[nextSlot] = correctLetter;
          _letterUsed[i] = true;
          _hintsUsed++;
        });
        if (!_answerSlots.contains(null)) _checkWord();
        break;
      }
    }
  }

  /// Speech-to-text voice input handler.
  Future<void> _handleVoiceInput() async {
    if (_wordComplete || _isListening) return;
    final stt = ref.read(sttServiceProvider);
    if (!stt.isAvailable) {
      await stt.init();
      if (!stt.isAvailable) return;
    }

    setState(() {
      _isListening = true;
      _voiceHint = 'Listening…';
    });

    await stt.startListening(
      locale: 'en-US',
      onResult: (spoken, isFinal) {
        if (!mounted || !isFinal) return;
        final expected = _cards[_currentIndex].wordEnglish;
        if (SttService.isFuzzyMatch(spoken, expected)) {
          // Auto-fill all slots
          final word = expected.toUpperCase();
          setState(() {
            for (int i = 0; i < word.length; i++) {
              _answerSlots[i] = word[i];
            }
            _letterUsed = List.filled(_letterUsed.length, true);
            _isListening = false;
            _voiceHint = '';
          });
          _checkWord();
        } else {
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            _isListening = false;
            _voiceHint = l10n.heardTryAgain(spoken);
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _voiceHint = '');
          });
        }
      },
    );

    // Safety timeout: if STT never fires onResult (e.g. silence), reset state
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isListening) {
        setState(() {
          _isListening = false;
          _voiceHint = '';
        });
      }
    });
  }

  /// [completed] is false only on the "Quit to Games" path — an abandoned run
  /// still counts toward stats but is not fed to the adaptive engine as if
  /// every unplayed round were a miss.
  void _saveProgress({bool completed = true}) {
    final categories = _cards.map((c) => c.category).toSet().toList();
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
          gameType: GameType.spellingBee,
          score: _score,
          total: _cards.length,
          starsEarned: _finalStars,
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

  void _nextWord() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _setupWord();
      });
    } else {
      _saveProgress();
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: CelebrationType.gameComplete,
      );
      clearResumePoint();
      setState(() => _showResult = true);
    }
  }

  void _restart() {
    disposeTimer(); // cancel any existing timer
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _showResult = false;
      _reviewItems.clear();
      if (_isFocusMode) {
        // Replay the same single word.
        _cards = [_focusCard!];
      } else {
        var source = List.of(SeedData.allFlashcards);
        if (widget.categories.isNotEmpty) {
          source = source
              .where((c) => widget.categories.contains(c.category))
              .toList();
        }
        // Exclude multi-word entries — spaces/hyphens produce invisible tiles
        source.removeWhere(
          (c) => c.wordEnglish.contains(' ') || c.wordEnglish.contains('-'),
        );
        _cards = AdaptiveDifficultyService.pickGameCards(
          profileId: ref.read(profileProvider)?.id,
          cards: source,
          count: _totalWords,
          random: _random,
        );
      }
      if (_cards.isEmpty) return;
      _setupWord();
    });
    startTimerIfNeeded(widget.timedMode);
  }

  int get _starsEarned {
    // Focus mode is a single round: exactly 1 star for a correct answer.
    if (_isFocusMode) return _score.clamp(0, 1);
    final pct = _score / _cards.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  /// Exits return to whatever launched this game — the Word Hunt sheet in
  /// focus mode, a learning-path step, or the games hub — falling back to the
  /// hub only when the game was opened with no stack behind it.
  void _exitGame() => context.popOrGo('/games');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    // Guard: if no cards were loaded, show safe placeholder while navigating back
    if (_cards.isEmpty) {
      return const Scaffold(body: ShimmerPageSkeleton());
    }

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
                    gameTitle: GameType.spellingBee.labelOf(l10n),
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
    // The letter highlight only means something while letters can still be
    // placed.
    final showCursor =
        ref.watch(gazeSettingsProvider.select((s) => s.enabled)) &&
        !_wordComplete;

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
                      GameType.spellingBee.labelOf(l10n),
                      _currentIndex + 1,
                      _cards.length,
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
              body: SafeArea(
                child: SingleChildScrollView(
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

                      // ─── Clue Area ────────────────────────
                      Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: card.category.color.withValues(alpha: 0.1),
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
                                  style: AppTypography.titleLarge.copyWith(
                                    color: card.category.darkColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.spellTheWord,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: hc.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(key: ValueKey('clue_$_currentIndex'))
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: -0.05, end: 0),

                      const SizedBox(height: 28),

                      // ─── Answer Slots ─────────────────────
                      Semantics(
                        label:
                            '${l10n.spelledSoFar(_answerSlots.where((s) => s != null).join())}'
                            '${_wordComplete ? ', ${l10n.wordComplete}' : ''}',
                        liveRegion: true,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: List.generate(_answerSlots.length, (i) {
                            final filled = _answerSlots[i] != null;
                            final isCorrectSlot = _wordComplete;
                            return Semantics(
                              button: true,
                              label: _answerSlots[i] != null
                                  ? l10n.slotFilled(i + 1, _answerSlots[i]!)
                                  : l10n.slotEmpty(i + 1),
                              child: GestureDetector(
                                onTap: () => _removeLetterAtSlot(i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: context.responsiveSize(48),
                                  height: context.responsiveSize(56),
                                  decoration: BoxDecoration(
                                    color: isCorrectSlot
                                        ? AppColors.successLight
                                        : filled
                                        ? AppColors.primaryLight
                                        : hc.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCorrectSlot
                                          ? AppColors.success
                                          : filled
                                          ? AppColors.primary
                                          : hc.textSecondary.withValues(
                                              alpha: 0.2,
                                            ),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _answerSlots[i] ?? '',
                                      style: AppTypography.titleLarge.copyWith(
                                        color: isCorrectSlot
                                            ? AppColors.successDark
                                            : hc.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      if (_wordComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child:
                              Text(
                                l10n.correct,
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ).animate().fadeIn().scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                                curve: Curves.elasticOut,
                              ),
                        ),

                      const SizedBox(height: 28),

                      // ─── Scrambled Letters ─────────────────
                      Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: List.generate(_scrambledLetters.length, (
                              i,
                            ) {
                              final used = _letterUsed[i];
                              final highlighted =
                                  showCursor && !used && i == _cursorIndex;
                              return Semantics(
                                button: true,
                                label: used
                                    ? l10n.letterAlreadyUsed(
                                        _scrambledLetters[i],
                                      )
                                    : l10n.letterTapToPlace(
                                        _scrambledLetters[i],
                                      ),
                                child: GestureDetector(
                                  onTap: () => _placeLetter(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: context.responsiveSize(52),
                                    height: context.responsiveSize(56),
                                    decoration: BoxDecoration(
                                      color: used
                                          ? hc.surfaceVariant
                                          : AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: highlighted
                                            ? AppColors.accent
                                            : used
                                            ? Colors.transparent
                                            : AppColors.primary.withValues(
                                                alpha: 0.4,
                                              ),
                                        width: highlighted ? 4 : 2,
                                      ),
                                      boxShadow: highlighted
                                          ? [
                                              BoxShadow(
                                                color: AppColors.accent
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : used
                                          ? []
                                          : AppColors.softShadow,
                                    ),
                                    child: Center(
                                      child: Text(
                                        used ? '' : _scrambledLetters[i],
                                        style: AppTypography.titleLarge
                                            .copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          )
                          .animate(key: ValueKey('letters_$_currentIndex'))
                          .fadeIn(duration: 300.ms, delay: 100.ms),

                      const SizedBox(height: 20),

                      // ─── Hint Button ──────────────────────
                      TextButton.icon(
                        onPressed: _hintsUsed < _maxHints ? _useHint : null,
                        icon: const Icon(Icons.lightbulb_rounded),
                        label: Text(l10n.hintsLeft(_maxHints - _hintsUsed)),
                      ),

                      // ─── Voice Input ──────────────────────
                      if (ref.watch(settingsProvider).speechToText) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _wordComplete ? null : _handleVoiceInput,
                              child: MicrophoneWaveform(
                                isListening: _isListening,
                                size: 44,
                                color: _isListening
                                    ? AppColors.error
                                    : AppColors.accent,
                              ),
                            ),
                            if (_voiceHint.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              // Flexible + ellipsis so a long hint at XL font scale wraps
                              // / truncates instead of overflowing next to the mic.
                              Flexible(
                                child: Text(
                                  _voiceHint,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _isListening
                                        ? AppColors.info
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
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
                  if (context.mounted) _exitGame();
                },
              ),
          ],
        ),
      ),
    );
  }
}
