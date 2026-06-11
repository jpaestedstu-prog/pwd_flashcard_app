import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../data/local/local_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import '../services/cloud_message_repository.dart';
import '../services/conversation_directory_service.dart';
import '../services/friend_service.dart';
import '../widgets/friend_ui.dart';

const _uuid = Uuid();

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  List<LocalMessage> _allMessages = [];
  List<Conversation> _peerSkeletons = [];
  List<Conversation> _conversations = [];
  List<FriendRequest> _incomingRequests = [];
  Conversation? _activeConversation;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<LocalMessage>>? _messagesSub;
  StreamSubscription<List<Conversation>>? _convosSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  String? _watchedProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _convosSub?.cancel();
    _requestsSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    if (_watchedProfileId == profile.id) return;

    // Tear down any previous subscriptions if the active profile changed.
    await _messagesSub?.cancel();
    await _convosSub?.cancel();
    await _requestsSub?.cancel();
    _watchedProfileId = profile.id;

    // 0. Self-heal: re-publish the active profile to Firestore so
    //    `profiles/{id}` and `profile_directory/{handle}` are
    //    guaranteed to exist for this device. Idempotent (`set` with
    //    `merge: true` under the hood). Covers profiles created before
    //    the rules were deployed — their original publish would have
    //    been silently denied. Fire-and-forget; LocalRepository.saveProfile
    //    already swallows cloud failures.
    // ignore: discarded_futures
    const LocalRepository().saveProfile(profile);

    // 1. Paint the Hive cache for instant initial render.
    final cached =
        await CloudMessageRepository.instance.loadCached(profile.id);
    if (!mounted) return;
    setState(() => _allMessages = cached);

    // 2. Live message stream — merged sent + received via Firestore.
    _messagesSub = CloudMessageRepository.instance
        .watchMessagesFor(profile.id)
        .listen((messages) {
      if (!mounted) return;
      setState(() {
        _allMessages = messages;
        _rebuildConversations();
      });
    });

    // 3. Conversation directory — friends + classroom teachers for
    //    students; classroom roster for educators. Source-of-truth for
    //    which peers appear in the inbox.
    _convosSub = ConversationDirectoryService.instance
        .watch(profile)
        .listen((skeletons) {
      if (!mounted) return;
      setState(() {
        _peerSkeletons = skeletons;
        _rebuildConversations();
      });
    });

    // 4. Friend requests badge (student/child only).
    if (_canAddFriends(profile.role)) {
      _requestsSub = FriendService.instance
          .watchIncomingRequests(profile.id)
          .listen((reqs) {
        if (!mounted) return;
        setState(() => _incomingRequests = reqs);
      });
    }
  }

  void _rebuildConversations() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // Group messages by the other party so we can attach them to the
    // matching peer skeleton.
    final grouped = <String, List<LocalMessage>>{};
    for (final msg in _allMessages) {
      final otherId =
          msg.senderId == profile.id ? msg.recipientId : msg.senderId;
      grouped.putIfAbsent(otherId, () => []).add(msg);
    }

    final convos = <Conversation>[];
    for (final skel in _peerSkeletons) {
      final msgs = grouped[skel.otherProfileId] ?? const <LocalMessage>[];
      final sorted = [...msgs]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      convos.add(Conversation(
        otherProfileId: skel.otherProfileId,
        otherProfileName: skel.otherProfileName,
        otherProfileRole: skel.otherProfileRole,
        messages: sorted,
      ));
    }

    // Surface any messages from peers we don't know about yet — covers
    // the brief window between a friendship being accepted on the other
    // side and the directory entry propagating to this device.
    final knownIds = convos.map((c) => c.otherProfileId).toSet();
    for (final entry in grouped.entries) {
      if (knownIds.contains(entry.key)) continue;
      final sample = entry.value.first;
      final name = sample.senderId == profile.id
          ? 'User'
          : (sample.senderName.isEmpty ? 'User' : sample.senderName);
      final sorted = [...entry.value]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      convos.add(Conversation(
        otherProfileId: entry.key,
        otherProfileName: name,
        otherProfileRole: 'student',
        messages: sorted,
      ));
    }

    // Sort: conversations with the most recent message first; empty
    // threads fall to the bottom alphabetically.
    convos.sort((a, b) {
      final aLast = a.lastMessage?.timestamp;
      final bLast = b.lastMessage?.timestamp;
      if (aLast != null && bLast != null) return bLast.compareTo(aLast);
      if (aLast != null) return -1;
      if (bLast != null) return 1;
      return a.otherProfileName
          .toLowerCase()
          .compareTo(b.otherProfileName.toLowerCase());
    });

    _conversations = convos;
    // Keep the open thread bound to the same peer across rebuilds.
    if (_activeConversation != null) {
      final id = _activeConversation!.otherProfileId;
      final next = _conversations.where((c) => c.otherProfileId == id);
      _activeConversation = next.isEmpty ? null : next.first;
    }
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
      _rebuildConversations();
    });

    await CloudMessageRepository.instance.sendMessage(message);
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

  bool _canAddFriends(UserRole role) =>
      role == UserRole.student || role == UserRole.child;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final profile = ref.watch(profileProvider);
    final showFriendTools = profile != null && _canAddFriends(profile.role);

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
        actions: [
          if (_activeConversation == null && showFriendTools)
            FriendRequestsBadgeButton(
              count: _incomingRequests.length,
              onTap: () => _showRequestsSheet(profile, isFilipino),
            ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton:
          _activeConversation == null && showFriendTools
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddFriendDialog(profile, isFilipino),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(isFilipino ? 'Magdagdag' : 'Add Friend'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                )
              : null,
      body: _activeConversation != null
          ? _buildThread(isFilipino, padding)
          : _buildInbox(isFilipino, padding, profile, showFriendTools),
    );
  }

  Widget _buildInbox(bool isFilipino, double padding, UserProfile? profile,
      bool showFriendTools) {
    final hc = HCColor.of(context);
    final isEducator =
        profile != null && !_canAddFriends(profile.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFriendTools && profile?.username != null)
          UsernameHeaderCard(
            username: profile!.username!,
            isFilipino: isFilipino,
          ),
        Expanded(
          child: _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text(
                          isEducator
                              ? (isFilipino
                                  ? 'Wala pang mag-aaral sa iyong klase.\nKapag sumali ang estudyante gamit ang code, lalabas sila dito.'
                                  : 'No students in your classes yet.\nThey appear here once they join with the class code.')
                              : (isFilipino
                                  ? 'Wala pang kaibigan.\nPindutin ang + para magdagdag gamit ang username.'
                                  : 'No friends yet.\nTap + to add one with their username.'),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium
                              .copyWith(color: hc.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(padding),
                  itemCount: _conversations.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return _ConversationTile(
                      conversation: convo,
                      isFilipino: isFilipino,
                      onTap: () =>
                          setState(() => _activeConversation = convo),
                    ).animate().fadeIn(
                        duration: 300.ms, delay: (index * 60).ms);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThread(bool isFilipino, double padding) {
    final profile = ref.read(profileProvider);
    final hc = HCColor.of(context);
    final messages = _activeConversation!.messages;

    return Column(
      children: [
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
                      ? 'I-type ang mensahe'
                      : 'Type a message',
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

  // ─── Friend dialogs ───────────────────────────────────

  Future<void> _showAddFriendDialog(UserProfile me, bool isFilipino) {
    return showAddFriendDialog(context, me: me, isFilipino: isFilipino);
  }

  Future<void> _showRequestsSheet(UserProfile me, bool isFilipino) {
    return showFriendRequestsSheet(
      context,
      myProfileId: me.id,
      isFilipino: isFilipino,
      initialRequests: _incomingRequests,
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
      label:
          '${conversation.otherProfileName}, ${conversation.otherProfileRole}',
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
