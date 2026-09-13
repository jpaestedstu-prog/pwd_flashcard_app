import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../parent/services/child_unlock_override_service.dart';
import '../models/routine_catalog.dart';
import '../models/routine_lock_status.dart';
import '../services/routine_service.dart';
import 'routine_sync_feedback.dart';

/// How long "Unlock" pauses every lock on a learner's device from here.
const Duration kRoutineRemoteUnlock = Duration(minutes: 30);

/// What an educator can do about a step holding a learner's device, from
/// their own dashboard: **mark it done**, **excuse it for today**, or
/// **unlock the device** for a while.
///
/// The three are different answers and the buttons say which is which:
///
///  * *Mark done* — "I watched them brush their teeth." The lock lifts and the
///    step counts as done, recorded as the educator's approval rather than the
///    learner's tick.
///  * *Excuse today* — "Not today." The lock lifts, the step stays not done,
///    and the history says who decided.
///  * *Unlock 30 min* — "Leave them alone for a bit." Every lock on the device
///    pauses — routine, time limit and alarm — through the same override the
///    classroom manager's "Unlock screen" already writes.
///
/// Every action confirms first. They reach a child's screen in another room,
/// and a mis-tap on a phone should not be the reason a learner's morning
/// routine silently disappeared.
class RoutineStepActionBar extends ConsumerStatefulWidget {
  const RoutineStepActionBar({
    super.key,
    required this.childProfileId,
    required this.learnerName,
    required this.status,
    required this.filipino,
  });

  final String childProfileId;
  final String learnerName;
  final RoutineStepLockStatus status;
  final bool filipino;

  @override
  ConsumerState<RoutineStepActionBar> createState() =>
      _RoutineStepActionBarState();
}

class _RoutineStepActionBarState extends ConsumerState<RoutineStepActionBar> {
  bool _busy = false;

  bool get l => widget.filipino;

  String get _title =>
      RoutineCatalog.titleFor(widget.status.step, filipino: l);

  Future<void> _run(
    Future<CloudSyncOutcome?> Function() action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted || outcome == null) return;
      ref.invalidate(routineDayActionsProvider(
        routineDayKey(widget.childProfileId, DateTime.now()),
      ));
      reportRoutineSync(
        context,
        outcome,
        filipino: l,
        subject: l ? 'pagbabago' : 'change',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() => _run(() async {
        final by = ref.read(profileProvider);
        if (by == null) return null;
        final ok = await confirmRoutineAction(
          context,
          filipino: l,
          title: l
              ? 'Markahang tapos ang $_title?'
              : 'Mark $_title done for ${widget.learnerName}?',
          body: l
              ? 'Gawin ito kung nakita ninyong ginawa ito. Aalis ang lock sa '
                  'device ni ${widget.learnerName} at bibilangin itong tapos.'
              : 'Only if you saw it done. ${widget.learnerName}’s lock '
                  'lifts and the step counts as done, recorded as marked by '
                  'you.',
          confirm: l ? 'Markahang tapos' : 'Mark done',
        );
        if (!ok) return null;
        return const RoutineService().approveStep(
          childProfileId: widget.childProfileId,
          day: DateTime.now(),
          stepId: widget.status.step.id,
          by: by,
        );
      });

  Future<void> _excuse() => _run(() async {
        final by = ref.read(profileProvider);
        if (by == null) return null;
        final ok = await confirmRoutineAction(
          context,
          filipino: l,
          title: l
              ? 'Laktawan ang $_title ngayong araw?'
              : 'Excuse $_title for today?',
          body: l
              ? 'Aalis ang lock sa device ni ${widget.learnerName}. Hindi '
                  'bibilangin itong tapos, at itatala sa kasaysayan kung sino '
                  'nagpasya.'
              : '${widget.learnerName}’s lock lifts. The step stays not '
                  'done, and the history records that you excused it.',
          confirm: l ? 'Laktawan' : 'Excuse',
        );
        if (!ok) return null;
        return const RoutineService().excuseStep(
          childProfileId: widget.childProfileId,
          day: DateTime.now(),
          stepId: widget.status.step.id,
          by: by,
        );
      });

  Future<void> _unlock() async {
    if (_busy) return;
    final by = ref.read(profileProvider);
    if (by == null) return;
    final ok = await confirmRoutineAction(
      context,
      filipino: l,
      title: l
          ? 'I-unlock ang device ni ${widget.learnerName} nang 30 minuto?'
          : 'Unlock ${widget.learnerName}’s device for 30 minutes?',
      body: l
          ? 'Mahihinto ang bawat lock — routine, time limit at alarm. Hindi '
              'binabago ang routine.'
          : 'Every lock pauses — routine, time limit and alarm. The routine '
              'itself is not changed.',
      confirm: l ? 'I-unlock' : 'Unlock',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await const ChildUnlockOverrideService().setUnlock(
        childProfileId: widget.childProfileId,
        unlockedUntil: DateTime.now().add(kRoutineRemoteUnlock),
        setter: by,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l
            ? 'Na-unlock ang device ni ${widget.learnerName} nang 30 minuto.'
            : '${widget.learnerName}’s device is unlocked for 30 minutes.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l
            ? 'Hindi na-unlock. Suriin ang koneksyon at subukan muli.'
            : 'Could not unlock. Check the connection and try again.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: Text(l ? 'Markahang tapos' : 'Mark done'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _excuse,
          icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
          label: Text(l ? 'Laktawan ngayon' : 'Excuse today'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _unlock,
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: Text(l ? 'I-unlock 30 min' : 'Unlock 30 min'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

/// "Undo" beside a step an adult excused or marked done today.
///
/// Taking back an excuse re-arms the lock if the step's hour is not over;
/// taking back an approval puts the step back to not done. Both are recorded,
/// so the history shows the change of mind rather than hiding it.
class RoutineUndoMarkButton extends ConsumerStatefulWidget {
  const RoutineUndoMarkButton({
    super.key,
    required this.childProfileId,
    required this.status,
    required this.filipino,
  });

  final String childProfileId;
  final RoutineStepLockStatus status;
  final bool filipino;

  @override
  ConsumerState<RoutineUndoMarkButton> createState() =>
      _RoutineUndoMarkButtonState();
}

class _RoutineUndoMarkButtonState extends ConsumerState<RoutineUndoMarkButton> {
  bool _busy = false;

  Future<void> _undo() async {
    if (_busy) return;
    final by = ref.read(profileProvider);
    if (by == null) return;
    final l = widget.filipino;
    final title = RoutineCatalog.titleFor(widget.status.step, filipino: l);
    final approval = widget.status.wasApproved;
    final ok = await confirmRoutineAction(
      context,
      filipino: l,
      title: approval
          ? (l ? 'Bawiin ang markang tapos?' : 'Take back "mark done"?')
          : (l ? 'Bawiin ang pagpapalaktaw?' : 'Take back the excuse?'),
      body: approval
          ? (l
              ? 'Hindi na bibilangin tapos ang $title.'
              : '$title goes back to not done.')
          : (l
              ? 'Kung hindi pa lumipas ang oras nito, babalik ang lock para sa '
                  '$title.'
              : 'If its hour is not over, the lock for $title comes back.'),
      confirm: l ? 'Bawiin' : 'Take back',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      const service = RoutineService();
      final day = DateTime.now();
      final outcome = approval
          ? await service.revokeApproval(
              childProfileId: widget.childProfileId,
              day: day,
              stepId: widget.status.step.id,
              by: by,
            )
          : await service.revokeExcuse(
              childProfileId: widget.childProfileId,
              day: day,
              stepId: widget.status.step.id,
              by: by,
            );
      if (!mounted) return;
      ref.invalidate(
        routineDayActionsProvider(routineDayKey(widget.childProfileId, day)),
      );
      reportRoutineSync(
        context,
        outcome,
        filipino: l,
        subject: l ? 'pagbabago' : 'change',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _busy ? null : _undo,
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      child: Text(widget.filipino ? 'Bawiin' : 'Undo'),
    );
  }
}

/// The shared confirm dialog for every remote routine action.
Future<bool> confirmRoutineAction(
  BuildContext context, {
  required bool filipino,
  required String title,
  required String body,
  required String confirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(filipino ? 'Kanselahin' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
