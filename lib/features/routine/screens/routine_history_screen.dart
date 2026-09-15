import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/rich_empty_states.dart';
import '../models/routine_catalog.dart';
import '../models/routine_history.dart';
import '../models/routine_models.dart';
import '../widgets/routine_lock_log.dart';
import '../widgets/routine_wait_report_section.dart';

/// What actually happened, day by day.
///
/// The day log has been written since routines shipped and nothing read it
/// back. This is the screen that turns it into the sentence an educator can
/// act on: "three weeks of mornings, and bath time is where it stalls".
class RoutineHistoryScreen extends ConsumerWidget {
  final String childProfileId;
  final String? childDisplayName;

  /// "student" / "child" — the audience's word for this learner.
  final String learnerNoun;

  const RoutineHistoryScreen({
    super.key,
    required this.childProfileId,
    this.childDisplayName,
    this.learnerNoun = 'learner',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final routines =
        ref.watch(routineListProvider(childProfileId)).valueOrNull ??
            const <Routine>[];
    final logs = ref.watch(routineHistoryProvider(childProfileId));

    final history = RoutineHistory.from(
      routines: routines,
      logs: logs,
      titleOf: (s) => RoutineCatalog.titleFor(s, filipino: l),
      emojiOf: RoutineCatalog.emojiFor,
    );

    return AnimatedGradientBackground(
      intensity: 0.22,
      preset: GradientPreset.assessment,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            childDisplayName == null
                ? (l ? 'Kasaysayan ng Routine' : 'Routine History')
                : (l
                    ? 'Kasaysayan ni $childDisplayName'
                    : '$childDisplayName — History'),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: history.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    children: [
                      RichEmptyState(
                        emoji: '📈',
                        title: l ? 'Wala pang kasaysayan' : 'No history yet',
                        description: l
                            ? 'Lalabas dito ang bawat araw kapag nagsimula '
                                'nang markahan ng bata ang mga hakbang.'
                            : 'Once the $learnerNoun starts ticking steps '
                                'off, every day shows up here.',
                      ),
                      // A day can have lock activity and no ticks — a step
                      // that was excused is exactly that day.
                      RoutineWaitReportSection(
                        profileId: childProfileId,
                        filipino: l,
                      ),
                      const SizedBox(height: 16),
                      RoutineLockLogSection(
                        profileId: childProfileId,
                        filipino: l,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _Headline(history: history, filipino: l),
                    const SizedBox(height: 16),
                    ProSectionHeader(
                      title: l ? 'Huling 2 Linggo' : 'Last 2 Weeks',
                      subtitle: _windowSubtitle(history, filipino: l),
                    ),
                    const SizedBox(height: 8),
                    _DayStrip(history: history, filipino: l),
                    const SizedBox(height: 16),
                    if (history.stalls.isNotEmpty) ...[
                      ProSectionHeader(
                        title: l ? 'Saan Naiipit' : 'Where It Stalls',
                        subtitle: l
                            ? 'Ang mga hakbang na madalas hindi natatapos'
                            : 'The steps that most often go unfinished',
                      ),
                      const SizedBox(height: 8),
                      for (final s in history.stalls.take(5))
                        _StallRow(entry: s, filipino: l),
                    ] else
                      _AllSteady(filipino: l, learnerNoun: learnerNoun),
                    const SizedBox(height: 16),
                    RoutineWaitReportSection(
                      profileId: childProfileId,
                      filipino: l,
                    ),
                    const SizedBox(height: 16),
                    RoutineLockLogSection(
                      profileId: childProfileId,
                      filipino: l,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  final RoutineHistory history;
  final bool filipino;

  const _Headline({required this.history, required this.filipino});

  @override
  Widget build(BuildContext context) {
    final l = filipino;
    final rate = history.completionRate;
    final streak = history.streak();

    return ProPanel(
      title: l ? 'Pangkalahatan' : 'Overall',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiles = [
            ProStatTile(
              label: l ? 'Natapos' : 'Completed',
              value: rate == null ? '—' : '${(rate * 100).round()}%',
              icon: Icons.check_circle_rounded,
              accent: AppColors.success,
            ),
            ProStatTile(
              label: l ? 'Buong araw na tapos' : 'Full days',
              value: '${history.completeDays}',
              icon: Icons.event_available_rounded,
            ),
            ProStatTile(
              label: l ? 'Sunod-sunod' : 'Streak',
              value: '$streak',
              icon: Icons.local_fire_department_rounded,
              accent: AppColors.warning,
            ),
          ];
          return ProStatGrid(tiles: tiles);
        },
      ),
    );
  }
}

/// One bar per day, newest on the right so it reads like a calendar.
class _DayStrip extends StatelessWidget {
  final RoutineHistory history;
  final bool filipino;

  const _DayStrip({required this.history, required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final days = history.days.reversed.toList();

    return ProPanel(
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayBar(day: d, filipino: filipino, hc: hc),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final RoutineDaySummary day;
  final bool filipino;
  final HCColor hc;

  const _DayBar({
    required this.day,
    required this.filipino,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = day.fraction;
    final label = _weekdayLetter(day.day, filipino: filipino);

    // A rest day draws a flat dash rather than an empty column: an empty
    // column reads as "did nothing", and the learner was not asked to.
    final semantics = day.isRestDay
        ? (filipino
            ? '${_dayStamp(day.day)}: walang nakatakda'
            : '${_dayStamp(day.day)}: nothing scheduled')
        : (filipino
            ? '${_dayStamp(day.day)}: ${day.done} sa ${day.scheduled} tapos'
                '${day.isEstimated ? ', tantiya' : ''}'
            : '${_dayStamp(day.day)}: ${day.done} of ${day.scheduled} done'
                '${day.isEstimated ? ', estimated' : ''}');

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: day.isRestDay
                  ? Center(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: hc.textHint.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (fraction ?? 0).clamp(0.06, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            // An estimated day is drawn hollow: the height is
                            // a guess against today's routine, and a solid bar
                            // would claim more than the app knows.
                            color: day.isEstimated
                                ? Colors.transparent
                                : (day.isComplete
                                    ? AppColors.success
                                    : hc.primary.withValues(alpha: 0.75)),
                            border: day.isEstimated
                                ? Border.all(
                                    color: hc.primary.withValues(alpha: 0.55),
                                    width: 1.5,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StallRow extends StatelessWidget {
  final RoutineStepReliability entry;
  final bool filipino;

  const _StallRow({required this.entry, required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final pct = (entry.rate * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProPanel(
        child: Row(
          children: [
            Text(entry.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l
                        ? 'Hindi natapos ${entry.missed} sa ${entry.scheduled} '
                            'na araw'
                        : 'Missed ${entry.missed} of ${entry.scheduled} days',
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.rate,
                      minHeight: 6,
                      backgroundColor: hc.textHint.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(
                        entry.rate < 0.5 ? AppColors.error : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$pct%',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllSteady extends StatelessWidget {
  final bool filipino;
  final String learnerNoun;

  const _AllSteady({required this.filipino, required this.learnerNoun});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return ProPanel(
      child: Row(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filipino
                  ? 'Walang hakbang na paulit-ulit na hindi natatapos. '
                      'Maayos ang takbo ng routine.'
                  : 'No step is being missed repeatedly — this routine is '
                      'running well for your $learnerNoun.',
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says how much of the window is a real record.
///
/// The distinction matters: a snapshot is what *was* scheduled, an estimate is
/// today's routine projected backwards. Telling an educator their learner
/// missed bath time nine days running is a serious claim, and it should only
/// be made when the app actually watched those days.
String _windowSubtitle(RoutineHistory history, {required bool filipino}) {
  if (history.isFullyRecorded) {
    return filipino
        ? 'Naitala araw-araw'
        : 'Recorded day by day';
  }
  final recorded = history.recordedDays;
  final total = history.activeDays.length;
  if (recorded == 0) {
    return filipino
        ? 'Tantiya batay sa kasalukuyang routine'
        : 'Estimated from the current routine';
  }
  return filipino
      ? '$recorded sa $total araw ang naitala; ang iba ay tantiya'
      : '$recorded of $total days recorded, the rest estimated';
}

String _weekdayLetter(DateTime d, {required bool filipino}) {
  const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const fil = ['L', 'M', 'M', 'H', 'B', 'S', 'L'];
  return (filipino ? fil : en)[(d.weekday - 1).clamp(0, 6)];
}

String _dayStamp(DateTime d) =>
    '${d.day}/${d.month}';
