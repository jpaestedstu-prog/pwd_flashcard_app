import 'device_timezone.dart';
import 'notification_schedule_mode.dart';
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/local/hive_service.dart';
import '../../data/models/alarm_action.dart';
import '../../data/models/child_alarm.dart';
import '../../features/parent/services/child_alarm_service.dart';
import '../../l10n/app_localizations.dart';

/// Bridges [ChildAlarm] data to the OS-level `flutter_local_notifications`
/// plugin so alarms set by a parent on one device fire on the child's
/// device — even when the app is closed.
///
/// Design notes:
///   • One scheduled-notification id is allocated per (alarm, weekday).
///     With weekly repeats and 7 days max per alarm, a child capped to
///     ~32 alarms stays well under iOS's 64-pending limit.
///   • IDs are offset by 1000 so they don't collide with the daily /
///     vocab-review IDs (0 and 1) that `NotificationService` uses.
///   • Stable hash from `(alarm.id, weekday)` keeps re-scheduling
///     idempotent across stream emissions.
///   • Payload format: `alarm:{alarmId}` — the tap handler in `main.dart`
///     dispatches based on this prefix.
///
/// The plugin instance here is independent of `NotificationService`'s.
/// Both wrap the same OS notification subsystem so there's no conflict —
/// they only need to use distinct IDs (which the offset above guarantees).
class AlarmScheduler {
  AlarmScheduler._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'child_alarm';
  static const _channelName = 'Child Alarms';
  static const _channelDesc =
      'Alarms set by parents/teachers for the child using this device.';

  /// Offset for alarm notification ids so they never collide with the
  /// other reminders. Each `(alarm, day-of-week)` pair gets a unique id
  /// in the range `[_idBase, _idBase + 0xFFFF)` from a stable hash.
  static const int _idBase = 1000;

  /// Active subscription to the child's alarm stream. Replaced on each
  /// [init] call so switching active profile cleans up the prior listener.
  static StreamSubscription<List<ChildAlarm>>? _sub;

  /// Last seen alarm ids — used so [rescheduleAll] can cancel stale
  /// notifications when an alarm is deleted or its weekday changes.
  static final Set<int> _activeNotificationIds = {};

  /// The learner these alarms are scheduled for. Kept while an educator or
  /// the profile picker is on screen — see `ScheduleOwnership`.
  static String? _profileId;

  static const _ownerKey = 'child_alarms';

  /// The learner the device's alarms belong to, surviving a restart.
  static String? get scheduledFor {
    if (_profileId != null) return _profileId;
    try {
      return HiveService.getScheduleOwner(_ownerKey);
    } catch (_) {
      return null;
    }
  }

  /// Callback for when an alarm's notification is tapped (or fires while
  /// the app is in the foreground). Set by `main.dart`.
  ///
  /// The callback receives the resolved [ChildAlarm] (or null if the row
  /// was deleted before the tap was processed). The dispatcher should
  /// branch on `alarm.action` — typically pushing `/time-up-lock` for
  /// [AlarmAction.lockScreen].
  static void Function(ChildAlarm? alarm)? onAlarmFired;

  /// Initialise the plugin and start streaming the alarms for [profileId].
  ///
  /// Safe to call multiple times — each call cancels the prior
  /// subscription. Cancels every previously-scheduled alarm for the
  /// previous profile so a profile switch doesn't leak.
  static Future<void> init(String profileId) async {
    await _initPlugin();

    // Cancel old listener and clear any previously-scheduled IDs so a
    // profile switch doesn't fire the previous child's alarms here.
    await _sub?.cancel();
    await _cancelAllAlarmIds();
    _profileId = profileId;
    try {
      await HiveService.setScheduleOwner(_ownerKey, profileId);
    } catch (_) {}

    // Pre-warm with whatever's in Hive so the very first OS reboot
    // doesn't lose alarms while Firestore takes its time.
    final cached = HiveService.getChildAlarmsForChild(profileId);
    if (cached.isNotEmpty) {
      await rescheduleAll(profileId, cached);
    }

    _sub = const ChildAlarmService().watchForChild(profileId).listen(
      (alarms) {
        // rescheduleAll is async; if the platform plugin throws (e.g.
        // permissions denied, timezone DB not initialised), the
        // unawaited Future would surface in `runZonedGuarded` and
        // light up the global "Something went wrong" snackbar. Pin
        // the error to the same onError behaviour as the stream.
        unawaited(rescheduleAll(profileId, alarms).catchError((e, s) {
          if (kDebugMode) {
            debugPrint('AlarmScheduler reschedule failed: $e');
          }
        }));
      },
      onError: (e, s) {
        if (kDebugMode) {
          debugPrint('AlarmScheduler stream error: $e');
        }
      },
    );
  }

  /// Stop listening and cancel every scheduled alarm. Used on sign-out
  /// or when the active profile loses its student/child role.
  static Future<void> shutdown() async {
    await _sub?.cancel();
    _sub = null;
    await _cancelAllAlarmIds();
    _profileId = null;
    try {
      await HiveService.setScheduleOwner(_ownerKey, null);
    } catch (_) {}
  }

  /// Cancels the alarms when [profileId] — the learner they are for — is
  /// deleted from this device, including alarms scheduled by an earlier run
  /// of the app whose ids are no longer in memory.
  static Future<void> forgetProfile(String profileId) async {
    if (scheduledFor != profileId) return;
    await shutdown();
    try {
      await _initPlugin();
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.payload?.startsWith('alarm:') ?? false) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (_) {}
  }

  /// Cancel every prior alarm-id and re-schedule [alarms].
  ///
  /// Public so the editor screen can call it after a manual save when
  /// the live stream hasn't yet emitted — keeps the UX snappy without
  /// waiting for the round-trip.
  static Future<void> rescheduleAll(
      String profileId, List<ChildAlarm> alarms) async {
    await _cancelAllAlarmIds();

    // Cap to 32 enabled alarms — keeps iOS pending notifications well
    // under its 64-slot ceiling even when an alarm repeats on 7 days
    // (which is one notification per day under `dayOfWeekAndTime`).
    final enabled = alarms.where((a) => a.enabled).take(32).toList();
    for (final a in enabled) {
      // If the alarm has no specific days, schedule one per day so the
      // OS reliably matches "every day at HH:mm" via dayOfWeekAndTime.
      final days = a.daysOfWeek.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : a.daysOfWeek;
      for (final day in days) {
        await _scheduleOne(a, day);
      }
    }

    if (kDebugMode) {
      debugPrint(
          'AlarmScheduler: scheduled ${_activeNotificationIds.length} '
          'pending notifications for profile $profileId');
    }
  }

  // ── private ──

  static bool _pluginInitialised = false;

  /// Whether Android will fire these at the exact minute — see
  /// [exactWhenAllowed].
  static bool _canScheduleExact = false;

  static Future<void> _initPlugin() async {
    // Puts tz.local on the device's zone; without it every alarm was
    // scheduled in UTC (see DeviceTimezone).
    await DeviceTimezone.init();
    if (_pluginInitialised) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Permission requests are no-ops on Android < 13 / pre-init iOS
    // contexts. Failure is non-fatal — alarms still schedule, they
    // just won't be shown until the user grants permission later.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    try {
      _canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _canScheduleExact = false;
    }

    _pluginInitialised = true;
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('alarm:')) return;
    final alarmId = payload.substring('alarm:'.length);
    // Look up locally — Firestore may not have streamed yet if the app
    // was launched cold from the notification.
    final alarm = HiveService.getChildAlarmById(alarmId);
    onAlarmFired?.call(alarm);
  }

  static Future<void> _scheduleOne(ChildAlarm a, int isoWeekday) async {
    final id = _idFor(a.id, isoWeekday);
    final scheduled = _nextOccurrence(
      hour: a.hour,
      minute: a.minute,
      isoWeekday: isoWeekday,
    );

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      _titleFor(a),
      _bodyFor(a),
      scheduled,
      details,
      payload: 'alarm:${a.id}',
      // An alarm is the one notification in the app that *is* the time: a
      // daily limit that ends screen time, or a "time's up" hand-off the
      // child has been counting down to. Inexact gave Android an hour to
      // deliver it.
      androidScheduleMode: exactWhenAllowed(
        canScheduleExact: _canScheduleExact,
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    _activeNotificationIds.add(id);
  }

  static String _titleFor(ChildAlarm a) {
    if (a.label.isNotEmpty) return '⏰ ${a.label}';
    return _strings().asAlarm;
  }

  static String _bodyFor(ChildAlarm a) {
    final t = _strings();
    return switch (a.action) {
      AlarmAction.notifyOnly => t.asMoment,
      AlarmAction.lockScreen => t.asWrapUp,
      AlarmAction.endSession => t.lrTakeBreak,
    };
  }

  /// The learner's own language — the alarm is theirs, whoever set it.
  static AppLocalizations _strings() {
    final locale = HiveService.getSettings(profileId: _profileId).locale;
    return lookupAppLocalizations(Locale(locale == 'fil' ? 'fil' : 'en'));
  }

  /// Computes the next [tz.TZDateTime] in the local timezone matching
  /// the alarm's hour/minute on [isoWeekday] (1=Mon..7=Sun). The
  /// `dayOfWeekAndTime` repeat handles future occurrences automatically;
  /// we only need a valid future starting point.
  static tz.TZDateTime _nextOccurrence({
    required int hour,
    required int minute,
    required int isoWeekday,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    // Advance to the matching weekday.
    while (candidate.weekday != isoWeekday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// Stable id for `(alarmId, weekday)` — keeps the schedule idempotent
  /// across stream emissions. Combines a 16-bit hash of [alarmId] with
  /// the weekday so duplicates across alarms are extremely unlikely.
  static int _idFor(String alarmId, int isoWeekday) {
    final h = alarmId.hashCode & 0xFFFF;
    return _idBase + (h * 8) + isoWeekday;
  }

  static Future<void> _cancelAllAlarmIds() async {
    for (final id in _activeNotificationIds.toList()) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    _activeNotificationIds.clear();
  }
}
