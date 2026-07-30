import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../companion/services/gemini_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../widgets/fsl_loading_overlay.dart';
import '../models/tutor_media_policy.dart';
import '../models/tutor_models.dart';
import '../services/tutor_engine.dart';
import '../services/tutor_memory_service.dart';
import '../services/tutor_sign_launcher.dart';
import '../services/tutor_speech.dart';
import '../widgets/tutor_chat.dart';
import '../widgets/tutor_persona.dart';

const _uuid = Uuid();

/// Stars awarded for a correct standalone quiz answer.
const _kQuizStar = 1;

/// Bonus stars for finishing the daily learning plan (once per calendar day).
const _kLessonBonus = 3;

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _messages = <TutorMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  // Persisted tutor relationship.
  TutorStats _stats = const TutorStats();
  String? _lastPlanDate;
  List<String> _planWordIds = const [];
  List<String> _favoriteCategories = const [];
  Map<String, double> _interestScores = const {};

  // Quiz / lesson run state.
  final _answeredQuizIds = <String>{};
  List<Flashcard> _lessonCards = const [];
  int _lessonIndex = 0;
  int _lessonCorrect = 0;
  bool _inLesson = false;

  /// Words missed on the first pass, re-asked in a retry round before the
  /// lesson is allowed to finish. Never grows during the retry round itself,
  /// so a lesson can only ever loop back once.
  final _missedWordIds = <String>[];
  bool _inReviewRound = false;

  /// First-pass question count, kept separate from [_lessonCards] because the
  /// retry round replaces that list — the summary must still report the score
  /// out of the original lesson length.
  int _lessonTotal = 0;
  int _reviewCorrect = 0;

  // Avatar mood.
  TutorAvatarState _avatarState = TutorAvatarState.idle;

  /// An FSL clip is being resolved. Guards against stacked downloads / player
  /// sheets when the control is tapped repeatedly, mirroring the Flashcards
  /// viewer.
  bool _isLoadingFsl = false;

  late TutorPersona _persona;
  String get _profileId => ref.read(profileProvider)?.id ?? 'guest';
  bool get _isFilipino => ref.read(settingsProvider).locale == 'fil';

  /// Current interests: explicit favorites first, then strong implicit ones.
  List<FlashcardCategory> get _interests => TutorEngine.topInterests(
        TutorMemory(
          favoriteCategories: _favoriteCategories,
          interestScores: _interestScores,
        ),
      );

  @override
  void initState() {
    super.initState();
    _persona = TutorPersona.of(ref.read(profileProvider)?.role);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initialize() {
    final profile = ref.read(profileProvider);
    final memory = TutorMemoryService.getMemory(_profileId);
    _stats = memory.stats;
    _lastPlanDate = memory.lastPlanDate;
    _planWordIds = memory.planWordIds;
    _favoriteCategories = memory.favoriteCategories;
    _interestScores = memory.interestScores;

    // Restore a remembered conversation instead of greeting from scratch.
    if (memory.messages.isNotEmpty) {
      setState(() {
        _messages.addAll(memory.messages);
        // Lock only the bubbles the learner actually resolved. Blanket-locking
        // every restored quiz and picker used to kill the first-run
        // favorite-topic choice the moment it was reloaded here.
        _answeredQuizIds.addAll(TutorMemoryService.resolveAnsweredIds(memory));
      });
      _scrollToBottom();

      // First visit of a new day → welcome the learner back by name, mention
      // their favorite topic, and offer today's interest-aware lesson plan.
      final lastDay =
          TutorMemoryService.dayKey(memory.messages.last.timestamp);
      if (lastDay != TutorMemoryService.dayKey(DateTime.now())) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          final progress = ref.read(progressProvider);
          final msg = TutorEngine.welcomeBack(
            profile?.name ?? 'Learner',
            progress,
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

    // Fresh start: greet, then (first ever visit) ask for favorite topics so
    // examples can be personalized — or offer the usual analysis.
    setState(() {
      _messages.add(
        TutorEngine.greet(profile?.name ?? 'Learner', isFilipino: _isFilipino),
      );
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_favoriteCategories.isEmpty) {
        _addTutorMessage(TutorEngine.askInterests(isFilipino: _isFilipino));
        return;
      }
      final progress = ref.read(progressProvider);
      _addTutorMessage(
        TutorEngine.analyzeAndRespond(
          progress,
          profile?.name ?? 'Learner',
          _profileId,
          isFilipino: _isFilipino,
          interests: _interests,
        ),
      );
    });
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  void _persist() {
    // Fire-and-forget — local Hive write, mirrors the SR-service pattern.
    TutorMemoryService.saveMemory(
      _profileId,
      TutorMemory(
        messages: _messages,
        stats: _stats,
        lastPlanDate: _lastPlanDate,
        planWordIds: _planWordIds,
        favoriteCategories: _favoriteCategories,
        interestScores: _interestScores,
        answeredIds: _answeredQuizIds,
      ),
    );
  }

  /// The learner's extra channels, read outside `build` for the speech path.
  TutorMediaPolicy get _media => TutorMediaPolicy.forLearner(
        ref.read(profileProvider)?.disabilityType ?? DisabilityType.none,
        ref.read(profileProvider)?.role,
        ref.read(settingsProvider),
      );

  /// Appends a tutor message, reading it aloud for the profiles that depend on
  /// audio.
  ///
  /// Driven by [TutorMediaPolicy.speak] rather than the persona's
  /// `autoReadAloud`: the persona only knows Child vs Student, so a learner
  /// with a visual impairment — for whom audio is the whole channel — got a
  /// silent screen here while the floating companion spoke to them. Everyone
  /// with Text-to-Speech on keeps the manual "Listen" control either way.
  void _addTutorMessage(TutorMessage msg, {bool? speak}) {
    setState(() => _messages.add(msg));
    if (speak ?? _media.speak) _speak(msg.content);
    _scrollToBottom();
    _persist();
  }

  void _speak(String text) {
    // Speak the sentence, not the decoration — see [TutorSpeech].
    final spoken = TutorSpeech.forSpeech(text, isFilipino: _isFilipino);
    if (spoken.isEmpty) return;
    final tts = ref.read(ttsServiceProvider);
    if (_isFilipino) {
      tts.speakFilipino(spoken);
    } else {
      tts.speakEnglish(spoken);
    }
  }

  void _flashCelebrate() {
    setState(() => _avatarState = TutorAvatarState.celebrate);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _avatarState = TutorAvatarState.idle);
    });
  }

  // ─── Sending ──────────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.student,
        content: text,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _stats = _stats.copyWith(questionsAsked: _stats.questionsAsked + 1);
    });
    _textController.clear();
    _scrollToBottom();

    // Same routing rule as the floating companion, so one question gets one
    // answer whichever surface it is asked on: structured intents (quiz,
    // lesson, hint, progress, favorites, a named category) always stay on the
    // offline engine; only genuinely open-ended questions may go online, and
    // any failure falls back to the engine.
    if (GeminiService.isConfigured && TutorEngine.isFreeForm(text)) {
      _respondOnline(text);
      return;
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _respondWithEngine(text);
    });
  }

  /// The default, fully-offline responder: the rule-based [TutorEngine].
  void _respondWithEngine(String text) {
    // Asking about a topic is itself an interest signal.
    final mentioned = TutorEngine.categoryInText(text);
    if (mentioned != null) {
      _interestScores = TutorEngine.bumpInterest(
          _interestScores, mentioned, TutorEngine.signalAsk);
    }
    final progress = ref.read(progressProvider);
    final response = TutorEngine.respondToQuestion(
      text,
      progress,
      _profileId,
      isFilipino: _isFilipino,
      interests: _interests,
    );
    setState(() => _isTyping = false);
    if (response.action?.type == TutorActionType.startLesson) {
      _planWordIds = response.action!.planWordIds ?? const [];
    }
    _addTutorMessage(response);
    // "I like animals" → the engine confirmed a favorite; record it.
    if (response.action?.type == TutorActionType.pickInterests &&
        response.action!.categoryLabel != null) {
      final cat =
          TutorEngine.categoryFromName(response.action!.categoryLabel!);
      if (cat != null) {
        _recordFavorite(cat);
        _celebrateNewFavorite(cat);
      }
    }
  }

  /// The online responder. On ANY failure (offline, timeout, quota, bad
  /// response) it falls back to [_respondWithEngine], so the learner always
  /// gets a helpful reply and the switch stays invisible to them.
  Future<void> _respondOnline(String text) async {
    String? answer;
    try {
      // Fast local radio check first: with no network at all, skip the HTTP
      // attempt so the offline reply is instant instead of waiting out a
      // socket timeout.
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
    if (!mounted) return;
    if (answer == null || answer.trim().isEmpty) {
      _respondWithEngine(text); // graceful offline fallback
      return;
    }
    setState(() => _isTyping = false);
    _addTutorMessage(TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: answer.trim(),
      timestamp: DateTime.now(),
    ));
  }

  void _sendQuick(String command) {
    _textController.text = command;
    _sendMessage();
  }

  // ─── Favorite topics (interest personalization) ───────────────────────────

  /// Remembers [cat] as an explicit favorite (most recent first, capped) and
  /// strengthens its implicit score.
  void _recordFavorite(FlashcardCategory cat) {
    setState(() {
      _favoriteCategories = [
        cat.name,
        ..._favoriteCategories.where((n) => n != cat.name),
      ].take(TutorEngine.maxFavorites).toList();
      _interestScores = TutorEngine.bumpInterest(
          _interestScores, cat, TutorEngine.signalPick);
    });
    _persist();
  }

  /// Celebration + an immediate quiz from the new favorite topic, so the
  /// learner sees the personalization right away.
  void _celebrateNewFavorite(FlashcardCategory cat) {
    _flashCelebrate();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _addTutorMessage(
        TutorEngine.quickQuiz(interests: [cat], isFilipino: _isFilipino),
      );
    });
  }

  /// A favorite-topic chip was tapped on a [TutorActionType.pickInterests]
  /// bubble. Locks the picker, records the pick, confirms, then quizzes.
  void _handleInterestPick(TutorMessage msg, String categoryName) {
    if (_answeredQuizIds.contains(msg.id)) return;
    final cat = TutorEngine.categoryFromName(categoryName);
    if (cat == null) return;
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _answeredQuizIds.add(msg.id));
    _recordFavorite(cat);
    _addTutorMessage(
      TutorEngine.interestConfirmation(cat, isFilipino: _isFilipino),
    );
    _celebrateNewFavorite(cat);
  }

  // ─── Quiz answering + progress tracking ───────────────────────────────────

  void _handleQuizAnswer(TutorMessage msg, String answer) {
    if (msg.action?.type != TutorActionType.quickQuiz) return;
    if (_answeredQuizIds.contains(msg.id)) return; // no double-counting
    final action = msg.action!;
    final correct = answer == action.correctAnswer;

    ref.read(hapticServiceProvider).lightTap();
    final notifier = ref.read(progressProvider.notifier);

    // ── Real progress tracking ──
    // Any answered question is a learning activity → keeps the streak alive.
    notifier.recordDailyActivity();
    if (correct) notifier.addStars(_kQuizStar);
    // Feed spaced repetition so the word is tracked + future plans adapt.
    if (action.wordId != null) {
      SpacedRepetitionService.recordWordAttempt(
        profileId: _profileId,
        wordId: action.wordId!,
        wasCorrect: correct,
      );
      // Count the word towards vocabulary learned, exactly as a game would —
      // otherwise the tutor hands out stars while "words learned" stays at 0.
      if (correct) notifier.recordWordsLearned([action.wordId!]);
    }
    // Engaging with a topic's quizzes is an implicit interest signal.
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

    setState(() {
      _answeredQuizIds.add(msg.id);
      _stats = _stats.copyWith(
        quizzesAnswered: _stats.quizzesAnswered + 1,
        quizzesCorrect: _stats.quizzesCorrect + (correct ? 1 : 0),
      );
      _messages.add(TutorMessage(
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
      ));
    });
    if (correct) _flashCelebrate();
    _scrollToBottom();
    _persist();

    // Re-teach a missed word before moving on — for standalone quizzes as well
    // as lessons, so a wrong answer is always followed by the word itself
    // rather than just a verdict.
    final missedCard = (!correct && action.wordId != null)
        ? TutorEngine.cardById(action.wordId!)
        : null;
    if (missedCard != null) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _addTutorMessage(
          TutorEngine.reteach(missedCard, isFilipino: _isFilipino),
        );
      });
    }

    // Continue the lesson, if one is running.
    if (_inLesson) {
      if (correct) {
        if (_inReviewRound) {
          _reviewCorrect++;
        } else {
          _lessonCorrect++;
        }
      } else if (!_inReviewRound &&
          action.wordId != null &&
          !_missedWordIds.contains(action.wordId)) {
        // Queue it for the retry round (first pass only — one loop maximum).
        _missedWordIds.add(action.wordId!);
      }
      _lessonIndex++;
      // Leave room for the re-teach card before the next question lands.
      final nextDelay =
          Duration(milliseconds: missedCard != null ? 1800 : 900);
      if (_lessonIndex < _lessonCards.length) {
        Future.delayed(nextDelay, () {
          if (mounted) _askLessonQuestion();
        });
      } else if (!_inReviewRound && _missedWordIds.isNotEmpty) {
        Future.delayed(nextDelay, () {
          if (mounted) _startReviewRound();
        });
      } else {
        Future.delayed(nextDelay, () {
          if (mounted) _finishLesson();
        });
      }
    }
  }

  // ─── Daily learning plan / lesson ─────────────────────────────────────────

  void _handleActionTap(TutorMessage msg) {
    final action = msg.action;
    if (action == null) return;
    if (action.type == TutorActionType.startLesson) {
      _startLesson(action.planWordIds ?? const []);
    } else if (action.targetRoute != null) {
      context.push(action.targetRoute!);
    }
  }

  void _startLesson(List<String> wordIds) {
    final cards = <Flashcard>[];
    for (final id in wordIds) {
      final card = TutorEngine.cardById(id);
      if (card != null) cards.add(card);
    }
    if (cards.isEmpty) return;

    setState(() {
      _lessonCards = cards;
      _lessonIndex = 0;
      _lessonCorrect = 0;
      _inLesson = true;
      _lessonTotal = cards.length;
      _missedWordIds.clear();
      _inReviewRound = false;
      _reviewCorrect = 0;
    });
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
    setState(() {
      _lessonCards = cards;
      _lessonIndex = 0;
      _inReviewRound = true;
      _reviewCorrect = 0;
    });
    _addTutorMessage(
      TutorEngine.reviewRoundIntro(cards.length, isFilipino: _isFilipino),
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _askLessonQuestion();
    });
  }

  void _askLessonQuestion() {
    if (_lessonIndex >= _lessonCards.length) return;
    final card = _lessonCards[_lessonIndex];
    final position = '${_lessonIndex + 1}/${_lessonCards.length}';
    final prefix = _inReviewRound
        ? (_isFilipino ? '🔁 Balik-aral $position' : '🔁 Review $position')
        : (_isFilipino ? '📚 Aralin $position' : '📚 Lesson $position');
    _addTutorMessage(
      TutorEngine.quizForWord(card, isFilipino: _isFilipino, prefix: prefix),
    );
  }

  void _finishLesson() {
    // The first-pass length, not _lessonCards — a retry round replaces that.
    final total = _lessonTotal;
    final alreadyToday = _lastPlanDate == TutorMemoryService.dayKey(DateTime.now());
    final notifier = ref.read(progressProvider.notifier);

    // Reward the lesson once per calendar day; revisits still give practice.
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

    setState(() {
      _inLesson = false;
      _inReviewRound = false;
    });
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

  /// Resolves and plays the sign for [cardId]. Every clip is a network fetch,
  /// so this shows a resolving overlay and lands on the "not available" sheet
  /// when the learner is offline — never an indefinite spinner.
  Future<void> _watchSign(String cardId) async {
    if (_isLoadingFsl) return;
    final card = TutorEngine.cardById(cardId);
    if (card == null) return;
    setState(() => _isLoadingFsl = true);
    try {
      await showSignForCard(context, card: card, profileId: _profileId);
    } finally {
      if (mounted) setState(() => _isLoadingFsl = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    _persona = TutorPersona.of(profile?.role);
    final media = TutorMediaPolicy.forLearner(
      profile?.disabilityType ?? DisabilityType.none,
      profile?.role,
      settings,
    );
    // Watched so the sign controls appear as soon as the manifest is parsed;
    // until then no word reports a clip and none are offered.
    ref.watch(fslAvailabilityProvider);

    /// The sign control is offered only when this learner's policy allows it
    /// AND the word actually has a clip somewhere — bundled, direct, or CDN.
    VoidCallback? watchSignFor(TutorMessage msg) {
      if (!media.sign) return null;
      final id = msg.action?.wordId;
      if (id == null) return null;
      final card = TutorEngine.cardById(id);
      if (card == null || !FslAssetsService.hasAnyVideoSource(card)) {
        return null;
      }
      return () => _watchSign(id);
    }
    final avatarState =
        _isTyping ? TutorAvatarState.thinking : _avatarState;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TutorAvatar(persona: _persona, state: avatarState, size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_persona.title(isFilipino),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: context.maxContentWidth),
            child: Column(
              children: [
                TutorStatsStrip(
                    stats: _stats, padding: padding, isFilipino: isFilipino),
                // Quick action chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      EdgeInsets.symmetric(horizontal: padding, vertical: 4),
                  child: Row(
                    children: [
                      TutorQuickChip(
                        label: isFilipino ? 'Aralin' : 'Lesson',
                        emoji: '🎯',
                        onTap: () => _sendQuick('lesson'),
                      ),
                      const SizedBox(width: 8),
                      TutorQuickChip(
                        label: 'Quiz',
                        emoji: '❓',
                        onTap: () => _sendQuick('quiz'),
                      ),
                      const SizedBox(width: 8),
                      TutorQuickChip(
                        label: 'Progress',
                        emoji: '📊',
                        onTap: () => _sendQuick('progress'),
                      ),
                      const SizedBox(width: 8),
                      TutorQuickChip(
                        label: 'Hint',
                        emoji: '💡',
                        onTap: () => _sendQuick('hint'),
                      ),
                      const SizedBox(width: 8),
                      TutorQuickChip(
                        label: isFilipino ? 'Practice' : 'Practice',
                        emoji: '📝',
                        onTap: () => _sendQuick('practice'),
                      ),
                      const SizedBox(width: 8),
                      TutorQuickChip(
                        label: isFilipino ? 'Paborito' : 'Favorites',
                        emoji: '💖',
                        onTap: () => _sendQuick('favorites'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return TutorTypingIndicator(persona: _persona);
                      }
                      final msg = _messages[index];
                      return TutorMessageBubble(
                        message: msg,
                        persona: _persona,
                        isFilipino: isFilipino,
                        media: media,
                        answered: _answeredQuizIds.contains(msg.id),
                        onQuizAnswer: (answer) => _handleQuizAnswer(msg, answer),
                        onInterestPick: (name) => _handleInterestPick(msg, name),
                        onActionTap: () => _handleActionTap(msg),
                        // Hide the read-aloud affordance for audio-off profiles
                        // (e.g. hearing) — the chat text already carries
                        // everything. Mirrors the companion panel.
                        onSpeak: settings.ttsEnabled
                            ? () => _speak(msg.content)
                            : null,
                        onWatchSign: watchSignFor(msg),
                      );
                    },
                  ),
                ),

                // Input
                Container(
                  padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
                  decoration: BoxDecoration(
                    color: hc.surface,
                    border: Border(top: BorderSide(color: hc.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: isFilipino
                              ? 'I-type ang iyong tanong'
                              : 'Type your question',
                          child: TextField(
                            controller: _textController,
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                              hintText: isFilipino
                                  ? 'Magtanong...'
                                  : 'Ask a question...',
                              filled: true,
                              fillColor: hc.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: hc.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: hc.border),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: isFilipino ? 'Ipadala' : 'Send',
                        child: IconButton.filled(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
          // Sits above the chat so a repeated tap can't stack downloads while
          // a clip is being resolved.
          if (_isLoadingFsl) const FslLoadingOverlay(),
        ],
      ),
    );
  }
}
