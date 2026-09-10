import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_reminder_scheduler.dart';

/// The reminder *policy* — which steps notify, when, on which days, and what
/// survives the pending-notification cap.
///
/// All pure: `RoutineReminderScheduler.plan` deliberately takes no plugin and
/// no clock, because the parts that go wrong here (a step reminding on the
/// wrong day, a daily routine consuming seven slots per step, a 5-minute
/// warning wrapping to a negative hour) are arithmetic, not platform.

RoutineStep _step(
  String id, {
  int? hour,
  int? minute = 0,
  int before = 0,
  bool enabled = true,
  RoutineActivity activity = RoutineActivity.breakfast,
}) =>
    RoutineStep(
      id: id,
      activity: activity,
      hour: hour,
      minute: hour == null ? null : minute,
      remindMinutesBefore: before,
      enabled: enabled,
    );

Routine _routine({
  List<RoutineStep> steps = const [],
  Set<int> days = const {},
  bool enabled = true,
  bool reminders = true,
  String id = 'r1',
}) =>
    Routine(
      id: id,
      childProfileId: 'child',
      setterProfileId: 'adult',
      setterRole: UserRole.parent,
      name: 'Morning',
      daysOfWeek: days,
      steps: steps,
      enabled: enabled,
      remindersEnabled: reminders,
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

List<RoutineReminder> _plan(List<Routine> rs, {int cap = 24}) =>
    RoutineReminderScheduler.plan(rs, filipino: false, cap: cap);

void main() {
  group('which steps remind', () {
    test('only scheduled, enabled steps of an enabled, reminding routine', () {
      final r = _routine(steps: [
        _step('timed', hour: 7),
        _step('loose'), // no time — nothing to fire at
        _step('off', hour: 8, enabled: false),
      ]);
      expect(_plan([r]).map((x) => x.stepId), ['timed']);
    });

    test('a routine with reminders switched off is silent', () {
      final r = _routine(steps: [_step('a', hour: 7)], reminders: false);
      expect(_plan([r]), isEmpty);
      expect(r.remindableSteps, isEmpty);
    });

    test('a disabled routine is silent even with reminders on', () {
      final r = _routine(steps: [_step('a', hour: 7)], enabled: false);
      expect(_plan([r]), isEmpty);
    });

    test('routines written before reminders existed still remind', () {
      // The field is absent from those documents; defaulting it to false
      // would leave every existing routine permanently silent.
      final decoded = Routine.fromJson({
        'id': 'r',
        'child_profile_id': 'c',
        'setter_profile_id': 'a',
        'setter_role': UserRole.parent.index,
        'name': 'Old',
        'steps': [
          {'id': 's', 'activity': 0, 'hour': 7, 'minute': 0},
        ],
      });
      expect(decoded.remindersEnabled, isTrue);
      expect(decoded.remindableSteps, hasLength(1));
    });
  });

  group('when they fire', () {
    test('at the step time by default', () {
      final r = _routine(steps: [_step('a', hour: 7, minute: 5)]);
      final one = _plan([r]).single;
      expect(one.hour, 7);
      expect(one.minute, 5);
    });

    test('early when the educator asked for a warning', () {
      final r = _routine(steps: [_step('a', hour: 7, minute: 5, before: 10)]);
      final one = _plan([r]).single;
      expect(one.hour, 6);
      expect(one.minute, 55);
      expect(one.body, contains('In 10 minutes'));
    });

    test('a warning before midnight wraps to the previous day, not a '
        'negative hour', () {
      final r = _routine(steps: [_step('a', hour: 0, minute: 5, before: 10)]);
      final one = _plan([r]).single;
      expect(one.hour, 23);
      expect(one.minute, 55);
    });

    test('the educator note becomes the body when there is no warning', () {
      final r = _routine(steps: [
        _step('a', hour: 7).copyWith(note: 'Use the blue toothbrush'),
      ]);
      expect(_plan([r]).single.body, 'Use the blue toothbrush');
    });

    test('a step with neither note nor warning still says something useful',
        () {
      final r = _routine(steps: [_step('a', hour: 7)]);
      expect(_plan([r]).single.body, isNotEmpty);
    });

    test('the title is the step the learner will see', () {
      final r = _routine(steps: [
        _step('a', hour: 7, activity: RoutineActivity.brushingTeeth),
      ]);
      expect(_plan([r]).single.title, 'Brushing Teeth');
    });

    test('Filipino reminders are in Filipino', () {
      final r = _routine(steps: [_step('a', hour: 7, before: 5)]);
      final fil = RoutineReminderScheduler.plan(
        [r],
        filipino: true,
      ).single;
      expect(fil.body, contains('Sa loob ng 5 minuto'));
      expect(fil.title, 'Almusal');
    });
  });

  group('how many slots they take', () {
    test('an every-day routine is one daily repeat per step, not seven', () {
      // The whole reason `plan` distinguishes daily from weekly: a 12-step
      // daily routine at seven-per-step would be 84 pending notifications and
      // blow past the OS ceiling on its own.
      final steps = [
        for (var i = 0; i < 12; i++) _step('s$i', hour: 6 + i),
      ];
      final plan = _plan([_routine(steps: steps)]);
      expect(plan, hasLength(12));
      expect(plan.every((r) => r.isDaily), isTrue);
    });

    test('a weekday routine is one per (step, day)', () {
      final r = _routine(
        steps: [_step('a', hour: 8), _step('b', hour: 12)],
        days: {1, 3, 5},
      );
      final plan = _plan([r]);
      expect(plan, hasLength(6));
      expect(plan.map((x) => x.isoWeekday).toSet(), {1, 3, 5});
      expect(plan.every((r) => !r.isDaily), isTrue);
    });

    test('the cap keeps the earliest steps of the day', () {
      final steps = [
        for (var i = 0; i < 20; i++) _step('s$i', hour: 4 + i ~/ 2, minute: (i % 2) * 30),
      ];
      final plan = _plan([_routine(steps: steps)], cap: 5);
      expect(plan, hasLength(5));
      // Sorted by time, so the survivors are the morning ones.
      final minutes = plan.map((r) => r.minutesOfDay).toList();
      expect(minutes, orderedEquals([...minutes]..sort()));
      expect(minutes.first, 4 * 60);
    });

    test('several routines are planned together and still capped', () {
      final a = _routine(id: 'a', steps: [_step('a1', hour: 7)]);
      final b = _routine(id: 'b', steps: [_step('b1', hour: 6)]);
      final plan = _plan([a, b]);
      expect(plan, hasLength(2));
      // Earliest first, across routines.
      expect(plan.first.stepId, 'b1');
    });
  });

  group('notification ids', () {
    test('are stable across re-planning, so rescheduling is idempotent', () {
      final r = _routine(steps: [_step('a', hour: 7)]);
      expect(_plan([r]).single.notificationId,
          _plan([r]).single.notificationId);
    });

    test('differ per step, per day and per routine', () {
      final r = _routine(steps: [_step('a', hour: 7), _step('b', hour: 8)]);
      final ids = _plan([r]).map((x) => x.notificationId).toSet();
      expect(ids, hasLength(2));

      final weekly = _routine(steps: [_step('a', hour: 7)], days: {1, 2, 3});
      expect(
        _plan([weekly]).map((x) => x.notificationId).toSet(),
        hasLength(3),
      );

      final other = _routine(id: 'r2', steps: [_step('a', hour: 7)]);
      expect(
        _plan([r]).first.notificationId,
        isNot(_plan([other]).first.notificationId),
      );
    });

    test('sit clear of the alarm scheduler\'s id range', () {
      // AlarmScheduler uses `1000 + (hash16 * 8) + weekday`, so it occupies
      // up to ~525,287. Two schedulers cancelling each other's notifications
      // would be a miserable bug to track down.
      final r = _routine(steps: [
        for (var i = 0; i < 40; i++) _step('s$i', hour: i % 24),
      ]);
      for (final rem in _plan([r], cap: 40)) {
        expect(rem.notificationId, greaterThan(600000));
      }
    });
  });

  group('accessibility', () {
    test('a Deaf learner gets the silent, vibrating channel', () {
      // A tone they cannot hear is a notification only for the room.
      expect(
        RoutineReminderScheduler.usesSilentChannel(DisabilityType.hearing),
        isTrue,
      );
      for (final t in DisabilityType.values) {
        if (t == DisabilityType.hearing) continue;
        expect(
          RoutineReminderScheduler.usesSilentChannel(t),
          isFalse,
          reason: '$t should keep the audible channel',
        );
      }
    });
  });
}
