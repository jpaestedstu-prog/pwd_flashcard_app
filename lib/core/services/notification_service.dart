import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      
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

    // iOS handled via initialization settings
    return true;
  }

  /// Schedule a daily notification at the given [hour] and [minute].
  ///
  /// Cancels any previously scheduled daily reminder first.
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = '📚 Time to Learn!',
    String body = "Let's practice some new words today!",
  }) async {
    await cancelDailyReminder();

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
  }) async {
    await cancelVocabReviewReminder();

    final body = weakWordCount > 0
        ? 'You have $weakWordCount word${weakWordCount == 1 ? '' : 's'} to review. '
            "Let's strengthen your memory!"
        : "Time to review your vocabulary and keep your streak going!";

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
      '🧠 Words Need Your Attention!',
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
