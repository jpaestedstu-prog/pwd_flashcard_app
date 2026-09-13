import '../../data/models/alarm_action.dart';
import '../../data/models/child_alarm.dart';
import '../../data/models/child_time_limit.dart';
import '../../features/routine/models/routine_models.dart';

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

/// A "My Day" step whose time has arrived and which is not done yet.
///
/// The one lock a learner can clear by themselves: doing the thing it names
/// unlocks it. Every other [LockReason] means "stop and hand the device over";
/// this one means "do this first". The lock screen (`RoutineLockScreen`) shows
/// the step, ticks it off when the learner says they did it, and then asks how
/// they feel about it.
///
/// Only ever raised for a Student or a Child, and only for a routine a Teacher
/// or Parent explicitly switched to locking — see [Routine.lockEnabled].
///
/// [title] and [subtitle] are the untranslated fallbacks; the lock screen
/// itself renders the step through `RoutineCatalog`, so a Filipino learner
/// reads their own words.
class RoutineStepDue extends LockReason {
  final RoutineStep step;

  const RoutineStepDue(this.step);

  @override
  String get title => step.title.isEmpty ? 'Routine time' : step.title;

  @override
  String get subtitle => 'Finish this to carry on.';
}

/// How long after its time a routine step still holds the device.
///
/// The same hour [RoutinePopupSchedule.taskFreshness] gives the pop-up, and
/// for the same reason: a step whose moment has long passed is not a lock, it
/// is an obstacle. A missed step stays missed and stays tickable in "My Day" —
/// it just stops standing in the way. Without a window, a device switched off
/// over the weekend would come back locked to Saturday breakfast.
const Duration kRoutineLockWindow = Duration(hours: 1);

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
  /// daily-time-limit (cumulative) → schedule (time of day) → routine step
  /// due. The first matching reason wins; ties broken by this order so a user
  /// can always see the most actionable message ("alarm just fired" beats
  /// "you've gone over the limit").
  ///
  /// The routine comes last on purpose. The three above it all mean "stop
  /// using the device"; telling a child to go and brush their teeth *in the
  /// app* when their screen time is over would be asking them to do the one
  /// thing they have just been told not to.
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
    List<RoutineStep> routineSteps = const <RoutineStep>[],
    Set<String> completedStepIds = const <String>{},
    Set<String> skippedStepIds = const <String>{},
    Duration routineLockWindow = kRoutineLockWindow,
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

    // 4. "My Day" step due.
    final step = routineStepDue(
      steps: routineSteps,
      completedStepIds: completedStepIds,
      skippedStepIds: skippedStepIds,
      now: now,
      window: routineLockWindow,
    );
    if (step != null) return RoutineStepDue(step);

    return null;
  }

  /// The routine step that should be holding the device right now, or null.
  ///
  /// A step qualifies when its clock time has arrived, that time is no more
  /// than [window] ago, it has not been ticked off, and an adult has not
  /// waved it through for today. With several overdue at once — the tablet was
  /// off all morning — the **earliest** wins, so the day is worked through in
  /// the order it was planned rather than backwards.
  ///
  /// [steps] must already be filtered to the ones that may lock (see
  /// [Routine.lockingSteps]); this function does not re-check the routine's
  /// own switch, because it never sees the routine.
  static RoutineStep? routineStepDue({
    required List<RoutineStep> steps,
    required Set<String> completedStepIds,
    required Set<String> skippedStepIds,
    required DateTime now,
    Duration window = kRoutineLockWindow,
  }) {
    RoutineStep? earliest;
    for (final s in steps) {
      if (!s.isScheduled) continue;
      if (completedStepIds.contains(s.id)) continue;
      if (skippedStepIds.contains(s.id)) continue;
      final dueAt = DateTime(now.year, now.month, now.day, s.hour!, s.minute!);
      if (now.isBefore(dueAt)) continue;
      if (now.difference(dueAt) > window) continue;
      if (earliest == null || s.minutesOfDay! < earliest.minutesOfDay!) {
        earliest = s;
      }
    }
    return earliest;
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
