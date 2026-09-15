import 'routine_catalog.dart';
import 'routine_day_state.dart';
import 'routine_models.dart';
import 'routine_timeline.dart';

/// Which routine steps a Teacher or Parent is told about on their own device.
///
/// Persisted **by index** — append only.
enum EducatorAlertMode {
  /// No start or end alerts.
  off,

  /// Only the steps that hold a learner's device — the ones an adult may need
  /// to act on. The default: a twelve-step day is twenty-four alerts a
  /// learner, and a teacher with a class would learn to ignore them all.
  lockedSteps,

  /// Every step with a clock time.
  everyStep;

  static EducatorAlertMode fromIndex(Object? raw) =>
      raw is int && raw >= 0 && raw < EducatorAlertMode.values.length
          ? EducatorAlertMode.values[raw]
          : EducatorAlertMode.lockedSteps;
}

enum EducatorStepAlertKind { started, ended, endedEarly }

/// One notification for an educator: a learner's step starting or ending.
class EducatorStepAlert {
  final DateTime at;
  final String learnerId;
  final String stepId;
  final EducatorStepAlertKind kind;
  final String title;
  final String body;

  const EducatorStepAlert({
    required this.at,
    required this.learnerId,
    required this.stepId,
    required this.kind,
    required this.title,
    required this.body,
  });

  /// Identifies this alert across re-plans, so an unchanged plan is not
  /// scheduled twice.
  String get key =>
      '$learnerId|$stepId|${kind.name}|${at.toIso8601String()}|$title|$body';
}

/// What the planner needs about one learner.
class EducatorAlertLearner {
  final String profileId;
  final String name;
  final List<Routine> routines;

  /// Today's joined day, when it has loaded — what says a step was already
  /// finished, excused, paused or given more time. Null plans from the
  /// routines alone.
  final RoutineDayView? today;

  const EducatorAlertLearner({
    required this.profileId,
    required this.name,
    required this.routines,
    this.today,
  });
}

/// Plans the start and end alerts for an educator's learners — pure, so the
/// wording and the timing rules are tested without a notification plugin.
///
/// Free-tier friendly by design: nothing is sent from a server. The alerts
/// are **scheduled on the educator's own device** from the routines it can
/// already read, re-planned whenever a routine or a learner's day changes
/// while the dashboard is open, and cancelled for a step that an adult
/// finished early, excused or paused.
class EducatorStepAlertPlan {
  EducatorStepAlertPlan._();

  /// Most alerts kept pending at once, earliest first.
  static const int maxPending = 40;

  /// How far ahead alerts are scheduled. The dashboard re-plans each time it
  /// opens, so a day ahead covers an educator who checks in daily.
  static const Duration horizon = Duration(hours: 24);

  static List<EducatorStepAlert> plan({
    required List<EducatorAlertLearner> learners,
    required DateTime now,
    required EducatorAlertMode mode,
    required bool filipino,
    Duration within = horizon,
    int cap = maxPending,
  }) {
    if (mode == EducatorAlertMode.off) return const [];
    final until = now.add(within);
    final today = DateTime(now.year, now.month, now.day);
    final out = <EducatorStepAlert>[];

    for (final learner in learners) {
      for (var offset = 0; offset < 2; offset++) {
        final day = today.add(Duration(days: offset));
        final view = offset == 0 ? learner.today : null;
        for (final routine in learner.routines) {
          if (!routine.enabled || !routine.runsOn(day)) continue;
          final locking = {for (final s in routine.lockingSteps) s.id};
          final steps = mode == EducatorAlertMode.lockedSteps
              ? routine.lockingSteps
              : routine.orderedSteps.where((s) => s.isScheduled).toList();
          for (final step in steps) {
            final start = step.startsOn(day);
            final planned = step.endsOn(day);
            if (start == null || planned == null) continue;
            if (view != null && view.isSettled(step.id)) continue;
            final adj = view?.adjustment(step.id);
            final end = adj == null ? planned : planned.add(adj.shiftAt(now));
            final locks = locking.contains(step.id);
            if (start.isAfter(now) && !start.isAfter(until)) {
              out.add(_started(learner, step, start, end, locks, filipino));
            }
            final paused = view?.isPaused(step.id) ?? false;
            if (!paused && end.isAfter(now) && !end.isAfter(until)) {
              out.add(_ended(learner, step, end, locks, filipino));
            }
          }
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.length > cap ? out.sublist(0, cap) : out;
  }

  /// Steps of [learner] whose time is running now and holding nothing back —
  /// started, not ended, not settled, not paused. The dashboard remembers
  /// these between ticks to notice one ending early.
  static Set<String> runningIds(
    EducatorAlertLearner learner,
    DateTime now,
    EducatorAlertMode mode,
  ) {
    final view = learner.today;
    if (mode == EducatorAlertMode.off || view == null) return const {};
    final out = <String>{};
    for (final step in _stepsToday(learner, now, mode)) {
      final start = step.startsOn(now);
      final end = view.endOf(step, now);
      if (start == null || end == null) continue;
      if (now.isBefore(start) || !now.isBefore(end)) continue;
      if (view.isSettled(step.id) || view.isPaused(step.id)) continue;
      out.add(step.id);
    }
    return out;
  }

  /// Alerts for steps that were running ([wasRunning]) and have since been
  /// finished or excused by an adult before their time ended.
  static List<EducatorStepAlert> endedEarly({
    required EducatorAlertLearner learner,
    required Set<String> wasRunning,
    required DateTime now,
    required EducatorAlertMode mode,
    required bool filipino,
  }) {
    final view = learner.today;
    if (view == null || wasRunning.isEmpty) return const [];
    final out = <EducatorStepAlert>[];
    for (final step in _stepsToday(learner, now, mode)) {
      if (!wasRunning.contains(step.id) || !view.isSettled(step.id)) continue;
      final end = view.endOf(step, now);
      if (end == null || !now.isBefore(end)) continue;
      final approval = view.approval(step.id);
      final excuse = view.excuse(step.id);
      final excused = !view.isDone(step.id) && excuse != null;
      final mark = excused ? excuse : approval;
      final by = mark == null || mark.source == RoutineMarkSource.learnerDevice
          ? ''
          : mark.byName;
      out.add(_endedEarly(learner, step, now, by, excused, filipino));
    }
    return out;
  }

  static List<RoutineStep> _stepsToday(
    EducatorAlertLearner learner,
    DateTime now,
    EducatorAlertMode mode,
  ) =>
      [
        for (final r in learner.routines)
          if (r.enabled && r.runsOn(now))
            ...(mode == EducatorAlertMode.lockedSteps
                ? r.lockingSteps
                : r.orderedSteps.where((s) => s.isScheduled)),
      ];

  static EducatorStepAlert _started(
    EducatorAlertLearner learner,
    RoutineStep step,
    DateTime start,
    DateTime end,
    bool locks,
    bool l,
  ) {
    final name = learner.name;
    final title = RoutineCatalog.titleFor(step, filipino: l);
    final until = formatClockOf(end);
    return EducatorStepAlert(
      at: start,
      learnerId: learner.profileId,
      stepId: step.id,
      kind: EducatorStepAlertKind.started,
      title: locks ? '🔒 $name: $title' : '⏰ $name: $title',
      body: locks
          ? (l
              ? 'Naka-lock ang tablet ni $name sa $title hanggang $until.'
              : '$name’s tablet is locked on $title until $until.')
          : (l
              ? 'Nagsimula ang $title para kay $name. Magtatapos sa $until.'
              : '$title has started for $name. It ends at $until.'),
    );
  }

  static EducatorStepAlert _ended(
    EducatorAlertLearner learner,
    RoutineStep step,
    DateTime end,
    bool locks,
    bool l,
  ) {
    final name = learner.name;
    final title = RoutineCatalog.titleFor(step, filipino: l);
    return EducatorStepAlert(
      at: end,
      learnerId: learner.profileId,
      stepId: step.id,
      kind: EducatorStepAlertKind.ended,
      title: l ? '✅ $name: tapos ang $title' : '✅ $name: $title is over',
      body: locks
          ? (l
              ? 'Naka-unlock na ang tablet ni $name.'
              : '$name’s tablet is unlocked.')
          : (l ? 'Tapos ang $title para kay $name.' : '$title is over for $name.'),
    );
  }

  static EducatorStepAlert _endedEarly(
    EducatorAlertLearner learner,
    RoutineStep step,
    DateTime at,
    String by,
    bool excused,
    bool l,
  ) {
    final name = learner.name;
    final title = RoutineCatalog.titleFor(step, filipino: l);
    final time = formatClockOf(at);
    final String body;
    if (excused) {
      body = by.isEmpty
          ? (l
              ? 'Pinalaktaw sa tablet ng isang nakatatanda sa $time.'
              : 'An adult excused it on the tablet at $time.')
          : (l ? 'Pinalaktaw ni $by sa $time.' : '$by excused it at $time.');
    } else {
      body = by.isEmpty
          ? (l
              ? 'Tinapos sa tablet ng isang nakatatanda sa $time.'
              : 'An adult ended it on the tablet at $time.')
          : (l ? 'Tinapos ni $by sa $time.' : '$by ended it at $time.');
    }
    return EducatorStepAlert(
      at: at,
      learnerId: learner.profileId,
      stepId: step.id,
      kind: EducatorStepAlertKind.endedEarly,
      title: excused
          ? (l ? '✅ $name: pinalaktaw ang $title' : '✅ $name: $title excused')
          : (l
              ? '✅ $name: tinapos nang maaga ang $title'
              : '✅ $name: $title ended early'),
      body: body,
    );
  }
}
