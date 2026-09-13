import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  group('skipping today without losing the days after', () {
    // The plugin ignores the first date of a repeating schedule and fires at
    // the next matching time from now — on the tablet, a step done at 4:30
    // still got its 4:35 reminder. A skipped day is therefore built from
    // schedules that cannot land today, not from a later start date.
    RoutineReminder r({int? weekday}) => RoutineReminder(
          routineId: 'morning',
          stepId: 'brush',
          title: 'Brushing Teeth',
          body: '',
          hour: 6,
          minute: 45,
          isoWeekday: weekday,
        );
    final wed6 = DateTime(2026, 9, 16, 6);

    test('a daily reminder that is not skipped stays one daily repeat', () {
      final slots = RoutineReminderScheduler.slotsFor(
        r(),
        now: wed6,
        skipToday: false,
      );
      expect(slots.single.id, r().notificationId);
      expect(slots.single.firstFire, DateTime(2026, 9, 16, 6, 45));
      expect(slots.single.repeat, DateTimeComponents.time);
    });

    test('a daily reminder skipped today becomes a week that misses today', () {
      final slots = RoutineReminderScheduler.slotsFor(
        r(),
        now: wed6,
        skipToday: true,
      );
      expect(
        slots.map((s) => s.id).toSet(),
        {for (var wd = 1; wd <= 7; wd++) r().notificationId + wd},
      );
      for (final s in slots) {
        expect(s.firstFire.isAfter(DateTime(2026, 9, 17)), isTrue);
        expect((s.firstFire.hour, s.firstFire.minute), (6, 45));
      }

      // Every other weekday repeats by itself, starting tomorrow…
      final repeating = slots.where((s) => s.repeat != null).toList();
      expect(repeating, hasLength(6));
      for (final s in repeating) {
        expect(s.repeat, DateTimeComponents.dayOfWeekAndTime);
        expect(s.firstFire.weekday, isNot(DateTime.wednesday));
      }
      expect(
        repeating.map((s) => s.firstFire).reduce((a, b) => a.isBefore(b) ? a : b),
        DateTime(2026, 9, 17, 6, 45),
      );

      // …and today's weekday comes back next week.
      final wed = slots.singleWhere((s) => s.repeat == null);
      expect(wed.firstFire, DateTime(2026, 9, 23, 6, 45));
    });

    test('once the time has passed there is nothing left to skip', () {
      final slots = RoutineReminderScheduler.slotsFor(
        r(),
        now: DateTime(2026, 9, 16, 7),
        skipToday: true,
      );
      expect(slots.single.id, r().notificationId);
      expect(slots.single.firstFire, DateTime(2026, 9, 17, 6, 45));
      expect(slots.single.repeat, DateTimeComponents.time);
      expect(
        RoutineReminderScheduler.expandsToSkip(r(), DateTime(2026, 9, 16, 7)),
        isFalse,
      );
    });

    test('a weekly reminder skipped on its own day fires once next week', () {
      final slots = RoutineReminderScheduler.slotsFor(
        r(weekday: 3),
        now: wed6,
        skipToday: true,
      );
      expect(slots.single.id, r(weekday: 3).notificationId);
      expect(slots.single.firstFire, DateTime(2026, 9, 23, 6, 45));
      expect(slots.single.repeat, isNull);
    });

    test('a weekly reminder on another day keeps repeating', () {
      final slots = RoutineReminderScheduler.slotsFor(
        r(weekday: 5),
        now: wed6,
        skipToday: true,
      );
      expect(slots.single.firstFire, DateTime(2026, 9, 18, 6, 45));
      expect(slots.single.repeat, DateTimeComponents.dayOfWeekAndTime);
    });

    test('every id a reminder can occupy is cleared together', () {
      expect(
        RoutineReminderScheduler.variantIds(r()),
        {for (var wd = 0; wd <= 7; wd++) r().notificationId + wd},
      );
      expect(
        RoutineReminderScheduler.variantIds(r(weekday: 3)),
        {r(weekday: 3).notificationId},
      );
      for (final id in RoutineReminderScheduler.variantIds(r())) {
        expect(RoutineReminderScheduler.isReminderId(id), isTrue);
      }
      expect(RoutineReminderScheduler.isReminderId(2000123), isFalse);
      expect(RoutineReminderScheduler.isReminderId(1234), isFalse);
    });

    test('at no minute of the day does a skipped reminder fire today', () {
      // Modelled the way the plugin behaves: a daily repeat fires at the
      // next matching time from now, a weekly one on its weekday, a one-off
      // at its date.
      for (var m = 0; m < 24 * 60; m += 5) {
        final now = DateTime(2026, 9, 16, m ~/ 60, m % 60);
        final today = DateTime(2026, 9, 16, 6, 45);
        for (final s in RoutineReminderScheduler.slotsFor(
          r(),
          now: now,
          skipToday: true,
        )) {
          final reason = 'now=$now slot=$s';
          switch (s.repeat) {
            case DateTimeComponents.time:
              expect(today.isAfter(now), isFalse, reason: reason);
            case DateTimeComponents.dayOfWeekAndTime:
              expect(s.firstFire.weekday, isNot(now.weekday), reason: reason);
            default:
              expect(s.firstFire.day == 16, isFalse, reason: reason);
          }
        }
      }
    });
  });

  test('checking before the scheduler has started does nothing', () async {
    // Every widget test, and every profile with no reminders.
    await RoutineReminderScheduler.refreshSettled();
  });
}
