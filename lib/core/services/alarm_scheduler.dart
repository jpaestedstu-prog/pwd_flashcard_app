import 'device_timezone.dart';
import 'notification_schedule_mode.dart';
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
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
/// The alarms belong to one learner at a time — the device's learner, see
/// `ScheduleOwnership.forAlarms`. On a shared tablet they are held back
/// ([suspend]) while somebody else uses the app, and they carry the
/// learner's name so nobody mistakes whose they are.
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

  /// The learner's alarms as last seen (stream or cache), so they can be put
  /// back after a [suspend].
  static List<ChildAlarm>? _latest;

  /// A profile the alarms are not for is using the app (see [suspend]).
  static bool _blocked = false;

  /// Whether the app is on screen. A suspension only holds while it is: in
  /// the background nobody is "using" a profile, and the device's learner
  /// must not miss an alarm because a teacher left the app open.
  static bool _foreground = true;

  static AppLifecycleListener? _lifecycle;

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

  /// Educators responsible for [learnerId]'s alarms on this device: whoever
  /// set one of their alarms or routines. They may see the alarms; any other
  /// educator on a shared tablet does not (`ScheduleOwnership.forAlarms`).
  static Set<String> responsibleEducatorsFor(String? learnerId) {
    if (learnerId == null) return const {};
    try {
      return {
        for (final a in HiveService.getChildAlarmsForChild(learnerId))
          a.setterProfileId,
        for (final r in HiveService.getRoutinesForChild(learnerId))
          r.setterProfileId,
      }..removeWhere((id) => id.isEmpty);
    } catch (_) {
      return const {};
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
  /// subscription. Cancels every alarm already scheduled on the device —
  /// including ones an earlier run of the app scheduled for another learner,
  /// whose ids are not in memory — so a profile switch doesn't leak.
  static Future<void> init(String profileId) async {
    await _initPlugin();
    _watchLifecycle();

    await _sub?.cancel();
    final previous = scheduledFor;
    _blocked = false;
    // Only [_activeNotificationIds] used to be cancelled here, and after a
    // restart that set is empty: the previous learner's alarms stayed with
    // the OS and fired in this learner's lesson. Their shown notifications
    // go too — they were never this learner's.
    await _cancelDeviceAlarms(
      includeShown: previous != null && previous != profileId,
    );
    _profileId = profileId;
    try {
      await HiveService.setScheduleOwner(_ownerKey, profileId);
    } catch (_) {}

    // Pre-warm with whatever's in Hive so the very first OS reboot
    // doesn't lose alarms while Firestore takes its time.
    _latest = HiveService.getChildAlarmsForChild(profileId);
    await _reconcile();

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

  /// Holds the learner's alarms back while a profile they are not for is on
  /// screen — another learner, an unrelated educator or a Player on a shared
  /// tablet. They come back on [resume], or whenever the app goes to the
  /// background. Shown alarm notifications are cleared too.
  static Future<void> suspend() async {
    final owner = scheduledFor;
    if (owner == null) return;
    _profileId ??= owner;
    await _initPlugin();
    _watchLifecycle();
    _blocked = true;
    await _reconcile();
  }

  /// Puts the learner's alarms back: after a [suspend], or the first time
  /// this run of the app reaches the profile picker or a responsible
  /// educator — which also restores alarms a suspension cancelled before the
  /// app was closed.
  static Future<void> resume() async {
    final owner = scheduledFor;
    if (owner == null) return;
    if (!_blocked && _profileId != null) return;
    _profileId ??= owner;
    await _initPlugin();
    _watchLifecycle();
    _blocked = false;
    await _reconcile();
  }

  /// Stop listening and cancel every scheduled alarm. Used on sign-out
  /// or when the active profile loses its student/child role.
  static Future<void> shutdown() async {
    await _sub?.cancel();
    _sub = null;
    await _cancelAllAlarmIds();
    _profileId = null;
    _latest = null;
    _blocked = false;
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
      await _cancelDeviceAlarms(includeShown: true);
    } catch (_) {}
  }

  /// Replace the learner's alarms with [alarms] and re-schedule them.
  ///
  /// Public so the editor screen can call it after a manual save when
  /// the live stream hasn't yet emitted — keeps the UX snappy without
  /// waiting for the round-trip. Ignored for any learner but the device's:
  /// alarms an educator edits on their own tablet are not theirs to ring.
  static Future<void> rescheduleAll(
      String profileId, List<ChildAlarm> alarms) async {
    final owner = scheduledFor;
    if (owner != null && owner != profileId) return;
    _latest = alarms;
    await _reconcile();
  }

  // ── pure rules (tested) ──

  /// Whether the learner's alarms should be with the OS right now.
  @visibleForTesting
  static bool shouldSchedule({
    required String? owner,
    required bool blocked,
    required bool foreground,
  }) =>
      owner != null && !(blocked && foreground);

  /// The notifications on the device that are child alarms: scheduled ones
  /// carry an `alarm:` payload; shown ones sit on the child-alarm channel.
  @visibleForTesting
  static Set<int> alarmNotificationIds({
    required Iterable<PendingNotificationRequest> pending,
    Iterable<ActiveNotification> shown = const [],
  }) =>
      {
        for (final p in pending)
          if (p.payload?.startsWith('alarm:') ?? false) p.id,
        for (final s in shown)
          if (s.id != null &&
              (s.channelId == _channelId ||
                  (s.payload?.startsWith('alarm:') ?? false)))
            s.id!,
      };

  /// The title, naming the learner so a shared tablet's other users can see
  /// whose alarm it is.
  @visibleForTesting
  static String titleWithLearner(String base, String? learnerName) {
    final name = learnerName?.trim() ?? '';
    return name.isEmpty ? base : '$base · $name';
  }

  /// Whether a tapped alarm may act for [learnerId]: one left over from
  /// another learner (shown before a switch) must not lock this one's app.
  @visibleForTesting
  static bool tapActsFor(ChildAlarm? alarm, String? learnerId) =>
      alarm == null || alarm.childProfileId == learnerId;

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

  /// Follows the app in and out of the foreground, so a suspension lifts
  /// while the app is in the background.
  static void _watchLifecycle() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          final foreground = state == AppLifecycleState.resumed ||
              state == AppLifecycleState.inactive;
          if (foreground == _foreground) return;
          _foreground = foreground;
          if (_blocked) {
            unawaited(_reconcile().catchError((Object e) {
              if (kDebugMode) debugPrint('AlarmScheduler lifecycle: $e');
            }));
          }
        },
      );
    } catch (_) {
      // No widgets binding (plain unit tests): always in the foreground.
    }
  }

  /// Make the OS's alarms match [_latest] for the learner, or hold them back.
  static Future<void> _reconcile() async {
    final owner = _profileId;
    if (!shouldSchedule(
      owner: owner,
      blocked: _blocked,
      foreground: _foreground,
    )) {
      await _cancelDeviceAlarms(includeShown: _blocked && _foreground);
      if (kDebugMode) {
        debugPrint('AlarmScheduler: alarms for $owner held back');
      }
      return;
    }

    // Everything pending goes first — the ids of an earlier run are not in
    // memory — then the learner's current alarms are scheduled afresh.
    await _cancelDeviceAlarms(includeShown: false);

    // Cap to 32 enabled alarms — keeps iOS pending notifications well
    // under its 64-slot ceiling even when an alarm repeats on 7 days
    // (which is one notification per day under `dayOfWeekAndTime`).
    final alarms = _latest ?? HiveService.getChildAlarmsForChild(owner!);
    final enabled = alarms
        .where((a) => a.enabled && a.childProfileId == owner)
        .take(32)
        .toList();
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
          'pending notifications for profile $owner');
    }
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('alarm:')) return;
    final alarmId = payload.substring('alarm:'.length);
    // Look up locally — Firestore may not have streamed yet if the app
    // was launched cold from the notification.
    final alarm = HiveService.getChildAlarmById(alarmId);
    if (_blocked || !tapActsFor(alarm, scheduledFor)) return;
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
    final base = a.label.isNotEmpty ? '⏰ ${a.label}' : _strings().asAlarm;
    String? name;
    try {
      name = HiveService.getProfileById(a.childProfileId)?.name;
    } catch (_) {}
    return titleWithLearner(base, name);
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

  /// Cancels every child alarm the OS holds — this run's and any earlier
  /// run's — and, with [includeShown], clears ones already on screen.
  static Future<void> _cancelDeviceAlarms({required bool includeShown}) async {
    await _cancelAllAlarmIds();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final shown = includeShown
          ? await _plugin.getActiveNotifications()
          : const <ActiveNotification>[];
      for (final id in alarmNotificationIds(pending: pending, shown: shown)) {
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }
}
