import 'package:flutter/foundation.dart';

/// How many scheduled notifications each part of the app may keep pending.
///
/// iOS keeps only the **64 soonest-firing** pending local notifications of an
/// app (a repeating one counts once) and quietly discards the rest — no
/// error, no log: an alarm past the limit simply never rings. Every scheduler
/// draws from that one pool, so each gets a fixed share that together stays
/// under it:
///
/// | source                                   | iOS | Android |
/// |------------------------------------------|----:|--------:|
/// | daily study + vocabulary reminders       |   2 |       2 |
/// | routine reminders (`RoutineReminderScheduler.maxPending`) | 24 | 24 |
/// | child alarms, in OS requests              |  16 |     224 |
/// | educator start/end alerts                 |  20 |      40 |
///
/// Android has no such pool — only a ceiling of 500 alarms per app — so it
/// keeps the limits the app always had. (Before this, child alarms were
/// "capped" at 32, but an every-day alarm is seven weekly requests: up to
/// 224 on iOS, where all but the soonest 64 of everything were dropped.)
class NotificationBudget {
  NotificationBudget._();

  /// What iOS keeps.
  static const int iosPendingLimit = 64;

  /// `NotificationService`'s daily reminder and vocabulary review.
  static const int studyReminders = 2;

  static const int childAlarmRequestsIos = 16;
  static const int childAlarmRequestsAndroid = 32 * 7;

  static const int educatorAlertsIos = 20;
  static const int educatorAlertsAndroid = 40;

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Most OS requests the child alarms may use on this platform.
  static int get childAlarmRequests =>
      _ios ? childAlarmRequestsIos : childAlarmRequestsAndroid;

  /// Most educator alerts kept pending on this platform, earliest first.
  static int get educatorAlerts =>
      _ios ? educatorAlertsIos : educatorAlertsAndroid;
}
