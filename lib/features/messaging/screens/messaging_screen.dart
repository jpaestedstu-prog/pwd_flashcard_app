import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../core/accessibility/stt_service.dart'
    show SttService, dictationMicLease, sttServiceProvider;
import '../../../core/services/shared_media_service.dart';
import '../../../core/widgets/media_capture_screen.dart';
import '../../../data/local/local_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/firestore_stream_helpers.dart'
    show homeGroupsByOwnerStreamProvider;
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
import '../services/message_media.dart';
import '../widgets/broadcast_sheet.dart';
import '../widgets/inline_pickers.dart';
import '../widgets/message_media_view.dart';
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
  List<FriendRequest> _outgoingRequests = [];

  /// Educator inbox filters: a name search and one class / home group.
  String _search = '';
  String? _groupFilter;

  /// profileId → display name for the people I've asked, resolved from the
  /// directory (the request doc only carries the sender's own name).
  Map<String, String> _outgoingNames = const {};
  Conversation? _activeConversation;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<Conversation>>? _convosSub;
  StreamSubscription<List<FriendRequest>>? _outgoingSub;

  /// Requests this device has already tried to finish, so a stream that
  /// re-emits does not start the same write twice.
  final Set<String> _finishing = {};

  // ─── Speak-to-type ───
  bool _dictating = false;

  /// Set synchronously the moment a dictation starts, before any await — so
  /// a double tap (or a repeated gaze dwell) cannot start a second one and
  /// take the microphone lease twice.
  bool _dictationStarting = false;

  /// Whether this screen holds [dictationMicLease]; it gives back exactly
  /// what it took.
  bool _holdsMicLease = false;
  String _beforeDictation = '';

  /// The recogniser the current dictation runs on — kept so [dispose] can
  /// stop it without reading a provider after the widget is gone.
  SttService? _dictationStt;
  Timer? _dictationWatch;
  int _dictationTicks = 0;

  // ─── Pickers drawn in the thread for gaze ───
  _InlinePicker _inlinePicker = _InlinePicker.none;
  FlashcardCategory? _signTopic;
  List<Flashcard>? _signable;

  /// Gaze is running on this screen (from the scope's last build). Decides
  /// whether a picker opens as a sheet (touch) or in the thread (gaze).
  bool _gazeActive = false;

  /// A photo or video is uploading; the composer shows its progress.
  MessageType? _uploading;
  double _uploadProgress = 0;
  String? _watchedProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _dictationWatch?.cancel();
    if (_dictating) {
      // ignore: discarded_futures
      _dictationStt?.cancel();
    }
    // Give the microphone back to gaze voice commands, whatever state the
    // dictation was in when the screen closed.
    _giveBackMicLease();
    _convosSub?.cancel();
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

    // Expire this profile's own message photos and videos after a week —
    // what keeps them inside the free plan. Once per session, never blocks.
    // ignore: discarded_futures
    const MessageMediaRetention().run(profile.id);

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

    // 3. Outgoing friend requests (friend-capable learners only). Incoming
    //    ones come from [incomingFriendRequestsProvider], shared with the Home
    //    tile's badge.
    if (profileUsesFriends(profile)) {
      _outgoingSub = FriendService.instance
          .watchOutgoingRequests(profile.id)
          .listen((reqs) async {
            // The request doc only carries the *sender's* display name, so the
            // recipient has to be resolved through the directory — otherwise the
            // strip shows a raw UUID, which means nothing to a child.
            _finishApproved(profile, reqs);
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

    _conversations = assembleInbox(
      myProfileId: profile.id,
      peers: _peerSkeletons,
      messages: _allMessages,
      blockedIds:
          ref.read(blockedProfileIdsProvider).valueOrNull ?? const <String>{},
    );
    // Keep the open thread bound to the same peer across rebuilds.
    if (_activeConversation != null) {
      final id = _activeConversation!.otherProfileId;
      final next = _conversations.where((c) => c.otherProfileId == id);
      _activeConversation = next.isEmpty ? null : next.first;
    }
  }

  /// Makes the friendship for any request whose parents have all said yes.
  /// A parent's device cannot write it, so the learners' devices do.
  void _finishApproved(UserProfile me, List<FriendRequest> requests) {
    for (final r in requests) {
      if (!r.readyToFinish || !_finishing.add(r.id)) continue;
      // ignore: discarded_futures
      FriendService.instance.finishApproved(me, r);
    }
  }

  /// The educator inbox after the search box and group filter.
  List<Conversation> get _visibleConversations {
    final q = _search.trim().toLowerCase();
    final group = _groupFilter;
    if (q.isEmpty && group == null) return _conversations;
    return [
      for (final c in _conversations)
        if ((q.isEmpty || c.otherProfileName.toLowerCase().contains(q)) &&
            (group == null || c.groups.any((g) => g.id == group)))
          c,
    ];
  }

  /// Every class / home group represented in the educator's inbox, by name.
  /// Sorted rather than in inbox order: the inbox reorders on every new
  /// message, and filter chips that jump about are hard to hit.
  List<InboxGroup> get _groups {
    final seen = <String>{};
    return [
      for (final c in _conversations)
        for (final g in c.groups)
          if (g.name.isNotEmpty && seen.add(g.id)) g,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
  Future<bool> _sendMessage(
    String content,
    MessageType type, {
    bool fromComposer = false,
    String? caption,
    String? toProfileId,
  }) async {
    // [toProfileId] pins the recipient for a send that finishes later (a
    // photo or video uploads for a while, and the learner may open another
    // thread meanwhile). Otherwise it is the thread on screen.
    final recipientId = toProfileId ?? _activeConversation?.otherProfileId;
    if (content.isEmpty || recipientId == null) return false;
    // History-only threads have no composer; this is the backstop — checked
    // against the live inbox, not a thread object captured earlier.
    final target = _conversations.where((c) => c.otherProfileId == recipientId);
    if (target.isEmpty || !target.first.isConnected) return false;
    final profile = ref.read(profileProvider);
    if (profile == null) return false;

    final message = LocalMessage(
      id: _uuid.v4(),
      senderId: profile.id,
      senderName: profile.name,
      recipientId: recipientId,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      caption: caption,
    );

    setState(() {
      _allMessages.add(message);
      _rebuildConversations();
    });
    if (fromComposer) _textController.clear();

    await CloudMessageRepository.instance.sendMessage(message);
    if (!mounted) return true;
    ref.read(hapticServiceProvider).lightTap();
    if (_activeConversation?.otherProfileId == recipientId) _jumpToLatest();
    return true;
  }

  /// The type a quick-reply chip is sent as — see [QuickEncouragements.typeFor].
  MessageType get _chipType => QuickEncouragements.typeFor(
    senderRole: ref.read(profileProvider)?.role.name ?? 'student',
  );

  /// Speak one message aloud, in the app's language.
  void _readAloud(LocalMessage message, bool isFilipino) {
    final words = MessageWording.speakable(message, isFilipino: isFilipino);
    if (words.isEmpty) return;
    final tts = ref.read(ttsServiceProvider);
    // ignore: discarded_futures
    isFilipino ? tts.speakFilipino(words) : tts.speakEnglish(words);
  }

  /// Educator: open "message the whole class".
  Future<void> _openBroadcast(UserProfile me, bool isFilipino) async {
    final sent = await showBroadcastSheet(
      context,
      me: me,
      conversations: _conversations.where((c) => c.isConnected).toList(),
      groups: _groups,
      initialGroupId: _groupFilter,
      isFilipino: isFilipino,
    );
    if (sent == null || sent == 0 || !mounted) return;
    ref.read(hapticServiceProvider).lightTap();
    final isParent = me.role == UserRole.parent;
    final who = isFilipino
        ? (isParent ? 'anak' : 'mag-aaral')
        : isParent
        ? (sent == 1 ? 'child' : 'children')
        : (sent == 1 ? 'learner' : 'learners');
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          isFilipino ? 'Naipadala sa $sent $who.' : 'Sent to $sent $who.',
        ),
      ),
    );
  }

  /// Educator: jump from a thread to the learner's progress page.
  Future<void> _seeProgress(Conversation convo) async {
    final me = ref.read(profileProvider);
    if (me == null) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    UserProfile? learner;
    try {
      final roster = await ref.read(educatorRosterProvider(me.id).future);
      for (final pair in roster) {
        if (pair.$1.id == convo.otherProfileId) learner = pair.$1;
      }
    } catch (_) {
      learner = null;
    }
    if (!mounted) return;
    if (learner == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            isFilipino
                ? 'Hindi pa makuha ang progreso. Subukan ulit kapag may internet.'
                : "Their progress isn't available yet. Try again when you're online.",
          ),
        ),
      );
      return;
    }
    // ignore: discarded_futures
    context.push('/student-profile-detail', extra: learner);
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
            style: FilledButton.styleFrom(backgroundColor: HCColor.of(context).fillFor(AppColors.error)),
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
    // An unsent photo or video leaves nothing behind in the cloud.
    if (message.isMedia) {
      // ignore: discarded_futures
      const SharedMediaService().delete(message.content);
    }
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

    // A block (or unblock) re-filters the inbox immediately.
    ref.listen<AsyncValue<Set<String>>>(blockedProfileIdsProvider, (_, next) {
      if (!mounted || next.valueOrNull == null) return;
      setState(_rebuildConversations);
    });
    final incomingRequests =
        ref.watch(incomingFriendRequestsProvider).valueOrNull ??
        const <FriendRequest>[];
    ref.listen<AsyncValue<List<FriendRequest>>>(incomingFriendRequestsProvider, (
      _,
      next,
    ) {
      final me = ref.read(profileProvider);
      final list = next.valueOrNull;
      if (me != null && list != null) _finishApproved(me, list);
    });
    final actionableRequests = incomingRequests
        .where((r) => r.isActionable)
        .length;

    final showFriendTools = profile != null && profileUsesFriends(profile);
    final isEducator =
        profile != null &&
        inboxKindFor(profile) == InboxKind.educatorRoster;

    // Back steps out one level at a time: an open picker, then the thread,
    // then Messages. Without this, Android's Back — and a spoken "close" or
    // "go back", which the voice resolver turns into a pop — left Messages
    // entirely from inside a thread, or from a picker a gaze learner had just
    // opened.
    final inner =
        _inlinePicker != _InlinePicker.none || _activeConversation != null;
    return PopScope(
      canPop: !inner,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _stepBack();
      },
      child: GazeDpadScope(
      rows: _gazeRows(isFilipino),
      // The way out. A hands-free learner who cannot reach a touch target
      // cannot reach the app bar's back arrow either — without this the
      // Messages screen was a room with no door for exactly the learners the
      // gaze D-pad exists to serve.
      onExit: () {
        if (_inlinePicker != _InlinePicker.none ||
            _activeConversation != null) {
          _stepBack();
        } else {
          context.popOrGo('/home');
        }
      },
      exitLabel: isFilipino ? 'Bumalik' : 'Back',
      camerasLoader: widget.camerasLoader,
      detectorFactory: widget.detectorFactory,
      builder: (context, gaze) {
        _gazeActive = gaze.active;
        return Scaffold(
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
            else if (isEducator &&
                _conversations.any((c) => c.isConnected))
              IconButton(
                tooltip: profile.role == UserRole.parent
                    ? (isFilipino
                          ? 'Magpadala sa buong pamilya'
                          : 'Message the whole family')
                    : (isFilipino
                          ? 'Magpadala sa buong klase'
                          : 'Message the whole class'),
                icon: const Icon(Icons.campaign_rounded),
                onPressed: () => _openBroadcast(profile, isFilipino),
              )
            else if (showFriendTools) ...[
              FriendRequestsBadgeButton(
                count: actionableRequests,
                onTap: () =>
                    _showRequestsSheet(profile, isFilipino, incomingRequests),
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
                backgroundColor: HCColor.of(context).primary,
                foregroundColor: HCColor.of(context).textOnPrimary,
              )
            : null,
        body: _activeConversation != null
            ? _buildThread(isFilipino, padding, gaze)
            : _buildInbox(isFilipino, padding, profile, showFriendTools, gaze),
        );
      },
      ),
    );
  }

  /// One level out: close an open picker, else the open thread.
  void _stepBack() {
    if (_inlinePicker != _InlinePicker.none) {
      _closeInlinePicker();
    } else if (_activeConversation != null) {
      _closeConversation();
    }
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
        for (final c in _visibleConversations)
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

    // A history-only thread has nothing to send — only the way out.
    if (!convo.isConnected) return const [];

    // A picker open in the thread: its tiles are the only cells, so the walk
    // stays inside it until a pick or Close.
    final panel = _inlinePanelRows(isFilipino);
    if (panel != null) return panel;

    // Inside a thread the chips *are* the composer for a hands-free learner —
    // there is no on-screen keyboard they can drive — so every quick reply
    // gets its own cell.
    final quickReplies = _quickRepliesFor(convo);
    final composer = ComposerPresentation.forProfile(ref.read(profileProvider));
    final layout = _ComposerGaze.of(composer, quickReplies.length);
    return [
      for (var i = 0; i < quickReplies.length; i += 2)
        [
          for (final item in quickReplies.skip(i).take(2))
            GazeDpadCell(
              label: isFilipino ? item['fil']! : item['en']!,
              onActivate: () => _sendMessage(
                isFilipino ? item['fil']! : item['en']!,
                _chipType,
              ),
            ),
        ],
      // The sign and sticker pickers — each opens in the thread, where its
      // tiles become cells.
      if (layout.toolsRow != null)
        [
          if (layout.signTool)
            GazeDpadCell(
              label: isFilipino ? 'Magpadala ng senyas' : 'Send a sign',
              onActivate: () => _openSignPicker(isFilipino),
            ),
          if (layout.stickerTool)
            GazeDpadCell(
              label: isFilipino ? 'Magpadala ng sticker' : 'Send a sticker',
              onActivate: () => _openStickerPicker(isFilipino),
            ),
        ],
      // Speak-to-type and Send: with voice commands on, "speak a message"
      // starts dictation and "send" sends what it wrote.
      if (layout.textRow != null)
        [
          if (layout.micCell)
            GazeDpadCell(
              label: _dictating
                  ? (isFilipino ? 'Itigil ang pagsasalita' : 'Stop speaking')
                  : (isFilipino ? 'Magsalita ng mensahe' : 'Speak a message'),
              onActivate: () => _toggleDictation(isFilipino),
            ),
          GazeDpadCell(
            label: isFilipino ? 'Ipadala' : 'Send',
            enabled: _textController.text.trim().isNotEmpty,
            onActivate: () => _sendMessage(
              _textController.text.trim(),
              MessageType.text,
              fromComposer: true,
            ),
          ),
        ],
    ];
  }

  /// The gaze rows of an open in-thread picker, or null when none is open.
  List<List<GazeDpadCell>>? _inlinePanelRows(bool isFilipino) {
    final close = GazeDpadCell(
      label: isFilipino ? 'Isara' : 'Close',
      onActivate: _closeInlinePicker,
    );
    switch (_inlinePicker) {
      case _InlinePicker.none:
        return null;
      case _InlinePicker.sticker:
        const stickers = MessageStickers.all;
        return [
          for (var i = 0; i < stickers.length; i += kStickerColumns)
            [
              for (final sticker in stickers.skip(i).take(kStickerColumns))
                GazeDpadCell(
                  label:
                      MessageStickerNames.nameOf(sticker, isFilipino: isFilipino) ??
                      sticker,
                  onActivate: () {
                    _closeInlinePicker();
                    _sendSticker(sticker);
                  },
                ),
            ],
          [close],
        ];
      case _InlinePicker.sign:
        final signable = _signable;
        if (signable == null) return [[close]];
        final topic = _signTopic;
        if (topic == null) {
          final topics = InlineSignPanel.topicsOf(signable);
          return [
            for (var i = 0; i < topics.length; i += kSignColumns)
              [
                for (final t in topics.skip(i).take(kSignColumns))
                  GazeDpadCell(
                    label: isFilipino ? t.labelFilipino : t.label,
                    onActivate: () => setState(() => _signTopic = t),
                  ),
              ],
            [close],
          ];
        }
        final words = InlineSignPanel.wordsIn(signable, topic);
        return [
          for (var i = 0; i < words.length; i += kSignColumns)
            [
              for (final w in words.skip(i).take(kSignColumns))
                GazeDpadCell(
                  label: w.wordEnglish,
                  onActivate: () {
                    _closeInlinePicker();
                    _sendSign(w.wordEnglish);
                  },
                ),
            ],
          [
            GazeDpadCell(
              label: isFilipino ? 'Ibang paksa' : 'Other topics',
              onActivate: () => setState(() => _signTopic = null),
            ),
            close,
          ],
        ];
    }
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
    if (_gazeActive) {
      setState(() => _inlinePicker = _InlinePicker.sticker);
      return;
    }
    final choice = await showMessageStickerPicker(context, isFilipino: isFilipino);
    if (choice != null) _sendSticker(choice);
  }

  Future<void> _openSignPicker(bool isFilipino) async {
    if (_gazeActive) {
      setState(() {
        _inlinePicker = _InlinePicker.sign;
        _signTopic = null;
      });
      if (_signable == null) {
        final cards = await loadSignableCards();
        if (mounted) setState(() => _signable = cards);
      }
      return;
    }
    final choice = await showMessageSignPicker(context, isFilipino: isFilipino);
    if (choice != null) _sendSign(choice);
  }

  void _closeInlinePicker() => setState(() {
    _inlinePicker = _InlinePicker.none;
    _signTopic = null;
  });

  // ─── Speak-to-type ────────────────────────────────────

  /// Starts or stops dictation into the text field.
  ///
  /// Takes [dictationMicLease] first, so the gaze voice-command loop stands
  /// down for the length of the message and resumes after — one recogniser,
  /// never two sessions fighting over it. The session is watched rather than
  /// trusted to report its end: a recogniser that times out on silence ends
  /// without a final result, and the lease must still come back.
  Future<void> _toggleDictation(bool isFilipino) async {
    final stt = ref.read(sttServiceProvider);
    if (_dictating) {
      await stt.stopListening();
      _endDictation();
      return;
    }
    if (_dictationStarting) return;
    _dictationStarting = true;
    try {
      await _startDictation(stt, isFilipino);
    } finally {
      _dictationStarting = false;
    }
  }

  Future<void> _startDictation(SttService stt, bool isFilipino) async {
    final available = await stt.init();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            isFilipino
                ? 'Hindi available ang mikropono sa device na ito.'
                : 'Speech input is not available on this device.',
          ),
        ),
      );
      return;
    }
    _takeMicLease();
    // Drop any command session still holding the recogniser, and let it
    // settle — starting straight after a cancel is refused as "busy".
    await stt.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      _giveBackMicLease();
      return;
    }
    _beforeDictation = _textController.text;
    _dictationStt = stt;
    setState(() => _dictating = true);
    _dictationTicks = 0;
    await stt.startListening(
      locale: isFilipino ? 'fil-PH' : 'en-US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (text, isFinal) {
        if (!mounted || !_dictating) return;
        if (text.isNotEmpty) {
          final before = _beforeDictation;
          final sep = before.isEmpty || before.endsWith(' ') ? '' : ' ';
          _textController.text = '$before$sep$text';
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
          setState(() {});
        }
        if (isFinal) _endDictation();
      },
    );
    _dictationWatch?.cancel();
    _dictationWatch = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_dictating) return;
      // Give the platform two seconds to report the session as live before
      // reading "not listening" as "finished".
      _dictationTicks++;
      if (_dictationTicks >= 4 && !stt.isListening) _endDictation();
    });
  }

  void _endDictation() {
    _dictationWatch?.cancel();
    _dictationWatch = null;
    if (!_dictating) return;
    _giveBackMicLease();
    if (mounted) setState(() => _dictating = false);
  }

  void _takeMicLease() {
    if (_holdsMicLease) return;
    _holdsMicLease = true;
    dictationMicLease.acquire();
  }

  void _giveBackMicLease() {
    if (!_holdsMicLease) return;
    _holdsMicLease = false;
    dictationMicLease.release();
  }

  // ─── Photos and sign videos ───────────────────────────

  /// Takes a photo or records a clip with the in-app camera, shares it
  /// through the free Firestore-chunk store, and sends it. Whatever is typed
  /// in the text field goes with it as the caption — what the sign means,
  /// for someone who does not sign.
  Future<void> _sendMedia(MessageType type, bool isFilipino) async {
    final me = ref.read(profileProvider);
    final convo = _activeConversation;
    if (me == null || convo == null || !convo.isConnected) return;
    if (_uploading != null) return;
    // Who it is for is decided now, while the learner is looking at that
    // thread — not whichever thread happens to be open when the upload ends.
    final recipientId = convo.otherProfileId;
    final captionAtCapture = _textController.text.trim();
    if (!MessageMedia.canSendMore(_allMessages, me.id)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            isFilipino
                ? 'Nakapagpadala ka na ng ${MessageMedia.dailyLimit} larawan at video ngayon. Subukan ulit bukas.'
                : "You've sent ${MessageMedia.dailyLimit} photos and videos today. Try again tomorrow.",
          ),
        ),
      );
      return;
    }
    final isVideo = type == MessageType.video;
    final path = await captureMedia(
      context,
      mode: isVideo ? CaptureMode.video : CaptureMode.photo,
      maxDuration: MessageMedia.maxVideo,
      title: isVideo
          ? (isFilipino ? 'Mag-record ng senyas' : 'Record a sign')
          : (isFilipino ? 'Kumuha ng larawan' : 'Take a photo'),
      prompt: isVideo
          ? (isFilipino
                ? 'I-senyas ang iyong mensahe. Hanggang 10 segundo.'
                : 'Sign your message. Up to 10 seconds.')
          : null,
    );
    if (path == null || !mounted) return;

    setState(() {
      _uploading = type;
      _uploadProgress = 0;
    });
    final file = File(path);
    final dot = path.lastIndexOf('.');
    final ext = dot >= 0 ? path.substring(dot + 1) : (isVideo ? 'mp4' : 'jpg');
    final result = await const SharedMediaService().upload(
      file,
      ownerProfileId: me.id,
      ext: ext,
      purpose: SharedMediaMeta.purposeMessage,
      onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p);
      },
    );
    try {
      await file.delete();
    } on Object {
      // The camera's temp file; the OS clears it eventually.
    }
    if (!mounted) return;
    setState(() => _uploading = null);

    final value = result.value;
    if (value == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            result.status == SharedUploadStatus.tooLarge
                ? (isFilipino
                      ? 'Masyadong malaki ang file.'
                      : 'That file is too big to send.')
                : (isFilipino
                      ? 'Hindi naipadala. Tingnan ang internet at subukan ulit.'
                      : "Couldn't send it. Check the internet and try again."),
          ),
        ),
      );
      return;
    }
    final sent = await _sendMessage(
      value,
      type,
      caption: captionAtCapture.isEmpty ? null : captionAtCapture,
      toProfileId: recipientId,
    );
    if (!sent) {
      // They stopped being connected while it uploaded (unfriended,
      // blocked, left the class): nothing was delivered, so nothing may be
      // left behind in the cloud either.
      // ignore: discarded_futures
      const SharedMediaService().delete(value);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              isFilipino
                  ? 'Hindi naipadala — hindi na kayo magkaugnay.'
                  : "Not sent — you're no longer connected.",
            ),
          ),
        );
      }
      return;
    }
    // The caption travelled with it; clear it only if it is still what the
    // field holds in the same thread.
    if (captionAtCapture.isNotEmpty &&
        _activeConversation?.otherProfileId == recipientId &&
        _textController.text.trim() == captionAtCapture) {
      _textController.clear();
    }
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
    final isEducator = kind == InboxKind.educatorRoster;
    final visible = isEducator ? _visibleConversations : _conversations;
    final groups = isEducator ? _groups : const <InboxGroup>[];

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
        if (profile != null && profile.role == UserRole.parent)
          _ParentApprovalsCard(isFilipino: isFilipino, parent: profile),
        if (isEducator && _conversations.length > 1)
          _EducatorInboxFilters(
            groups: groups,
            selectedGroupId: _groupFilter,
            isFilipino: isFilipino,
            onSearch: (v) => setState(() => _search = v),
            onGroup: (id) => setState(() => _groupFilter = id),
          ),
        Expanded(
          child: _conversations.isNotEmpty && visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Text(
                      isFilipino
                          ? 'Walang tugma. Subukan ang ibang pangalan o grupo.'
                          : 'No one matches. Try another name or group.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
                )
              : _conversations.isEmpty
              ? Center(
                  // Scrollable: at 2x text on a small phone the educator copy
                  // runs past the bottom of the screen.
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text(
                          _emptyInboxCopy(kind, isFilipino, profile),
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
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final convo = visible[index];
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
  String _emptyInboxCopy(
    InboxKind kind,
    bool isFilipino,
    UserProfile? profile,
  ) {
    switch (kind) {
      case InboxKind.educatorRoster:
        // A parent's learners join a home group, not a class — the teacher
        // copy told Mommy about "class codes" she has never seen.
        if (profile?.role == UserRole.parent) {
          return isFilipino
              ? 'Wala pang anak sa iyong grupo.\nKapag sumali sila gamit ang code ng grupo, lalabas sila dito.'
              : 'No children in your home group yet.\nThey appear here once they join with your group code.';
        }
        return isFilipino
            ? 'Wala pang mag-aaral sa iyong klase.\nKapag sumali ang estudyante gamit ang code, lalabas sila dito.'
            : 'No students in your classes yet.\nThey appear here once they join with the class code.';
      case InboxKind.guestPlayer:
        return isFilipino
            ? 'Ang Player mode ay para sa iyo lang sa device na ito.\nSumali sa isang klase o home group para makipag-usap sa iba.'
            : 'Player mode stays on this device.\nJoin a class or home group to message other people.';
      case InboxKind.learnerWithFriends:
        return isFilipino
            ? 'Wala pang kaibigan.\nPindutin ang Magdagdag para humanap ng kaibigan.'
            : 'No friends yet.\nTap Add Friend to find one.';
    }
  }

  // ─── Thread ───────────────────────────────────────────

  Widget _buildThread(bool isFilipino, double padding, GazeDpadState gaze) {
    final profile = ref.read(profileProvider);
    final composer = ComposerPresentation.forProfile(profile);
    final hc = HCColor.of(context);
    final convo = _activeConversation!;
    final messages = convo.messages;
    final connected = convo.isConnected;
    final quickReplies = connected
        ? _quickRepliesFor(convo)
        : const <Map<String, String>>[];
    final isEducator =
        profile != null && inboxKindFor(profile) == InboxKind.educatorRoster;
    final hint = isEducator && connected
        ? RecipientHint.forLearner(
            convo.otherDisabilityIndex,
            isFilipino: isFilipino,
          )
        : null;

    return Column(
      children: [
        if (hint != null)
          _RecipientHintBar(
            hint: hint,
            isFilipino: isFilipino,
            onSign: () => _openSignPicker(isFilipino),
            onSticker: () => _openStickerPicker(isFilipino),
            onRecord: composer.signVideos
                ? () => _sendMedia(MessageType.video, isFilipino)
                : null,
          ),
        if (connected)
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
                    // While a picker is open its tiles own the gaze rows, so
                    // the same row/column here is not the chip.
                    focused:
                        _inlinePicker == _InlinePicker.none &&
                        gaze.isFocused(i ~/ 2, i % 2),
                    onPressed: () => _sendMessage(
                      isFilipino ? item['fil']! : item['en']!,
                      _chipType,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (connected) const Divider(height: 1),
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
                          otherName: convo.otherProfileName,
                          onUnsend: isMine ? () => _unsend(msg) : null,
                          onReadAloud: composer.readAloud
                              ? () => _readAloud(msg, isFilipino)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (!connected)
          _DisconnectedBar(
            isFilipino: isFilipino,
            isEducator: isEducator,
            padding: padding,
          )
        else if (_inlinePicker == _InlinePicker.sticker)
          InlineStickerPanel(
            isFilipino: isFilipino,
            isFocused: (i) => gaze.isFocused(
              i ~/ kStickerColumns,
              i % kStickerColumns,
            ),
            closeFocused: gaze.isFocused(
              (MessageStickers.all.length / kStickerColumns).ceil(),
              0,
            ),
            onPick: (sticker) {
              _closeInlinePicker();
              _sendSticker(sticker);
            },
            onClose: _closeInlinePicker,
          )
        else if (_inlinePicker == _InlinePicker.sign)
          _buildInlineSignPanel(isFilipino, gaze)
        else
          _buildComposer(composer, quickReplies.length, isFilipino, padding, gaze),
      ],
    );
  }

  Widget _buildInlineSignPanel(bool isFilipino, GazeDpadState gaze) {
    final signable = _signable;
    final topic = _signTopic;
    final count = signable == null
        ? 0
        : topic == null
        ? InlineSignPanel.topicsOf(signable).length
        : InlineSignPanel.wordsIn(signable, topic).length;
    final lastRow = signable == null ? 0 : (count / kSignColumns).ceil();
    return InlineSignPanel(
      isFilipino: isFilipino,
      signable: signable,
      category: topic,
      isFocused: (i) => gaze.isFocused(i ~/ kSignColumns, i % kSignColumns),
      // The last row is [Close] on the topic list, [Other topics, Close] in
      // a topic.
      closeFocused: gaze.isFocused(lastRow, topic == null ? 0 : 1),
      backFocused: topic != null && gaze.isFocused(lastRow, 0),
      onCategory: (t) => setState(() => _signTopic = t),
      onWord: (word) {
        _closeInlinePicker();
        _sendSign(word);
      },
      onBack: () => setState(() => _signTopic = null),
      onClose: _closeInlinePicker,
    );
  }

  /// The composer: a row of labelled tools (sign, sticker, photo, sign
  /// video), then the text field with its microphone and Send.
  ///
  /// The tools used to be bare icons squeezed beside the field. With photos
  /// and videos added there are up to four, and a row of named buttons is
  /// both easier to hit and easier to understand for a child who does not
  /// know what a smiley icon does.
  Widget _buildComposer(
    ComposerPresentation composer,
    int quickReplyCount,
    bool isFilipino,
    double padding,
    GazeDpadState gaze,
  ) {
    final hc = HCColor.of(context);
    final layout = _ComposerGaze.of(composer, quickReplyCount);
    final uploading = _uploading;
    var toolCol = 0;

    Widget tool({
      required IconData icon,
      required String label,
      required String semantics,
      required VoidCallback onPressed,
      bool gazeCell = false,
    }) {
      final focused =
          gazeCell &&
          layout.toolsRow != null &&
          gaze.isFocused(layout.toolsRow!, toolCol);
      if (gazeCell) toolCol++;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          child: Tooltip(
            message: semantics,
            child: OutlinedButton.icon(
              onPressed: uploading == null ? onPressed : null,
              icon: Icon(icon, color: hc.graphic(AppColors.primary)),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                side: focused
                    ? const BorderSide(color: AppColors.accent, width: 3)
                    : BorderSide(color: hc.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
      );
    }

    final tools = <Widget>[
      if (composer.allowsSigns)
        tool(
          icon: Icons.sign_language_rounded,
          label: isFilipino ? 'Senyas' : 'Sign',
          semantics: isFilipino ? 'Magpadala ng senyas' : 'Send a sign',
          onPressed: () => _openSignPicker(isFilipino),
          gazeCell: true,
        ),
      if (composer.allowsStickers)
        tool(
          icon: Icons.emoji_emotions_rounded,
          label: 'Sticker',
          semantics: isFilipino ? 'Magpadala ng sticker' : 'Send a sticker',
          onPressed: () => _openStickerPicker(isFilipino),
          gazeCell: true,
        ),
      if (composer.signVideos)
        tool(
          icon: Icons.videocam_rounded,
          label: isFilipino ? 'Video' : 'Video',
          semantics: isFilipino
              ? 'Mag-record ng senyas o video'
              : 'Record a sign or video',
          onPressed: () => _sendMedia(MessageType.video, isFilipino),
        ),
      if (composer.photos)
        tool(
          icon: Icons.photo_camera_rounded,
          label: isFilipino ? 'Larawan' : 'Photo',
          semantics: isFilipino ? 'Kumuha ng larawan' : 'Take a photo',
          onPressed: () => _sendMedia(MessageType.photo, isFilipino),
        ),
    ];

    final micFocused =
        layout.textRow != null && layout.micCell && gaze.isFocused(layout.textRow!, 0);
    final sendFocused =
        layout.textRow != null &&
        gaze.isFocused(layout.textRow!, layout.micCell ? 1 : 0);

    return Container(
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(top: BorderSide(color: hc.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (uploading != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  label: uploading == MessageType.video
                      ? (isFilipino
                            ? 'Ipinapadala ang video'
                            : 'Sending your video')
                      : (isFilipino
                            ? 'Ipinapadala ang larawan'
                            : 'Sending your photo'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        uploading == MessageType.video
                            ? (isFilipino
                                  ? 'Ipinapadala ang video…'
                                  : 'Sending your video…')
                            : (isFilipino
                                  ? 'Ipinapadala ang larawan…'
                                  : 'Sending your photo…'),
                        style: AppTypography.labelMedium.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                      ),
                    ],
                  ),
                ),
              ),
            if (tools.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: tools),
              ),
            if (composer.allowsText) ...[
              if (tools.isNotEmpty) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: isFilipino ? 'I-type ang mensahe' : 'Type a message',
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (v) => _sendMessage(
                          v.trim(),
                          MessageType.text,
                          fromComposer: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _dictating
                              ? (isFilipino
                                    ? 'Nakikinig… magsalita na'
                                    : 'Listening… speak now')
                              : (isFilipino
                                    ? 'Mag-type ng mensahe...'
                                    : 'Type a message...'),
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
                  if (composer.dictation) ...[
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      toggled: _dictating,
                      label: _dictating
                          ? (isFilipino
                                ? 'Nakikinig. Pindutin para itigil'
                                : 'Listening. Tap to stop')
                          : (isFilipino
                                ? 'Magsalita ng mensahe'
                                : 'Speak a message'),
                      excludeSemantics: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: micFocused
                              ? Border.all(color: AppColors.accent, width: 3)
                              : null,
                        ),
                        child: IconButton(
                          tooltip: _dictating
                              ? (isFilipino ? 'Itigil' : 'Stop')
                              : (isFilipino
                                    ? 'Magsalita ng mensahe'
                                    : 'Speak a message'),
                          onPressed: () => _toggleDictation(isFilipino),
                          icon: Icon(
                            _dictating
                                ? Icons.stop_circle_rounded
                                : Icons.mic_rounded,
                            color: _dictating
                                ? hc.graphic(AppColors.error)
                                : hc.graphic(AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: isFilipino ? 'Ipadala' : 'Send',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: sendFocused
                            ? Border.all(color: AppColors.accent, width: 3)
                            : null,
                      ),
                      child: IconButton.filled(
                        onPressed: () => _sendMessage(
                          _textController.text.trim(),
                          MessageType.text,
                          fromComposer: true,
                        ),
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: HCColor.of(context).primary,
                          foregroundColor: HCColor.of(context).textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Friend dialogs ───────────────────────────────────

  Future<void> _showAddFriendDialog(UserProfile me, bool isFilipino) {
    return showAddFriendDialog(context, me: me, isFilipino: isFilipino);
  }

  Future<void> _showRequestsSheet(
    UserProfile me,
    bool isFilipino,
    List<FriendRequest> incoming,
  ) {
    return showFriendRequestsSheet(
      context,
      me: me,
      isFilipino: isFilipino,
      initialRequests: incoming,
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

    final isEducator = inboxKindFor(profile) == InboxKind.educatorRoster;
    await showPeerActionsSheet(
      context,
      me: profile,
      conversation: convo,
      isFilipino: isFilipino,
      // A learner's report goes to their own teacher and parent.
      grownUps: isEducator
          ? const []
          : _conversations.where((c) => c.isEducatorPeer).toList(),
      onSeeProgress: isEducator ? () => _seeProgress(convo) : null,
      onDone: () {
        if (!mounted) return;
        // The peer is gone from the directory now; drop the open thread so we
        // don't leave the learner staring at a conversation they just left.
        _closeConversation();
      },
    );
  }
}

/// Which picker is open inside the thread (gaze only).
enum _InlinePicker { none, sticker, sign }

/// Where the composer's gaze cells sit, shared by the scope's rows and the
/// widgets that draw the focus rings — so the two can never disagree.
class _ComposerGaze {
  /// Row of the sign / sticker tools, when there is one.
  final int? toolsRow;
  final bool signTool;
  final bool stickerTool;

  /// Row of [Speak a message] and [Send], when there is a text field.
  final int? textRow;
  final bool micCell;

  const _ComposerGaze({
    required this.toolsRow,
    required this.signTool,
    required this.stickerTool,
    required this.textRow,
    required this.micCell,
  });

  /// Photos and videos are touch-only: the capture screen takes over the
  /// camera the gaze D-pad itself runs on.
  factory _ComposerGaze.of(ComposerPresentation composer, int quickReplies) {
    var row = (quickReplies / 2).ceil();
    final sign = composer.allowsSigns;
    final sticker = composer.allowsStickers;
    final toolsRow = sign || sticker ? row++ : null;
    final textRow = composer.allowsText ? row++ : null;
    return _ComposerGaze(
      toolsRow: toolsRow,
      signTool: sign,
      stickerTool: sticker,
      textRow: textRow,
      micCell: composer.dictation,
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

    final hasReport = conversation.hasUnreadReport;
    final preview = last == null
        ? null
        : MessageWording.preview(last, isFilipino: isFilipino);

    final tile = Semantics(
      button: true,
      // The row used to say only name, role and a count — a screen-reader
      // user had to open every thread to learn what was in it.
      label: [
        conversation.otherProfileName,
        _roleWord(conversation.otherProfileRole, isFilipino),
        if (hasReport)
          isFilipino ? 'may ulat pangkaligtasan' : 'safety report waiting',
        if (hasUnread)
          isFilipino
              ? '$unread hindi pa nabasang mensahe'
              : unread == 1
              ? '1 unread message'
              : '$unread unread messages',
        if (preview != null)
          '${isFilipino ? 'Huling mensahe' : 'Last message'}: $preview, '
              '${MessageTime.relative(last!.timestamp, isFilipino: isFilipino)}',
        if (!conversation.isConnected)
          isFilipino ? 'hindi na makakapagpadala' : 'read only',
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
        subtitle: preview != null
            ? Text(
                preview,
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
                  color: hasUnread ? HCColor.of(context).primary : hc.textSecondary,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasReport) ...[
                    Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: hc.graphic(AppColors.error),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      // White on the raw lavender was under 3:1 — a count a
                      // low-vision learner could not read.
                      color: hc.fillFor(AppColors.primary),
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

/// "2 friend requests need your OK" — a parent's way into
/// [ParentApprovalsSheet]. Hidden when nothing is waiting.
class _ParentApprovalsCard extends ConsumerWidget {
  final bool isFilipino;
  final UserProfile parent;

  const _ParentApprovalsCard({required this.isFilipino, required this.parent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests =
        ref.watch(parentApprovalsProvider).valueOrNull ??
        const <FriendRequest>[];
    if (requests.isEmpty) return const SizedBox.shrink();
    final hc = HCColor.of(context);
    final n = requests.length;
    final text = isFilipino
        ? '$n kahilingang makipagkaibigan ang naghihintay ng iyong pahintulot'
        : n == 1
        ? '1 friend request needs your OK'
        : '$n friend requests need your OK';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: hc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: hc.graphic(AppColors.success), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final groups =
                ref
                    .read(homeGroupsByOwnerStreamProvider(parent.id))
                    .valueOrNull ??
                const [];
            showParentApprovalsSheet(
              context,
              requests: requests,
              myGroupIds: {for (final g in groups) g.id},
              isFilipino: isFilipino,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Text('🤝', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: hc.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A role slug as a word in the app's language, for screen-reader labels.
String _roleWord(String role, bool isFilipino) {
  switch (role.toLowerCase()) {
    case 'teacher':
      return isFilipino ? 'guro' : 'teacher';
    case 'parent':
      return isFilipino ? 'magulang' : 'parent';
    case 'child':
      return isFilipino ? 'anak' : 'child';
    case 'player':
      return 'player';
    default:
      return isFilipino ? 'mag-aaral' : 'student';
  }
}

/// The educator inbox's search box and class / home-group filter.
///
/// A teacher with six classes had one flat alphabetical list of every
/// learner and no way to narrow it.
class _EducatorInboxFilters extends StatefulWidget {
  final List<InboxGroup> groups;
  final String? selectedGroupId;
  final bool isFilipino;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onGroup;

  const _EducatorInboxFilters({
    required this.groups,
    required this.selectedGroupId,
    required this.isFilipino,
    required this.onSearch,
    required this.onGroup,
  });

  @override
  State<_EducatorInboxFilters> createState() => _EducatorInboxFiltersState();
}

class _EducatorInboxFiltersState extends State<_EducatorInboxFilters> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fil = widget.isFilipino;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            onChanged: (v) {
              widget.onSearch(v);
              setState(() {});
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: fil ? 'Hanapin ang pangalan' : 'Search by name',
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: fil ? 'Burahin' : 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        widget.onSearch('');
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (widget.groups.length > 1) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(fil ? 'Lahat' : 'All'),
                      selected: widget.selectedGroupId == null,
                      onSelected: (_) => widget.onGroup(null),
                    ),
                  ),
                  for (final g in widget.groups)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Text(g.isHomeGroup ? '🏠' : '🏫'),
                        label: Text(g.name),
                        selected: widget.selectedGroupId == g.id,
                        onSelected: (on) => widget.onGroup(on ? g.id : null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What an educator's message should look like for *this* learner — see
/// [RecipientHint].
class _RecipientHintBar extends StatelessWidget {
  final RecipientHint hint;
  final bool isFilipino;
  final VoidCallback onSign;
  final VoidCallback onSticker;

  /// Record a sign video — the most direct way to reach a Deaf learner.
  final VoidCallback? onRecord;

  const _RecipientHintBar({
    required this.hint,
    required this.isFilipino,
    required this.onSign,
    required this.onSticker,
    this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hc.border),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(hint.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint.text,
              style: AppTypography.bodySmall.copyWith(color: hc.textPrimary),
            ),
          ),
          if (hint.suggestsSign)
            TextButton.icon(
              onPressed: onSign,
              icon: const Icon(Icons.sign_language_rounded, size: 18),
              label: Text(isFilipino ? 'Senyas' : 'Sign'),
            ),
          if (hint.suggestsSign && onRecord != null)
            TextButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: Text(isFilipino ? 'I-record' : 'Record'),
            ),
          if (hint.suggestsSticker)
            TextButton.icon(
              onPressed: onSticker,
              icon: const Icon(Icons.emoji_emotions_rounded, size: 18),
              label: const Text('Sticker'),
            ),
        ],
      ),
    );
  }
}

/// Stands where the composer was, in a thread that is only history.
class _DisconnectedBar extends StatelessWidget {
  final bool isFilipino;
  final bool isEducator;
  final double padding;

  const _DisconnectedBar({
    required this.isFilipino,
    required this.isEducator,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final text = isEducator
        ? (isFilipino
              ? 'Wala na siya sa iyong klase o grupo, kaya hindi ka na makakapagpadala ng mensahe dito.'
              : "They're no longer in your class or group, so you can't send messages here.")
        : (isFilipino
              ? 'Hindi na kayo magkaibigan, kaya hindi ka na makakapagpadala ng mensahe dito. Pwede mo siyang i-add ulit.'
              : "You're not friends anymore, so you can't send messages here. You can add them again.");
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(top: BorderSide(color: hc.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: hc.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
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

  /// The other person in the thread, so a screen reader names the sender
  /// instead of reading the avatar's initial.
  final String otherName;

  /// Non-null only for the sender's own messages — long-press to unsend.
  final VoidCallback? onUnsend;

  /// Speaks the message. Null where the composer policy turns read-aloud
  /// off (Deaf / hard-of-hearing learners).
  final VoidCallback? onReadAloud;

  const _MessageBubbleMsgScreen({
    required this.message,
    required this.isMine,
    required this.isFilipino,
    required this.otherName,
    this.onUnsend,
    this.onReadAloud,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isEncouragement = message.type == MessageType.encouragement;
    final isReport = message.type == MessageType.report;
    final readAloud = onReadAloud;
    // Beside the bubble rather than inside it, so the sign bubble's own tap
    // target (play the clip) stays whole.
    final Widget? speaker =
        readAloud != null &&
            MessageWording.speakable(message, isFilipino: isFilipino)
                .isNotEmpty
        ? IconButton(
            tooltip: isFilipino ? 'Basahin nang malakas' : 'Read aloud',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: hc.graphic(AppColors.primary),
            ),
            onPressed: readAloud,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // My own bubbles hug the right edge, so their speaker sits on the
          // inner side, mirroring the one beside a received bubble.
          if (isMine && speaker != null) speaker,
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: ExcludeSemantics(
                child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  message.senderName.isNotEmpty
                      ? message.senderName[0].toUpperCase()
                      : '?',
                  style: AppTypography.labelMedium.copyWith(
                    color: HCColor.of(context).primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ),
            ),
          Flexible(
            child: Semantics(
              container: true,
              label: MessageWording.bubbleLabel(
                message,
                isMine: isMine,
                otherName: otherName,
                isFilipino: isFilipino,
              ),
              onLongPressHint: onUnsend == null
                  ? null
                  : (isFilipino ? 'Bawiin ang mensahe' : 'Unsend message'),
              child: GestureDetector(
              onLongPress: onUnsend,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isReport
                      ? AppColors.error.withValues(alpha: 0.10)
                      : isEncouragement
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
                    width: isReport ? 1.5 : 1,
                    color: isReport
                        ? hc.graphic(AppColors.error)
                        : isEncouragement
                        ? Colors.pink.withValues(alpha: 0.2)
                        : isMine
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : hc.border,
                  ),
                ),
                // The bubble's own Semantics label says it all, in order;
                // the pieces below would repeat it word by word. A sign keeps
                // its children: its "play the sign" button must stay
                // reachable to a screen reader.
                child: ExcludeSemantics(
                  excluding:
                      message.type != MessageType.sign && !message.isMedia,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isReport)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 14,
                              color: hc.graphic(AppColors.error),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFilipino
                                  ? 'Ulat pangkaligtasan'
                                  : 'Safety report',
                              style: AppTypography.labelSmall.copyWith(
                                color: hc.readable(AppColors.error),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                color: hc.readable(Colors.pink),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // A sticker is the whole message, so it renders at picture
                    // size rather than as body text a learner has to squint at.
                    if (message.type == MessageType.sticker)
                      Text(
                        message.content,
                        style: const TextStyle(fontSize: 44),
                      )
                    else if (message.type == MessageType.sign)
                      _SignMessageBody(
                        word: message.content,
                        isFilipino: isFilipino,
                      )
                    else if (message.isMedia)
                      MessageMediaBody(
                        message: message,
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
                          Icon(
                            message.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: message.isRead
                                ? HCColor.of(context).primary
                                : hc.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
            ),
          ),
          if (!isMine && speaker != null) speaker,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[r.toProfileId] ??
                            '${isFilipino ? 'Gumagamit' : 'User'} '
                                '${r.toProfileId.substring(0, r.toProfileId.length.clamp(0, 6))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                      if (r.status == FriendRequestStatus.awaitingParent ||
                          r.fromNeedsParent)
                        Text(
                          r.status == FriendRequestStatus.awaitingParent
                              ? (isFilipino
                                    ? 'Pumayag na sila. Hinihintay ang isang nakatatanda.'
                                    : 'They said yes. Waiting for a grown-up.')
                              : (isFilipino
                                    ? 'Kailangan ding pumayag ng isang nakatatanda.'
                                    : 'A grown-up will need to say yes too.'),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                    ],
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
              Icon(
                Icons.sign_language_rounded,
                size: 20,
                color: HCColor.of(context).primary,
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
