import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_native_alarms.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_reminder_scheduler.dart';

/// The Dart half of Android's routine alarm scheduler (RoutineAlarms.kt): the
/// plan it stores, the day it compares, and the launches it reports.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const brush = RoutineReminder(
    routineId: 'morning',
    stepId: 'brush',
    title: 'Brushing Teeth',
    body: 'FlashLearn is waiting for you to do this.',
    hour: 6,
    minute: 45,
    locksScreen: true,
  );
  const art = RoutineReminder(
    routineId: 'school',
    stepId: 'art',
    title: 'Art',
    body: 'Tap to see what to do.',
    hour: 13,
    minute: 5,
    isoWeekday: 3,
  );

  test('the plan carries everything the alarm needs when it fires', () {
    final decoded = jsonDecode(RoutineNativeAlarms.planJson([brush, art]))
        as List<dynamic>;
    expect(decoded, hasLength(2));
    final b = decoded.first as Map<String, dynamic>;
    expect(b, {
      'id': brush.notificationId,
      'routineId': 'morning',
      'stepId': 'brush',
      'title': 'Brushing Teeth',
      'body': 'FlashLearn is waiting for you to do this.',
      'hour': 6,
      'minute': 45,
      'weekday': 0,
      'locks': true,
    });
    final a = decoded.last as Map<String, dynamic>;
    expect(a['weekday'], 3);
    expect(a['locks'], false);
  });

  test('ids stay in the reminder range, so old plugin schedules are found', () {
    expect(RoutineReminderScheduler.isReminderId(brush.notificationId), isTrue);
    expect(RoutineReminderScheduler.isReminderId(art.notificationId), isTrue);
  });

  test('the day is compared as yyyy-MM-dd in local time', () {
    expect(RoutineNativeAlarms.dayStamp(DateTime(2026, 9, 4, 23, 59)), '2026-09-04');
    expect(RoutineNativeAlarms.dayStamp(DateTime(2026, 12, 31)), '2026-12-31');
  });

  group('a launch from a notification', () {
    test('a lock launch names the step and the learner', () {
      final launch = RoutineLaunch.tryParse({
        'payload': 'morning|brush',
        'profile': 'ana',
        'lock': true,
      })!;
      expect(launch.routineId, 'morning');
      expect(launch.stepId, 'brush');
      expect(launch.profileId, 'ana');
      expect(launch.isLock, isTrue);
    });

    test('a plain tap is not a lock', () {
      final launch = RoutineLaunch.tryParse({'payload': 'morning|brush'})!;
      expect(launch.isLock, isFalse);
      expect(launch.profileId, '');
    });

    test('anything malformed is ignored', () {
      expect(RoutineLaunch.tryParse(null), isNull);
      expect(RoutineLaunch.tryParse('morning|brush'), isNull);
      expect(RoutineLaunch.tryParse({'payload': 'brush'}), isNull);
      expect(RoutineLaunch.tryParse({'payload': '|brush'}), isNull);
    });
  });

  test('without the Android side every call is a quiet no-op', () async {
    expect(
      await RoutineNativeAlarms.apply([brush], silent: false, profileId: 'ana'),
      isFalse,
    );
    await RoutineNativeAlarms.setSettled(DateTime(2026, 9, 16), {'brush'});
    await RoutineNativeAlarms.setShowWhenLocked(true);
    expect(await RoutineNativeAlarms.canDrawOverlays(), isFalse);
    expect(await RoutineNativeAlarms.consumeLaunch(), isNull);
  });
}
