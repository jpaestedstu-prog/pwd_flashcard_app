import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
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
import '../../../core/constants/flashcard_emojis.dart';
import '../../../widgets/accessibility_visual_feedback.dart';
import '../timed_game_mixin.dart';
import '../../../l10n/app_localizations.dart';

class SpellingBeeScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;
  const SpellingBeeScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<SpellingBeeScreen> createState() => _SpellingBeeScreenState();
}

class _SpellingBeeScreenState extends ConsumerState<SpellingBeeScreen>
    with TimedGameMixin {
  late List<Flashcard> _cards;
  int _currentIndex = 0;
  int _score = 0;
  List<String> _scrambledLetters = [];
  List<String?> _answerSlots = [];
  List<bool> _letterUsed = [];
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

  @override
  void initState() {
    super.initState();
    var source = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      source = source.where((c) => widget.categories.contains(c.category)).toList();
    }
    // Exclude multi-word entries — spaces/hyphens produce invisible tiles
    source.removeWhere((c) => c.wordEnglish.contains(' ') || c.wordEnglish.contains('-'));
    _cards = source..shuffle(_random);
    _cards = _cards.take(_totalWords).toList();
    if (_cards.isEmpty) {
      // Schedule navigation back; build() will show a safe placeholder
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.warning(context, message: AppLocalizations.of(context)!.noWordsAvailable);
          context.go('/games');
        }
      });
      return;
    }
    _setupWord();
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
    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _setupWord() {
    final word = _cards[_currentIndex].wordEnglish.toUpperCase();
    _answerSlots = List.filled(word.length, null);
    _scrambledLetters = word.split('')..shuffle(_random);
    _letterUsed = List.filled(word.length, false);
    _wordComplete = false;
    _hintsUsed = 0;
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
      _reviewItems.add(GameReviewItem(
        wordEnglish: _cards[_currentIndex].wordEnglish,
        wordFilipino: _cards[_currentIndex].wordFilipino,
        category: _cards[_currentIndex].category,
        isCorrect: true,
      ));
      setState(() {
        _wordComplete = true;
        _score++;
      });
      Future.delayed(const Duration(milliseconds: 1500), _nextWord);
    } else {
      sound.playWrong();
      ref.read(hapticServiceProvider).error();
      // Track wrong review only on first failed attempt per word
      if (!_reviewItems.any((r) => r.wordEnglish == _cards[_currentIndex].wordEnglish)) {
        _reviewItems.add(GameReviewItem(
          wordEnglish: _cards[_currentIndex].wordEnglish,
          wordFilipino: _cards[_currentIndex].wordFilipino,
          category: _cards[_currentIndex].category,
          isCorrect: false,
          userAnswer: answer,
        ));
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

  void _saveProgress() {
    final categories = _cards
        .map((c) => c.category)
        .toSet()
        .toList();
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.spellingBee,
      score: _score,
      total: _cards.length,
      starsEarned: _starsEarned,
      categoriesPlayed: categories,
    );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final r in _reviewItems) {
        final card = _cards.where((c) => c.wordEnglish == r.wordEnglish).firstOrNull;
        if (card != null) srResults[card.id] = r.isCorrect;
      }
      SpacedRepetitionService.recordBatch(profileId: profile.id, results: srResults);
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
        context: context, ref: ref, type: CelebrationType.gameComplete,
      );
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
      var source = List.of(SeedData.allFlashcards);
      if (widget.categories.isNotEmpty) {
        source = source.where((c) => widget.categories.contains(c.category)).toList();
      }
      // Exclude multi-word entries — spaces/hyphens produce invisible tiles
      source.removeWhere((c) => c.wordEnglish.contains(' ') || c.wordEnglish.contains('-'));
      _cards = source..shuffle(_random);
      _cards = _cards.take(_totalWords).toList();
      if (_cards.isEmpty) return;
      _setupWord();
    });
    startTimerIfNeeded(widget.timedMode);
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
    // Guard: if no cards were loaded, show safe placeholder while navigating back
    if (_cards.isEmpty) {
      return const Scaffold(
        body: ShimmerPageSkeleton(),
      );
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
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.go('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'Spelling Bee',
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.go('/games'),
        ),
        title: Text('Spelling Bee  •  ${_currentIndex + 1}/${_cards.length}'),
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
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 20, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('$_score', style: AppTypography.labelLarge.copyWith(color: AppColors.warning)),
                ],
              ),
            ),
          ),
        ],
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
                backgroundColor: AppColors.accentLight.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
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
                  color: card.category.color.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    FlashcardEmojis.forId(card.id),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.wordFilipino,
                    style: AppTypography.titleLarge.copyWith(
                      color: card.category.darkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Spell the English word',
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
              label: 'Answer: ${_answerSlots.where((s) => s != null).join()}'
                  '${_wordComplete ? ', Correct!' : ', ${_answerSlots.where((s) => s == null).length} letters remaining'}',
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
                      ? 'Slot ${i + 1}: ${_answerSlots[i]}, tap to remove'
                      : 'Slot ${i + 1}: empty',
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
                                : hc.textSecondary.withValues(alpha: 0.2),
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
                child: Text(
                  'Correct! 🎉',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn().scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    curve: Curves.elasticOut),
              ),

            const Spacer(),

            // ─── Scrambled Letters ─────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_scrambledLetters.length, (i) {
                final used = _letterUsed[i];
                return Semantics(
                  button: true,
                  label: used
                      ? 'Letter ${_scrambledLetters[i]}, already used'
                      : 'Letter ${_scrambledLetters[i]}, tap to place',
                  child: GestureDetector(
                  onTap: () => _placeLetter(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: context.responsiveSize(52),
                    height: context.responsiveSize(56),
                    decoration: BoxDecoration(
                      color: used
                          ? hc.surfaceVariant
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: used
                            ? Colors.transparent
                            : AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: used ? [] : AppColors.softShadow,
                    ),
                    child: Center(
                      child: Text(
                        used ? '' : _scrambledLetters[i],
                        style: AppTypography.titleLarge.copyWith(
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
              label: Text('Hint (${_maxHints - _hintsUsed} left)'),
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
                    Text(
                      _voiceHint,
                      style: AppTypography.bodySmall.copyWith(
                        color: _isListening ? AppColors.info : AppColors.error,
                        fontWeight: FontWeight.w600,
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
    );
  }
}
