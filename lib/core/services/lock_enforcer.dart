import '../../data/models/alarm_action.dart';
import '../../data/models/child_alarm.dart';
import '../../data/models/child_time_limit.dart';

/// Why the child's screen is currently locked.
///
/// Sealed-style hierarchy: each subclass carries the data the lock
/// screen needs to render its message. `null` means "not locked" and
/// is the common case — keep evaluation cheap so we can call it from
/// the router redirect.
sealed class LockReason {
  const LockReason();

  /// User-facing label shown on the lock screen.
  String get title;

  /// Optional subtitle (e.g. "set by your teacher").
  String? get subtitle => null;
}

class TimeLimitReached extends LockReason {
  final int dailyLimitMinutes;
  final int minutesUsed;

  const TimeLimitReached({
    required this.dailyLimitMinutes,
    required this.minutesUsed,
  });

  @override
  String get title => 'Time\'s up for today';

  @override
  String get subtitle =>
      'You\'ve used $minutesUsed of $dailyLimitMinutes minutes.';
}

class OutsideSchedule extends LockReason {
  final int allowedStartHour;
  final int allowedEndHour;

  const OutsideSchedule({
    required this.allowedStartHour,
    required this.allowedEndHour,
  });

  @override
  String get title => 'Outside study hours';

  @override
  String get subtitle =>
      'Allowed: ${_fmt(allowedStartHour)} – ${_fmt(allowedEndHour)}.';

  static String _fmt(int h) => '${h.toString().padLeft(2, "0")}:00';
}

class AlarmTriggered extends LockReason {
  final ChildAlarm alarm;

  const AlarmTriggered(this.alarm);

  @override
  String get title => alarm.label.isEmpty ? 'Alarm' : alarm.label;

  @override
  String get subtitle => 'Time to take a break.';
}

/// Pure-function evaluator: given the child's policy, current minutes
/// used, list of alarms, and `now`, returns a [LockReason] or null.
///
/// Designed to be unit-testable without any Flutter or Firebase deps.
/// Called by:
///   • The router redirect (every navigation).
///   • The active-time tick (every minute).
///   • The alarm-tap handler (when an alarm fires).
class LockEnforcer {
  const LockEnforcer._();

  /// `null` means "not locked".
  ///
  /// Order of checks: alarm-triggered (explicit user-set events) →
  /// daily-time-limit (cumulative) → schedule (time of day). The first
  /// matching reason wins; ties broken by this order so a user can
  /// always see the most actionable message ("alarm just fired" beats
  /// "you've gone over the limit").
  ///
  /// [recentAlarmFireWindow] caps how far back an alarm whose fire-time
  /// has just elapsed can be treated as "currently locking". Defaults
  /// to 5 minutes — long enough that an alarm fired during a backgrounded
  /// app still triggers the lock when the user resumes, short enough
  /// that an old-but-passed alarm doesn't sneakily relock.
  static LockReason? evaluate({
    required ChildTimeLimit? limit,
    required int minutesUsedToday,
    required List<ChildAlarm> alarms,
    required DateTime now,
    Duration recentAlarmFireWindow = const Duration(minutes: 5),
  }) {
    // 1. Alarm-triggered. We treat any enabled `lockScreen` alarm whose
    //    most-recent fire was within [recentAlarmFireWindow] as locking.
    for (final a in alarms) {
      if (!a.enabled) continue;
      if (a.action != AlarmAction.lockScreen) continue;
      final lastFire = _mostRecentFire(a, now);
      if (lastFire == null) continue;
      final delta = now.difference(lastFire);
      if (delta >= Duration.zero && delta <= recentAlarmFireWindow) {
        return AlarmTriggered(a);
      }
    }

    // 2. Daily time limit.
    if (limit != null &&
        limit.dailyLimitEnabled &&
        limit.dailyLimitMinutes > 0 &&
        minutesUsedToday >= limit.dailyLimitMinutes) {
      return TimeLimitReached(
        dailyLimitMinutes: limit.dailyLimitMinutes,
        minutesUsed: minutesUsedToday,
      );
    }

    // 3. Schedule (time of day).
    if (limit != null && limit.scheduleEnabled) {
      // Day-of-week filter — when [allowedDays] is empty, the schedule
      // applies every day; otherwise it only applies on listed days.
      final today = now.weekday;
      final restrictsToday =
          limit.allowedDays.isEmpty || limit.allowedDays.contains(today);
      if (restrictsToday &&
          !_withinSchedule(
            now.hour,
            limit.allowedStartHour,
            limit.allowedEndHour,
          )) {
        return OutsideSchedule(
          allowedStartHour: limit.allowedStartHour,
          allowedEndHour: limit.allowedEndHour,
        );
      }
    }

    return null;
  }

  /// True if [hour] falls inside `[start, end)`. Wraps around midnight
  /// when `end <= start` (e.g. start=22, end=6 means "10 PM through
  /// 6 AM"). Mirrors the legacy `ParentalControls.isWithinSchedule`.
  static bool _withinSchedule(int hour, int start, int end) {
    if (start == end) return true; // Effectively "no restriction"
    if (start < end) {
      return hour >= start && hour < end;
    }
    // Wraps around midnight
    return hour >= start || hour < end;
  }

  /// Most recent moment in the past when [alarm] fired, or null if the
  /// alarm has never matched [now]'s allowed-day set yet.
  ///
  /// Pulls today's hour:minute first, then walks backwards by day until
  /// it hits a [ChildAlarm.firesOn] match. Limits to 7 lookbacks since
  /// alarms are weekly — a "recent" fire is by definition within 7 days.
  static DateTime? _mostRecentFire(ChildAlarm alarm, DateTime now) {
    var cursor = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
    if (cursor.isAfter(now)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    for (var i = 0; i < 7; i++) {
      if (alarm.firesOn(cursor.weekday)) return cursor;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return null;
  }
}
