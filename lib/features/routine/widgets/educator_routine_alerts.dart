import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../models/educator_step_alerts.dart';
import '../services/routine_reminder_scheduler.dart';
import 'educator_routine_section.dart';

/// Where educator alerts go. The device implementation posts real
/// notifications; widget tests override it with a recorder.
abstract class EducatorRoutineAlertSink {
  Future<void> schedule(List<EducatorStepAlert> alerts);
  Future<void> showNow(EducatorStepAlert alert);
}

class DeviceEducatorRoutineAlertSink implements EducatorRoutineAlertSink {
  const DeviceEducatorRoutineAlertSink();

  @override
  Future<void> schedule(List<EducatorStepAlert> alerts) =>
      RoutineReminderScheduler.scheduleEducatorAlerts(alerts);

  @override
  Future<void> showNow(EducatorStepAlert alert) =>
      RoutineReminderScheduler.showEducatorAlertNow(alert);
}

final educatorRoutineAlertSinkProvider = Provider<EducatorRoutineAlertSink>(
  (ref) => const DeviceEducatorRoutineAlertSink(),
);

/// Which steps one educator is alerted about on this device.
class EducatorAlertModeNotifier
    extends FamilyNotifier<EducatorAlertMode, String> {
  @override
  EducatorAlertMode build(String educatorProfileId) {
    try {
      return EducatorAlertMode.fromIndex(
        HiveService.getRoutineAlertModeIndex(educatorProfileId),
      );
    } catch (_) {
      return EducatorAlertMode.lockedSteps;
    }
  }

  Future<void> choose(EducatorAlertMode mode) async {
    state = mode;
    try {
      await HiveService.setRoutineAlertModeIndex(arg, mode.index);
    } catch (_) {}
  }
}

final educatorAlertModeProvider = NotifierProvider.family<
    EducatorAlertModeNotifier, EducatorAlertMode, String>(
  EducatorAlertModeNotifier.new,
);

/// Keeps this device's routine start and end alerts in step with the
/// educator's learners while their dashboard is open.
///
/// Renders nothing. Mounted in the dashboard's app bar, which is always built
/// — the routine section itself lives in a lazy scroll view and is not built
/// while it is scrolled out of sight.
///
/// Every change to a routine or a learner's day re-plans the pending alerts
/// ([EducatorStepAlertPlan.plan]); a step an adult finishes or excuses while
/// it is running is announced at once, since no schedule could have known.
class EducatorRoutineAlertSync extends ConsumerStatefulWidget {
  const EducatorRoutineAlertSync({super.key, required this.learners});

  final List<EducatorRoutineLearner> learners;

  @override
  ConsumerState<EducatorRoutineAlertSync> createState() =>
      _EducatorRoutineAlertSyncState();
}

class _EducatorRoutineAlertSyncState
    extends ConsumerState<EducatorRoutineAlertSync> {
  /// Per learner, the steps that were running at the last build — how a step
  /// ending early is noticed.
  final Map<String, Set<String>> _running = {};
  String _runningFor = '';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null || !profile.role.isEducator) {
      return const SizedBox.shrink();
    }
    final now = ref.watch(wallClockTickerProvider).valueOrNull;
    if (now == null) return const SizedBox.shrink();
    final mode = ref.watch(educatorAlertModeProvider(profile.id));
    final filipino = ref.watch(settingsProvider).locale == 'fil';

    final dayTag = '${profile.id}|${now.year}-${now.month}-${now.day}';
    if (_runningFor != dayTag) {
      _runningFor = dayTag;
      _running.clear();
    }

    final learners = <EducatorAlertLearner>[];
    for (final l in widget.learners) {
      final key = routineDayKey(l.profileId, now);
      final loaded = ref.watch(routineDayLogProvider(key)).hasValue &&
          ref.watch(routineDayActionsProvider(key)).hasValue;
      learners.add(EducatorAlertLearner(
        profileId: l.profileId,
        name: l.name,
        routines: ref.watch(routineListProvider(l.profileId)).valueOrNull ??
            const [],
        today: loaded ? ref.watch(routineDayViewProvider(key)) : null,
      ));
    }

    final plan = EducatorStepAlertPlan.plan(
      learners: learners,
      now: now,
      mode: mode,
      filipino: filipino,
    );
    final early = <EducatorStepAlert>[];
    for (final learner in learners) {
      if (learner.today == null) continue;
      final was = _running[learner.profileId];
      if (was != null) {
        early.addAll(EducatorStepAlertPlan.endedEarly(
          learner: learner,
          wasRunning: was,
          now: now,
          mode: mode,
          filipino: filipino,
        ));
      }
      _running[learner.profileId] =
          EducatorStepAlertPlan.runningIds(learner, now, mode);
    }

    final sink = ref.read(educatorRoutineAlertSinkProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(sink.schedule(plan));
      for (final alert in early) {
        unawaited(sink.showNow(alert));
      }
    });
    return const SizedBox.shrink();
  }
}

/// The routine-alerts control on the dashboard's Today's Routines card.
class EducatorRoutineAlertsButton extends ConsumerWidget {
  const EducatorRoutineAlertsButton({super.key, required this.filipino});

  final bool filipino;

  static String modeLabel(EducatorAlertMode mode, {required bool filipino}) =>
      switch (mode) {
        EducatorAlertMode.off => filipino ? 'Naka-off' : 'Off',
        EducatorAlertMode.lockedSteps =>
          filipino ? 'Mga naka-lock na hakbang' : 'Locked steps',
        EducatorAlertMode.everyStep =>
          filipino ? 'Bawat hakbang na may oras' : 'Every step with a time',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const SizedBox.shrink();
    final hc = HCColor.of(context);
    final mode = ref.watch(educatorAlertModeProvider(profile.id));
    final l = filipino;
    return IconButton(
      tooltip: l
          ? 'Mga alerto ng routine: ${modeLabel(mode, filipino: true)}'
          : 'Routine alerts: ${modeLabel(mode, filipino: false)}',
      icon: Icon(
        mode == EducatorAlertMode.off
            ? Icons.notifications_off_rounded
            : Icons.notifications_active_rounded,
        color: mode == EducatorAlertMode.off ? hc.textSecondary : hc.primary,
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _AlertModeSheet(
          educatorProfileId: profile.id,
          filipino: l,
        ),
      ),
    );
  }
}

class _AlertModeSheet extends ConsumerWidget {
  const _AlertModeSheet({
    required this.educatorProfileId,
    required this.filipino,
  });

  final String educatorProfileId;
  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final l = filipino;
    final mode = ref.watch(educatorAlertModeProvider(educatorProfileId));
    final notifier =
        ref.read(educatorAlertModeProvider(educatorProfileId).notifier);
    String detail(EducatorAlertMode m) => switch (m) {
          EducatorAlertMode.off => l
              ? 'Walang alerto sa device na ito.'
              : 'No alerts on this device.',
          EducatorAlertMode.lockedSteps => l
              ? 'Kapag nagsimula at natapos ang isang hakbang na nag-lock sa '
                  'tablet. Iminumungkahi.'
              : 'When a step that locks the tablet starts and when it ends. '
                  'Recommended.',
          EducatorAlertMode.everyStep => l
              ? 'Kapag nagsimula at natapos ang bawat hakbang na may oras.'
              : 'When every step with a time starts and when it ends.',
        };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l ? 'Mga alerto ng routine' : 'Routine alerts',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l
                  ? 'Ipinapadala sa device na ito kapag nagsimula at natapos ang '
                      'hakbang ng inyong mga learner — kasama kapag tinapos o '
                      'pinalaktaw nang maaga.'
                  : 'Sent to this device when your learners’ steps start and '
                      'end — including when one is ended or excused early.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final m in EducatorAlertMode.values)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: m == mode,
                child: ListTile(
                  selected: m == mode,
                  leading: Icon(
                    m == mode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: m == mode ? hc.primary : hc.textSecondary,
                  ),
                  title: Text(
                    EducatorRoutineAlertsButton.modeLabel(m, filipino: l),
                  ),
                  subtitle: Text(detail(m)),
                  onTap: () => unawaited(notifier.choose(m)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
