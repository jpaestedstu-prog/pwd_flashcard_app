import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../providers/app_providers.dart';
import '../models/tutor_models.dart';
import '../services/tutor_engine.dart';

const _uuid = Uuid();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initialize() {
    final profile = ref.read(profileProvider);
    final progress = ref.read(progressProvider);
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    setState(() {
      _messages.add(
        TutorEngine.greet(profile?.name ?? 'Learner',
            isFilipino: isFilipino),
      );
    });

    // Auto-send an analysis after a brief delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _messages.add(
            TutorEngine.analyzeAndRespond(
              progress,
              profile?.name ?? 'Learner',
              isFilipino: isFilipino,
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final studentMsg = TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.student,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(studentMsg);
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Simulate "thinking" delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final progress = ref.read(progressProvider);
      final settings = ref.read(settingsProvider);
      final isFilipino = settings.locale == 'fil';

      final response = TutorEngine.respondToQuestion(
        text,
        progress,
        isFilipino: isFilipino,
      );

      setState(() {
        _isTyping = false;
        _messages.add(response);
      });
      _scrollToBottom();
    });
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

  void _handleQuizAnswer(TutorMessage msg, String answer) {
    if (msg.action?.type != TutorActionType.quickQuiz) return;
    final correct = answer == msg.action!.correctAnswer;
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    ref.read(hapticServiceProvider).lightTap();

    setState(() {
      _messages.add(TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: correct
            ? (isFilipino
                ? '✅ Tama! Ang sagot ay "$answer". Napakagaling! 🎉'
                : '✅ Correct! The answer is "$answer". Well done! 🎉')
            : (isFilipino
                ? '❌ Hindi tama. Ang tamang sagot ay "${msg.action!.correctAnswer}". Subukan muli sa susunod! 💪'
                : '❌ Not quite. The correct answer is "${msg.action!.correctAnswer}". Try again next time! 💪'),
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(isFilipino ? 'AI Tutor' : 'AI Tutor'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick action chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
              child: Row(
                children: [
                  _QuickChip(
                    label: isFilipino ? 'Quiz' : 'Quiz',
                    emoji: '❓',
                    onTap: () {
                      _textController.text = 'quiz';
                      _sendMessage();
                    },
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: isFilipino ? 'Progress' : 'Progress',
                    emoji: '📊',
                    onTap: () {
                      _textController.text = 'progress';
                      _sendMessage();
                    },
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: isFilipino ? 'Hint' : 'Hint',
                    emoji: '💡',
                    onTap: () {
                      _textController.text = 'hint';
                      _sendMessage();
                    },
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: isFilipino ? 'Practice' : 'Practice',
                    emoji: '📝',
                    onTap: () {
                      _textController.text = 'practice';
                      _sendMessage();
                    },
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
                    return _TypingIndicator();
                  }
                  final msg = _messages[index];
                  return _MessageBubble(
                    message: msg,
                    isFilipino: isFilipino,
                    onQuizAnswer: (answer) =>
                        _handleQuizAnswer(msg, answer),
                    onActionTap: () {
                      if (msg.action?.targetRoute != null) {
                        context.push(msg.action!.targetRoute!);
                      }
                    },
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
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final TutorMessage message;
  final bool isFilipino;
  final ValueChanged<String>? onQuizAnswer;
  final VoidCallback? onActionTap;

  const _MessageBubble({
    required this.message,
    required this.isFilipino,
    this.onQuizAnswer,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTutor = message.role == TutorMessageRole.tutor;
    final hc = HCColor.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTutor) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isTutor ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isTutor
                        ? hc.surface
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isTutor ? Radius.zero : const Radius.circular(16),
                      bottomRight:
                          isTutor ? const Radius.circular(16) : Radius.zero,
                    ),
                    border: Border.all(
                      color: isTutor
                          ? hc.border
                          : AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                // Quiz options
                if (message.action?.type == TutorActionType.quickQuiz &&
                    message.action?.options != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.action!.options!.map((option) {
                        return Semantics(
                          button: true,
                          label: option,
                          child: InkWell(
                            onTap: () => onQuizAnswer?.call(option),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                option,
                                style: AppTypography.labelMedium.copyWith(
                                  color: hc.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Practice redirect button
                if (message.action?.type ==
                    TutorActionType.practiceRedirect)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: onActionTap,
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 18, color: AppColors.textOnPrimary),
                      label: Text(
                        isFilipino ? 'Mag-Practice' : 'Start Practice',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textOnPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isTutor) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: hc.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .then()
        .fadeOut(duration: 400.ms);
  }
}
