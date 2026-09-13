import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_reminder_scheduler.dart';

/// A step that is excused or already done has nothing to remind about today —
/// but the reminder for every day after must survive.
///
/// Both halves are pure: when a reminder first fires (optionally not today),
/// and which reminders need re-scheduling when today's settled steps change.
/// 2026-09-16 is a Wednesday.
void main() {
  group('when a reminder first fires', () {
    DateTime fire(
      DateTime now, {
      int? weekday,
      bool skipToday = false,
    }) =>
        RoutineReminderScheduler.firstFireAfter(
          now: now,
          hour: 6,
          minute: 45,
          isoWeekday: weekday,
          skipToday: skipToday,
        );

    test('a daily reminder still ahead today fires today', () {
      expect(fire(DateTime(2026, 9, 16, 6)), DateTime(2026, 9, 16, 6, 45));
    });

    test('one whose time has passed fires tomorrow', () {
      expect(fire(DateTime(2026, 9, 16, 7)), DateTime(2026, 9, 17, 6, 45));
    });

    test('skipping today moves even a later-today reminder to tomorrow', () {
      expect(
        fire(DateTime(2026, 9, 16, 6), skipToday: true),
        DateTime(2026, 9, 17, 6, 45),
      );
    });

    test('a weekly reminder skipped today comes back next week', () {
      expect(
        fire(DateTime(2026, 9, 16, 6), weekday: 3),
        DateTime(2026, 9, 16, 6, 45),
      );
      expect(
        fire(DateTime(2026, 9, 16, 6), weekday: 3, skipToday: true),
        DateTime(2026, 9, 23, 6, 45),
      );
    });

    test('skipping today leaves a different weekday alone', () {
      expect(
        fire(DateTime(2026, 9, 16, 6), weekday: 5, skipToday: true),
        DateTime(2026, 9, 18, 6, 45),
      );
    });

    test('rolls over the end of a month and a year', () {
      expect(fire(DateTime(2026, 9, 30, 7)), DateTime(2026, 10, 1, 6, 45));
      expect(
        fire(DateTime(2026, 12, 31, 6), skipToday: true),
        DateTime(2027, 1, 1, 6, 45),
      );
    });
  });

  group('which reminders change', () {
    RoutineReminder r(String step, {int? weekday}) => RoutineReminder(
          routineId: 'morning',
          stepId: step,
          title: 'Brushing Teeth',
          body: '',
          hour: 6,
          minute: 45,
          isoWeekday: weekday,
        );

    test('a settled step skips today; the rest are untouched', () {
      final brush = r('brush');
      final dress = r('dress');
      expect(
        RoutineReminderScheduler.suppressionChanges(
          plan: [brush, dress],
          settled: {'brush'},
          suppressed: {},
        ),
        {brush.notificationId: true},
      );
    });

    test('an already-skipped step is not scheduled again', () {
      final brush = r('brush');
      expect(
        RoutineReminderScheduler.suppressionChanges(
          plan: [brush],
          settled: {'brush'},
          suppressed: {brush.notificationId},
        ),
        isEmpty,
      );
    });

    test('a step that is no longer settled gets today back', () {
      final brush = r('brush');
      expect(
        RoutineReminderScheduler.suppressionChanges(
          plan: [brush],
          settled: {},
          suppressed: {brush.notificationId},
        ),
        {brush.notificationId: false},
      );
    });

    test('every weekly copy of a settled step is covered', () {
      final mon = r('brush', weekday: 1);
      final wed = r('brush', weekday: 3);
      expect(
        RoutineReminderScheduler.suppressionChanges(
          plan: [mon, wed],
          settled: {'brush'},
          suppressed: {},
        ).keys,
        {mon.notificationId, wed.notificationId},
      );
    });
  });

  test('checking before the scheduler has started does nothing', () async {
    // Every widget test, and every profile with no reminders.
    await RoutineReminderScheduler.refreshSettled();
  });
}
