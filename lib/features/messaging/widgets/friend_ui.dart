import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          isFilipino ? 'Naipadala ang request.' : 'Friend request sent.'),
    ));
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

/// A pill that surfaces the active profile's shareable username, with a copy
/// button. Shown at the top of friend surfaces so kids can read their handle
/// to a friend.
class UsernameHeaderCard extends StatelessWidget {
  final String username;
  final bool isFilipino;
  const UsernameHeaderCard(
      {super.key, required this.username, required this.isFilipino});

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
                  style: AppTypography.labelSmall
                      .copyWith(color: hc.textSecondary),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isFilipino
                    ? 'Nakopya ang username.'
                    : 'Username copied.'),
                duration: const Duration(seconds: 1),
              ));
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
  const AddFriendDialog(
      {super.key, required this.me, required this.isFilipino});

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
  const FriendRequestsBadgeButton(
      {super.key, required this.count, required this.onTap});

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
              style: AppTypography.titleMedium
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.isFilipino
                      ? 'Walang nakahaing request.'
                      : 'No pending requests.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textSecondary),
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
                      title: Text(r.fromDisplayName.isEmpty
                          ? 'User'
                          : r.fromDisplayName),
                      subtitle: Text(
                        widget.isFilipino
                            ? 'Gustong maging kaibigan'
                            : 'Wants to be friends',
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip:
                                widget.isFilipino ? 'Tanggihan' : 'Reject',
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.red),
                            onPressed: () async {
                              await FriendService.instance.rejectRequest(r.id);
                            },
                          ),
                          IconButton(
                            tooltip:
                                widget.isFilipino ? 'Tanggapin' : 'Accept',
                            icon: const Icon(Icons.check_rounded,
                                color: Colors.green),
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
