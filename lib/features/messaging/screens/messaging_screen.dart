import 'dart:async';

import 'package:camera/camera.dart';
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
import '../../../data/models/models.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../providers/app_providers.dart';
import '../../gaze_control/services/gaze_detector.dart';
import '../../gaze_control/widgets/gaze_dpad_scope.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import '../providers/messaging_providers.dart';
import '../services/cloud_message_repository.dart';
import '../services/conversation_directory_service.dart';
import '../services/friend_service.dart';
import '../services/profile_directory_service.dart';
import '../widgets/friend_ui.dart';
import '../models/composer_presentation.dart';
import '../widgets/composer_pickers.dart';
import '../../../data/local/seed_data.dart';
import '../../ai_tutor/services/tutor_sign_launcher.dart';

const _uuid = Uuid();

class MessagingScreen extends ConsumerStatefulWidget {
  /// Injection seams for tests, forwarded to the [GazeDpadScope]; production
  /// uses the real camera + ML Kit. Mirrors the seams on the other
  /// camera-owning screens so the hands-free wiring can be driven headlessly.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const MessagingScreen({super.key, this.camerasLoader, this.detectorFactory});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  List<LocalMessage> _allMessages = [];
  List<Conversation> _peerSkeletons = [];
  List<Conversation> _conversations = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];

  /// profileId → display name for the people I've asked, resolved from the
  /// directory (the request doc only carries the sender's own name).
  Map<String, String> _outgoingNames = const {};
  Conversation? _activeConversation;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<Conversation>>? _convosSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  StreamSubscription<List<FriendRequest>>? _outgoingSub;
  String? _watchedProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _convosSub?.cancel();
    _requestsSub?.cancel();
    _outgoingSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    if (_watchedProfileId == profile.id) return;

    // Tear down any previous subscriptions if the active profile changed.
    await _convosSub?.cancel();
    await _requestsSub?.cancel();
    await _outgoingSub?.cancel();
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

    // 1. Paint the Hive cache for instant initial render. The live message
    //    stream itself comes from [activeProfileMessagesProvider], shared
    //    with the Home hubs' unread badge so only one listener pair exists.
    final cached = await CloudMessageRepository.instance.loadCached(profile.id);
    if (!mounted) return;
    if (_allMessages.isEmpty) {
      setState(() {
        _allMessages = cached;
        _rebuildConversations();
      });
    }

    // 2. Conversation directory — friends + classroom teachers for
    //    students; classroom roster for educators. Source-of-truth for
    //    which peers appear in the inbox.
    _convosSub = ConversationDirectoryService.instance.watch(profile).listen((
      skeletons,
    ) {
      if (!mounted) return;
      setState(() {
        _peerSkeletons = skeletons;
        _rebuildConversations();
      });
    });

    // 3. Friend requests, both directions (friend-capable learners only).
    if (profileUsesFriends(profile)) {
      _requestsSub = FriendService.instance
          .watchIncomingRequests(profile.id)
          .listen((reqs) {
            if (!mounted) return;
            setState(() => _incomingRequests = reqs);
          });
      _outgoingSub = FriendService.instance
          .watchOutgoingRequests(profile.id)
          .listen((reqs) async {
            // The request doc only carries the *sender's* display name, so the
            // recipient has to be resolved through the directory — otherwise the
            // strip shows a raw UUID, which means nothing to a child.
            final resolved = await ProfileDirectoryService.instance.lookupMany(
              reqs.map((r) => r.toProfileId).toSet(),
            );
            if (!mounted) return;
            setState(() {
              _outgoingRequests = reqs;
              _outgoingNames = {
                for (final entry in resolved.entries)
                  if (entry.value.name.isNotEmpty) entry.key: entry.value.name,
              };
            });
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
      final otherId = msg.senderId == profile.id
          ? msg.recipientId
          : msg.senderId;
      grouped.putIfAbsent(otherId, () => []).add(msg);
    }

    final convos = <Conversation>[];
    for (final skel in _peerSkeletons) {
      final msgs = grouped[skel.otherProfileId] ?? const <LocalMessage>[];
      final sorted = [...msgs]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      convos.add(
        Conversation(
          otherProfileId: skel.otherProfileId,
          otherProfileName: skel.otherProfileName,
          otherProfileRole: skel.otherProfileRole,
          messages: sorted,
        ),
      );
    }

    // Surface any messages from peers we don't know about yet — covers
    // the brief window between a friendship being accepted on the other
    // side and the directory entry propagating to this device. A peer the
    // directory has *removed* (blocked / unfriended) must not reappear here,
    // so only threads with an inbound message qualify.
    final knownIds = convos.map((c) => c.otherProfileId).toSet();
    for (final entry in grouped.entries) {
      if (knownIds.contains(entry.key)) continue;
      final inbound = entry.value
          .where((m) => m.senderId == entry.key)
          .toList();
      if (inbound.isEmpty) continue;
      final name = inbound.first.senderName.isEmpty
          ? 'User'
          : inbound.first.senderName;
      final sorted = [...entry.value]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      convos.add(
        Conversation(
          otherProfileId: entry.key,
          otherProfileName: name,
          otherProfileRole: 'student',
          messages: sorted,
        ),
      );
    }

    // Sort: conversations with the most recent message first; empty
    // threads fall to the bottom alphabetically.
    convos.sort((a, b) {
      final aLast = a.lastMessage?.timestamp;
      final bLast = b.lastMessage?.timestamp;
      if (aLast != null && bLast != null) return bLast.compareTo(aLast);
      if (aLast != null) return -1;
      if (bLast != null) return 1;
      return a.otherProfileName.toLowerCase().compareTo(
        b.otherProfileName.toLowerCase(),
      );
    });

    _conversations = convos;
    // Keep the open thread bound to the same peer across rebuilds.
    if (_activeConversation != null) {
      final id = _activeConversation!.otherProfileId;
      final next = _conversations.where((c) => c.otherProfileId == id);
      _activeConversation = next.isEmpty ? null : next.first;
    }
  }

  /// Open a thread: bind it, mark everything in it read, and land the learner
  /// on the newest message rather than the oldest.
  void _openConversation(Conversation convo) {
    setState(() => _activeConversation = convo);
    _markActiveRead();
    _jumpToLatest(animate: false);
  }

  void _closeConversation() {
    setState(() => _activeConversation = null);
  }

  /// Clear the unread badge for the open thread. Called on open and again on
  /// every stream emission while it stays open, so a message that arrives
  /// while the learner is reading never leaves a stale badge behind.
  void _markActiveRead() {
    final convo = _activeConversation;
    final profile = ref.read(profileProvider);
    if (convo == null || profile == null) return;
    if (convo.unreadMessages.isEmpty) return;
    // ignore: discarded_futures
    CloudMessageRepository.instance.markConversationRead(
      profile.id,
      convo.messages,
    );
  }

  /// Scroll the thread to the newest message. A plain `ListView.builder`
  /// starts at offset 0 — the *oldest* message — so without this every thread
  /// longer than a screen opened on stale history.
  void _jumpToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  /// Send [content] to the open thread.
  ///
  /// [fromComposer] distinguishes the text field from a one-tap chip: only a
  /// composer send may clear the draft. Clearing unconditionally meant tapping
  /// a quick reply silently threw away whatever the learner had typed.
  Future<void> _sendMessage(
    String content,
    MessageType type, {
    bool fromComposer = false,
  }) async {
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
    if (fromComposer) _textController.clear();

    await CloudMessageRepository.instance.sendMessage(message);
    ref.read(hapticServiceProvider).lightTap();
    _jumpToLatest();
  }

  Future<void> _unsend(LocalMessage message) async {
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFilipino ? 'Bawiin ang mensahe?' : 'Unsend message?'),
        content: Text(
          isFilipino
              ? 'Mawawala ito sa inyong dalawa.'
              : 'It will disappear for both of you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isFilipino ? 'Huwag' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(isFilipino ? 'Bawiin' : 'Unsend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _allMessages.removeWhere((m) => m.id == message.id);
      _rebuildConversations();
    });
    await CloudMessageRepository.instance.deleteMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final profile = ref.watch(profileProvider);

    // Live messages come from the shared provider so the Home badge and this
    // screen never disagree — and so only one Firestore listener pair exists.
    ref.listen<AsyncValue<List<LocalMessage>>>(activeProfileMessagesProvider, (
      _,
      next,
    ) {
      final messages = next.valueOrNull;
      if (messages == null || !mounted) return;
      setState(() {
        _allMessages = messages;
        _rebuildConversations();
      });
      _markActiveRead();
    });

    final showFriendTools = profile != null && profileUsesFriends(profile);

    return GazeDpadScope(
      rows: _gazeRows(isFilipino),
      // The way out. A hands-free learner who cannot reach a touch target
      // cannot reach the app bar's back arrow either — without this the
      // Messages screen was a room with no door for exactly the learners the
      // gaze D-pad exists to serve.
      onExit: () {
        if (_activeConversation != null) {
          _closeConversation();
        } else {
          context.popOrGo('/home');
        }
      },
      exitLabel: isFilipino ? 'Bumalik' : 'Back',
      camerasLoader: widget.camerasLoader,
      detectorFactory: widget.detectorFactory,
      builder: (context, gaze) => Scaffold(
        appBar: AppBar(
          title: _activeConversation != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _activeConversation!.roleEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _activeConversation!.otherProfileName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(isFilipino ? '💬 Mga Mensahe' : '💬 Messages'),
          centerTitle: true,
          leading: _activeConversation != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _closeConversation,
                )
              : null,
          actions: [
            if (_activeConversation != null)
              _ThreadOverflowButton(
                conversation: _activeConversation!,
                isFilipino: isFilipino,
                onManage: () => _showPeerActions(_activeConversation!),
              )
            else if (showFriendTools) ...[
              FriendRequestsBadgeButton(
                count: _incomingRequests.length,
                onTap: () => _showRequestsSheet(profile, isFilipino),
              ),
              // The only route back from a block: blocked peers are filtered
              // out of the inbox, so without this entry there is nowhere left
              // to reach them and undo it.
              IconButton(
                tooltip: isFilipino ? 'Mga na-block' : 'Blocked people',
                icon: const Icon(Icons.block_rounded),
                onPressed: () => showBlockedPeopleSheet(
                  context,
                  me: profile,
                  isFilipino: isFilipino,
                ),
              ),
            ],
          ],
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        floatingActionButton: _activeConversation == null && showFriendTools
            ? FloatingActionButton.extended(
                onPressed: () => _showAddFriendDialog(profile, isFilipino),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(isFilipino ? 'Magdagdag' : 'Add Friend'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              )
            : null,
        body: _activeConversation != null
            ? _buildThread(isFilipino, padding, gaze)
            : _buildInbox(isFilipino, padding, profile, showFriendTools, gaze),
      ),
    );
  }

  // ─── Gaze D-pad wiring ────────────────────────────────

  /// The rows the head-D-pad walks. Mirrors the visual order on each of the
  /// two states this screen has, so "look right" moves the ring the way the
  /// learner expects.
  List<List<GazeDpadCell>> _gazeRows(bool isFilipino) {
    final convo = _activeConversation;
    if (convo == null) {
      final profile = ref.read(profileProvider);
      final rows = <List<GazeDpadCell>>[
        for (final c in _conversations)
          [
            GazeDpadCell(
              label: c.otherProfileName,
              onActivate: () => _openConversation(c),
            ),
          ],
      ];
      if (profile != null && profileUsesFriends(profile)) {
        rows.add([
          GazeDpadCell(
            label: isFilipino ? 'Magdagdag' : 'Add Friend',
            onActivate: () => _showAddFriendDialog(profile, isFilipino),
          ),
        ]);
      }
      return rows;
    }

    // Inside a thread the chips *are* the composer for a hands-free learner —
    // there is no on-screen keyboard they can drive — so every quick reply
    // gets its own cell.
    final quickReplies = _quickRepliesFor(convo);
    return [
      for (var i = 0; i < quickReplies.length; i += 2)
        [
          for (final item in quickReplies.skip(i).take(2))
            GazeDpadCell(
              label: isFilipino ? item['fil']! : item['en']!,
              onActivate: () => _sendMessage(
                isFilipino ? item['fil']! : item['en']!,
                MessageType.encouragement,
              ),
            ),
        ],
    ];
  }

  List<Map<String, String>> _quickRepliesFor(Conversation convo) {
    final profile = ref.read(profileProvider);
    final all = QuickEncouragements.forAudience(
      senderRole: profile?.role.name ?? 'student',
      recipientRole: convo.otherProfileRole,
    );
    // Trimmed to the profile's cap: a wall of chips is its own barrier for a
    // learner who finds choice hard, and for a gaze learner every extra chip
    // is another cell to walk past.
    final limit = ComposerPresentation.forProfile(profile).maxQuickReplies;
    return all.length <= limit ? all : all.sublist(0, limit);
  }

  /// Sends the picture [sticker] as its own message type, so the bubble can
  /// render it large instead of as tiny body text.
  void _sendSticker(String sticker) =>
      _sendMessage(sticker, MessageType.sticker);

  /// Sends [word] as a sign message — the recipient gets a bubble that plays
  /// the FSL clip rather than a bare string.
  void _sendSign(String word) => _sendMessage(word, MessageType.sign);

  Future<void> _openStickerPicker(bool isFilipino) async {
    final choice = await showMessageStickerPicker(context, isFilipino: isFilipino);
    if (choice != null) _sendSticker(choice);
  }

  Future<void> _openSignPicker(bool isFilipino) async {
    final choice = await showMessageSignPicker(context, isFilipino: isFilipino);
    if (choice != null) _sendSign(choice);
  }

  // ─── Inbox ────────────────────────────────────────────

  Widget _buildInbox(
    bool isFilipino,
    double padding,
    UserProfile? profile,
    bool showFriendTools,
    GazeDpadState gaze,
  ) {
    final hc = HCColor.of(context);
    final kind = profile == null
        ? InboxKind.learnerWithFriends
        : inboxKindFor(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFriendTools && profile?.username != null)
          UsernameHeaderCard(
            username: profile!.username!,
            isFilipino: isFilipino,
          ),
        if (_outgoingRequests.isNotEmpty)
          _OutgoingRequestsStrip(
            requests: _outgoingRequests,
            names: _outgoingNames,
            isFilipino: isFilipino,
            onCancel: (r) async {
              await FriendService.instance.cancelRequest(r.id);
            },
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
                          _emptyInboxCopy(kind, isFilipino),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
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
                      focused: gaze.isFocused(index, 0),
                      onTap: () => _openConversation(convo),
                      onLongPress: () => _showPeerActions(convo),
                    ).animate().fadeIn(
                      duration: 300.ms,
                      delay: (index * 60).ms,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Empty-inbox copy per audience.
  ///
  /// A guest player is neither an educator nor friend-capable: they used to
  /// fall through to the educator branch and were told "no students in your
  /// classes yet", which is nonsense for a child in Player mode.
  String _emptyInboxCopy(InboxKind kind, bool isFilipino) {
    switch (kind) {
      case InboxKind.educatorRoster:
        return isFilipino
            ? 'Wala pang mag-aaral sa iyong klase.\nKapag sumali ang estudyante gamit ang code, lalabas sila dito.'
            : 'No students in your classes yet.\nThey appear here once they join with the class code.';
      case InboxKind.guestPlayer:
        return isFilipino
            ? 'Ang Player mode ay para sa iyo lang sa device na ito.\nSumali sa isang klase o home group para makipag-usap sa iba.'
            : 'Player mode stays on this device.\nJoin a class or home group to message other people.';
      case InboxKind.learnerWithFriends:
        return isFilipino
            ? 'Wala pang kaibigan.\nPindutin ang + para magdagdag gamit ang username.'
            : 'No friends yet.\nTap + to add one with their username.';
    }
  }

  // ─── Thread ───────────────────────────────────────────

  Widget _buildThread(bool isFilipino, double padding, GazeDpadState gaze) {
    final profile = ref.read(profileProvider);
    final composer = ComposerPresentation.forProfile(profile);
    final hc = HCColor.of(context);
    final messages = _activeConversation!.messages;
    final quickReplies = _quickRepliesFor(_activeConversation!);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
          child: Row(
            children: [
              for (final (i, item) in quickReplies.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _QuickReplyChip(
                    text: isFilipino ? item['fil']! : item['en']!,
                    focused: gaze.isFocused(i ~/ 2, i % 2),
                    onPressed: () => _sendMessage(
                      isFilipino ? item['fil']! : item['en']!,
                      MessageType.encouragement,
                    ),
                  ),
                ),
            ],
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
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(padding),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == profile?.id;
                    final previous = index == 0 ? null : messages[index - 1];
                    final showDay =
                        previous == null ||
                        !_sameDay(previous.timestamp, msg.timestamp);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDay)
                          _DayDivider(
                            label: MessageTime.dayLabel(
                              msg.timestamp,
                              isFilipino: isFilipino,
                            ),
                          ),
                        _MessageBubbleMsgScreen(
                          message: msg,
                          isMine: isMine,
                          isFilipino: isFilipino,
                          onUnsend: isMine ? () => _unsend(msg) : null,
                        ),
                      ],
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
              if (composer.allowsSigns)
                Semantics(
                  button: true,
                  label: isFilipino ? 'Magpadala ng senyas' : 'Send a sign',
                  child: IconButton(
                    onPressed: () => _openSignPicker(isFilipino),
                    icon: const Icon(Icons.sign_language_rounded),
                    color: AppColors.primary,
                  ),
                ),
              if (composer.allowsStickers)
                Semantics(
                  button: true,
                  label: isFilipino ? 'Magpadala ng sticker' : 'Send a sticker',
                  child: IconButton(
                    onPressed: () => _openStickerPicker(isFilipino),
                    icon: const Icon(Icons.emoji_emotions_rounded),
                    color: AppColors.primary,
                  ),
                ),
              if (composer.allowsText)
                Expanded(
                  child: Semantics(
                    label: isFilipino ? 'I-type ang mensahe' : 'Type a message',
                    child: TextField(
                    controller: _textController,
                    onSubmitted: (v) => _sendMessage(
                      v.trim(),
                      MessageType.text,
                      fromComposer: true,
                    ),
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
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              // Without a text field there is nothing to send from, and the
              // chips and pickers post on tap — so the send button goes with it.
              if (composer.allowsText) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: isFilipino ? 'Ipadala' : 'Send',
                  child: IconButton.filled(
                    onPressed: () => _sendMessage(
                      _textController.text.trim(),
                      MessageType.text,
                      fromComposer: true,
                    ),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else
                // Pickers alone can leave the row unbalanced; a spacer keeps
                // the buttons left-aligned instead of stretched.
                const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  /// Unfriend / block / report for a peer.
  ///
  /// Educators in a learner's inbox are there because of a classroom, not a
  /// friendship, so they can't be unfriended — but they can still be reported,
  /// which is the one route a child has if an adult behaves badly.
  Future<void> _showPeerActions(Conversation convo) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';

    await showPeerActionsSheet(
      context,
      me: profile,
      conversation: convo,
      isFilipino: isFilipino,
      onDone: () {
        if (!mounted) return;
        // The peer is gone from the directory now; drop the open thread so we
        // don't leave the learner staring at a conversation they just left.
        _closeConversation();
      },
    );
  }
}

// ─── Inbox row ──────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isFilipino;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isFilipino,
    required this.focused,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;

    final tile = Semantics(
      button: true,
      label: [
        conversation.otherProfileName,
        conversation.otherProfileRole,
        if (hasUnread)
          isFilipino
              ? '$unread hindi pa nabasang mensahe'
              : '$unread unread messages',
      ].join(', '),
      excludeSemantics: true,
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
            // Unread threads read heavier, so the badge isn't the only cue —
            // a colour-blind or low-vision learner still sees the difference.
            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
            color: hc.textPrimary,
          ),
        ),
        subtitle: last != null
            ? Text(
                last.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: hasUnread ? hc.textPrimary : hc.textSecondary,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              )
            : Text(
                isFilipino ? 'Walang mensahe pa' : 'No messages yet',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (last != null)
              Text(
                MessageTime.relative(last.timestamp, isFilipino: isFilipino),
                style: AppTypography.labelSmall.copyWith(
                  color: hasUnread ? AppColors.primary : hc.textSecondary,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );

    if (!focused) return tile;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        tile,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Thread pieces ──────────────────────────────────────

class _DayDivider extends StatelessWidget {
  final String label;
  const _DayDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hc.border),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String text;
  final bool focused;
  final VoidCallback onPressed;

  const _QuickReplyChip({
    required this.text,
    required this.focused,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: focused
            ? const BorderSide(color: AppColors.accent, width: 3)
            : BorderSide.none,
      ),
    );
  }
}

class _MessageBubbleMsgScreen extends StatelessWidget {
  final LocalMessage message;
  final bool isMine;
  final bool isFilipino;

  /// Non-null only for the sender's own messages — long-press to unsend.
  final VoidCallback? onUnsend;

  const _MessageBubbleMsgScreen({
    required this.message,
    required this.isMine,
    required this.isFilipino,
    this.onUnsend,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isEncouragement = message.type == MessageType.encouragement;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  message.senderName.isNotEmpty
                      ? message.senderName[0].toUpperCase()
                      : '?',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: onUnsend,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isEncouragement
                      ? Colors.pink.withValues(alpha: 0.08)
                      : isMine
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : hc.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMine
                        ? const Radius.circular(16)
                        : Radius.zero,
                    bottomRight: isMine
                        ? Radius.zero
                        : const Radius.circular(16),
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
                            const Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: Colors.pink,
                            ),
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
                    // A sticker is the whole message, so it renders at picture
                    // size rather than as body text a learner has to squint at.
                    if (message.type == MessageType.sticker)
                      Semantics(
                        label: message.content,
                        child: Text(
                          message.content,
                          style: const TextStyle(fontSize: 44),
                        ),
                      )
                    else if (message.type == MessageType.sign)
                      _SignMessageBody(
                        word: message.content,
                        isFilipino: isFilipino,
                      )
                    else
                      Text(
                        message.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Time + (for my own messages) the read receipt. Without
                    // these a thread was an undated wall with no way to tell
                    // whether anyone had seen it.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          MessageTime.clock(message.timestamp),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Semantics(
                            label: message.isRead
                                ? (isFilipino ? 'Nabasa na' : 'Read')
                                : (isFilipino ? 'Naipadala' : 'Sent'),
                            child: Icon(
                              message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 14,
                              color: message.isRead
                                  ? AppColors.primary
                                  : hc.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Outgoing pending friend requests, with a cancel affordance.
///
/// The sender previously had no record that a request existed at all — the
/// dialog closed and the request vanished into a void they could neither see
/// nor withdraw.
class _OutgoingRequestsStrip extends StatelessWidget {
  final List<FriendRequest> requests;

  /// profileId → display name. A missing entry falls back to a short id
  /// rather than hiding the row, so a request is always cancellable.
  final Map<String, String> names;
  final bool isFilipino;
  final Future<void> Function(FriendRequest) onCancel;

  const _OutgoingRequestsStrip({
    required this.requests,
    required this.names,
    required this.isFilipino,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFilipino
                ? 'Naghihintay ng sagot (${requests.length})'
                : 'Waiting for a reply (${requests.length})',
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
          for (final r in requests)
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    names[r.toProfileId] ??
                        '${isFilipino ? 'Gumagamit' : 'User'} '
                            '${r.toProfileId.substring(0, r.toProfileId.length.clamp(0, 6))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onCancel(r),
                  child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// App-bar overflow inside an open thread — the touch route to the same
/// unfriend / block / report actions a long-press on the inbox row opens.
class _ThreadOverflowButton extends StatelessWidget {
  final Conversation conversation;
  final bool isFilipino;
  final VoidCallback onManage;

  const _ThreadOverflowButton({
    required this.conversation,
    required this.isFilipino,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isFilipino ? 'Mga pagpipilian' : 'Options',
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: onManage,
    );
  }
}

/// The body of a Filipino Sign Language message.
///
/// The word travels as plain text so any device can show *something*, and the
/// clip is resolved on tap through the same launcher the tutor and flashcard
/// viewer use — which is also what makes the offline case honest: a Deaf
/// learner gets "could not be fetched" rather than "this sign does not exist".
class _SignMessageBody extends ConsumerStatefulWidget {
  final String word;
  final bool isFilipino;

  const _SignMessageBody({required this.word, required this.isFilipino});

  @override
  ConsumerState<_SignMessageBody> createState() => _SignMessageBodyState();
}

class _SignMessageBodyState extends ConsumerState<_SignMessageBody> {
  /// Guards against a second tap while a resolve is already in flight — the
  /// launcher's contract.
  bool _resolving = false;

  Flashcard? get _card {
    for (final card in SeedData.allFlashcards) {
      if (card.wordEnglish.toLowerCase() == widget.word.toLowerCase()) {
        return card;
      }
    }
    return null;
  }

  Future<void> _play() async {
    final card = _card;
    if (card == null || _resolving) return;
    setState(() => _resolving = true);
    try {
      // Counted as a sign view like any other surface: watching a clip a
      // friend sent is still exposure, which is all `signedWordKeys` claims.
      await showSignForCard(
        context,
        card: card,
        profileId: ref.read(profileProvider)?.id,
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final playable = _card != null;

    return Semantics(
      button: playable,
      label: widget.isFilipino
          ? 'Senyas para sa ${widget.word}'
          : 'Sign for ${widget.word}',
      child: InkWell(
        onTap: playable ? _play : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_resolving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.sign_language_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.word,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    playable
                        ? (widget.isFilipino
                              ? 'Pindutin upang makita ang senyas'
                              : 'Tap to watch the sign')
                        : (widget.isFilipino
                              ? 'Walang senyas para dito'
                              : 'No sign for this word'),
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
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
