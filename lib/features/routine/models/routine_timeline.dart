import 'routine_models.dart';

/// Where one step of a learner's day stands on the clock.
///
/// A Student's or Child's day runs on the clock rather than on their own
/// ticks: a step starts at its time, is finished when its time ends, and only
/// an adult can finish it early or excuse it. This is the one place that turns
/// "a step, the time, and what the day log says" into the words every learner
/// surface shows — so My Day, the step screen and the Home card can never
/// disagree about whether Brushing Teeth is on right now.
enum RoutineStepMoment {
  /// A scheduled step whose time has not started yet.
  upcoming,

  /// Its time is running now.
  now,

  /// Its time is over, or an adult finished it early.
  earlier,

  /// An adult excused it for today.
  excused,

  /// No clock time — sequenced, not scheduled.
  anyTime,
}

/// [step]'s moment at [now], given whether the day log counts it [done] and
/// whether an adult [excused] it.
RoutineStepMoment routineStepMoment(
  RoutineStep step, {
  required DateTime now,
  required bool done,
  required bool excused,
}) {
  if (done) return RoutineStepMoment.earlier;
  if (excused) return RoutineStepMoment.excused;
  final start = step.startsOn(now);
  final end = step.endsOn(now);
  if (start == null || end == null) return RoutineStepMoment.anyTime;
  if (now.isBefore(start)) return RoutineStepMoment.upcoming;
  if (now.isBefore(end)) return RoutineStepMoment.now;
  return RoutineStepMoment.earlier;
}

/// `7:40 PM` — when [step]'s time ends — or empty for an unscheduled step.
String formatStepEnd(RoutineStep step) {
  final end = step.endsOn(DateTime(2000));
  if (end == null) return '';
  final h = end.hour;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${end.minute.toString().padLeft(2, '0')} $suffix';
}

/// The short label a card shows for [moment]: "Now · until 7:40 PM",
/// "Earlier today", "Not today" — or empty where the step's own time already
/// says everything (upcoming, any time).
String routineMomentLabel(
  RoutineStep step,
  RoutineStepMoment moment, {
  required bool filipino,
}) {
  return switch (moment) {
    RoutineStepMoment.now => filipino
        ? 'Ngayon · hanggang ${formatStepEnd(step)}'
        : 'Now · until ${formatStepEnd(step)}',
    RoutineStepMoment.earlier => filipino ? 'Kanina' : 'Earlier today',
    RoutineStepMoment.excused => filipino ? 'Hindi ngayon' : 'Not today',
    RoutineStepMoment.upcoming || RoutineStepMoment.anyTime => '',
  };
}

/// The same moment as a screen reader says it: "happening now, until 7:40 PM".
String routineMomentSpoken(
  RoutineStep step,
  RoutineStepMoment moment, {
  required bool filipino,
}) {
  return switch (moment) {
    RoutineStepMoment.now => filipino
        ? 'ngayon, hanggang ${formatStepEnd(step)}'
        : 'happening now, until ${formatStepEnd(step)}',
    RoutineStepMoment.earlier => filipino ? 'kanina' : 'earlier today',
    RoutineStepMoment.excused => filipino ? 'hindi ngayon' : 'not today',
    RoutineStepMoment.upcoming => filipino ? 'mamaya' : 'coming up',
    RoutineStepMoment.anyTime => '',
  };
}
