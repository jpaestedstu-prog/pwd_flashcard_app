import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/device_timezone.dart';
import '../../../core/services/notification_schedule_mode.dart';
import '../../../data/models/enums.dart';
import '../models/routine_catalog.dart';
import '../models/routine_day_state.dart';
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

  /// Educator-side alerts that a learner has waited too long on a step.
  static const _helpChannelId = 'routine_help';
  static const _helpChannelName = 'Routine Help Alerts';

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

  /// The reminders currently scheduled, the learner they are for, and how
  /// their notifications are delivered — kept so today's settled steps can be
  /// re-checked without re-reading routines.
  static List<RoutineReminder> _plan = const [];
  static String? _profileId;
  static DisabilityType _accessibility = DisabilityType.none;

  /// Notification ids whose occurrence **today** has been skipped, and the day
  /// that set belongs to. A new day clears it; the schedules themselves were
  /// already started from tomorrow, which is now today.
  static String _suppressedDay = '';
  static final Set<int> _suppressedToday = {};

  /// Today's day log and educator actions for the learner, watched so an
  /// excuse or approval made on another device reaches this device's
  /// notifications too.
  static StreamSubscription<RoutineDayLog>? _logSub;
  static StreamSubscription<RoutineDayActions>? _actionsSub;
  static String _watchedDay = '';

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
    _profileId = profileId;
    _accessibility = accessibility;
    _watchToday(profileId);

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
    await _logSub?.cancel();
    await _actionsSub?.cancel();
    _logSub = null;
    _actionsSub = null;
    _watchedDay = '';
    _plan = const [];
    _profileId = null;
    _suppressedToday.clear();
    await cancelAll();
  }

  static Future<void> rescheduleAll(
    List<Routine> routines, {
    required DisabilityType accessibility,
    required bool filipino,
  }) async {
    await cancelAll();
    final reminders = plan(routines, filipino: filipino);
    _plan = reminders;
    _accessibility = accessibility;
    final today = DateTime.now();
    final id = _profileId;
    if (id != null) _watchToday(id);
    _suppressedDay = dayStampOf(today);
    _suppressedToday.clear();
    // A step already done or excused today is scheduled from tomorrow, so
    // editing the routine at 6:50 cannot resurrect a reminder for a morning
    // that is already settled.
    final settled = _settledToday(today);
    for (final r in reminders) {
      final skip = settled.contains(r.stepId);
      await _scheduleOne(r, accessibility: accessibility, skipToday: skip);
      if (skip) _suppressedToday.add(r.notificationId);
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

  /// Posts "Ana needs help with Brushing Teeth" on the educator's device.
  ///
  /// A one-off, not a schedule. Ids sit at 2,000,000+, clear of the reminder
  /// range above and the alarm scheduler's below. Failures are swallowed: an
  /// alert that could not be posted must never take the dashboard down with
  /// it, and the red row is still there.
  static Future<void> showHelpAlert({
    required String key,
    required String title,
    required String body,
  }) async {
    try {
      await _initPlugin();
      await _plugin.show(
        2000000 + (key.hashCode & 0xFFFF),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _helpChannelId,
            _helpChannelName,
            channelDescription:
                'When a learner has waited too long on a routine step.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (_) {}
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
    bool skipToday = false,
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
      _nextOccurrence(
        hour: r.hour,
        minute: r.minute,
        isoWeekday: r.isoWeekday,
        skipToday: skipToday,
      ),
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
    bool skipToday = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    final next = firstFireAfter(
      now: DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ),
      hour: hour,
      minute: minute,
      isoWeekday: isoWeekday,
      skipToday: skipToday,
    );
    return tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
  }

  /// When a reminder at [hour]:[minute] should first fire, counting from
  /// [now] — optionally not today at all.
  ///
  /// **Skipping today is safe for the days after** because of how the
  /// repeat works on Android: the alarm is set for exactly this first date,
  /// each firing schedules the next one from the time components, and a
  /// reboot re-arms from this same stored date. Starting a daily reminder
  /// tomorrow therefore skips one morning and keeps every morning after it.
  /// (iOS repeats from the time components alone and would still fire today;
  /// nothing breaks, the one skip just does not happen there.)
  ///
  /// Built day by day with calendar arithmetic rather than adding 24-hour
  /// durations, so a daylight-saving change cannot slide the time an hour.
  static DateTime firstFireAfter({
    required DateTime now,
    required int hour,
    required int minute,
    int? isoWeekday,
    bool skipToday = false,
  }) {
    bool tooEarly(DateTime c) =>
        !c.isAfter(now) ||
        (skipToday &&
            c.year == now.year &&
            c.month == now.month &&
            c.day == now.day);
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    while ((isoWeekday != null && candidate.weekday != isoWeekday) ||
        tooEarly(candidate)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        hour,
        minute,
      );
    }
    return candidate;
  }

  /// Which reminders need re-scheduling, and whether each should now skip
  /// today (true) or get today back (false). Pure; unchanged ids are absent.
  static Map<int, bool> suppressionChanges({
    required List<RoutineReminder> plan,
    required Set<String> settled,
    required Set<int> suppressed,
  }) {
    final out = <int, bool>{};
    for (final r in plan) {
      final shouldSkip = settled.contains(r.stepId);
      final isSkipped = suppressed.contains(r.notificationId);
      if (shouldSkip != isSkipped) out[r.notificationId] = shouldSkip;
    }
    return out;
  }

  /// Brings today's reminders in line with today's day.
  ///
  /// A step that is done, excused or approved has nothing left to remind
  /// about: its reminder — including one already sitting in the shade saying
  /// "FlashLearn is waiting for you to do this" — is cleared, and the schedule
  /// is started again from its next day. A step un-ticked before its time
  /// gets today's reminder back.
  ///
  /// Called whenever today's log or actions change (from any device), and
  /// straight after a local tick or excuse. A no-op before [init], which is
  /// every widget test and every profile that has no reminders.
  static Future<void> refreshSettled() async {
    final id = _profileId;
    if (id == null || _plan.isEmpty) return;
    final today = DateTime.now();
    final stamp = dayStampOf(today);
    if (_suppressedDay != stamp) {
      _suppressedDay = stamp;
      _suppressedToday.clear();
    }
    final changes = suppressionChanges(
      plan: _plan,
      settled: _settledToday(today),
      suppressed: _suppressedToday,
    );
    if (changes.isEmpty) return;
    for (final r in _plan) {
      final skip = changes[r.notificationId];
      if (skip == null) continue;
      try {
        await _plugin.cancel(r.notificationId);
        await _scheduleOne(r, accessibility: _accessibility, skipToday: skip);
        _activeIds.add(r.notificationId);
        skip
            ? _suppressedToday.add(r.notificationId)
            : _suppressedToday.remove(r.notificationId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('RoutineReminderScheduler refreshSettled failed: $e');
        }
      }
    }
  }

  static Set<String> _settledToday(DateTime today) {
    final id = _profileId;
    if (id == null) return const <String>{};
    try {
      final view = RoutineService.viewFromCache(id, today);
      return {...view.doneIds, ...view.excusedIds};
    } catch (_) {
      return const <String>{};
    }
  }

  /// Watches today's log and actions for [profileId], re-subscribing when the
  /// date has moved on. The service writes each merged snapshot to the local
  /// mirror before emitting, so [refreshSettled] can simply read the mirror.
  static void _watchToday(String profileId) {
    final today = DateTime.now();
    final stamp = '$profileId|${dayStampOf(today)}';
    if (_watchedDay == stamp) return;
    _watchedDay = stamp;
    unawaited(_logSub?.cancel());
    unawaited(_actionsSub?.cancel());
    _logSub = const RoutineService().watchDayLog(profileId, today).listen(
          (_) => unawaited(refreshSettled()),
          onError: (Object _) {},
        );
    _actionsSub =
        const RoutineService().watchDayActions(profileId, today).listen(
              (_) => unawaited(refreshSettled()),
              onError: (Object _) {},
            );
  }
}
