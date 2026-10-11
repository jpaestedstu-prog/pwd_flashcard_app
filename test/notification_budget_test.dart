import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/alarm_scheduler.dart';
import 'package:pwdpwdpwd/core/services/notification_budget.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/educator_step_alerts.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_reminder_scheduler.dart';

/// iOS keeps only the 64 soonest pending local notifications of an app and
/// silently drops the rest. The child alarms claimed to stay under that with
/// a cap of 32 alarms — but an every-day alarm was seven weekly requests, so
/// the "cap" allowed 224.

ChildAlarm _alarm(
  String id, {
  Set<int> days = const {},
  String child = 'ben',
  bool enabled = true,
}) =>
    ChildAlarm(
      id: id,
      childProfileId: child,
      setterProfileId: 'mom',
      setterRole: UserRole.parent,
      label: '',
      hour: 7,
      minute: 30,
      daysOfWeek: days,
      enabled: enabled,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('every scheduler together stays inside iOS\'s 64', () {
    const total = NotificationBudget.studyReminders +
        RoutineReminderScheduler.maxPending +
        NotificationBudget.childAlarmRequestsIos +
        NotificationBudget.educatorAlertsIos;
    expect(total, lessThanOrEqualTo(NotificationBudget.iosPendingLimit));
  });

  test('iOS gets the small shares, Android keeps its old limits', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(NotificationBudget.childAlarmRequests, 16);
    expect(NotificationBudget.educatorAlerts, 20);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(NotificationBudget.childAlarmRequests, 32 * 7);
    expect(NotificationBudget.educatorAlerts,
        EducatorStepAlertPlan.maxPending);
  });

  group('child alarm requests', () {
    test('an every-day alarm is one daily repeat, not seven', () {
      for (final days in [<int>{}, {1, 2, 3, 4, 5, 6, 7}]) {
        final plan = AlarmScheduler.plannedRequests(
          [_alarm('a', days: days)],
          owner: 'ben',
          maxRequests: 16,
        );
        expect(plan.map((r) => r.$2), [0], reason: 'days $days');
      }
    });

    test('chosen days are one weekly repeat each, in order', () {
      final plan = AlarmScheduler.plannedRequests(
        [_alarm('a', days: {5, 1, 3})],
        owner: 'ben',
        maxRequests: 16,
      );
      expect(plan.map((r) => r.$2), [1, 3, 5]);
    });

    test('the budget takes whole alarms only, first listed first', () {
      final plan = AlarmScheduler.plannedRequests(
        [
          _alarm('weekdays', days: {1, 2, 3, 4, 5}),
          _alarm('weekend', days: {6, 7}),
          _alarm('daily'),
          _alarm('three', days: {1, 3, 5}),
        ],
        owner: 'ben',
        maxRequests: 8,
      );
      // 5 + 2 + 1 = 8; "three" no longer fits and is left out whole.
      expect(plan.map((r) => r.$1.id).toSet(), {'weekdays', 'weekend', 'daily'});
      expect(plan, hasLength(8));
    });

    test('a smaller alarm still fits after a bigger one did not', () {
      final plan = AlarmScheduler.plannedRequests(
        [
          _alarm('four', days: {1, 2, 3, 4}),
          _alarm('five', days: {1, 2, 3, 4, 5}),
          _alarm('daily'),
        ],
        owner: 'ben',
        maxRequests: 6,
      );
      expect(plan.map((r) => r.$1.id).toSet(), {'four', 'daily'});
    });

    test('switched-off alarms and other learners\' alarms take nothing', () {
      final plan = AlarmScheduler.plannedRequests(
        [
          _alarm('off', enabled: false),
          _alarm('ana', child: 'ana'),
          _alarm('mine'),
        ],
        owner: 'ben',
        maxRequests: 16,
      );
      expect(plan.map((r) => r.$1.id), ['mine']);
    });

    test('twenty every-day alarms fit the iOS share', () {
      final plan = AlarmScheduler.plannedRequests(
        [for (var i = 0; i < 20; i++) _alarm('a$i')],
        owner: 'ben',
        maxRequests: NotificationBudget.childAlarmRequestsIos,
      );
      expect(plan, hasLength(NotificationBudget.childAlarmRequestsIos));
    });
  });
}
