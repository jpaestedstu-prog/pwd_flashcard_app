import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../models/routine_catalog.dart';
import '../models/routine_lock_status.dart';
import '../models/routine_models.dart';

/// `6:52 AM`, without a locale-aware formatter.
String formatClockTime(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$hour12:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Builds a control for one step's status — the host decides what an adult
/// may do about it.
typedef RoutineStatusActionBuilder = Widget Function(
  BuildContext context,
  RoutineStepLockStatus status,
);

/// One learner's routine lock, live, in the words an educator acts on.
///
/// "Waiting on Brushing Teeth · since 6:45 AM · 12 min", turning red as
/// "Needs help" once the routine's escalation time passes, plus a line for
/// every step an adult excused or marked done today and who did it.
///
/// Renders nothing for a learner whose routines do not lock — the dashboard
/// row already says how their day is going, and a status line about a lock
/// that cannot happen would be noise.
///
/// Honest about what it knows: it describes the **routine** (a step is due
/// and not done), and only says the lock is on screen once the learner's
/// device has reported showing it. A tablet that is switched off is waiting
/// on a step too; the educator should not be told it is locked.
class RoutineLearnerLockStatus extends ConsumerWidget {
  const RoutineLearnerLockStatus({
    super.key,
    required this.profileId,
    required this.filipino,
    this.actionsFor,
    this.undoFor,
  });

  final String profileId;
  final bool filipino;

  /// Controls for the step currently holding the device (mark done, excuse,
  /// unlock). Supplied by the host so the status itself stays read-only.
  final RoutineStatusActionBuilder? actionsFor;

  /// A control for taking back an adult's excuse or approval.
  final RoutineStatusActionBuilder? undoFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();
    final routines =
        ref.watch(routineListProvider(profileId)).valueOrNull ??
            const <Routine>[];
    if (!routines.any((r) => r.enabled && r.lockEnabled)) {
      return const SizedBox.shrink();
    }
    final view = ref.watch(
      routineDayViewProvider(routineDayKey(profileId, now)),
    );
    final summary =
        RoutineLockSummary.of(routines: routines, view: view, now: now);
    if (summary.isEmpty) return const SizedBox.shrink();

    final l = filipino;
    final children = <Widget>[];
    final current = summary.current;
    final upcoming = summary.upcoming;
    if (current != null) {
      children.add(_HoldingBanner(
        status: current,
        filipino: l,
        actions: actionsFor?.call(context, current),
      ));
    } else if (upcoming != null) {
      final title = RoutineCatalog.titleFor(upcoming.step, filipino: l);
      children.add(_Line(
        icon: Icons.alarm_rounded,
        color: AppColors.info,
        text: l
            ? 'Mala-lock para sa $title sa ${formatClockTime(upcoming.dueAt)}'
                ' · ${upcoming.minutesUntil} minuto'
            : '$title locks at ${formatClockTime(upcoming.dueAt)}'
                ' · in ${upcoming.minutesUntil} min',
      ));
    }

    for (final s in summary.excused) {
      children.add(_Line(
        icon: Icons.pan_tool_alt_rounded,
        color: AppColors.warning,
        text: excusedSentence(s, filipino: l),
        trailing: undoFor?.call(context, s),
      ));
    }
    for (final s in summary.approved) {
      children.add(_Line(
        icon: Icons.verified_rounded,
        color: AppColors.success,
        text: approvedSentence(s, filipino: l),
        trailing: undoFor?.call(context, s),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }

  /// "Brushing Teeth excused by Rose at 6:52 AM".
  static String excusedSentence(
    RoutineStepLockStatus s, {
    required bool filipino,
  }) {
    final title = RoutineCatalog.titleFor(s.step, filipino: filipino);
    final mark = s.mark;
    final at = mark == null ? '' : formatClockTime(mark.at);
    final who = mark == null || mark.byName.isEmpty
        ? (filipino ? ' sa tablet' : ' on the tablet')
        : (filipino ? ' ni ${mark.byName}' : ' by ${mark.byName}');
    return filipino
        ? 'Pinayagang laktawan: $title$who · $at'
        : '$title excused$who at $at';
  }

  /// "Brushing Teeth marked done by Rose at 6:52 AM".
  static String approvedSentence(
    RoutineStepLockStatus s, {
    required bool filipino,
  }) {
    final title = RoutineCatalog.titleFor(s.step, filipino: filipino);
    final mark = s.mark;
    final name = mark?.byName ?? '';
    final at = mark == null ? '' : formatClockTime(mark.at);
    return filipino
        ? 'Minarkahang tapos${name.isEmpty ? '' : ' ni $name'}: $title · $at'
        : '$title marked done${name.isEmpty ? '' : ' by $name'} at $at';
  }
}

/// The step holding the device: amber while waiting, red once it needs help.
class _HoldingBanner extends StatelessWidget {
  const _HoldingBanner({
    required this.status,
    required this.filipino,
    this.actions,
  });

  final RoutineStepLockStatus status;
  final bool filipino;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final help = status.phase == RoutineStepPhase.needsHelp;
    final tint = hc.hc ? hc.primary : (help ? AppColors.error : AppColors.warning);
    final title = RoutineCatalog.titleFor(status.step, filipino: l);
    final emoji = RoutineCatalog.emojiFor(status.step);
    final since = formatClockTime(status.dueAt);
    final minutes = status.minutesWaiting;

    final headline = help
        ? (l ? 'Kailangan ng tulong: $title' : 'Needs help: $title')
        : (l ? 'Naghihintay sa $title' : 'Waiting on $title');
    final detail = help
        ? (l
            ? '$minutes minutong naghihintay, mula $since'
            : 'Waiting $minutes min, since $since')
        : (l ? 'Mula $since · $minutes minuto' : 'Since $since · $minutes min');
    final device = status.lockShownAt != null
        ? (l
            ? 'Nakabukas ang lock sa kanilang device.'
            : 'The lock is showing on their device.')
        : (l
            ? 'Hindi pa ipinapakita ng kanilang device ang lock — maaaring '
                'nakapatay ito.'
            : "Their device hasn't shown the lock yet — it may be off.");

    return Semantics(
      container: true,
      label: '$headline. $detail. $device',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: hc.hc ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    help ? '⚠️' : '🔒',
                    style: const TextStyle(fontSize: 18, height: 1.2),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$emoji $headline',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: hc.textPrimary,
                          ),
                        ),
                        Text(
                          detail,
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          device,
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
            if (actions != null) ...[
              const SizedBox(height: 8),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: hc.hc ? hc.primary : color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
