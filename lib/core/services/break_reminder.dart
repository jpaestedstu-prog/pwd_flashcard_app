import '../../data/models/child_time_limit.dart';

/// "Time for a short break" — a gentle reminder after a stretch of learning,
/// set by the learner's teacher or parent (Time limits → Break reminders).
///
/// A reminder, never a lock: the learner chooses "Take a break" (the app's
/// own break screen) or "Keep learning". Pure and Flutter-free so the rule is
/// unit-tested; `BreakReminderGate` does the showing.
///
/// Counted in **minutes of use** ([usedMinutes] is today's active time, the
/// same figure the daily limit counts), measured from an [anchorMinutes]: the
/// minute count when the learner last had a break — the app opened, the last
/// reminder, their own "I need a break", or a long stay away from the app.
abstract final class BreakReminderEvaluator {
  /// Whether a reminder is due now.
  static bool isDue({
    required ChildTimeLimit? limit,
    required int usedMinutes,
    required int anchorMinutes,
  }) {
    if (limit == null || !limit.breakReminderEnabled) return false;
    if (usedMinutes < anchorMinutes) return false; // a new day: re-anchor
    return usedMinutes - anchorMinutes >= limit.effectiveBreakEveryMinutes;
  }

  /// The anchor to keep: [anchorMinutes], or [usedMinutes] when the count went
  /// backwards (a new day started).
  static int keepAnchor({
    required int usedMinutes,
    required int anchorMinutes,
  }) => usedMinutes < anchorMinutes ? usedMinutes : anchorMinutes;

  /// Minutes of learning time left today, or null when no daily limit is set.
  static int? minutesLeftToday(ChildTimeLimit? limit, int usedMinutes) {
    if (limit == null ||
        !limit.dailyLimitEnabled ||
        limit.dailyLimitMinutes <= 0) {
      return null;
    }
    final left = limit.dailyLimitMinutes - usedMinutes;
    return left < 0 ? 0 : left;
  }

  /// A stay away from the app at least this long counts as a break.
  static const Duration awayCountsAsBreak = Duration(minutes: 5);
}
