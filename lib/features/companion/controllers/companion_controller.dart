import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/stt_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../ai_tutor/models/tutor_models.dart';
import '../../ai_tutor/services/tutor_engine.dart';
import '../../ai_tutor/services/tutor_memory_service.dart';
import '../../ai_tutor/services/tutor_speech.dart';
import '../../ai_tutor/widgets/tutor_persona.dart';
import '../models/companion_presentation.dart';
import '../services/gemini_service.dart';

const _uuid = Uuid();

/// Stars for a correct standalone quiz; bonus for finishing the daily plan.
/// Mirrors the AI Tutor screen so the two surfaces reward identically.
const _kQuizStar = 1;
const _kLessonBonus = 3;

/// Immutable view-state for the floating companion. Run-state that the UI never
/// needs to see directly (lesson cursor, cached memory counters) lives as
/// private fields on the controller instead, keeping this small.
class CompanionState {
  final List<TutorMessage> messages;
  final bool isTyping;
  final bool isOpen;

  /// Microphone is actively capturing speech.
  final bool isListening;

  /// Live speech-to-text hypothesis shown while [isListening].
  final String partialTranscript;

  /// Interactive bubbles (quiz options, favorite pickers) already resolved.
  final Set<String> answeredIds;

  /// Avatar mood for a one-shot celebrate pop. `thinking` is derived from
  /// [isTyping] in the UI, so it is not stored here.
  final TutorAvatarState avatar;

  /// A reply arrived while the panel was closed — badge the launcher.
  final bool hasUnread;

  /// Conversation has been greeted/restored once this session.
  final bool initialized;

  const CompanionState({
    this.messages = const [],
    this.isTyping = false,
    this.isOpen = false,
    this.isListening = false,
    this.partialTranscript = '',
    this.answeredIds = const {},
    this.avatar = TutorAvatarState.idle,
    this.hasUnread = false,
    this.initialized = false,
  });

  CompanionState copyWith({
    List<TutorMessage>? messages,
    bool? isTyping,
    bool? isOpen,
    bool? isListening,
    String? partialTranscript,
    Set<String>? answeredIds,
    TutorAvatarState? avatar,
    bool? hasUnread,
    bool? initialized,
  }) {
    return CompanionState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isOpen: isOpen ?? this.isOpen,
      isListening: isListening ?? this.isListening,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      answeredIds: answeredIds ?? this.answeredIds,
      avatar: avatar ?? this.avatar,
      hasUnread: hasUnread ?? this.hasUnread,
      initialized: initialized ?? this.initialized,
    );
  }
}

/// Drives the floating AI Companion.
///
/// The *intelligence* is entirely the existing on-device [TutorEngine]; this
/// controller adds the "live" layer the companion needs — a typing indicator,
/// send/arrival cues, spoken replies, and voice input — and routes every one of
/// those effects through [CompanionPresentation] so the behaviour adapts to the
/// learner's accessibility profile (silent + haptic for a hearing profile,
/// spoken + announced for a visual one, calm + instant for a cognitive one …).
class CompanionController extends Notifier<CompanionState> {
  // ── Persisted relationship (loaded on first open) ──
  TutorStats _stats = const TutorStats();
  String? _lastPlanDate;
  List<String> _planWordIds = const [];
  List<String> _favoriteCategories = const [];
  Map<String, double> _interestScores = const {};

  // ── Lesson run-state ──
  List<Flashcard> _lessonCards = const [];
  int _lessonIndex = 0;
  int _lessonCorrect = 0;
  bool _inLesson = false;

  /// Words missed on the first pass, re-asked in a retry round before the
  /// lesson finishes. Never grows during the retry round, so a lesson can only
  /// ever loop back once. Mirrors AiTutorScreen.
  final List<String> _missedWordIds = [];
  bool _inReviewRound = false;

  /// First-pass question count, kept separate from [_lessonCards] because the
  /// retry round replaces that list.
  int _lessonTotal = 0;
  int _reviewCorrect = 0;

  // ── Voice ──
  /// True between starting the mic and consuming its transcript, so a final
  /// result and a manual stop can't both fire the same utterance.
  bool _awaitingTranscript = false;

  bool _disposed = false;
  Timer? _celebrateTimer;

  @override
  CompanionState build() {
    _disposed = false;
    // Reset the whole surface when the active learner changes, so each profile
    // gets its own remembered conversation and its own adaptive presentation.
    ref.watch(profileProvider.select((p) => p?.id));

    ref.onDispose(() {
      _disposed = true;
      _celebrateTimer?.cancel();
      try {
        ref.read(sttServiceProvider).cancel();
      } catch (_) {}
      try {
        ref.read(ttsServiceProvider).stop();
      } catch (_) {}
    });
    return const CompanionState();
  }

  // ── Context helpers ──
  String get _profileId => ref.read(profileProvider)?.id ?? 'guest';
  bool get _isFilipino => ref.read(settingsProvider).locale == 'fil';
  CompanionPresentation get _presentation => CompanionPresentation.forProfile(
        ref.read(profileProvider)?.disabilityType ?? DisabilityType.none,
        ref.read(settingsProvider),
      );
  List<FlashcardCategory> get _interests => TutorEngine.topInterests(
        TutorMemory(
          favoriteCategories: _favoriteCategories,
          interestScores: _interestScores,
        ),
      );

  // ── Open / close ──
  void open() {
    ensureInitialized();
    state = state.copyWith(isOpen: true, hasUnread: false);
  }

  void close() {
    _stopListening();
    ref.read(ttsServiceProvider).stop();
    state = state.copyWith(isOpen: false);
  }

  void toggle() => state.isOpen ? close() : open();

  /// Loads remembered stats + history and posts the opening message(s). Safe to
  /// call repeatedly — only the first call does work.
  void ensureInitialized() {
    if (state.initialized) return;
    final profile = ref.read(profileProvider);
    final memory = TutorMemoryService.getMemory(_profileId);
    _stats = memory.stats;
    _lastPlanDate = memory.lastPlanDate;
    _planWordIds = memory.planWordIds;
    _favoriteCategories = memory.favoriteCategories;
    _interestScores = memory.interestScores;

    if (memory.messages.isNotEmpty) {
      // Restore the conversation, locking only the bubbles the learner really
      // resolved — a still-unanswered picker or quiz stays usable.
      state = state.copyWith(
        messages: List.of(memory.messages),
        answeredIds: TutorMemoryService.resolveAnsweredIds(memory),
        initialized: true,
      );
      // New day → welcome back and offer today's (interest-aware) plan.
      final lastDay = TutorMemoryService.dayKey(memory.messages.last.timestamp);
      if (lastDay != TutorMemoryService.dayKey(DateTime.now())) {
        _scheduleFollowUp(() {
          final msg = TutorEngine.welcomeBack(
            profile?.name ?? 'Learner',
            ref.read(progressProvider),
            _profileId,
            isFilipino: _isFilipino,
            interests: _interests,
          );
          if (msg.action?.type == TutorActionType.startLesson) {
            _planWordIds = msg.action!.planWordIds ?? const [];
          }
          _addTutorMessage(msg);
        });
      }
      return;
    }

    // Fresh start: greet, then either ask for favorites or analyse progress.
    final greeting =
        TutorEngine.greet(profile?.name ?? 'Learner', isFilipino: _isFilipino);
    state = state.copyWith(messages: [greeting], initialized: true);
    _cueReplyEffects(greeting);
    _scheduleFollowUp(() {
      if (_favoriteCategories.isEmpty) {
        _addTutorMessage(TutorEngine.askInterests(isFilipino: _isFilipino));
        return;
      }
      _addTutorMessage(TutorEngine.analyzeAndRespond(
        ref.read(progressProvider),
        profile?.name ?? 'Learner',
        _profileId,
        isFilipino: _isFilipino,
        interests: _interests,
      ));
    });
  }

  // ── Sending ──
  void sendText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    ensureInitialized();

    _playSend();
    final student = TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.student,
      content: text,
      timestamp: DateTime.now(),
    );
    _stats = _stats.copyWith(questionsAsked: _stats.questionsAsked + 1);

    // A free-form question goes to Gemini automatically when a key is compiled
    // in; everything the engine handles structurally (quizzes, lessons,
    // interests, progress, …) always stays on the offline TutorEngine. The
    // online path checks connectivity first and falls back to the engine, so
    // the switch between online and offline is fully automatic.
    if (GeminiService.isConfigured && TutorEngine.isFreeForm(text)) {
      // Show the thinking state for the whole network round-trip — a real
      // loading cue (genuine latency), not decorative motion.
      state = state.copyWith(
        messages: [...state.messages, student],
        isTyping: true,
      );
      _respondOnline(text);
    } else {
      state = state.copyWith(
        messages: [...state.messages, student],
        isTyping: _presentation.typingIndicator,
      );
      _afterTyping(() => _respondWithEngine(text));
    }
  }

  void sendQuick(String command) => sendText(command);

  /// The default, fully-offline responder: the rule-based [TutorEngine].
  void _respondWithEngine(String text) {
    // Asking about a topic is itself an interest signal.
    final mentioned = TutorEngine.categoryInText(text);
    if (mentioned != null) {
      _interestScores = TutorEngine.bumpInterest(
          _interestScores, mentioned, TutorEngine.signalAsk);
    }
    final response = TutorEngine.respondToQuestion(
      text,
      ref.read(progressProvider),
      _profileId,
      isFilipino: _isFilipino,
      interests: _interests,
    );
    if (response.action?.type == TutorActionType.startLesson) {
      _planWordIds = response.action!.planWordIds ?? const [];
    }
    _addTutorMessage(response);
    // "I like animals" → engine confirmed a favorite; record + reinforce it.
    if (response.action?.type == TutorActionType.pickInterests &&
        response.action!.categoryLabel != null) {
      final cat = TutorEngine.categoryFromName(response.action!.categoryLabel!);
      if (cat != null) {
        _recordFavorite(cat);
        _celebrateNewFavorite(cat);
      }
    }
  }

  /// The online responder. On ANY failure (offline, timeout, quota, bad
  /// response) it falls back to the offline engine, so the learner always gets
  /// a helpful reply and the adaptive cues still fire — the online/offline
  /// switch is invisible to them.
  Future<void> _respondOnline(String text) async {
    final mentioned = TutorEngine.categoryInText(text);
    if (mentioned != null) {
      _interestScores = TutorEngine.bumpInterest(
          _interestScores, mentioned, TutorEngine.signalAsk);
    }
    String? answer;
    try {
      // Fast local radio check first: with no network at all, skip the HTTP
      // attempt entirely so the offline reply is instant instead of waiting
      // out a socket timeout. A connected-but-dead network still gets caught
      // by the HTTP timeout below.
      final radios = await Connectivity().checkConnectivity();
      final offline =
          radios.isEmpty || radios.every((r) => r == ConnectivityResult.none);
      answer = offline
          ? null
          : await ref.read(geminiServiceProvider).answer(
                question: text,
                learnerName: ref.read(profileProvider)?.name,
                isFilipino: _isFilipino,
              );
    } catch (_) {
      answer = null;
    }
    if (_disposed) return;
    if (answer == null || answer.trim().isEmpty) {
      _respondWithEngine(text); // graceful offline fallback
      return;
    }
    _addTutorMessage(TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: answer.trim(),
      timestamp: DateTime.now(),
    ));
  }

  // ── Voice input ──
  Future<void> toggleVoiceInput() async {
    if (!_presentation.voiceInput) return;
    if (state.isListening) {
      final partial = state.partialTranscript.trim();
      await _stopListening();
      if (partial.isNotEmpty && _consumeTranscript()) sendText(partial);
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    final stt = ref.read(sttServiceProvider);
    // Initialise (and request mic permission) *first*: if the recogniser is
    // unavailable or the user denies the mic, we must not leave the panel stuck
    // showing "Listening…". init() caches success, so calling it here and again
    // inside startListening does not prompt twice.
    final ready = await stt.init();
    if (_disposed) return;
    if (!ready) {
      state = state.copyWith(isListening: false, partialTranscript: '');
      return;
    }
    _awaitingTranscript = true;
    state = state.copyWith(isListening: true, partialTranscript: '');
    await stt.startListening(
      locale: _isFilipino ? 'fil-PH' : 'en-US',
      listenFor: const Duration(seconds: 12),
      onResult: (text, isFinal) {
        if (_disposed) return;
        state = state.copyWith(partialTranscript: text);
        if (isFinal) {
          state = state.copyWith(isListening: false, partialTranscript: '');
          if (_consumeTranscript()) sendText(text);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    if (!state.isListening) return;
    try {
      await ref.read(sttServiceProvider).stopListening();
    } catch (_) {}
    if (!_disposed) {
      state = state.copyWith(isListening: false, partialTranscript: '');
    }
  }

  /// Returns true exactly once per utterance, so a final result and a manual
  /// stop can't both send the same words.
  bool _consumeTranscript() {
    if (!_awaitingTranscript) return false;
    _awaitingTranscript = false;
    return true;
  }

  // ── Quiz answering (mirrors AiTutorScreen so rewards match) ──
  void answerQuiz(TutorMessage msg, String answer) {
    if (msg.action?.type != TutorActionType.quickQuiz) return;
    if (state.answeredIds.contains(msg.id)) return;
    final action = msg.action!;
    final correct = answer == action.correctAnswer;

    final notifier = ref.read(progressProvider.notifier);
    notifier.recordDailyActivity();
    if (correct) notifier.addStars(_kQuizStar);
    if (action.wordId != null) {
      SpacedRepetitionService.recordWordAttempt(
        profileId: _profileId,
        wordId: action.wordId!,
        wasCorrect: correct,
      );
      // Count the word towards vocabulary learned, exactly as a game would.
      if (correct) notifier.recordWordsLearned([action.wordId!]);
    }
    final quizCat = action.categoryLabel == null
        ? null
        : TutorEngine.categoryFromLabel(action.categoryLabel!);
    if (quizCat != null) {
      _interestScores = TutorEngine.bumpInterest(
        _interestScores,
        quizCat,
        TutorEngine.signalQuiz + (correct ? TutorEngine.signalQuizCorrect : 0),
      );
    }

    _stats = _stats.copyWith(
      quizzesAnswered: _stats.quizzesAnswered + 1,
      quizzesCorrect: _stats.quizzesCorrect + (correct ? 1 : 0),
    );
    final feedback = TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: correct
          ? (_isFilipino
              ? '✅ Tama! Ang sagot ay "$answer". Napakagaling! 🎉'
              : '✅ Correct! The answer is "$answer". Well done! 🎉')
          : (_isFilipino
              ? '❌ Hindi tama. Ang tamang sagot ay "${action.correctAnswer}". Subukan muli sa susunod! 💪'
              : '❌ Not quite. The correct answer is "${action.correctAnswer}". Try again next time! 💪'),
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      answeredIds: {...state.answeredIds, msg.id},
      messages: [...state.messages, feedback],
    );
    _cueReplyEffects(feedback);
    if (correct) {
      _flashCelebrate();
    } else if (_presentation.haptics) {
      HapticFeedback.mediumImpact();
    }
    _persist();

    // Re-teach a missed word before moving on — for standalone quizzes as well
    // as lessons, so a wrong answer is always followed by the word itself
    // rather than just a verdict.
    final missedCard = (!correct && action.wordId != null)
        ? TutorEngine.cardById(action.wordId!)
        : null;

    // Advance the lesson cursor, then continue *after* any re-teach card so
    // the two never land in the same beat.
    void continueLesson() {
      if (!_inLesson) return;
      if (correct) {
        if (_inReviewRound) {
          _reviewCorrect++;
        } else {
          _lessonCorrect++;
        }
      } else if (!_inReviewRound &&
          action.wordId != null &&
          !_missedWordIds.contains(action.wordId)) {
        _missedWordIds.add(action.wordId!);
      }
      _lessonIndex++;
      if (_lessonIndex < _lessonCards.length) {
        _scheduleFollowUp(_askLessonQuestion);
      } else if (!_inReviewRound && _missedWordIds.isNotEmpty) {
        _scheduleFollowUp(_startReviewRound);
      } else {
        _scheduleFollowUp(_finishLesson);
      }
    }

    if (missedCard != null) {
      _scheduleFollowUp(() {
        _addTutorMessage(
          TutorEngine.reteach(missedCard, isFilipino: _isFilipino),
        );
        continueLesson();
      });
    } else {
      continueLesson();
    }
  }

  // ── Favorite topics ──
  void pickInterest(TutorMessage msg, String categoryName) {
    if (state.answeredIds.contains(msg.id)) return;
    final cat = TutorEngine.categoryFromName(categoryName);
    if (cat == null) return;
    state = state.copyWith(answeredIds: {...state.answeredIds, msg.id});
    _recordFavorite(cat);
    _addTutorMessage(
        TutorEngine.interestConfirmation(cat, isFilipino: _isFilipino));
    _celebrateNewFavorite(cat);
  }

  void _recordFavorite(FlashcardCategory cat) {
    _favoriteCategories = [
      cat.name,
      ..._favoriteCategories.where((n) => n != cat.name),
    ].take(TutorEngine.maxFavorites).toList();
    _interestScores =
        TutorEngine.bumpInterest(_interestScores, cat, TutorEngine.signalPick);
    _persist();
  }

  void _celebrateNewFavorite(FlashcardCategory cat) {
    _flashCelebrate();
    _scheduleFollowUp(() => _addTutorMessage(
          TutorEngine.quickQuiz(interests: [cat], isFilipino: _isFilipino),
        ));
  }

  // ── Daily lesson ──
  void startLesson(List<String> wordIds) {
    final cards = <Flashcard>[];
    for (final id in wordIds) {
      final card = TutorEngine.cardById(id);
      if (card != null) cards.add(card);
    }
    if (cards.isEmpty) return;
    _lessonCards = cards;
    _lessonIndex = 0;
    _lessonCorrect = 0;
    _inLesson = true;
    _lessonTotal = cards.length;
    _missedWordIds.clear();
    _inReviewRound = false;
    _reviewCorrect = 0;
    _askLessonQuestion();
  }

  /// Re-asks the words missed on the first pass. Entered once per lesson,
  /// between the last question and the summary.
  void _startReviewRound() {
    final cards = <Flashcard>[];
    for (final id in _missedWordIds) {
      final card = TutorEngine.cardById(id);
      if (card != null) cards.add(card);
    }
    if (cards.isEmpty) {
      _finishLesson();
      return;
    }
    _lessonCards = cards;
    _lessonIndex = 0;
    _inReviewRound = true;
    _reviewCorrect = 0;
    _addTutorMessage(
        TutorEngine.reviewRoundIntro(cards.length, isFilipino: _isFilipino));
    _scheduleFollowUp(_askLessonQuestion);
  }

  void _askLessonQuestion() {
    if (_lessonIndex >= _lessonCards.length) return;
    final card = _lessonCards[_lessonIndex];
    final position = '${_lessonIndex + 1}/${_lessonCards.length}';
    final prefix = _inReviewRound
        ? (_isFilipino ? '🔁 Balik-aral $position' : '🔁 Review $position')
        : (_isFilipino ? '📚 Aralin $position' : '📚 Lesson $position');
    _addTutorMessage(
        TutorEngine.quizForWord(card, isFilipino: _isFilipino, prefix: prefix));
  }

  void _finishLesson() {
    // The first-pass length, not _lessonCards — a retry round replaces that.
    final total = _lessonTotal;
    final alreadyToday =
        _lastPlanDate == TutorMemoryService.dayKey(DateTime.now());
    final notifier = ref.read(progressProvider.notifier);
    if (!alreadyToday) {
      notifier.recordDailyActivity();
      notifier.addStars(_kLessonBonus);
      _lastPlanDate = TutorMemoryService.dayKey(DateTime.now());
      _stats = _stats.copyWith(lessonsCompleted: _stats.lessonsCompleted + 1);
    }
    final bonusLine = alreadyToday
        ? (_isFilipino
            ? 'Nakuha mo na ang bituin ngayong araw, pero magaling pa rin ang practice! 💪'
            : 'You already earned today\'s bonus, but great practice! 💪')
        : (_isFilipino
            ? '🌟 +$_kLessonBonus na bituin para sa tapos na aralin!'
            : '🌟 +$_kLessonBonus stars for finishing your lesson!');
    // Credit the retry round separately so the headline score stays honest
    // about the first pass while the fix-up still gets celebrated.
    final reviewed = _missedWordIds.length;
    final reviewLine = (_inReviewRound && reviewed > 0)
        ? (_isFilipino
            ? '\n🔁 Binalikan mo ang $reviewed salitang mahirap — $_reviewCorrect ang tama sa pangalawang subok!'
            : '\n🔁 You went back over $reviewed tricky '
                '${reviewed == 1 ? 'word' : 'words'} and got $_reviewCorrect '
                'right on the second try!')
        : '';

    _inLesson = false;
    _inReviewRound = false;
    _flashCelebrate();
    _addTutorMessage(TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: _isFilipino
          ? '🎉 Tapos na ang aralin! Nakakuha ka ng $_lessonCorrect/$total na tama.$reviewLine\n\n$bonusLine'
          : '🎉 Lesson complete! You got $_lessonCorrect/$total correct.$reviewLine\n\n$bonusLine',
      timestamp: DateTime.now(),
    ));
  }

  /// Manually read a message aloud (the bubble's "Listen" control).
  void speakMessage(String text) => _speak(text);

  // ── Internals ──

  /// Appends a tutor message and fires the profile-appropriate reply cues.
  void _addTutorMessage(TutorMessage msg, {bool? speak}) {
    state = state.copyWith(
      messages: [...state.messages, msg],
      isTyping: false,
      hasUnread: !state.isOpen,
    );
    _cueReplyEffects(msg, speak: speak);
    _persist();
  }

  /// Runs [produce] after the (presentation-gated) typing pause. Calm / reduced
  /// motion profiles get the reply immediately — no artificial latency.
  void _afterTyping(void Function() produce) {
    final delay = _presentation.typingDelay;
    if (delay == Duration.zero) {
      if (!_disposed) produce();
      return;
    }
    Timer(delay, () {
      if (_disposed) return;
      produce();
    });
  }

  /// Small "feels alive" beat between an opening message and its follow-up.
  /// Collapses to a microtask under reduced motion / calm styles.
  void _scheduleFollowUp(void Function() action) {
    final delay =
        _presentation.animate ? const Duration(milliseconds: 900) : Duration.zero;
    Timer(delay, () {
      if (_disposed) return;
      action();
    });
  }

  void _flashCelebrate() {
    if (!_presentation.animate) return; // no celebratory motion when calm
    state = state.copyWith(avatar: TutorAvatarState.celebrate);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!_disposed) state = state.copyWith(avatar: TutorAvatarState.idle);
    });
  }

  /// The heart of the adaptive output: which channels fire for a reply.
  ///
  /// Sound + haptic + TTS live here (they need provider access). The
  /// screen-reader *announcement* is handled in the panel via a `liveRegion`
  /// node (only when the profile wants announcing but not our own TTS) so we
  /// never issue both our TTS and a TalkBack read of the same reply — the two
  /// would talk over each other.
  void _cueReplyEffects(TutorMessage msg, {bool? speak}) {
    final p = _presentation;
    if (p.soundEffects) {
      ref.read(soundServiceProvider).play(SoundEffect.cardFlip);
    }
    // Haptic arrival cue fires directly (not via the sound-gated HapticService)
    // because for a hearing profile it is the *substitute* for the sound.
    if (p.haptics) HapticFeedback.selectionClick();

    // Auto-read via our TTS. A manual "Listen" button always remains too.
    final shouldSpeak = speak ?? p.speakReplies;
    if (shouldSpeak) _speak(msg.content);
  }

  void _speak(String text) {
    // Speak the sentence, not the decoration — see [TutorSpeech]. Shared with
    // the full screen so both surfaces sound the same.
    final spoken = TutorSpeech.forSpeech(text, isFilipino: _isFilipino);
    if (spoken.isEmpty) return;
    final tts = ref.read(ttsServiceProvider);
    if (_isFilipino) {
      tts.speakFilipino(spoken);
    } else {
      tts.speakEnglish(spoken);
    }
  }

  void _playSend() {
    if (_presentation.soundEffects) {
      ref.read(soundServiceProvider).play(SoundEffect.buttonTap);
    }
  }

  void _persist() {
    TutorMemoryService.saveMemory(
      _profileId,
      TutorMemory(
        messages: state.messages,
        stats: _stats,
        lastPlanDate: _lastPlanDate,
        planWordIds: _planWordIds,
        favoriteCategories: _favoriteCategories,
        interestScores: _interestScores,
        answeredIds: state.answeredIds,
      ),
    );
  }

  // Exposed for the header stats strip.
  TutorStats get stats => _stats;
}

/// The floating companion's state + brain.
final companionControllerProvider =
    NotifierProvider<CompanionController, CompanionState>(
  CompanionController.new,
);

/// The active learner's adaptive presentation. Recomputes when the profile or
/// any relevant setting changes, so toggling e.g. Reduced Motion or Sound
/// Effects instantly re-shapes the companion.
final companionPresentationProvider = Provider<CompanionPresentation>((ref) {
  final type =
      ref.watch(profileProvider.select((p) => p?.disabilityType)) ??
          DisabilityType.none;
  final settings = ref.watch(settingsProvider);
  return CompanionPresentation.forProfile(type, settings);
});

/// Whether the floating launcher should be shown at all: only for learner
/// profiles, only when enabled, and not while the bottom nav is hidden (games /
/// flashcard viewer go immersive, and the companion must not cover them).
final companionVisibleProvider = Provider<bool>((ref) {
  final enabled =
      ref.watch(settingsProvider.select((s) => s.aiCompanionEnabled));
  final isLearner =
      ref.watch(profileProvider.select((p) => p?.role.isLearner)) ?? false;
  final navVisible = ref.watch(bottomNavVisibleProvider);
  return enabled && isLearner && navVisible;
});
