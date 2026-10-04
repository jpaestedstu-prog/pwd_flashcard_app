import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/alarm_scheduler.dart';
import 'package:pwdpwdpwd/data/models/alarm_action.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// A shared tablet: a child's alarm, scheduled by an earlier run of the app,
/// fired in the middle of a different student's lesson. The scheduler only
/// cancelled the ids it remembered, and after a restart it remembered none.
ChildAlarm _alarm(String child) => ChildAlarm(
      id: 'a-$child',
      childProfileId: child,
      setterProfileId: 'mom',
      setterRole: UserRole.parent,
      label: '',
      hour: 13,
      minute: 20,
      daysOfWeek: const {7},
      action: AlarmAction.lockScreen,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('when the learner\'s alarms are with the OS', () {
    test('scheduled whenever there is a learner and nobody else is on screen', () {
      expect(
        AlarmScheduler.shouldSchedule(owner: 'ben', blocked: false, foreground: true),
        isTrue,
      );
    });

    test('held back while another profile uses the app', () {
      expect(
        AlarmScheduler.shouldSchedule(owner: 'ben', blocked: true, foreground: true),
        isFalse,
      );
    });

    test('back while the app is in the background, so none is missed', () {
      expect(
        AlarmScheduler.shouldSchedule(owner: 'ben', blocked: true, foreground: false),
        isTrue,
      );
    });

    test('nothing without a learner', () {
      expect(
        AlarmScheduler.shouldSchedule(owner: null, blocked: false, foreground: true),
        isFalse,
      );
    });
  });

  group('which notifications are child alarms', () {
    test('pending ones by their alarm payload — whichever run scheduled them', () {
      final ids = AlarmScheduler.alarmNotificationIds(pending: const [
        PendingNotificationRequest(1234, 'Alarm', 'Time to take a moment.', 'alarm:a-ben'),
        PendingNotificationRequest(0, 'Daily', 'Study time', null),
        PendingNotificationRequest(1000001, 'Lunch', 'Please have your lunch now', 'routine:r1:s1'),
      ]);
      expect(ids, {1234});
    });

    test('shown ones by their channel or payload', () {
      final ids = AlarmScheduler.alarmNotificationIds(
        pending: const [],
        shown: const [
          ActiveNotification(id: 1500, channelId: 'child_alarm', title: '⏰ Alarm'),
          ActiveNotification(id: 1600, payload: 'alarm:a-ana'),
          ActiveNotification(id: 7, channelId: 'routine_reminders'),
          ActiveNotification(channelId: 'child_alarm'),
        ],
      );
      expect(ids, {1500, 1600});
    });
  });

  group('the notification', () {
    test("names the learner it is for", () {
      expect(
        AlarmScheduler.titleWithLearner('⏰ Alarm', 'Hearing Impairment Anak'),
        '⏰ Alarm · Hearing Impairment Anak',
      );
    });

    test('stays as it was when the name is unknown', () {
      expect(AlarmScheduler.titleWithLearner('⏰ Alarma', null), '⏰ Alarma');
      expect(AlarmScheduler.titleWithLearner('⏰ Alarma', '  '), '⏰ Alarma');
    });
  });

  group('a tapped alarm', () {
    test("acts for the learner it was set for", () {
      expect(AlarmScheduler.tapActsFor(_alarm('ben'), 'ben'), isTrue);
    });

    test("never locks another learner's app", () {
      expect(AlarmScheduler.tapActsFor(_alarm('ben'), 'ana'), isFalse);
      expect(AlarmScheduler.tapActsFor(_alarm('ben'), null), isFalse);
    });

    test('a deleted alarm is left to the handler, which ignores it', () {
      expect(AlarmScheduler.tapActsFor(null, 'ana'), isTrue);
    });
  });
}
