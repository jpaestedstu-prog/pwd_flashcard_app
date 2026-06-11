/// Pure, dependency-free streak math.
///
/// Streaks are measured in **local calendar days**, not 24-hour windows.
/// The old logic used `now.difference(last).inDays`, which counts whole
/// 24h periods — so playing at 23:00 and again at 08:00 the next morning
/// yielded a delta of 0 and the streak never advanced. Comparing
/// date-only values (`DateTime(y, m, d)`, which is local by construction)
/// fixes that and matches how a learner experiences a "day".
///
/// All functions take `now` as a parameter so they can be unit-tested
/// without mocking the clock.
class StreakService {
  const StreakService._();

  /// Local midnight for [dt] (drops the time-of-day component).
  static DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Whole calendar days between [last] and [now] (can be negative if the
  /// device clock moved backwards).
  static int dayDelta(DateTime last, DateTime now) =>
      _dayStart(now).difference(_dayStart(last)).inDays;

  /// True when [last] falls on the same calendar day as [now].
  static bool isActiveToday(DateTime last, {DateTime? now}) =>
      dayDelta(last, now ?? DateTime.now()) == 0;

  /// Computes the streak value after a learning activity at [now].
  ///
  /// - first-ever / migrated-from-zero → 1
  /// - same calendar day               → unchanged (already counted)
  /// - exactly the next day            → +1
  /// - a gap of >1 day, or clock skew  → reset to 1
  static int nextStreak({
    required int prevStreak,
    required DateTime lastActivity,
    required DateTime now,
  }) {
    final delta = dayDelta(lastActivity, now);
    if (prevStreak <= 0) return 1; // first-ever / migrated
    if (delta == 0) return prevStreak; // already counted today
    if (delta == 1) return prevStreak + 1; // consecutive day
    return 1; // gap or clock skew → reset
  }
}
