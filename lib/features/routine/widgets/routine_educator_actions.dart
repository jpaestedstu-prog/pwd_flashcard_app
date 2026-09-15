import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../parent/services/child_unlock_override_service.dart';
import '../models/routine_catalog.dart';
import '../models/routine_day_state.dart';
import '../models/routine_lock_status.dart';
import '../services/routine_service.dart';
import 'routine_lock_status_line.dart' show formatClockTime;
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
              ? 'Markahang tapos ang $_title ni ${widget.learnerName}?'
              : 'Mark $_title done for ${widget.learnerName}?',
          body: l
              ? 'Gawin ito kung nakita ninyong ginawa ito. Aalis ang lock sa '
                  'device ni ${widget.learnerName}, bibilangin itong tapos, at itatala na kayo ang nagmarka.'
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
                  'bibilangin itong tapos, at itatala sa kasaysayan na kayo '
                  'ang pumayag.'
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
          ? 'Mapapahinto ang bawat lock — routine, time limit at alarm. Hindi '
              'binabago ang routine mismo.'
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

  Future<void> _pause() => _run(() async {
        final by = ref.read(profileProvider);
        if (by == null) return null;
        final left = widget.status.minutesLeft;
        final ok = await confirmRoutineAction(
          context,
          filipino: l,
          title: l
              ? 'Pahintuin ang $_title ni ${widget.learnerName}?'
              : 'Pause $_title for ${widget.learnerName}?',
          body: l
              ? 'Aalis ang lock sa device ni ${widget.learnerName} at hihinto '
                  'ang orasan. Kapag ipagpatuloy, $left minuto ang natitira.'
              : '${widget.learnerName}’s lock lifts and the clock stops. When '
                  'you resume it, $left min will be left.',
          confirm: l ? 'Pahintuin' : 'Pause',
        );
        if (!ok) return null;
        return const RoutineService().pauseStep(
          childProfileId: widget.childProfileId,
          day: DateTime.now(),
          stepId: widget.status.step.id,
          by: by,
        );
      });

  Future<void> _resume() => _run(() async {
        final by = ref.read(profileProvider);
        if (by == null) return null;
        final left = widget.status.minutesLeft;
        final ok = await confirmRoutineAction(
          context,
          filipino: l,
          title: l
              ? 'Ipagpatuloy ang $_title ni ${widget.learnerName}?'
              : 'Resume $_title for ${widget.learnerName}?',
          body: l
              ? 'Babalik ang lock sa device ni ${widget.learnerName} nang '
                  '$left minuto.'
              : 'The lock comes back on ${widget.learnerName}’s device for '
                  '$left min.',
          confirm: l ? 'Ipagpatuloy' : 'Resume',
        );
        if (!ok) return null;
        return const RoutineService().resumeStep(
          childProfileId: widget.childProfileId,
          day: DateTime.now(),
          stepId: widget.status.step.id,
          by: by,
        );
      });

  /// Minutes that may still be added today, after what already was.
  int get _roomToAdd => kRoutineMaxAddedMinutes - widget.status.addedMinutes;

  Future<void> _addTime() => _run(() async {
        final by = ref.read(profileProvider);
        if (by == null) return null;
        final end = widget.status.endsAt;
        final choices = [
          for (final m in kRoutineAddTimeChoices)
            if (m <= _roomToAdd) m,
        ];
        final minutes = await showDialog<int>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              l ? 'Magdagdag ng oras sa $_title?' : 'Add time to $_title?',
            ),
            content: Text(
              widget.status.isPaused
                  ? (l
                      ? 'Mas matagal na mananatili ang lock kapag ipagpatuloy.'
                      : 'The lock stays on longer once you resume it.')
                  : (l
                      ? 'Mas matagal na mananatili ang lock ni '
                          '${widget.learnerName}. Kasalukuyang magtatapos sa '
                          '${formatClockTime(end)}.'
                      : '${widget.learnerName}’s lock stays on longer. It '
                          'ends at ${formatClockTime(end)} now.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l ? 'Kanselahin' : 'Cancel'),
              ),
              for (final m in choices)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, m),
                  child: Text(l ? '+$m minuto' : '+$m min'),
                ),
            ],
          ),
        );
        if (minutes == null) return null;
        return const RoutineService().addStepTime(
          childProfileId: widget.childProfileId,
          day: DateTime.now(),
          stepId: widget.status.step.id,
          minutes: minutes,
          by: by,
        );
      });

  @override
  Widget build(BuildContext context) {
    // "Mark done" ends a step before its time is up, so it is offered only on
    // a step the educator set as "can be released early" — otherwise the
    // learner waits until the time ends. Pause, more time and excuse stay on
    // every step, and so does the 30-minute unlock while the lock is on: they
    // are for a day that is not going to plan, not for finishing.
    final paused = widget.status.isPaused;
    final canReleaseEarly = widget.status.step.releaseEarly && !paused;
    final canAdd = _roomToAdd >= kRoutineAddTimeChoices.first;
    const compact = VisualDensity.compact;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (canReleaseEarly)
          FilledButton.icon(
            onPressed: _busy ? null : _approve,
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: Text(l ? 'Markahang tapos' : 'Mark done'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              visualDensity: compact,
            ),
          ),
        if (paused)
          FilledButton.icon(
            onPressed: _busy ? null : _resume,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(l ? 'Ipagpatuloy' : 'Resume'),
            style: FilledButton.styleFrom(visualDensity: compact),
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : _pause,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: Text(l ? 'Pahintuin' : 'Pause'),
            style: OutlinedButton.styleFrom(visualDensity: compact),
          ),
        OutlinedButton.icon(
          onPressed: _busy || !canAdd ? null : _addTime,
          icon: const Icon(Icons.more_time_rounded, size: 18),
          label: Text(l ? 'Magdagdag ng oras' : 'Add time'),
          style: OutlinedButton.styleFrom(visualDensity: compact),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _excuse,
          icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
          label: Text(l ? 'Laktawan ngayon' : 'Excuse today'),
          style: OutlinedButton.styleFrom(visualDensity: compact),
        ),
        if (!paused)
          TextButton.icon(
            onPressed: _busy ? null : _unlock,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: Text(l ? 'I-unlock 30 minuto' : 'Unlock 30 min'),
            style: TextButton.styleFrom(visualDensity: compact),
          ),
      ],
    );
  }
}

/// The amounts "Add time" offers, smallest first.
const List<int> kRoutineAddTimeChoices = [5, 10, 15];

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
              ? 'Ibabalik sa hindi tapos ang $title.'
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
