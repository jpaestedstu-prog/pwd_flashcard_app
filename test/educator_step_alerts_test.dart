import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/educator_step_alerts.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';

/// Start and end alerts for a Teacher or Parent, scheduled on their own
/// device: which steps, when, in what words — and never for a step an adult
/// already finished, excused or paused.

final _day = DateTime(2026, 9, 15);
DateTime _at(int h, int m) => DateTime(2026, 9, 15, h, m);

/// 7:00–7:10, locks.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 7,
  minute: 0,
  durationMinutes: 10,
);

/// 8:00–8:20, does not lock.
const _breakfast = RoutineStep(
  id: 'breakfast',
  activity: RoutineActivity.breakfast,
  hour: 8,
  minute: 0,
  durationMinutes: 20,
  lockScreen: false,
);

Routine _routine({Set<int> days = const {}}) => Routine(
      id: 'r',
      childProfileId: 'ana',
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush, _breakfast],
      lockEnabled: true,
      daysOfWeek: days,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

EducatorAlertLearner _ana({RoutineDayView? today, Set<int> days = const {}}) =>
    EducatorAlertLearner(
      profileId: 'ana',
      name: 'Ana',
      routines: [_routine(days: days)],
      today: today,
    );

RoutineDayView _view({RoutineDayLog? log, RoutineDayActions? actions}) =>
    RoutineDayView.of(profileId: 'ana', day: _day, log: log, actions: actions);

RoutineStepMark _mark(DateTime at) => RoutineStepMark(
      at: at,
      byProfileId: 'rose',
      byName: 'Rose',
      source: RoutineMarkSource.educator,
    );

void main() {
  test('locked steps: a start and an end alert, in plain words', () {
    final plan = EducatorStepAlertPlan.plan(
      learners: [_ana(today: _view())],
      now: _at(6, 0),
      mode: EducatorAlertMode.lockedSteps,
      filipino: false,
    );
    final today = plan.where((a) => a.at.day == 15).toList();
    expect(today.map((a) => a.kind), [
      EducatorStepAlertKind.started,
      EducatorStepAlertKind.ended,
    ]);
    expect(today.first.at, _at(7, 0));
    expect(today.first.title, '🔒 Ana: Brushing Teeth');
    expect(today.first.body, 'Ana’s tablet is locked on Brushing Teeth until 7:10 AM.');
    expect(today.last.at, _at(7, 10));
    expect(today.last.title, '✅ Ana: Brushing Teeth is over');
    expect(today.last.body, 'Ana’s tablet is unlocked.');
  });

  test('every step: the step that does not lock is included too', () {
    final plan = EducatorStepAlertPlan.plan(
      learners: [_ana(today: _view())],
      now: _at(6, 0),
      mode: EducatorAlertMode.everyStep,
      filipino: false,
    ).where((a) => a.at.day == 15).toList();
    expect(plan.length, 4);
    final breakfastStart = plan.firstWhere(
      (a) => a.stepId == 'breakfast' && a.kind == EducatorStepAlertKind.started,
    );
    expect(breakfastStart.title, '⏰ Ana: Breakfast');
    expect(breakfastStart.body, 'Breakfast has started for Ana. It ends at 8:20 AM.');
  });

  test('off plans nothing', () {
    expect(
      EducatorStepAlertPlan.plan(
        learners: [_ana(today: _view())],
        now: _at(6, 0),
        mode: EducatorAlertMode.off,
        filipino: false,
      ),
      isEmpty,
    );
  });

  test('only what is still ahead, within a day', () {
    final plan = EducatorStepAlertPlan.plan(
      learners: [_ana(today: _view())],
      now: _at(7, 5),
      mode: EducatorAlertMode.lockedSteps,
      filipino: false,
    );
    // Today's start is past; today's end is ahead; tomorrow's start at 7:00
    // is within 24 hours, tomorrow's end at 7:10 is not.
    expect(plan.map((a) => (a.kind, a.at)).toList(), [
      (EducatorStepAlertKind.ended, _at(7, 10)),
      (EducatorStepAlertKind.started, DateTime(2026, 9, 16, 7)),
    ]);
  });

  test('a step already finished, excused or paused gets no end alert', () {
    for (final view in [
      _view(actions: RoutineDayActions.empty('ana', _day)
          .withApproval('brush', _mark(_at(7, 4)))),
      _view(actions: RoutineDayActions.empty('ana', _day)
          .withExcuse('brush', _mark(_at(7, 4)))),
      _view(actions: RoutineDayActions.empty('ana', _day).withAdjustment(
            'brush',
            RoutineStepAdjustment(changedAt: _at(7, 4)).paused(at: _at(7, 4)),
          )),
    ]) {
      final plan = EducatorStepAlertPlan.plan(
        learners: [_ana(today: view)],
        now: _at(7, 5),
        mode: EducatorAlertMode.lockedSteps,
        filipino: false,
      ).where((a) => a.at.day == 15);
      expect(plan, isEmpty);
    }
  });

  test('added time moves the end alert', () {
    final view = _view(
      actions: RoutineDayActions.empty('ana', _day).withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _at(7, 4))
            .withAddedMinutes(10, at: _at(7, 4)),
      ),
    );
    final end = EducatorStepAlertPlan.plan(
      learners: [_ana(today: view)],
      now: _at(7, 5),
      mode: EducatorAlertMode.lockedSteps,
      filipino: false,
    ).firstWhere((a) => a.kind == EducatorStepAlertKind.ended);
    expect(end.at, _at(7, 20));
  });

  test('a routine that does not run today plans nothing for today', () {
    // 2026-09-15 is a Tuesday; this routine runs on Mondays only.
    final plan = EducatorStepAlertPlan.plan(
      learners: [_ana(today: _view(), days: {1})],
      now: _at(6, 0),
      mode: EducatorAlertMode.lockedSteps,
      filipino: false,
    );
    expect(plan, isEmpty);
  });

  test('the cap keeps the earliest alerts', () {
    final plan = EducatorStepAlertPlan.plan(
      learners: [
        for (var i = 0; i < 30; i++)
          EducatorAlertLearner(
            profileId: 'kid$i',
            name: 'Kid $i',
            routines: [_routine()],
          ),
      ],
      now: _at(6, 0),
      mode: EducatorAlertMode.lockedSteps,
      filipino: false,
    );
    expect(plan.length, EducatorStepAlertPlan.maxPending);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
    }
  });

  test('Filipino wording', () {
    final plan = EducatorStepAlertPlan.plan(
      learners: [_ana(today: _view())],
      now: _at(6, 0),
      mode: EducatorAlertMode.lockedSteps,
      filipino: true,
    );
    expect(plan.first.body,
        'Naka-lock ang tablet ni Ana sa Pagsisipilyo hanggang 7:10 AM.');
  });

  group('ended early', () {
    test('noticed when a running step is finished by an adult', () {
      final running = EducatorStepAlertPlan.runningIds(
        _ana(today: _view()),
        _at(7, 3),
        EducatorAlertMode.lockedSteps,
      );
      expect(running, {'brush'});

      final after = _ana(
        today: _view(
          actions: RoutineDayActions.empty('ana', _day)
              .withApproval('brush', _mark(_at(7, 4))),
        ),
      );
      final alerts = EducatorStepAlertPlan.endedEarly(
        learner: after,
        wasRunning: running,
        now: _at(7, 4),
        mode: EducatorAlertMode.lockedSteps,
        filipino: false,
      );
      expect(alerts.single.kind, EducatorStepAlertKind.endedEarly);
      expect(alerts.single.title, '✅ Ana: Brushing Teeth ended early');
      expect(alerts.single.body, 'Rose ended it at 7:04 AM.');
    });

    test('an excuse on the tablet names nobody', () {
      final log = RoutineDayLog.empty('ana', _day).withExcuse(
        'brush',
        RoutineStepMark(
          at: _at(7, 4),
          byProfileId: '',
          byName: '',
          source: RoutineMarkSource.learnerDevice,
        ),
      );
      final alerts = EducatorStepAlertPlan.endedEarly(
        learner: _ana(today: _view(log: log)),
        wasRunning: const {'brush'},
        now: _at(7, 4),
        mode: EducatorAlertMode.lockedSteps,
        filipino: false,
      );
      expect(alerts.single.title, '✅ Ana: Brushing Teeth excused');
      expect(alerts.single.body, 'An adult excused it on the tablet at 7:04 AM.');
    });

    test('a step that simply ran out is not "early"', () {
      final log = RoutineDayLog.empty('ana', _day)
          .setDone('brush', true, at: _at(7, 10));
      final alerts = EducatorStepAlertPlan.endedEarly(
        learner: _ana(today: _view(log: log)),
        wasRunning: const {'brush'},
        now: _at(7, 10),
        mode: EducatorAlertMode.lockedSteps,
        filipino: false,
      );
      expect(alerts, isEmpty);
    });
  });

  test('the mode is read back from its stored index, defaulting safely', () {
    expect(EducatorAlertMode.fromIndex(0), EducatorAlertMode.off);
    expect(EducatorAlertMode.fromIndex(2), EducatorAlertMode.everyStep);
    expect(EducatorAlertMode.fromIndex(null), EducatorAlertMode.lockedSteps);
    expect(EducatorAlertMode.fromIndex(99), EducatorAlertMode.lockedSteps);
  });
}
