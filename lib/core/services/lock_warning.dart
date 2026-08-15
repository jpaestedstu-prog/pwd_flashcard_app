import '../../data/models/alarm_action.dart';
import '../../data/models/child_alarm.dart';
import '../../data/models/child_time_limit.dart';
import 'lock_enforcer.dart';

/// Why the child is about to be locked out.
enum LockWarningCause {
  /// The daily minute budget is nearly spent.
  dailyLimit,

  /// The allowed time-of-day window is nearly over.
  schedule,

  /// A lock-screen alarm is about to fire.
  alarm,
}

/// "Nearly time" notice, raised before [LockEnforcer] would lock.
///
/// The lock arriving unannounced is the single most distressing part of a
/// hard cut-off: a learner loses whatever they were part-way through and
/// has no chance to finish or hand over calmly. This gives them notice in
/// the same channels the lock itself uses.
class LockWarning {
  /// Whole minutes remaining, rounded up and never below 1 — a warning
  /// that says "0 minutes left" is just a confusing lock screen.
  final int minutesLeft;

  final LockWarningCause cause;

  const LockWarning({required this.minutesLeft, required this.cause});

  /// Identity of the *lock event* this warning is about.
  ///
  /// Used to show the warning once per approaching lock rather than once
  /// per evaluation tick. Deliberately excludes [minutesLeft]: 5-minutes-left
  /// and 4-minutes-left are the same event, so the second must not re-fire.
  String get eventKey => cause.name;

  /// Headline, e.g. "5 minutes left".
  String get title =>
      minutesLeft == 1 ? '1 minute left' : '$minutesLeft minutes left';

  /// Plain-language explanation of what happens next. [address] is the
  /// resolved guardian name (see `GuardianAddress`).
  String body(String address) => switch (cause) {
    LockWarningCause.dailyLimit =>
      'Then it will be time to give the device to $address.',
    LockWarningCause.schedule =>
      'Then study time is over and the device goes to $address.',
    LockWarningCause.alarm =>
      'Then it will be time to give the device to $address.',
  };

  /// One short sentence for cognitive / multiple-disability profiles.
  String bodySimple(String address) => 'Then give the device to $address.';

  /// Filipino counterpart of [body].
  String bodyFilipino(String address) =>
      'Pagkatapos, ibigay ang device kay $address.';

  @override
  bool operator ==(Object other) =>
      other is LockWarning &&
      other.minutesLeft == minutesLeft &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(minutesLeft, cause);
}

/// Pure "is a lock coming soon?" evaluator.
///
/// Mirrors [LockEnforcer.evaluate] in shape and precedence so the warning
/// always describes the same rule that will actually do the locking. Kept
/// free of Flutter and Firebase so the whole matrix is unit-testable.
class LockWarningEvaluator {
  const LockWarningEvaluator._();

  /// Returns the warning that applies right now, or null.
  ///
  /// Null when: the learner is already locked (the lock screen supersedes
  /// any warning), the educator turned warnings off, no rule is close
  /// enough, or no rule is enabled at all.
  ///
  /// Precedence matches [LockEnforcer.evaluate] — alarm, then daily limit,
  /// then schedule — so a learner who is close to two cut-offs at once is
  /// warned about the one that will actually fire first.
  static LockWarning? evaluate({
    required ChildTimeLimit? limit,
    required int minutesUsedToday,
    required List<ChildAlarm> alarms,
    required DateTime now,
  }) {
    if (limit == null || !limit.warningEnabled) return null;

    // Already locked → the lock screen is the message. Guard against
    // stacking a "5 minutes left" banner on top of "Time's up".
    final locked = LockEnforcer.evaluate(
      limit: limit,
      minutesUsedToday: minutesUsedToday,
      alarms: alarms,
      now: now,
    );
    if (locked != null) return null;

    final lead = limit.effectiveWarningMinutes;

    // 1. Alarm about to fire.
    int? soonestAlarm;
    for (final a in alarms) {
      if (!a.enabled) continue;
      if (a.action != AlarmAction.lockScreen) continue;
      final next = _minutesUntilNextFire(a, now);
      if (next == null || next > lead) continue;
      if (soonestAlarm == null || next < soonestAlarm) soonestAlarm = next;
    }
    if (soonestAlarm != null) {
      return LockWarning(
        minutesLeft: _atLeastOne(soonestAlarm),
        cause: LockWarningCause.alarm,
      );
    }

    // 2. Daily budget nearly spent.
    if (limit.dailyLimitEnabled && limit.dailyLimitMinutes > 0) {
      final remaining = limit.dailyLimitMinutes - minutesUsedToday;
      if (remaining > 0 && remaining <= lead) {
        return LockWarning(
          minutesLeft: _atLeastOne(remaining),
          cause: LockWarningCause.dailyLimit,
        );
      }
    }

    // 3. Allowed window about to close.
    if (limit.scheduleEnabled) {
      final today = now.weekday;
      final restrictsToday =
          limit.allowedDays.isEmpty || limit.allowedDays.contains(today);
      if (restrictsToday) {
        final untilClose = _minutesUntilHour(now, limit.allowedEndHour);
        if (untilClose > 0 && untilClose <= lead) {
          return LockWarning(
            minutesLeft: _atLeastOne(untilClose),
            cause: LockWarningCause.schedule,
          );
        }
      }
    }

    return null;
  }

  static int _atLeastOne(int minutes) => minutes < 1 ? 1 : minutes;

  /// Minutes from [now] until the next time `hour:00` comes around,
  /// wrapping to tomorrow when the hour has already passed today.
  static int _minutesUntilHour(DateTime now, int hour) {
    var target = DateTime(now.year, now.month, now.day, hour);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now).inMinutes;
  }

  /// Minutes until [alarm] next fires, or null if it never fires within a
  /// week (an alarm whose weekday set somehow excludes every day).
  ///
  /// Walks forward day by day the way [LockEnforcer] walks backwards, so
  /// the two agree about which days an alarm is active on.
  static int? _minutesUntilNextFire(ChildAlarm alarm, DateTime now) {
    var cursor = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );
    if (!cursor.isAfter(now)) {
      cursor = cursor.add(const Duration(days: 1));
    }
    for (var i = 0; i < 7; i++) {
      if (alarm.firesOn(cursor.weekday)) {
        return cursor.difference(now).inMinutes;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }
}
