import 'dart:ui' show Locale;

import 'device_timezone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';

/// Manages daily study-reminder notifications via flutter_local_notifications.
///
/// Call [init] once at app startup, then [scheduleDailyReminder] whenever
/// the user changes their preferred reminder time.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  /// Callback invoked when a notification is tapped.
  /// Set via [init] so the caller can navigate.
  static void Function(String payload)? _onTapCallback;

  // ── Notification channel (Android) ──
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily Reminders';
  static const _channelDesc = 'Daily study reminders for FlashLearn PWD';

  // ── Notification IDs ──
  static const _dailyReminderId = 0;
  static const _vocabReviewId = 1;

  /// Initialise the plugin & time-zone database.
  /// Safe to call multiple times – only runs once.
  ///
  /// [onNotificationTap] is called whenever the user taps a notification.
  /// The string is the notification payload (e.g. `'daily_challenge'`).
  static Future<void> init({
    void Function(String payload)? onNotificationTap,
  }) async {
    if (_initialised) return;

    _onTapCallback = onNotificationTap;

    // Loads the zone database *and* sets tz.local to the device's zone. The
    // bare `tz.initializeTimeZones()` that used to be here left tz.local on
    // UTC, which scheduled every notification in the app 8 hours late on a
    // Philippine device.
    await DeviceTimezone.init();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // This runs at launch, before onboarding. iOS would put up its
    // notification prompt right here, before anyone knows what reminders are
    // for; Android asks only when a learner starts using the app or a
    // reminder is switched on. Same on iOS now: the schedulers ask when they
    // start, and [requestPermission] asks for real.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    _initialised = true;

    // Handle cold-start: app was launched by tapping a notification
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload != null) {
      _onTapCallback?.call(launchDetails.notificationResponse!.payload!);
    }
  }

  // ── Tap handler ──
  static void _onTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
    if (response.payload != null && _onTapCallback != null) {
      _onTapCallback!(response.payload!);
    }
  }

  // ────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────

  /// Request the user's permission (Android 13+, iOS).
  static Future<bool> requestPermission() async {
    // Android 13+ (API 33)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a daily notification at the given [hour] and [minute].
  ///
  /// Cancels any previously scheduled daily reminder first.
  ///
  /// The wording is fixed when the reminder is scheduled, so it follows
  /// [filipino] — see [relocalize] for a language change afterwards.
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool filipino = false,
  }) async {
    await cancelDailyReminder();
    final t = _strings(filipino);
    final title = t.nsDailyTitle;
    final body = t.nsDailyBody;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the time is already past today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

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

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      title,
      body,
      scheduled,
      details,
      payload: 'daily_challenge',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );

    if (kDebugMode) {
      debugPrint('Daily reminder scheduled at $hour:${minute.toString().padLeft(2, '0')}');
    }
  }

  /// Re-issues whichever reminders are pending so their wording follows a
  /// language change — a scheduled notification keeps the text it was
  /// created with. Reminders that are off stay off.
  static Future<void> relocalize({
    required bool filipino,
    required int hour,
    required int minute,
    required int Function() weakWordCount,
  }) async {
    final Set<int> pending;
    try {
      pending = {
        for (final p in await _plugin.pendingNotificationRequests()) p.id,
      };
    } catch (_) {
      return; // No notifications plugin here (tests, desktop).
    }
    if (pending.contains(_dailyReminderId)) {
      await scheduleDailyReminder(hour: hour, minute: minute, filipino: filipino);
    }
    if (pending.contains(_vocabReviewId)) {
      await scheduleVocabReviewReminder(
        hour: hour,
        minute: minute,
        weakWordCount: weakWordCount(),
        filipino: filipino,
      );
    }
  }

  static AppLocalizations _strings(bool filipino) =>
      lookupAppLocalizations(Locale(filipino ? 'fil' : 'en'));

  /// Cancel the daily reminder.
  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  // ────────────────────────────────────────
  // Vocabulary Review Reminder
  // ────────────────────────────────────────

  /// Schedule a daily vocabulary review reminder at the given time.
  ///
  /// The notification uses the `vocab_review` payload so the app can
  /// navigate directly to the Smart Review screen when tapped.
  static Future<void> scheduleVocabReviewReminder({
    required int hour,
    required int minute,
    required int weakWordCount,
    bool filipino = false,
  }) async {
    await cancelVocabReviewReminder();

    final t = _strings(filipino);
    final body = weakWordCount > 0
        ? t.nsReviewBody(weakWordCount)
        : t.nsReviewNone;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'vocab_review',
      'Vocabulary Review',
      channelDescription: 'Reminders to review weak vocabulary words',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      _vocabReviewId,
      t.nsReviewTitle,
      body,
      scheduled,
      details,
      payload: 'vocab_review',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    if (kDebugMode) {
      debugPrint(
        'Vocab review reminder scheduled at '
        '$hour:${minute.toString().padLeft(2, '0')} '
        '($weakWordCount weak words)',
      );
    }
  }

  /// Cancel the vocabulary review reminder.
  static Future<void> cancelVocabReviewReminder() async {
    await _plugin.cancel(_vocabReviewId);
  }

  /// Cancel all pending notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
