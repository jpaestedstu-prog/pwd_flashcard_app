import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// The last-ten-years database — the one the app already shipped with (it is
// far smaller than the full history, and scheduling only looks forward).
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Points the `timezone` package's `tz.local` at the device's real zone.
///
/// Every scheduled notification in the app — routine reminders, the "Check-in
/// time" prompt, child alarms, the daily study reminder — is built as a
/// `tz.TZDateTime` in `tz.local`. The package initialises `tz.local` to
/// **UTC** and nothing ever changed it, so a step set for 9:00 on a
/// Philippine tablet (UTC+8) was handed to Android as 9:00 UTC — 17:00 local.
/// Found with `dumpsys alarm`: a 2:40 AM check-in queued for 10:40.
///
/// The zone id comes from the platform (`flashlearn/device_timezone` in
/// `MainActivity.kt`). Where that is unavailable (iOS, tests) the zone is
/// chosen by matching the device's current offset and abbreviation, which
/// gives the right wall-clock time for every zone without daylight saving —
/// the Philippines included.
class DeviceTimezone {
  DeviceTimezone._();

  static const MethodChannel _channel = MethodChannel(
    'flashlearn/device_timezone',
  );

  static bool _databaseLoaded = false;
  static bool _idFetched = false;
  static String? _id;

  /// Loads the zone database (once) and sets `tz.local` (every call).
  ///
  /// Deliberately re-applies the local zone each time rather than memoising
  /// the whole call: `tz.initializeTimeZones()` resets `tz.local` to UTC, so
  /// any code path that re-initialises the database after this ran would
  /// quietly undo it. Calling this again is cheap and puts it right.
  static Future<void> init() async {
    if (!_databaseLoaded) {
      tzdata.initializeTimeZones();
      _databaseLoaded = true;
    }
    if (!_idFetched) {
      try {
        _id = await _channel.invokeMethod<String>('getLocalTimezone');
      } catch (_) {
        // No platform side (iOS, widget tests): fall back to the offset.
      }
      _idFetched = true;
    }
    final now = DateTime.now();
    final location = pickLocation(
      id: _id,
      offset: now.timeZoneOffset,
      abbreviation: now.timeZoneName,
    );
    if (location != null) {
      tz.setLocalLocation(location);
      if (kDebugMode) {
        debugPrint('DeviceTimezone: tz.local = ${location.name}');
      }
    }
  }

  /// The zone to use: [id] when the database knows it, otherwise a zone whose
  /// current offset matches [offset] — preferring one whose abbreviation is
  /// [abbreviation], so "+08:00, PST" resolves to Manila rather than to
  /// whichever +08:00 zone the database happens to list first.
  @visibleForTesting
  static tz.Location? pickLocation({
    String? id,
    required Duration offset,
    String? abbreviation,
  }) {
    if (id != null && id.isNotEmpty) {
      try {
        return tz.getLocation(id);
      } catch (_) {
        // Unknown to this database version — fall through to the offset.
      }
    }
    final ms = offset.inMilliseconds;
    tz.Location? firstWithOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final zone = location.currentTimeZone;
      if (zone.offset != ms) continue;
      if (abbreviation != null && zone.abbreviation == abbreviation) {
        return location;
      }
      firstWithOffset ??= location;
    }
    return firstWithOffset;
  }
}
