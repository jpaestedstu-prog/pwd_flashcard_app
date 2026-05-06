import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../providers/app_providers.dart';
import '../../../data/local/hive_service.dart';
import '../models/messaging_models.dart';

const _uuid = Uuid();

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  List<LocalMessage> _allMessages = [];
  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final saved = await HiveService.getMessages(profile.id);
    if (!mounted) return;
    setState(() {
      _allMessages = saved;
      _buildConversations();
    });
  }

  void _buildConversations() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // Group messages by the other profile
    final Map<String, List<LocalMessage>> grouped = {};
    for (final msg in _allMessages) {
      final otherIdForMsg =
          msg.senderId == profile.id ? msg.recipientId : msg.senderId;
      grouped.putIfAbsent(otherIdForMsg, () => []).add(msg);
    }

    // Build conversations from profiles
    final allProfiles = HiveService.getAllProfiles();
    final convos = <Conversation>[];
    for (final p in allProfiles) {
      if (p['id'] == profile.id) continue;
      final threadMessages = grouped[p['id']] ?? [];
      threadMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      convos.add(Conversation(
        otherProfileId: p['id'] as String,
        otherProfileName: p['name'] as String? ?? 'User',
        otherProfileRole: p['role'] as String? ?? 'student',
        messages: threadMessages,
      ));
    }
    // Sort by last message time
    convos.sort((a, b) {
      final aTime = a.lastMessage?.timestamp ?? DateTime(2000);
      final bTime = b.lastMessage?.timestamp ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    setState(() {
      _conversations = convos;
    });
  }

  Future<void> _sendMessage(String content, MessageType type) async {
    if (content.isEmpty || _activeConversation == null) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final message = LocalMessage(
      id: _uuid.v4(),
      senderId: profile.id,
      senderName: profile.name,
      recipientId: _activeConversation!.otherProfileId,
      content: content,
      type: type,
      timestamp: DateTime.now(),
    );

    setState(() {
      _allMessages.add(message);
      _buildConversations();
      // Update active conversation reference
      _activeConversation = _conversations.firstWhere(
        (c) => c.otherProfileId == _activeConversation!.otherProfileId,
      );
    });

    await HiveService.saveMessages(profile.id, _allMessages);
    _textController.clear();
    ref.read(hapticServiceProvider).lightTap();

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
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;

    return Scaffold(
      appBar: AppBar(
        title: _activeConversation != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_activeConversation!.roleEmoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(_activeConversation!.otherProfileName),
                ],
              )
            : Text(isFilipino ? '💬 Mga Mensahe' : '💬 Messages'),
        centerTitle: true,
        leading: _activeConversation != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _activeConversation = null),
              )
            : null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _activeConversation != null
          ? _buildThread(isFilipino, padding)
          : _buildInbox(isFilipino, padding),
    );
  }

  Widget _buildInbox(bool isFilipino, double padding) {
    final hc = HCColor.of(context);

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              isFilipino
                  ? 'Walang mga mensahe pa.\nGumawa ng iba pang profile para magsimula!'
                  : 'No messages yet.\nCreate another profile to start messaging!',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(padding),
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final convo = _conversations[index];
        return _ConversationTile(
          conversation: convo,
          isFilipino: isFilipino,
          onTap: () => setState(() => _activeConversation = convo),
        ).animate().fadeIn(duration: 300.ms, delay: (index * 60).ms);
      },
    );
  }

  Widget _buildThread(bool isFilipino, double padding) {
    final profile = ref.read(profileProvider);
    final hc = HCColor.of(context);
    final messages = _activeConversation!.messages;

    return Column(
      children: [
        // Quick encouragement chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
          child: Row(
            children: QuickEncouragements.items.map((item) {
              final text = isFilipino ? item['fil']! : item['en']!;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(text, style: const TextStyle(fontSize: 12)),
                  onPressed: () =>
                      _sendMessage(text, MessageType.encouragement),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // Messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    isFilipino
                        ? 'Walang mensahe pa. Mag-send ng unang mensahe!'
                        : 'No messages yet. Send the first message!',
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textSecondary),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(padding),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == profile?.id;
                    return _MessageBubbleMsgScreen(
                      message: msg,
                      isMine: isMine,
                      isFilipino: isFilipino,
                    );
                  },
                ),
        ),

        // Text input
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
                  label: isFilipino ? 'I-type ang mensahe' : 'Type a message',
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (v) =>
                        _sendMessage(v.trim(), MessageType.text),
                    decoration: InputDecoration(
                      hintText: isFilipino
                          ? 'Mag-type ng mensahe...'
                          : 'Type a message...',
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
                  onPressed: () => _sendMessage(
                      _textController.text.trim(), MessageType.text),
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
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isFilipino;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isFilipino,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final last = conversation.lastMessage;

    return Semantics(
      button: true,
      label: '${conversation.otherProfileName}, ${conversation.otherProfileRole}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              conversation.roleEmoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          conversation.otherProfileName,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: hc.textPrimary,
          ),
        ),
        subtitle: last != null
            ? Text(
                last.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textSecondary),
              )
            : Text(
                isFilipino ? 'Walang mensahe pa' : 'No messages yet',
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textSecondary),
              ),
        trailing: last != null
            ? Text(
                _formatTime(last.timestamp),
                style: AppTypography.labelSmall
                    .copyWith(color: hc.textSecondary),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _MessageBubbleMsgScreen extends StatelessWidget {
  final LocalMessage message;
  final bool isMine;
  final bool isFilipino;

  const _MessageBubbleMsgScreen({
    required this.message,
    required this.isMine,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isEncouragement = message.type == MessageType.encouragement;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: AppTypography.labelMedium.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isEncouragement
                    ? Colors.pink.withValues(alpha: 0.08)
                    : isMine
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : hc.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMine ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      isMine ? Radius.zero : const Radius.circular(16),
                ),
                border: Border.all(
                  color: isEncouragement
                      ? Colors.pink.withValues(alpha: 0.2)
                      : isMine
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : hc.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEncouragement)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded,
                              size: 14, color: Colors.pink),
                          const SizedBox(width: 4),
                          Text(
                            isFilipino ? 'Pagpapalakas' : 'Encouragement',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.pink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message.content,
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
