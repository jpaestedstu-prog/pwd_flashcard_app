import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/device_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Where "9:00" lands when the app schedules a notification.
///
/// Every reminder is a `tz.TZDateTime` in `tz.local`, which the `timezone`
/// package starts on UTC. Nothing moved it, so on a Philippine tablet a 9:00
/// check-in was handed to Android as 9:00 UTC — 17:00 local. `dumpsys alarm`
/// on the Honor showed a 2:40 AM check-in queued for 10:40.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('the device zone id wins when the database knows it', () {
    final location = DeviceTimezone.pickLocation(
      id: 'Asia/Manila',
      offset: const Duration(hours: 8),
    );
    expect(location?.name, 'Asia/Manila');
  });

  test('without an id, the abbreviation picks Manila out of the +08:00 zones',
      () {
    // Several zones sit at +08:00 (Perth, Singapore, Shanghai…). All give the
    // right wall clock, but the named one is the honest answer.
    final location = DeviceTimezone.pickLocation(
      offset: const Duration(hours: 8),
      abbreviation: 'PST',
    );
    expect(location?.name, 'Asia/Manila');
  });

  test('an unknown id still lands on a zone with the right offset', () {
    final location = DeviceTimezone.pickLocation(
      id: 'Not/AZone',
      offset: const Duration(hours: 8),
    );
    expect(location, isNotNull);
    expect(location!.currentTimeZone.offset, const Duration(hours: 8).inMilliseconds);
  });

  test('with the zone set, 9:00 local is 9:00 local — not 9:00 UTC', () {
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    final nine = tz.TZDateTime(tz.local, 2026, 9, 12, 9);
    expect(nine.toUtc().hour, 1, reason: '09:00 +08:00 is 01:00 UTC');

    // The bug, for contrast: on UTC the same call means 17:00 in Manila.
    tz.setLocalLocation(tz.UTC);
    final wrong = tz.TZDateTime(tz.local, 2026, 9, 12, 9);
    expect(
      tz.TZDateTime.from(wrong, tz.getLocation('Asia/Manila')).hour,
      17,
    );
  });

  test('init sets tz.local even without a platform channel', () async {
    // Widget tests have no MainActivity: init must fall back to the offset
    // rather than throw or leave UTC in place on a non-UTC machine.
    tz.setLocalLocation(tz.UTC);
    await DeviceTimezone.init();
    expect(
      tz.local.currentTimeZone.offset,
      DateTime.now().timeZoneOffset.inMilliseconds,
    );
  });
}
