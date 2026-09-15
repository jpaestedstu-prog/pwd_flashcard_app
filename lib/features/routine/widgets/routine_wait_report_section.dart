import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_wait_report.dart';

/// "This Week: Waiting & Early Releases" — the educator's weekly report on a
/// learner's routine lock.
///
/// How long the lock held the learner in total and on average, how often an
/// adult ended a step early, excused it, paused it or added time — and which
/// steps those were. The question it answers is the one an educator tunes a
/// routine from: *is this step's length right for this learner?*
///
/// Renders nothing for a learner whose routines never lock.
class RoutineWaitReportSection extends ConsumerWidget {
  const RoutineWaitReportSection({
    super.key,
    required this.profileId,
    required this.filipino,
  });

  final String profileId;
  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines =
        ref.watch(routineListProvider(profileId)).valueOrNull ??
            const <Routine>[];
    // The same pull the lock log makes: an educator's phone never lived
    // through the learner's days.
    ref.watch(routineRecentDaysSyncProvider(profileId));
    final logs = ref.watch(routineHistoryProvider(profileId));
    final actions = ref.watch(routineActionsHistoryProvider(profileId));
    final now =
        ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();

    final report = RoutineWaitReport.from(
      profileId: profileId,
      routines: routines,
      logs: logs,
      actions: actions,
      now: now,
    );
    final locks = routines.any((r) => r.enabled && r.lockEnabled);
    if (!locks && report.isEmpty) return const SizedBox.shrink();

    final l = filipino;
    final hc = HCColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProSectionHeader(
          title: l
              ? 'Linggong Ito: Pagtitimpi at Maagang Pagtapos'
              : 'This Week: Waiting & Early Releases',
          subtitle: l
              ? 'Gaano ang hinintay sa lock, at kapag nakialam ang nakatatanda'
              : 'How long the lock held, and when an adult stepped in',
        ),
        const SizedBox(height: 8),
        if (report.isEmpty)
          ProPanel(
            child: Text(
              l
                  ? 'Walang hakbang na nag-lock sa tablet sa nakaraang 7 araw.'
                  : 'No step has locked the tablet in the last 7 days.',
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          )
        else ...[
          ProPanel(
            child: ProStatGrid(
              tiles: [
                ProStatTile(
                  label: l ? 'Minutong hinintay' : 'Minutes waited',
                  value: '${report.minutesWaited}',
                  icon: Icons.hourglass_bottom_rounded,
                  accent: AppColors.warning,
                ),
                ProStatTile(
                  label: l ? 'Karaniwang hintay' : 'Average wait',
                  value: report.averageWait == null
                      ? '—'
                      : (l
                          ? '${report.averageWait} min'
                          : '${report.averageWait} min'),
                  icon: Icons.timelapse_rounded,
                ),
                ProStatTile(
                  label: l ? 'Lock na ipinakita' : 'Locks shown',
                  value: '${report.locksShown}',
                  icon: Icons.lock_clock_rounded,
                ),
                ProStatTile(
                  label: l
                      ? 'Tinapos nang maaga ng nakatatanda'
                      : 'Ended early by an adult',
                  value: '${report.endedEarly}',
                  icon: Icons.verified_rounded,
                  accent: AppColors.success,
                ),
                ProStatTile(
                  label: l ? 'Pinalaktaw' : 'Excused',
                  value: '${report.excused}',
                  icon: Icons.pan_tool_alt_rounded,
                ),
                ProStatTile(
                  label: l ? 'Idinagdag na oras' : 'Time added',
                  value: '${report.addedMinutes} min',
                  icon: Icons.more_time_rounded,
                ),
              ],
            ),
          ),
          if (report.endedEarlyBy.isNotEmpty) ...[
            const SizedBox(height: 8),
            ProPanel(
              title: l ? 'Sino ang tinapos nang maaga' : 'Who ended steps early',
              child: Text(
                _whoLine(report.endedEarlyBy, filipino: l),
                style:
                    AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final s in report.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StepRow(summary: s, filipino: l),
            ),
        ],
      ],
    );
  }

  /// "Rose ×2 · On the tablet ×1".
  static String _whoLine(Map<String, int> by, {required bool filipino}) {
    final entries = by.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) =>
            '${e.key.isEmpty ? (filipino ? 'Sa tablet' : 'On the tablet') : e.key} ×${e.value}')
        .join(' · ');
  }

  /// One step's week in a sentence — public for tests.
  static String stepSentence(
    RoutineWaitStepSummary s, {
    required bool filipino,
  }) {
    final l = filipino;
    final parts = <String>[
      l
          ? 'Naka-lock ${s.locksShown} ${s.locksShown == 1 ? 'araw' : 'araw'}'
          : 'Locked ${s.locksShown} ${s.locksShown == 1 ? 'day' : 'days'}',
      l ? 'hinintay ${s.minutesWaited} minuto' : 'waited ${s.minutesWaited} min',
      if (s.endedEarly > 0)
        l ? 'tinapos nang maaga ${s.endedEarly}×' : 'ended early ${s.endedEarly}×',
      if (s.excused > 0) l ? 'pinalaktaw ${s.excused}×' : 'excused ${s.excused}×',
      if (s.addedMinutes > 0)
        l ? '+${s.addedMinutes} minuto' : '+${s.addedMinutes} min added',
    ];
    return parts.join(' · ');
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.summary, required this.filipino});

  final RoutineWaitStepSummary summary;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final title = RoutineCatalog.titleFor(summary.step, filipino: filipino);
    return ProPanel(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              RoutineCatalog.emojiFor(summary.step),
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  RoutineWaitReportSection.stepSentence(
                    summary,
                    filipino: filipino,
                  ),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
