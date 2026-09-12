import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// How precisely a scheduled notification should fire.
///
/// One helper so the two schedulers that carry time-critical notifications —
/// child alarms ([AlarmScheduler]) and routine reminders / check-ins
/// ([RoutineReminderScheduler]) — can never drift apart again.
///
/// Inexact alarms hand Android a **one-hour window** (`dumpsys alarm`:
/// `window=+1h`). For a study-reminder nudge that is fine; for "time's up" or
/// "please do your check-in now" it is not: an alarm that ends screen time at
/// 8:47 for an 8:00 limit has not enforced anything, and the child was told a
/// different time from the one that arrived.
///
/// Exact is asked for rather than assumed. The app declares `USE_EXACT_ALARM`,
/// but a device or policy can withhold it, and an exact schedule then throws —
/// a late alarm is worth having, a crash is not.
AndroidScheduleMode exactWhenAllowed({required bool canScheduleExact}) =>
    canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
