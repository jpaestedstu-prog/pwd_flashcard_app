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

  /// Its time had started and an adult paused it: the clock is stopped and
  /// the lock is lifted until they resume it.
  paused,
}

/// [step]'s moment at [now], given whether the day log counts it [done],
/// whether an adult [excused] it, and whether an adult [paused] it.
///
/// [endsAt] is the step's end as it actually stands today — later than its
/// planned end when an adult added time or paused it. Null means the planned
/// end.
RoutineStepMoment routineStepMoment(
  RoutineStep step, {
  required DateTime now,
  required bool done,
  required bool excused,
  DateTime? endsAt,
  bool paused = false,
}) {
  if (done) return RoutineStepMoment.earlier;
  if (excused) return RoutineStepMoment.excused;
  final start = step.startsOn(now);
  final end = endsAt ?? step.endsOn(now);
  if (start == null || end == null) return RoutineStepMoment.anyTime;
  if (now.isBefore(start)) return RoutineStepMoment.upcoming;
  if (paused) return RoutineStepMoment.paused;
  if (now.isBefore(end)) return RoutineStepMoment.now;
  return RoutineStepMoment.earlier;
}

/// `7:40 AM`, without a locale-aware formatter.
String formatClockOf(DateTime t) {
  final h = t.hour;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${t.minute.toString().padLeft(2, '0')} $suffix';
}

/// `7:40 PM` — when [step]'s time ends — or empty for an unscheduled step.
///
/// [end] is the end as it stands today when an adult changed it; null means
/// the planned end.
String formatStepEnd(RoutineStep step, {DateTime? end}) {
  final at = end ?? step.endsOn(DateTime(2000));
  if (at == null) return '';
  return formatClockOf(at);
}

/// Whole minutes from [now] until [end], rounded up; zero once it has passed.
int minutesUntilEnd(DateTime end, DateTime now) {
  final d = end.difference(now);
  if (d <= Duration.zero) return 0;
  return (d.inSeconds / 60).ceil();
}

/// The short label a card shows for [moment]: "Now · until 7:40 PM",
/// "Earlier today", "Not today", "Paused" — or empty where the step's own
/// time already says everything (upcoming, any time).
String routineMomentLabel(
  RoutineStep step,
  RoutineStepMoment moment, {
  required bool filipino,
  DateTime? endsAt,
}) {
  final until = formatStepEnd(step, end: endsAt);
  return switch (moment) {
    RoutineStepMoment.now =>
      filipino ? 'Ngayon · hanggang $until' : 'Now · until $until',
    RoutineStepMoment.earlier => filipino ? 'Kanina' : 'Earlier today',
    RoutineStepMoment.excused => filipino ? 'Hindi ngayon' : 'Not today',
    RoutineStepMoment.paused => filipino ? 'Nakahinto' : 'Paused',
    RoutineStepMoment.upcoming || RoutineStepMoment.anyTime => '',
  };
}

/// The same moment as a screen reader says it: "happening now, until 7:40 PM".
String routineMomentSpoken(
  RoutineStep step,
  RoutineStepMoment moment, {
  required bool filipino,
  DateTime? endsAt,
}) {
  final until = formatStepEnd(step, end: endsAt);
  return switch (moment) {
    RoutineStepMoment.now => filipino
        ? 'ngayon, hanggang $until'
        : 'happening now, until $until',
    RoutineStepMoment.earlier => filipino ? 'kanina' : 'earlier today',
    RoutineStepMoment.excused => filipino ? 'hindi ngayon' : 'not today',
    RoutineStepMoment.upcoming => filipino ? 'mamaya' : 'coming up',
    RoutineStepMoment.paused =>
      filipino ? 'nakahinto sandali' : 'paused for now',
    RoutineStepMoment.anyTime => '',
  };
}
