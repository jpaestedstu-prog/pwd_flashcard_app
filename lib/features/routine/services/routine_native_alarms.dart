import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'routine_reminder_scheduler.dart' show RoutineReminder;

/// A tap on a routine notification, or a lock launch, as the native side
/// reports it.
class RoutineLaunch {
  final String routineId;
  final String stepId;

  /// The profile the reminder was scheduled for.
  final String profileId;

  /// True when Android opened FlashLearn for a locking step (full-screen
  /// intent, or the awake-tablet takeover), not a plain tap.
  final bool isLock;

  const RoutineLaunch({
    required this.routineId,
    required this.stepId,
    required this.profileId,
    required this.isLock,
  });

  /// Parses the channel map; null for anything malformed.
  static RoutineLaunch? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final payload = raw['payload'];
    if (payload is! String) return null;
    final parts = payload.split('|');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return RoutineLaunch(
      routineId: parts[0],
      stepId: parts[1],
      profileId: (raw['profile'] as String?) ?? '',
      isLock: raw['lock'] == true,
    );
  }
}

/// Dart side of `RoutineAlarms.kt` — Android's own scheduler for routine
/// reminders and locks.
///
/// flutter_local_notifications cannot skip one day of a repeating reminder
/// (it recomputes a repeat's first date from now), cannot open the lock over
/// another app, and cannot tell a delivery after a clock jump from a real one.
/// The native side does all three; Dart hands it the plan and today's settled
/// steps. Every call is best-effort and a no-op off Android, in tests and in
/// the web build.
class RoutineNativeAlarms {
  RoutineNativeAlarms._();

  static const _channel = MethodChannel('flashlearn/routine_alarms');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The plan as the native side stores it — pure, so it is tested.
  static String planJson(List<RoutineReminder> plan) => jsonEncode([
        for (final r in plan)
          {
            'id': r.notificationId,
            'routineId': r.routineId,
            'stepId': r.stepId,
            'title': r.title,
            'body': r.body,
            'hour': r.hour,
            'minute': r.minute,
            'weekday': r.isoWeekday ?? 0,
            'locks': r.locksScreen,
          },
      ]);

  /// `yyyy-MM-dd` in local time, the day the native side compares against.
  static String dayStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<bool> apply(
    List<RoutineReminder> plan, {
    required bool silent,
    required String profileId,
  }) async =>
      await _call<bool>('apply', {
        'plan': planJson(plan),
        'silent': silent,
        'profile': profileId,
      }) ??
      false;

  static Future<void> cancelAll() => _call<bool>('cancelAll');

  static Future<void> setSettled(DateTime day, Set<String> stepIds) =>
      _call<bool>('setSettled', {
        'day': dayStamp(day),
        'ids': stepIds.toList(),
      });

  /// Whether "Display over other apps" is granted on this device.
  static Future<bool> canDrawOverlays() async =>
      await _call<bool>('canDrawOverlays') ?? false;

  /// Opens Android's "Display over other apps" page for FlashLearn.
  static Future<void> openOverlaySettings() => _call<bool>('openOverlaySettings');

  /// Lets the lock show over the tablet's own lock screen — only while the
  /// routine lock is on screen, never for the rest of the app.
  static Future<void> setShowWhenLocked(bool on) =>
      _call<bool>('setShowWhenLocked', {'on': on});

  static RoutineLaunch? _launch;
  static bool _fetched = false;

  /// The notification or lock launch that started the app — fetched from
  /// Android once and kept until [consumeLaunch], so the splash screen can
  /// look at it before a profile is signed in.
  static Future<RoutineLaunch?> peekLaunch() async {
    if (!_fetched) {
      _fetched = true;
      _launch = RoutineLaunch.tryParse(await _call<Object>('takeLaunch'));
    }
    return _launch;
  }

  /// Hands over the starting launch once.
  static Future<RoutineLaunch?> consumeLaunch() async {
    final launch = await peekLaunch();
    _launch = null;
    return launch;
  }

  /// Delivers taps and lock launches while the app is running.
  static void listen(void Function(RoutineLaunch launch) onLaunch) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLaunch') return null;
      final launch = RoutineLaunch.tryParse(call.arguments);
      if (launch != null) onLaunch(launch);
      return null;
    });
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('RoutineNativeAlarms $method failed: $e');
      return null;
    }
  }
}
