import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/device_timezone.dart';
import '../../../core/services/notification_schedule_mode.dart';
import '../../../data/models/enums.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import 'routine_service.dart';

/// One reminder the OS should raise: a step, on a weekday, at a wall time.
///
/// Split out from the plugin call so the whole scheduling *policy* — which
/// steps remind, on which days, at what time, how many survive the cap — is
/// pure and testable without a notification plugin or a device clock.
class RoutineReminder {
  final String routineId;
  final String stepId;

  /// Title and body as the learner will read them.
  final String title;
  final String body;

  final int hour;
  final int minute;

  /// ISO weekday (1 = Monday … 7 = Sunday), or null for "every day", which
  /// schedules as a single daily repeat rather than seven weekly ones.
  final int? isoWeekday;

  /// Whether this step will hold the learner's device when its time arrives
  /// ([Routine.lockEnabled] + [RoutineStep.canLock]).
  ///
  /// Changes what kind of notification this is, not just its words. A
  /// reminder invites; a lock announces something that is about to happen
  /// whether the learner taps or not — so it is filed as an **alarm** and
  /// carries a full-screen intent, which is the only handle Android gives an
  /// app for "bring yourself up, the moment has come".
  final bool locksScreen;

  const RoutineReminder({
    required this.routineId,
    required this.stepId,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.isoWeekday,
    this.locksScreen = false,
  });

  bool get isDaily => isoWeekday == null;

  int get minutesOfDay => hour * 60 + minute;

  /// Stable id so re-scheduling on every stream emission is idempotent.
  ///
  /// Based at 1,000,000: `AlarmScheduler` occupies roughly [1000, 525287]
  /// (`1000 + hash16 * 8 + weekday`), and two schedulers quietly cancelling
  /// each other's notifications would be a miserable bug to find.
  int get notificationId {
    final h = ('$routineId:$stepId').hashCode & 0xFFFF;
    return 1000000 + (h * 8) + (isoWeekday ?? 0);
  }
}

/// Turns a learner's routines into OS notifications.
///
/// A visual schedule nobody is nudged toward is a schedule that gets
/// forgotten — this is the piece that makes a routine act on the day rather
/// than wait to be opened.
///
/// Mirrors `AlarmScheduler`, with two deliberate differences:
///
///  * **An every-day routine schedules one daily repeat per step**, not seven
///    weekly ones. A twelve-step daily routine would otherwise be 84 pending
///    notifications on its own and blow past iOS's 64-slot ceiling; this way
///    it is twelve.
///  * **Two channels, picked from the learner's accessibility category.** A
///    Deaf learner gets the silent-but-vibrating channel: a sound they cannot
///    hear is a notification only for the room, and the vibration is the part
///    that reaches them.
class RoutineReminderScheduler {
  RoutineReminderScheduler._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'routine_reminder';
  static const _channelName = 'Routine Reminders';
  static const _channelDesc =
      'Reminders for the steps of a daily routine set by a parent or teacher.';

  /// Silent variant for learners who cannot hear the tone. Separate channel
  /// because Android fixes sound and vibration at channel creation — the same
  /// channel cannot be quiet for one learner and audible for another.
  static const _silentChannelId = 'routine_reminder_silent';
  static const _silentChannelName = 'Routine Reminders (vibrate only)';

  /// Hard cap on pending routine notifications. iOS allows 64 across the whole
  /// app and `AlarmScheduler` is already using some, so routines take a little
  /// under half and drop the rest — the earliest steps of the day survive,
  /// because a morning routine is the one that needs the nudge.
  static const int maxPending = 24;

  /// Tapped-notification hook, wired in `main.dart` to open `/routine`.
  static void Function(String routineId, String stepId)? onReminderTapped;

  static StreamSubscription<List<Routine>>? _sub;
  static final Set<int> _activeIds = {};
  static bool _pluginInitialised = false;

  /// Whether Android will fire at the exact minute. The app declares
  /// `USE_EXACT_ALARM`, but it is checked rather than assumed: on a device or
  /// policy that withholds it, an exact schedule throws, and a late reminder
  /// is better than none.
  static bool _canScheduleExact = false;

  /// Builds the reminder set for [routines] — pure, no plugin, no clock.
  ///
  /// Ordered by time of day and capped at [maxPending] so the cap is
  /// deterministic and the earliest steps win.
  static List<RoutineReminder> plan(
    List<Routine> routines, {
    required bool filipino,
    int cap = maxPending,
  }) {
    final out = <RoutineReminder>[];
    for (final routine in routines) {
      final locking = {for (final s in routine.lockingSteps) s.id};
      for (final step in routine.remindableSteps) {
        final at = _remindAt(step);
        // Only the reminder that lands *at* the step is an alarm. An early
        // warning is still a warning — nothing is locked five minutes before,
        // and dressing it as an alarm would be a promise the learner soon
        // learns to ignore.
        final locks =
            locking.contains(step.id) && step.remindMinutesBefore == 0;
        final title = _titleFor(step, filipino: filipino);
        final body = _bodyFor(step, filipino: filipino, locks: locks);
        if (routine.isEveryDay) {
          out.add(RoutineReminder(
            routineId: routine.id,
            stepId: step.id,
            title: title,
            body: body,
            hour: at.$1,
            minute: at.$2,
            locksScreen: locks,
          ));
        } else {
          for (final day in (routine.daysOfWeek.toList()..sort())) {
            out.add(RoutineReminder(
              routineId: routine.id,
              stepId: step.id,
              title: title,
              body: body,
              hour: at.$1,
              minute: at.$2,
              isoWeekday: day,
              locksScreen: locks,
            ));
          }
        }
      }
    }
    out.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return out.length <= cap ? out : out.sublist(0, cap);
  }

  /// The wall time a step's reminder fires at, honouring
  /// [RoutineStep.remindMinutesBefore] and wrapping backwards over midnight
  /// rather than landing on a negative hour.
  static (int, int) _remindAt(RoutineStep step) {
    final total = step.minutesOfDay! - step.remindMinutesBefore;
    final wrapped = ((total % 1440) + 1440) % 1440;
    return (wrapped ~/ 60, wrapped % 60);
  }

  /// A check-in step announces itself as one — the learner needs to know this
  /// notification is asking a question, not naming a chore. Everything else
  /// is titled with the step's own name.
  static String _titleFor(RoutineStep step, {required bool filipino}) {
    if (step.activity.isMoodCheckIn) {
      return filipino ? 'Oras na ng check-in 💬' : 'Check-in time 💬';
    }
    return RoutineCatalog.titleFor(step, filipino: filipino);
  }

  static String _bodyFor(
    RoutineStep step, {
    required bool filipino,
    bool locks = false,
  }) {
    // The words the brief asked for, verbatim. No "in N minutes" variant: a
    // check-in is answered when it arrives, not prepared for.
    if (step.activity.isMoodCheckIn) {
      return filipino
          ? 'Pakigawa na ang iyong check-in ngayon. Kumusta ang pakiramdam mo?'
          : 'Please do your check-in now. How are you feeling?';
    }
    final early = step.remindMinutesBefore;
    if (early > 0) {
      return filipino
          ? 'Sa loob ng $early minuto. I-tap para makita.'
          : 'In $early minutes. Tap to see what to do.';
    }
    // The educator's own note beats a generic line — it is more specific and
    // it is what the learner has been read before.
    final note = RoutineCatalog.noteFor(step, filipino: filipino);
    if (note.isNotEmpty) return note;
    // "Tap to see what to do" is the wrong promise for a step that locks: the
    // app is not offering to show the learner something, it is waiting for
    // them, and it will keep waiting whether they tap or not.
    if (locks) {
      return filipino
          ? 'Hinihintay ka ng FlashLearn para dito.'
          : 'FlashLearn is waiting for you to do this.';
    }
    return filipino ? 'Oras na. I-tap para makita.' : 'Tap to see what to do.';
  }

  /// Start scheduling for [profileId]. Safe to call repeatedly; each call
  /// replaces the previous subscription and cancels the previous schedule so
  /// a profile switch cannot leak another learner's reminders.
  static Future<void> init(
    String profileId, {
    required DisabilityType accessibility,
    required bool filipino,
  }) async {
    await _initPlugin();
    await _sub?.cancel();
    await cancelAll();

    _sub = const RoutineService().watchForChild(profileId).listen(
      (routines) {
        unawaited(
          rescheduleAll(
            routines,
            accessibility: accessibility,
            filipino: filipino,
          ).catchError((Object e) {
            // Unawaited plugin failures (permission denied, no timezone DB)
            // would otherwise surface through runZonedGuarded and light the
            // global "Something went wrong" snackbar on whatever screen the
            // learner happens to be on.
            if (kDebugMode) {
              debugPrint('RoutineReminderScheduler reschedule failed: $e');
            }
          }),
        );
      },
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('RoutineReminderScheduler stream error: $e');
        }
      },
    );
  }

  /// Stop listening and clear every pending routine reminder.
  static Future<void> shutdown() async {
    await _sub?.cancel();
    _sub = null;
    await cancelAll();
  }

  static Future<void> rescheduleAll(
    List<Routine> routines, {
    required DisabilityType accessibility,
    required bool filipino,
  }) async {
    await cancelAll();
    final reminders = plan(routines, filipino: filipino);
    for (final r in reminders) {
      await _scheduleOne(r, accessibility: accessibility);
    }
    if (kDebugMode) {
      debugPrint(
        'RoutineReminderScheduler: ${reminders.length} pending reminders',
      );
    }
  }

  static Future<void> cancelAll() async {
    for (final id in _activeIds.toList()) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    _activeIds.clear();
  }

  // ── private ──

  static Future<void> _initPlugin() async {
    // Every call, not just the first: it is what puts tz.local on the
    // device's zone (see DeviceTimezone), and cheap to repeat.
    await DeviceTimezone.init();
    if (_pluginInitialised) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTap,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    try {
      _canScheduleExact = await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _canScheduleExact = false;
    }
    _pluginInitialised = true;
  }

  /// Asks Android for the permission a locking routine needs to raise its
  /// lock by itself, and reports whether it is now granted.
  ///
  /// Deliberately separate from [_initPlugin] and never called at start-up: on
  /// Android 14+ this opens a system settings page, and throwing one of those
  /// at whoever launches the app would be worse than the delay it fixes. The
  /// routine builder offers it at the one moment it is relevant — when an
  /// educator switches a routine to locking.
  static Future<bool> requestFullScreenPermission() async {
    try {
      await _initPlugin();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestFullScreenIntentPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('routine:')) return;
    final parts = payload.substring('routine:'.length).split('|');
    if (parts.length != 2) return;
    onReminderTapped?.call(parts[0], parts[1]);
  }

  /// True when the learner cannot hear the notification tone, so the channel
  /// should vibrate silently instead.
  static bool usesSilentChannel(DisabilityType type) =>
      type == DisabilityType.hearing;

  static Future<void> _scheduleOne(
    RoutineReminder r, {
    required DisabilityType accessibility,
  }) async {
    final silent = usesSilentChannel(accessibility);
    final androidDetails = AndroidNotificationDetails(
      silent ? _silentChannelId : _channelId,
      silent ? _silentChannelName : _channelName,
      channelDescription: _channelDesc,
      importance: r.locksScreen ? Importance.max : Importance.high,
      priority: r.locksScreen ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: !silent,
      // A locking step is an alarm in the platform's own vocabulary, and
      // saying so is what earns it an alarm's treatment: it wakes a sleeping
      // screen and it is not filed away with the rest of the app's chatter.
      category: r.locksScreen ? AndroidNotificationCategory.alarm : null,
      // The only handle Android gives an app for "come to the front now".
      // On a device that is awake and in use the platform downgrades this to
      // a heads-up notification — no app may seize a screen somebody is
      // already using — but on the sleeping tablet at 6:45 it is the
      // difference between the lock being there and the lock waiting in the
      // shade. Degrades silently when the permission is not granted; see
      // [requestFullScreenPermission].
      fullScreenIntent: r.locksScreen,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !silent,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      r.notificationId,
      r.title,
      r.body,
      _nextOccurrence(hour: r.hour, minute: r.minute, isoWeekday: r.isoWeekday),
      details,
      payload: 'routine:${r.routineId}|${r.stepId}',
      // Exact where allowed. Inexact gave Android a one-hour window
      // (`dumpsys alarm`: window=+1h) — "Please do your check-in now" at
      // 9:47 for a 9:00 check-in is not a check-in at 9:00.
      androidScheduleMode: exactWhenAllowed(
        canScheduleExact: _canScheduleExact,
      ),
      matchDateTimeComponents:
          r.isDaily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
    );
    _activeIds.add(r.notificationId);
  }

  /// The next local occurrence of the given time. The repeat component
  /// handles everything after it; this only needs a valid future start.
  static tz.TZDateTime _nextOccurrence({
    required int hour,
    required int minute,
    int? isoWeekday,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (isoWeekday != null) {
      while (candidate.weekday != isoWeekday) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 7));
      }
    } else if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
