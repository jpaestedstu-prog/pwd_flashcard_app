import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../providers/routine_provider.dart';
import '../models/routine_catalog.dart';
import '../models/routine_day_state.dart';
import '../models/routine_lock_status.dart';
import '../models/routine_models.dart';
import 'routine_lock_status_line.dart';

/// "Lock & Excuse Log" — the audit trail behind a learner's routine lock.
///
/// Every lock that appeared, how long it held, who excused or approved a step
/// and whether they later took it back, when a morning needed help, and when
/// it was started over — for the last two weeks, newest first.
///
/// The accountability half of the lock. A lock an adult can wave past from a
/// maths question is only trustworthy if the waving is visible afterwards; an
/// educator seeing "Brushing Teeth: 3 steps done, 1 incomplete" cannot tell
/// whether the child refused or somebody said it was fine. This is where they
/// can.
///
/// Reads the raw records rather than the joined day view on purpose: an excuse
/// that was later revoked, or a morning that was later started over, still
/// happened.
class RoutineLockLogSection extends ConsumerWidget {
  const RoutineLockLogSection({
    super.key,
    required this.profileId,
    required this.filipino,
  });

  final String profileId;
  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pulls the learner's days down onto this device first — an educator's
    // phone never lived through them.
    ref.watch(routineRecentDaysSyncProvider(profileId));
    final logs = ref.watch(routineHistoryProvider(profileId));
    final actions = ref.watch(routineActionsHistoryProvider(profileId));
    final routines =
        ref.watch(routineListProvider(profileId)).valueOrNull ??
            const <Routine>[];

    final stepsById = <String, RoutineStep>{
      for (final r in routines)
        for (final s in r.steps) s.id: s,
    };
    final actionsByDay = {for (final a in actions) dayStampOf(a.day): a};

    final days = <({DateTime day, List<RoutineLockEvent> events})>[];
    for (final log in logs) {
      final dayActions = actionsByDay[dayStampOf(log.day)] ??
          RoutineDayActions.empty(profileId, log.day);
      final events = RoutineLockEvent.forDay(log: log, actions: dayActions);
      if (events.isEmpty) continue;
      for (final s in log.scheduled) {
        stepsById.putIfAbsent(s.id, s.toStep);
      }
      days.add((day: log.day, events: events));
    }

    final l = filipino;
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProSectionHeader(
          title: l ? 'Talaan ng Lock at Pagpapalaktaw' : 'Lock & Excuse Log',
          subtitle: l
              ? 'Bawat lock, pagpapalaktaw at markang tapos ng nakatatanda'
              : 'Every lock, and every step an adult excused or marked done',
        ),
        const SizedBox(height: 8),
        for (final d in days)
          _DayBlock(
            day: d.day,
            events: d.events,
            stepsById: stepsById,
            filipino: l,
          ),
      ],
    );
  }

  /// The event as one sentence. Public for tests.
  static String sentence(
    RoutineLockEvent e, {
    required bool filipino,
  }) {
    final l = filipino;
    final name = e.byName;
    final onTablet = e.source == RoutineMarkSource.learnerDevice;
    return switch (e.kind) {
      RoutineLockEventKind.lockShown => l ? 'Lumabas ang lock' : 'Lock appeared',
      RoutineLockEventKind.done => e.minutesHeld == null
          ? (l ? 'Tapos' : 'Done')
          : (l
              ? 'Tapos makalipas ang ${e.minutesHeld} minutong lock'
              : 'Done after ${e.minutesHeld} min locked'),
      RoutineLockEventKind.approved => l
          ? 'Minarkahang tapos${name.isEmpty ? '' : ' ni $name'}'
          : 'Marked done${name.isEmpty ? '' : ' by $name'}',
      RoutineLockEventKind.approvalRevoked => l
          ? 'Binawi${name.isEmpty ? '' : ' ni $name'} ang markang tapos'
          : 'Mark-done taken back${name.isEmpty ? '' : ' by $name'}',
      RoutineLockEventKind.excused => onTablet || name.isEmpty
          ? (l
              ? 'Pinayagang laktawan sa tablet (pagsusuri ng nakatatanda)'
              : 'Excused on the tablet (adult check)')
          : (l ? 'Pinayagang laktawan ni $name' : 'Excused by $name'),
      RoutineLockEventKind.excuseRevoked => l
          ? 'Binawi${name.isEmpty ? '' : ' ni $name'} ang pagpapalaktaw'
          : 'Excuse taken back${name.isEmpty ? '' : ' by $name'}',
      RoutineLockEventKind.escalated =>
        l ? 'Kinailangan ng tulong' : 'Needed help',
      RoutineLockEventKind.reset => l
          ? 'Inulit ang araw${name.isEmpty ? '' : ' ni $name'}'
          : 'Day started over${name.isEmpty ? '' : ' by $name'}',
    };
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.day,
    required this.events,
    required this.stepsById,
    required this.filipino,
  });

  final DateTime day;
  final List<RoutineLockEvent> events;
  final Map<String, RoutineStep> stepsById;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProPanel(
        title: _dayLabel(day, filipino: filipino),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        formatClockTime(e.at),
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _iconFor(e.kind),
                      size: 16,
                      color: hc.hc ? hc.primary : _colorFor(e.kind),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _withStep(e),
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textPrimary,
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

  String _withStep(RoutineLockEvent e) {
    final sentence = RoutineLockLogSection.sentence(e, filipino: filipino);
    final id = e.stepId;
    if (id == null) return sentence;
    final step = stepsById[id];
    final title = step == null
        ? (filipino ? 'Inalis na hakbang' : 'A removed step')
        : '${RoutineCatalog.emojiFor(step)} '
            '${RoutineCatalog.titleFor(step, filipino: filipino)}';
    return '$title — $sentence';
  }

  static IconData _iconFor(RoutineLockEventKind k) => switch (k) {
        RoutineLockEventKind.lockShown => Icons.lock_clock_rounded,
        RoutineLockEventKind.done => Icons.check_circle_rounded,
        RoutineLockEventKind.approved => Icons.verified_rounded,
        RoutineLockEventKind.approvalRevoked => Icons.undo_rounded,
        RoutineLockEventKind.excused => Icons.pan_tool_alt_rounded,
        RoutineLockEventKind.excuseRevoked => Icons.undo_rounded,
        RoutineLockEventKind.escalated => Icons.warning_amber_rounded,
        RoutineLockEventKind.reset => Icons.restart_alt_rounded,
      };

  static Color _colorFor(RoutineLockEventKind k) => switch (k) {
        RoutineLockEventKind.done ||
        RoutineLockEventKind.approved =>
          AppColors.success,
        RoutineLockEventKind.escalated => AppColors.error,
        RoutineLockEventKind.excused ||
        RoutineLockEventKind.approvalRevoked ||
        RoutineLockEventKind.excuseRevoked =>
          AppColors.warning,
        _ => AppColors.info,
      };

  static String _dayLabel(DateTime day, {required bool filipino}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return filipino ? 'Ngayon' : 'Today';
    if (diff == 1) return filipino ? 'Kahapon' : 'Yesterday';
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fil = ['Lun', 'Mar', 'Miy', 'Huw', 'Biy', 'Sab', 'Lin'];
    final wd = (filipino ? fil : en)[d.weekday - 1];
    return '$wd ${d.month}/${d.day}';
  }
}
