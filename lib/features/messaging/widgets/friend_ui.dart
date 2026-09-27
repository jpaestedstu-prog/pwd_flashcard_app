import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import 'package:uuid/uuid.dart';

import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import '../services/cloud_message_repository.dart';
import '../providers/messaging_providers.dart' show parentApprovalsProvider;
import '../services/friend_service.dart';
import '../services/profile_directory_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
    final needsParent = FriendService.needsParentApproval(me);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          needsParent
              ? (isFilipino
                    ? 'Naipadala ang request. Kailangan ding pumayag ng isang nakatatanda.'
                    : 'Friend request sent. A grown-up will need to say yes too.')
              : (isFilipino ? 'Naipadala ang request.' : 'Friend request sent.'),
        ),
      ),
    );
  }
  return sent == true;
}

/// Show the incoming friend-requests bottom sheet.
Future<void> showFriendRequestsSheet(
  BuildContext context, {
  required UserProfile me,
  required bool isFilipino,
  required List<FriendRequest> initialRequests,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Without this the dismiss barrier announces itself as "Scrim",
    // Material's untranslated default.
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    builder: (ctx) => FriendRequestsSheet(
      me: me,
      isFilipino: isFilipino,
      initialRequests: initialRequests,
    ),
  );
}

/// Show the unfriend / block / report sheet for one conversation peer.
///
/// [onDone] fires after an action that removes the peer, so the caller can
/// close whatever thread was open on them. [grownUps] are the learner's own
/// teacher / parent threads — where a report is delivered. [onSeeProgress]
/// is the educator's route to the learner's progress.
Future<void> showPeerActionsSheet(
  BuildContext context, {
  required UserProfile me,
  required Conversation conversation,
  required bool isFilipino,
  required VoidCallback onDone,
  List<Conversation> grownUps = const [],
  VoidCallback? onSeeProgress,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Without this the dismiss barrier announces itself as "Scrim",
    // Material's untranslated default.
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    builder: (ctx) => PeerActionsSheet(
      me: me,
      conversation: conversation,
      isFilipino: isFilipino,
      onDone: onDone,
      grownUps: grownUps,
      onSeeProgress: onSeeProgress,
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
          Icon(Icons.alternate_email_rounded, color: HCColor.of(context).primary),
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

  /// Classmate suggestions. Injectable for tests; production asks
  /// [FriendService.suggestClassmates].
  final Future<List<DirectoryEntry>> Function(UserProfile me)? suggestions;

  const AddFriendDialog({
    super.key,
    required this.me,
    required this.isFilipino,
    this.suggestions,
  });

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _errorText;

  /// Null while loading; empty when there is nobody to suggest.
  List<DirectoryEntry>? _classmates;

  bool get _hasGroup =>
      (widget.me.classroomId?.isNotEmpty ?? false) ||
      (widget.me.homeGroupId?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    if (_hasGroup) {
      _loadClassmates();
    } else {
      _classmates = const [];
    }
  }

  Future<void> _loadClassmates() async {
    List<DirectoryEntry> found;
    try {
      found = await (widget.suggestions ??
          FriendService.instance.suggestClassmates)(widget.me);
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() => _classmates = found);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() => _send(_controller.text.trim());

  Future<void> _send(String target) async {
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
        _errorText = e.messageOf(filipino: widget.isFilipino);
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
        // Large text plus the classmate list is taller than a small phone.
        scrollable: true,
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
              // With classmates to pick from, an open keyboard would cover
              // the easier path.
              autofocus: !_hasGroup,
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
            if (_hasGroup) ...[
              const SizedBox(height: 16),
              _ClassmateSuggestions(
                classmates: _classmates,
                isFilipino: isFilipino,
                busy: _busy,
                onAsk: (entry) => _send(entry.username),
              ),
            ],
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

/// The "People in your class" list inside [AddFriendDialog]: each classmate
/// by name with one button, so a learner who cannot type a username can
/// still make a friend.
class _ClassmateSuggestions extends StatelessWidget {
  final List<DirectoryEntry>? classmates;
  final bool isFilipino;
  final bool busy;
  final ValueChanged<DirectoryEntry> onAsk;

  const _ClassmateSuggestions({
    required this.classmates,
    required this.isFilipino,
    required this.busy,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final list = classmates;
    final heading = Text(
      isFilipino ? 'O pumili sa iyong klase' : 'Or pick someone from your class',
      style: AppTypography.labelMedium.copyWith(
        color: hc.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
    if (list == null) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Flexible(child: heading),
        ],
      );
    }
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          // Not a ListView: AlertDialog measures its content's intrinsic
          // width, which a viewport cannot report.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              for (final entry in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  // A Wrap, not a Row: at large text the name and the button
                  // do not fit side by side in a dialog, so the button drops
                  // under the name instead of running off the edge.
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '🧑‍🎓 ${entry.name}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: isFilipino
                            ? 'Hilingin na maging kaibigan si ${entry.name}'
                            : 'Ask ${entry.name} to be friends',
                        excludeSemantics: true,
                        child: OutlinedButton(
                          onPressed: busy ? null : () => onAsk(entry),
                          child: Text(isFilipino ? 'Hilingin' : 'Ask'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final name = _t(context).frRequests;
    // The badge's number used to *replace* the button's name for a screen
    // reader, which announced a bare "1".
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        button: true,
        label: count > 0 ? '$name, $count' : name,
        excludeSemantics: true,
        child: IconButton(
          tooltip: name,
          onPressed: onTap,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count.toString()),
            child: const Icon(Icons.person_outline_rounded),
          ),
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
    // Without this the dismiss barrier announces itself as "Scrim",
    // Material's untranslated default.
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
///
/// An **educator** looking at their own learner gets a different sheet: no
/// friend actions (they are not friends — the link is the class or home
/// group), and no "tells a grown-up" report (they *are* the grown-up).
/// Teachers used to be offered "Remove friend" and "Block" on their own
/// students; both reported success and did nothing, because the roster
/// comes from the class, not a friendship or a block list.
class PeerActionsSheet extends ConsumerStatefulWidget {
  final UserProfile me;
  final Conversation conversation;
  final bool isFilipino;
  final VoidCallback onDone;
  final List<Conversation> grownUps;
  final VoidCallback? onSeeProgress;

  const PeerActionsSheet({
    super.key,
    required this.me,
    required this.conversation,
    required this.isFilipino,
    required this.onDone,
    this.grownUps = const [],
    this.onSeeProgress,
  });

  @override
  ConsumerState<PeerActionsSheet> createState() => _PeerActionsSheetState();
}

class _PeerActionsSheetState extends ConsumerState<PeerActionsSheet> {
  bool _busy = false;

  bool get _isEducatorPeer => widget.conversation.isEducatorPeer;

  bool get _iAmEducator =>
      widget.me.role == UserRole.teacher || widget.me.role == UserRole.parent;

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
            style: FilledButton.styleFrom(backgroundColor: HCColor.of(context).fillFor(AppColors.error)),
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
    // Quote what *they* wrote. The thread's last message is often the
    // reporter's own reply, which says nothing about what went wrong.
    final quote = widget.conversation.lastInbound;
    final recipients = SafetyReport.recipients(
      grownUps: widget.grownUps,
      reportedId: widget.conversation.otherProfileId,
    );
    final quoteText = quote == null
        ? null
        : MessageWording.preview(quote, isFilipino: fil);
    await _run(() async {
      await FriendService.instance.reportUser(
        myProfileId: widget.me.id,
        myDisplayName: widget.me.name,
        reportedProfileId: widget.conversation.otherProfileId,
        reportedDisplayName: name,
        reason: reason,
        alsoBlock: alsoBlock,
        lastMessageContent: quoteText,
      );
      if (recipients.isEmpty) return;
      const uuid = Uuid();
      await CloudMessageRepository.instance.sendMessages(
        SafetyReport.messages(
          reporterId: widget.me.id,
          reporterName: widget.me.name,
          recipients: recipients,
          content: SafetyReport.content(
            reportedName: name,
            reason: reason,
            quote: quoteText,
            isFilipino: fil,
          ),
          newId: uuid.v4,
        ),
      );
    }, _reportToast(recipients, name, alsoBlock: alsoBlock));
  }

  /// Says who the report actually reached — or, when the learner has no
  /// teacher or parent in the app, says so instead of promising a grown-up
  /// who does not exist.
  String _reportToast(
    List<Conversation> recipients,
    String name, {
    required bool alsoBlock,
  }) {
    final fil = widget.isFilipino;
    final who = recipients.map((r) => r.otherProfileName).toList();
    final String sent;
    if (who.isEmpty) {
      sent = fil
          ? 'Naitala ang ulat. Sabihin din ito sa isang nakatatandang pinagkakatiwalaan mo.'
          : 'Report saved. Please also tell a grown-up you trust.';
    } else {
      final names = who.length == 1
          ? who.first
          : '${who.sublist(0, who.length - 1).join(', ')} ${fil ? 'at' : 'and'} ${who.last}';
      sent = fil ? 'Naipadala kay $names.' : 'Sent to $names.';
    }
    if (!alsoBlock) return sent;
    return fil ? '$sent Na-block na rin si $name.' : '$sent $name is blocked too.';
  }

  /// Names the grown-ups a report will reach, so "tells a grown-up" is a
  /// promise the app can keep.
  String _reportSubtitle(bool fil) {
    final who = SafetyReport.recipients(
      grownUps: widget.grownUps,
      reportedId: widget.conversation.otherProfileId,
    ).map((g) => g.otherProfileName).toList();
    if (who.isEmpty) {
      return fil
          ? 'Itatala ito. Sabihin din sa isang nakatatanda.'
          : 'Saves a report. Tell a grown-up too.';
    }
    return fil ? 'Sasabihin kay ${who.join(', ')}.' : 'Tells ${who.join(', ')}.';
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

  /// The educator's own sheet for one of their learners.
  Widget _buildForEducator(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final convo = widget.conversation;
    final groups = convo.groups.where((g) => g.name.isNotEmpty).toList();
    final inHomeGroup = groups.isNotEmpty && groups.every((g) => g.isHomeGroup);
    final where = groups.isEmpty
        ? null
        : groups.map((g) => g.name).join(', ');

    final String explain;
    if (!convo.isConnected) {
      explain = fil
          ? 'Wala na siya sa iyong klase o grupo, kaya hindi na kayo makakapagpadala ng mensahe. Makikita mo pa rin ang dating usapan.'
          : "They're no longer in your class or group, so you can't message each other. The old chat stays here to read.";
    } else if (inHomeGroup) {
      explain = fil
          ? 'Kasama siya sa iyong pamilya${where == null ? '' : ' ($where)'}. Para ihinto ang mga mensahe, alisin siya sa grupo sa Manage Groups.'
          : 'They\'re in your family group${where == null ? '' : ' ($where)'}. To stop messages, remove them from the group in Manage Groups.';
    } else {
      explain = fil
          ? 'Kasama siya sa iyong klase${where == null ? '' : ' ($where)'}. Para ihinto ang mga mensahe, alisin siya sa klase sa Manage Classes.'
          : 'They\'re in your class${where == null ? '' : ' ($where)'}. To stop messages, remove them from the class in Manage Classes.';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                convo.otherProfileName,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                explain,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
            if (widget.onSeeProgress != null && convo.isConnected)
              ListTile(
                leading: Icon(
                  Icons.insights_rounded,
                  color: hc.graphic(AppColors.primary),
                ),
                title: Text(fil ? 'Tingnan ang progreso' : 'See their progress'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSeeProgress!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_iAmEducator) return _buildForEducator(context);
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final name = widget.conversation.otherProfileName;
    final peerIsParent =
        widget.conversation.otherProfileRole.toLowerCase() == 'parent';
    // Removing and blocking only mean something for a friendship. A thread
    // that is only history (they unfriended or blocked you) can still be
    // reported, and blocked so they stay gone.
    final isFriend = !_isEducatorPeer && widget.conversation.isConnected;

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
                  peerIsParent
                      ? (fil
                            ? 'Kasama mo siya sa iyong pamilya, kaya hindi siya pwedeng alisin. Pwede mo pa rin siyang i-report.'
                            : "They're in your family group, so they can't be removed. You can still report them.")
                      : (fil
                            ? 'Kasama mo siya sa klase, kaya hindi siya pwedeng alisin. Pwede mo pa rin siyang i-report.'
                            : "They're in your class, so they can't be removed. You can still report them."),
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            if (isFriend)
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.person_remove_alt_1_rounded),
                title: Text(fil ? 'Alisin sa kaibigan' : 'Remove friend'),
                onTap: _remove,
              ),
            if (!_isEducatorPeer)
              ListTile(
                enabled: !_busy,
                leading: Icon(
                  Icons.block_rounded,
                  color: HCColor.of(context).graphic(AppColors.error),
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
            ListTile(
              enabled: !_busy,
              leading: Icon(Icons.flag_rounded, color: HCColor.of(context).graphic(AppColors.error)),
              title: Text(fil ? 'I-report' : 'Report'),
              subtitle: Text(
                _reportSubtitle(fil),
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
  final UserProfile me;
  final bool isFilipino;
  final List<FriendRequest> initialRequests;
  const FriendRequestsSheet({
    super.key,
    required this.me,
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
        .watchIncomingRequests(widget.me.id)
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
                    final waiting = !r.isActionable;
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      title: Text(
                        r.fromDisplayName.isEmpty ? 'User' : r.fromDisplayName,
                      ),
                      subtitle: Text(
                        waiting
                            ? (widget.isFilipino
                                  ? 'Pumayag ka na. Hinihintay ang isang nakatatanda.'
                                  : 'You said yes. Waiting for a grown-up.')
                            : (widget.isFilipino
                                  ? 'Gustong maging kaibigan'
                                  : 'Wants to be friends'),
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      trailing: waiting
                          ? Icon(
                              Icons.hourglass_top_rounded,
                              color: hc.textSecondary,
                            )
                          : Row(
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
                              final outcome = await FriendService.instance
                                  .acceptRequest(me: widget.me, requestId: r.id);
                              if (!context.mounted) return;
                              if (outcome == AcceptOutcome.needsGroup) {
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.isFilipino
                                          ? 'Kailangan ka munang idagdag ng isang nakatatanda sa kanilang pamilya bago ka makipagkaibigan.'
                                          : 'A grown-up needs to add you to their family group before you can make friends.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (outcome == AcceptOutcome.awaitingParent) {
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.isFilipino
                                          ? 'Halos magkaibigan na! Kailangan munang pumayag ng isang nakatatanda.'
                                          : "Almost friends! A grown-up needs to say yes first.",
                                    ),
                                  ),
                                );
                              }
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

/// Show the "say yes to your child's new friend" sheet for a parent.
Future<void> showParentApprovalsSheet(
  BuildContext context, {
  required List<FriendRequest> requests,
  required Set<String> myGroupIds,
  required bool isFilipino,
}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ParentApprovalsSheet(
      initialRequests: requests,
      myGroupIds: myGroupIds,
      isFilipino: isFilipino,
    ),
  );
}

/// A parent's list of their children's friend requests to approve.
///
/// A Child could previously befriend anyone who knew their username, with
/// no grown-up in the loop. Now a Child's new friendship waits here: the
/// parent sees who their child wants to be friends with and says yes or
/// no. The rules check the parent really owns the child's home group, so
/// nobody else can say yes for them.
class ParentApprovalsSheet extends ConsumerStatefulWidget {
  final List<FriendRequest> initialRequests;
  final Set<String> myGroupIds;
  final bool isFilipino;

  /// Resolves profile ids to names. Injectable for tests.
  final Future<Map<String, DirectoryEntry>> Function(Set<String>)? lookup;

  const ParentApprovalsSheet({
    super.key,
    required this.initialRequests,
    required this.myGroupIds,
    required this.isFilipino,
    this.lookup,
  });

  @override
  ConsumerState<ParentApprovalsSheet> createState() =>
      _ParentApprovalsSheetState();
}

class _ParentApprovalsSheetState extends ConsumerState<ParentApprovalsSheet> {
  Map<String, String> _names = const {};
  final Set<String> _answered = {};

  @override
  void initState() {
    super.initState();
    _resolveNames(widget.initialRequests);
  }

  Future<void> _resolveNames(List<FriendRequest> requests) async {
    final ids = {
      for (final r in requests) ...[r.fromProfileId, r.toProfileId],
    };
    Map<String, DirectoryEntry> found;
    try {
      found = await (widget.lookup ??
          ProfileDirectoryService.instance.lookupMany)(ids);
    } catch (_) {
      found = const {};
    }
    if (!mounted) return;
    setState(() {
      _names = {
        for (final r in requests) r.fromProfileId: r.fromDisplayName,
        for (final e in found.entries)
          if (e.value.name.isNotEmpty) e.key: e.value.name,
      };
    });
  }

  String _name(String id) {
    final n = _names[id];
    if (n != null && n.isNotEmpty) return n;
    return widget.isFilipino ? 'Isang mag-aaral' : 'A learner';
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final live = ref.watch(parentApprovalsProvider).valueOrNull;
    final requests = (live ?? widget.initialRequests)
        .where((r) => !_answered.contains(r.id))
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fil ? 'Mga bagong kaibigan ng anak mo' : "Your child's new friends",
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fil
                  ? 'Magiging magkaibigan lang sila kapag pumayag ka.'
                  : 'They only become friends once you say yes.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  fil ? 'Wala nang naghihintay.' : 'Nothing waiting.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = requests[i];
                    final mineIsSender = r.fromHomeGroupId != null &&
                        widget.myGroupIds.contains(r.fromHomeGroupId);
                    final child = mineIsSender ? r.fromProfileId : r.toProfileId;
                    final other = mineIsSender ? r.toProfileId : r.fromProfileId;
                    final line = mineIsSender
                        ? (fil
                              ? 'Gustong makipagkaibigan ni ${_name(child)} kay ${_name(other)}.'
                              : '${_name(child)} wants to be friends with ${_name(other)}.')
                        : (fil
                              ? 'Pumayag si ${_name(child)} na maging kaibigan si ${_name(other)}.'
                              : '${_name(child)} said yes to being friends with ${_name(other)}.');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            line,
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  setState(() => _answered.add(r.id));
                                  FriendService.instance.declineAsParent(r);
                                },
                                child: Text(fil ? 'Huwag' : 'Not now'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  setState(() => _answered.add(r.id));
                                  FriendService.instance.approveAsParent(
                                    r,
                                    widget.myGroupIds,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: hc.fillFor(AppColors.success),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(fil ? 'Pumayag' : 'Say yes'),
                              ),
                            ],
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
