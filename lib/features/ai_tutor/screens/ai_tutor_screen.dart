import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../data/local/seed_data.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../models/tutor_models.dart';
import '../services/tutor_engine.dart';
import '../services/tutor_memory_service.dart';
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

  // Quiz / lesson run state.
  final _answeredQuizIds = <String>{};
  List<Flashcard> _lessonCards = const [];
  int _lessonIndex = 0;
  int _lessonCorrect = 0;
  bool _inLesson = false;

  // Avatar mood.
  TutorAvatarState _avatarState = TutorAvatarState.idle;

  late TutorPersona _persona;
  String get _profileId => ref.read(profileProvider)?.id ?? 'guest';
  bool get _isFilipino => ref.read(settingsProvider).locale == 'fil';

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

    // Restore a remembered conversation instead of greeting from scratch.
    if (memory.messages.isNotEmpty) {
      setState(() {
        _messages.addAll(memory.messages);
        for (final m in memory.messages) {
          if (m.action?.type == TutorActionType.quickQuiz) {
            // Quizzes restored from history are already in the past — lock them.
            _answeredQuizIds.add(m.id);
          }
        }
      });
      _scrollToBottom();
      return;
    }

    // Fresh start: greet, then offer a personalized analysis after a beat.
    setState(() {
      _messages.add(
        TutorEngine.greet(profile?.name ?? 'Learner', isFilipino: _isFilipino),
      );
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final progress = ref.read(progressProvider);
      _addTutorMessage(
        TutorEngine.analyzeAndRespond(
          progress,
          profile?.name ?? 'Learner',
          _profileId,
          isFilipino: _isFilipino,
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
      ),
    );
  }

  /// Appends a tutor message, optionally reading it aloud (auto for Child).
  void _addTutorMessage(TutorMessage msg, {bool? speak}) {
    setState(() => _messages.add(msg));
    if (speak ?? _persona.autoReadAloud) _speak(msg.content);
    _scrollToBottom();
    _persist();
  }

  void _speak(String text) {
    final tts = ref.read(ttsServiceProvider);
    if (_isFilipino) {
      tts.speakFilipino(text);
    } else {
      tts.speakEnglish(text);
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

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final progress = ref.read(progressProvider);
      final response = TutorEngine.respondToQuestion(
        text,
        progress,
        _profileId,
        isFilipino: _isFilipino,
      );
      setState(() => _isTyping = false);
      if (response.action?.type == TutorActionType.startLesson) {
        _planWordIds = response.action!.planWordIds ?? const [];
      }
      _addTutorMessage(response);
    });
  }

  void _sendQuick(String command) {
    _textController.text = command;
    _sendMessage();
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

    // Continue the lesson, if one is running.
    if (_inLesson) {
      if (correct) _lessonCorrect++;
      _lessonIndex++;
      if (_lessonIndex < _lessonCards.length) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _askLessonQuestion();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), () {
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
      final match = SeedData.allFlashcards.where((c) => c.id == id);
      if (match.isNotEmpty) cards.add(match.first);
    }
    if (cards.isEmpty) return;

    setState(() {
      _lessonCards = cards;
      _lessonIndex = 0;
      _lessonCorrect = 0;
      _inLesson = true;
    });
    _askLessonQuestion();
  }

  void _askLessonQuestion() {
    if (_lessonIndex >= _lessonCards.length) return;
    final card = _lessonCards[_lessonIndex];
    final prefix = _isFilipino
        ? '📚 Aralin ${_lessonIndex + 1}/${_lessonCards.length}'
        : '📚 Lesson ${_lessonIndex + 1}/${_lessonCards.length}';
    _addTutorMessage(
      TutorEngine.quizForWord(card, isFilipino: _isFilipino, prefix: prefix),
    );
  }

  void _finishLesson() {
    final total = _lessonCards.length;
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

    setState(() => _inLesson = false);
    _flashCelebrate();
    _addTutorMessage(TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: _isFilipino
          ? '🎉 Tapos na ang aralin! Nakakuha ka ng $_lessonCorrect/$total na tama.\n\n$bonusLine'
          : '🎉 Lesson complete! You got $_lessonCorrect/$total correct.\n\n$bonusLine',
      timestamp: DateTime.now(),
    ));
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.maxContentWidth),
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
                        answered: _answeredQuizIds.contains(msg.id),
                        onQuizAnswer: (answer) => _handleQuizAnswer(msg, answer),
                        onActionTap: () => _handleActionTap(msg),
                        onSpeak: () => _speak(msg.content),
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
    );
  }
}
