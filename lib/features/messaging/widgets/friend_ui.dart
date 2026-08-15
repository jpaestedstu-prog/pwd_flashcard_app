import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import '../services/friend_service.dart';
import '../services/profile_directory_service.dart';

/// Shared "add / manage friends" UI.
///
/// Extracted from the Messages screen so any surface that lets a learner add
/// friends — Messages and the multiplayer "Play Together" lobby — uses the
/// exact same flow and look. The underlying [FriendService] is already shared;
/// this file unifies the presentation layer too.

/// Show the "Add a friend" dialog and, on a successful send, a confirmation
/// SnackBar. Returns true if a request was sent.
Future<bool> showAddFriendDialog(
  BuildContext context, {
  required UserProfile me,
  required bool isFilipino,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AddFriendDialog(me: me, isFilipino: isFilipino),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFilipino ? 'Naipadala ang request.' : 'Friend request sent.',
        ),
      ),
    );
  }
  return sent == true;
}

/// Show the incoming friend-requests bottom sheet.
Future<void> showFriendRequestsSheet(
  BuildContext context, {
  required String myProfileId,
  required bool isFilipino,
  required List<FriendRequest> initialRequests,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FriendRequestsSheet(
      myProfileId: myProfileId,
      isFilipino: isFilipino,
      initialRequests: initialRequests,
    ),
  );
}

/// Show the unfriend / block / report sheet for one conversation peer.
///
/// [onDone] fires after an action that removes the peer, so the caller can
/// close whatever thread was open on them.
Future<void> showPeerActionsSheet(
  BuildContext context, {
  required UserProfile me,
  required Conversation conversation,
  required bool isFilipino,
  required VoidCallback onDone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => PeerActionsSheet(
      me: me,
      conversation: conversation,
      isFilipino: isFilipino,
      onDone: onDone,
    ),
  );
}

/// A pill that surfaces the active profile's shareable username, with a copy
/// button. Shown at the top of friend surfaces so kids can read their handle
/// to a friend.
class UsernameHeaderCard extends StatelessWidget {
  final String username;
  final bool isFilipino;
  const UsernameHeaderCard({
    super.key,
    required this.username,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFilipino ? 'Ang iyong username' : 'Your username',
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isFilipino ? 'Kopyahin' : 'Copy',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: username));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFilipino ? 'Nakopya ang username.' : 'Username copied.',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Stateful Add Friend dialog. Owns its own `_busy` / `_errorText` so a
/// stalled or rejected `FriendService.sendRequest` surfaces as a spinner on
/// the Send button followed by an inline error — never as a frozen dialog. The
/// dialog is dismissible only via Cancel or a successful send; the back
/// gesture is blocked while a request is in flight.
class AddFriendDialog extends StatefulWidget {
  final UserProfile me;
  final bool isFilipino;
  const AddFriendDialog({
    super.key,
    required this.me,
    required this.isFilipino,
  });

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target = _controller.text.trim();
    if (target.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await FriendService.instance.sendRequest(
        me: widget.me,
        targetUsernameOrId: target,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FriendActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = e.message;
      });
    } catch (e, st) {
      // Belt-and-braces: anything that slips past sendRequest's mapping still
      // surfaces as an inline error instead of a frozen dialog.
      ErrorHandler.report(e, st, 'AddFriendDialog._submit');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = widget.isFilipino
            ? 'May nangyaring problema. Subukan ulit.'
            : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = widget.isFilipino;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(isFilipino ? 'Magdagdag ng kaibigan' : 'Add a friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFilipino
                  ? 'I-type ang kanilang username (hal. maria-1947) o profile ID.'
                  : "Type their username (e.g. maria-1947) or profile ID.",
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: isFilipino ? 'username o ID' : 'username or ID',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isFilipino ? 'Ipadala' : 'Send'),
          ),
        ],
      ),
    );
  }
}

/// A friend-requests inbox icon with an unread-count badge.
class FriendRequestsBadgeButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const FriendRequestsBadgeButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: 'Friend requests',
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count.toString()),
          child: const Icon(Icons.person_outline_rounded),
        ),
      ),
    );
  }
}

/// Show the "people you blocked" sheet, with an Unblock for each.
Future<void> showBlockedPeopleSheet(
  BuildContext context, {
  required UserProfile me,
  required bool isFilipino,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => BlockedPeopleSheet(me: me, isFilipino: isFilipino),
  );
}

/// The people [me] has blocked, and the way back.
///
/// Blocking without an undo is a trap: a mis-tap (or a report that blocked as
/// a side effect) permanently removed a peer with no route to restore them,
/// and blocked peers are filtered out of the inbox precisely so they can't be
/// reached — which also meant they could not be reached to unblock. This sheet
/// is the only surface where a blocked peer is still visible.
class BlockedPeopleSheet extends ConsumerStatefulWidget {
  final UserProfile me;
  final bool isFilipino;

  const BlockedPeopleSheet({
    super.key,
    required this.me,
    required this.isFilipino,
  });

  @override
  ConsumerState<BlockedPeopleSheet> createState() => _BlockedPeopleSheetState();
}

class _BlockedPeopleSheetState extends ConsumerState<BlockedPeopleSheet> {
  StreamSubscription<Set<String>>? _sub;
  Set<String> _blocked = const {};
  Map<String, DirectoryEntry> _names = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = FriendService.instance.watchBlocked(widget.me.id).listen((
      ids,
    ) async {
      final resolved = await ProfileDirectoryService.instance.lookupMany(ids);
      if (!mounted) return;
      setState(() {
        _blocked = ids;
        _names = resolved;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _unblock(String profileId, String label) async {
    await FriendService.instance.unblockUser(
      myProfileId: widget.me.id,
      blockedProfileId: profileId,
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          widget.isFilipino ? 'Na-unblock si $label.' : 'Unblocked $label.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fil ? 'Mga na-block' : 'Blocked people',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fil
                  ? 'Hindi ka nila mamemessage habang naka-block sila.'
                  : "They can't message you while they're blocked.",
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_blocked.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  fil
                      ? 'Wala kang na-block na tao.'
                      : "You haven't blocked anyone.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _blocked.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final id = _blocked.elementAt(i);
                    final entry = _names[id];
                    // A peer whose directory entry is gone still has to be
                    // unblockable, so fall back to a stable short id rather
                    // than hiding the row.
                    final label = (entry != null && entry.name.isNotEmpty)
                        ? entry.name
                        : '${fil ? 'Gumagamit' : 'User'} '
                              '${id.substring(0, id.length.clamp(0, 6))}';
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.block_rounded),
                      ),
                      title: Text(label),
                      trailing: TextButton(
                        onPressed: () => _unblock(id, label),
                        child: Text(fil ? 'I-unblock' : 'Unblock'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Unfriend / block / report actions for one conversation peer.
///
/// Every destructive action confirms first, in words a child can read. The
/// three are deliberately distinct: *remove* is reversible social tidying,
/// *block* also stops them coming back through a new friend request, and
/// *report* additionally files the incident for a grown-up to look at.
///
/// Educators reached through a classroom (rather than a friendship) can't be
/// removed or blocked — that would silently cut a learner off from their
/// teacher — but they can still be reported, which is the one route a child
/// has if an adult behaves badly.
class PeerActionsSheet extends ConsumerStatefulWidget {
  final UserProfile me;
  final Conversation conversation;
  final bool isFilipino;
  final VoidCallback onDone;

  const PeerActionsSheet({
    super.key,
    required this.me,
    required this.conversation,
    required this.isFilipino,
    required this.onDone,
  });

  @override
  ConsumerState<PeerActionsSheet> createState() => _PeerActionsSheetState();
}

class _PeerActionsSheetState extends ConsumerState<PeerActionsSheet> {
  bool _busy = false;

  bool get _isEducatorPeer {
    final role = widget.conversation.otherProfileRole.toLowerCase();
    return role == 'teacher' || role == 'parent';
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(widget.isFilipino ? 'Huwag' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _run(Future<void> Function() action, String toast) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onDone();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _remove() async {
    final fil = widget.isFilipino;
    final name = widget.conversation.otherProfileName;
    final ok = await _confirm(
      title: fil ? 'Alisin si $name?' : 'Remove $name?',
      body: fil
          ? 'Hindi na kayo magkaibigan. Pwede kayong mag-add ulit mamaya.'
          : "You won't be friends anymore. You can add each other again later.",
      confirmLabel: fil ? 'Alisin' : 'Remove',
    );
    if (!ok) return;
    await _run(
      () => FriendService.instance.removeFriend(
        myProfileId: widget.me.id,
        friendProfileId: widget.conversation.otherProfileId,
      ),
      fil ? 'Inalis si $name.' : 'Removed $name.',
    );
  }

  Future<void> _block() async {
    final fil = widget.isFilipino;
    final name = widget.conversation.otherProfileName;
    final ok = await _confirm(
      title: fil ? 'I-block si $name?' : 'Block $name?',
      body: fil
          ? 'Hindi ka na nila mamemessage at hindi ka na nila makikita sa listahan mo.'
          : "They won't be able to message you, and they'll disappear from your list.",
      confirmLabel: fil ? 'I-block' : 'Block',
    );
    if (!ok) return;
    await _run(
      () => FriendService.instance.blockUser(
        myProfileId: widget.me.id,
        blockedProfileId: widget.conversation.otherProfileId,
      ),
      fil ? 'Na-block si $name.' : 'Blocked $name.',
    );
  }

  Future<void> _report() async {
    final fil = widget.isFilipino;
    final name = widget.conversation.otherProfileName;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(fil ? 'Ano ang nangyari?' : 'What happened?'),
        children: [
          for (final option in _reportReasons(fil))
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(option, style: AppTypography.bodyMedium),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                fil ? 'Huwag na' : 'Never mind',
                style: AppTypography.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
    if (reason == null) return;

    // A classroom educator is never auto-blocked — see reportUser's doc.
    final alsoBlock = !_isEducatorPeer;
    await _run(
      () => FriendService.instance.reportUser(
        myProfileId: widget.me.id,
        myDisplayName: widget.me.name,
        reportedProfileId: widget.conversation.otherProfileId,
        reportedDisplayName: name,
        reason: reason,
        alsoBlock: alsoBlock,
        lastMessageContent: widget.conversation.lastMessage?.content,
      ),
      alsoBlock
          ? (fil
                ? 'Naipadala sa isang nakatatanda. Na-block na rin si $name.'
                : 'Sent to a grown-up. $name is blocked too.')
          : (fil
                ? 'Naipadala sa isang nakatatanda. Titingnan nila ito.'
                : "Sent to a grown-up. They'll look into it."),
    );
  }

  static List<String> _reportReasons(bool fil) => fil
      ? const [
          'Masasakit na salita',
          'Binu-bully ako',
          'Hindi bagay na mensahe',
          'Ibang dahilan',
        ]
      : const [
          'Mean words',
          'They are bullying me',
          'Message I should not see',
          'Something else',
        ];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final name = widget.conversation.otherProfileName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                name,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isEducatorPeer)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  fil
                      ? 'Kasama mo siya sa klase, kaya hindi siya pwedeng alisin. Pwede mo pa rin siyang i-report.'
                      : "They're in your class, so they can't be removed. You can still report them.",
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            if (!_isEducatorPeer) ...[
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.person_remove_alt_1_rounded),
                title: Text(fil ? 'Alisin sa kaibigan' : 'Remove friend'),
                onTap: _remove,
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                ),
                title: Text(fil ? 'I-block' : 'Block'),
                subtitle: Text(
                  fil
                      ? 'Hindi ka na nila mamemessage.'
                      : "They can't message you anymore.",
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                onTap: _block,
              ),
            ],
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.flag_rounded, color: AppColors.error),
              title: Text(fil ? 'I-report' : 'Report'),
              subtitle: Text(
                fil
                    ? 'Sasabihin sa isang nakatatanda.'
                    : 'Tells a grown-up about this.',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              onTap: _report,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing incoming friend requests with accept / reject actions.
class FriendRequestsSheet extends ConsumerStatefulWidget {
  final String myProfileId;
  final bool isFilipino;
  final List<FriendRequest> initialRequests;
  const FriendRequestsSheet({
    super.key,
    required this.myProfileId,
    required this.isFilipino,
    required this.initialRequests,
  });

  @override
  ConsumerState<FriendRequestsSheet> createState() =>
      _FriendRequestsSheetState();
}

class _FriendRequestsSheetState extends ConsumerState<FriendRequestsSheet> {
  late List<FriendRequest> _requests;
  StreamSubscription<List<FriendRequest>>? _sub;

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests;
    _sub = FriendService.instance
        .watchIncomingRequests(widget.myProfileId)
        .listen((list) {
          if (!mounted) return;
          setState(() => _requests = list);
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isFilipino ? 'Mga Friend Request' : 'Friend Requests',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.isFilipino
                      ? 'Walang nakahaing request.'
                      : 'No pending requests.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _requests.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = _requests[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      title: Text(
                        r.fromDisplayName.isEmpty ? 'User' : r.fromDisplayName,
                      ),
                      subtitle: Text(
                        widget.isFilipino
                            ? 'Gustong maging kaibigan'
                            : 'Wants to be friends',
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: widget.isFilipino ? 'Tanggihan' : 'Reject',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await FriendService.instance.rejectRequest(r.id);
                            },
                          ),
                          IconButton(
                            tooltip: widget.isFilipino ? 'Tanggapin' : 'Accept',
                            icon: const Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await FriendService.instance.acceptRequest(
                                myProfileId: widget.myProfileId,
                                requestId: r.id,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
