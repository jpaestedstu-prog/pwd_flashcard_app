import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/notification_schedule_mode.dart';

/// How precisely the app's time-critical notifications are scheduled.
///
/// Both schedulers that carry them — child alarms and routine reminders /
/// check-ins — go through this one decision, so "the alarm fires at the time
/// it says" cannot be true of one and false of the other.
///
/// The failure this guards against was measured on the tablet: an inexact
/// alarm is registered with `window=+1h`, so an 8:00 screen-time limit could
/// end the session any time up to 9:00.
void main() {
  test('exact when the OS allows it', () {
    expect(
      exactWhenAllowed(canScheduleExact: true),
      AndroidScheduleMode.exactAllowWhileIdle,
    );
  });

  test('inexact — never a throw — when it does not', () {
    // A device or policy can withhold exact alarms. Scheduling exactly anyway
    // throws, and an alarm that arrives late beats one that never arrives.
    expect(
      exactWhenAllowed(canScheduleExact: false),
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  test('both modes still fire while the device is idle', () {
    // `allowWhileIdle` is the half that survives Doze. Losing it would mean a
    // tablet left alone overnight simply never rings.
    for (final mode in [
      exactWhenAllowed(canScheduleExact: true),
      exactWhenAllowed(canScheduleExact: false),
    ]) {
      expect(mode.name, contains('AllowWhileIdle'));
    }
  });
}
