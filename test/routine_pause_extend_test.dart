import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/lock_enforcer.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_lock_status.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_timeline.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';

/// An adult's pause and "add time" on a running step, from the educator's
/// dashboard: the step's end moves, a pause lifts the lock and freezes the
/// countdown, and every surface — the lock, My Day, the dashboard — reads the
/// same moved end.

final _day = DateTime(2026, 9, 15);
DateTime _at(int h, int m, [int s = 0]) => DateTime(2026, 9, 15, h, m, s);

/// 7:00–7:10.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 7,
  minute: 0,
  durationMinutes: 10,
);

Routine _routine(List<RoutineStep> steps) => Routine(
      id: 'r',
      childProfileId: 'ana',
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: steps,
      lockEnabled: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineDayView _view(RoutineStepAdjustment? adj, {RoutineDayLog? log}) =>
    RoutineDayView.of(
      profileId: 'ana',
      day: _day,
      log: log,
      actions: adj == null
          ? null
          : RoutineDayActions.empty('ana', _day).withAdjustment('brush', adj),
    );

void main() {
  group('RoutineStepAdjustment', () {
    test('added minutes move the end; a cap stops two hours more', () {
      final a = RoutineStepAdjustment(changedAt: _at(7, 2))
          .withAddedMinutes(10, at: _at(7, 2));
      expect(a.shiftAt(_at(7, 3)), const Duration(minutes: 10));
      final capped = a.withAddedMinutes(500, at: _at(7, 4));
      expect(capped.addedMinutes, kRoutineMaxAddedMinutes);
    });

    test('a pause moves the end with the clock, and resuming keeps it', () {
      final paused = RoutineStepAdjustment(changedAt: _at(7, 4))
          .paused(at: _at(7, 4), byName: 'Rose');
      expect(paused.isPaused, isTrue);
      expect(paused.byName, 'Rose');
      // Six minutes into the pause the end is six minutes later.
      expect(paused.shiftAt(_at(7, 10)), const Duration(minutes: 6));
      final resumed = paused.resumed(at: _at(7, 10));
      expect(resumed.isPaused, isFalse);
      expect(resumed.pausedSeconds, 360);
      expect(resumed.shiftAt(_at(7, 20)), const Duration(minutes: 6));
      // Pausing twice or resuming a running step changes nothing.
      expect(paused.paused(at: _at(7, 8)).pausedAt, _at(7, 4));
      expect(resumed.resumed(at: _at(7, 30)).pausedSeconds, 360);
    });

    test('round-trips through json, and the actions document keeps it', () {
      final a = RoutineStepAdjustment(changedAt: _at(7, 4))
          .withAddedMinutes(5, at: _at(7, 4), byProfileId: 'rose', byName: 'Rose')
          .paused(at: _at(7, 5), byProfileId: 'rose', byName: 'Rose');
      final back = RoutineStepAdjustment.tryFromJson(a.toJson())!;
      expect(back.addedMinutes, 5);
      expect(back.pausedAt, _at(7, 5));
      expect(back.byName, 'Rose');

      final actions =
          RoutineDayActions.empty('ana', _day).withAdjustment('brush', a);
      final restored = RoutineDayActions.fromJson(actions.toJson());
      expect(restored.adjustments['brush']!.addedMinutes, 5);
      expect(restored.isEmpty, isFalse);
      // A document written before adjustments existed reads as none.
      final old = actions.toJson()..remove('adjustments');
      expect(RoutineDayActions.fromJson(old).adjustments, isEmpty);
    });

    test('a merge keeps the copy that changed last, not a sum', () {
      final local = RoutineDayActions.empty('ana', _day).withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _at(7, 2))
            .withAddedMinutes(10, at: _at(7, 2)),
      );
      final remote = RoutineDayActions.empty('ana', _day).withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _at(7, 3))
            .withAddedMinutes(10, at: _at(7, 3)),
      );
      final merged = RoutineDayActions.merge(local, remote);
      expect(merged.adjustments['brush']!.addedMinutes, 10);
      expect(merged.adjustments['brush']!.changedAt, _at(7, 3));
    });

    test('corrupt rows read as nothing rather than throwing', () {
      expect(RoutineStepAdjustment.tryFromJson('nope'), isNull);
      expect(RoutineStepAdjustment.tryFromJson({'added_minutes': 5}), isNull);
    });
  });

  group('the day view answers "when does it end?"', () {
    test('as planned without an adjustment', () {
      expect(_view(null).endOf(_brush, _at(7, 3)), _at(7, 10));
      expect(_view(null).isPaused('brush'), isFalse);
      expect(_view(null).movedEnds([_brush], _at(7, 3)), isEmpty);
    });

    test('later by the added time', () {
      final v = _view(RoutineStepAdjustment(changedAt: _at(7, 2))
          .withAddedMinutes(15, at: _at(7, 2)));
      expect(v.endOf(_brush, _at(7, 3)), _at(7, 25));
      expect(v.movedEnds([_brush], _at(7, 3)), {'brush': _at(7, 25)});
    });

    test('frozen while paused — the time left stays the same', () {
      final v = _view(RoutineStepAdjustment(changedAt: _at(7, 4))
          .paused(at: _at(7, 4)));
      expect(v.isPaused('brush'), isTrue);
      expect(v.pausedIds, {'brush'});
      final leftAt5 = v.endOf(_brush, _at(7, 5))!.difference(_at(7, 5));
      final leftAt30 = v.endOf(_brush, _at(7, 30))!.difference(_at(7, 30));
      expect(leftAt5, const Duration(minutes: 6));
      expect(leftAt30, leftAt5);
    });

    test('a step settled after its pause is not paused any more', () {
      final log = RoutineDayLog.empty('ana', _day).setDone('brush', true,
          at: _at(7, 8));
      final v = _view(
        RoutineStepAdjustment(changedAt: _at(7, 4)).paused(at: _at(7, 4)),
        log: log,
      );
      expect(v.isPaused('brush'), isFalse);
    });

    test('a reset after the adjustment wipes it', () {
      final actions = RoutineDayActions.empty('ana', _day)
          .withAdjustment(
            'brush',
            RoutineStepAdjustment(changedAt: _at(7, 2))
                .withAddedMinutes(10, at: _at(7, 2)),
          )
          .withReset(at: _at(7, 3));
      final v = RoutineDayView.of(profileId: 'ana', day: _day, actions: actions);
      expect(v.adjustment('brush'), isNull);
      expect(v.endOf(_brush, _at(7, 4)), _at(7, 10));
    });
  });

  group('the lock', () {
    test('holds past the planned end when time was added', () {
      final due = LockEnforcer.routineStepDue(
        steps: const [_brush],
        completedStepIds: const {},
        skippedStepIds: const {},
        now: _at(7, 15),
        endsAt: {'brush': _at(7, 20)},
      );
      expect(due?.id, 'brush');
      expect(
        LockEnforcer.routineStepDue(
          steps: const [_brush],
          completedStepIds: const {},
          skippedStepIds: const {},
          now: _at(7, 15),
        ),
        isNull,
        reason: 'without the added time the step is over at 7:10',
      );
    });

    test('lets go while an adult has paused the step', () {
      final reason = LockEnforcer.evaluate(
        limit: null,
        minutesUsedToday: 0,
        alarms: const [],
        now: _at(7, 5),
        routineSteps: const [_brush],
        pausedStepIds: const {'brush'},
      );
      expect(reason, isNull);
    });
  });

  group('the timeline and Today card', () {
    test('a paused step reads as paused; a moved end is the one shown', () {
      expect(
        routineStepMoment(_brush,
            now: _at(7, 5), done: false, excused: false, paused: true),
        RoutineStepMoment.paused,
      );
      expect(
        routineStepMoment(_brush,
            now: _at(7, 15),
            done: false,
            excused: false,
            endsAt: _at(7, 20)),
        RoutineStepMoment.now,
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.now,
            filipino: false, endsAt: _at(7, 20)),
        'Now · until 7:20 AM',
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.paused, filipino: false),
        'Paused',
      );
      expect(formatStepEnd(_brush, end: _at(19, 5)), '7:05 PM');
      expect(minutesUntilEnd(_at(7, 10), _at(7, 8, 30)), 2);
      expect(minutesUntilEnd(_at(7, 10), _at(7, 11)), 0);
    });

    test('TodayRoutine skips a paused step as "now" and reports it paused',
        () {
      final paused = _view(
        RoutineStepAdjustment(changedAt: _at(7, 4)).paused(at: _at(7, 4)),
      );
      final today = TodayRoutine(
        steps: const [_brush],
        log: RoutineDayLog.empty('ana', _day),
        streak: 0,
        hasEducator: true,
        view: paused,
      );
      expect(today.currentStep(_at(7, 5)), isNull);
      expect(today.pausedStep(_at(7, 5))?.id, 'brush');
      expect(today.pausedIds, {'brush'});

      final longer = TodayRoutine(
        steps: const [_brush],
        log: RoutineDayLog.empty('ana', _day),
        streak: 0,
        hasEducator: true,
        view: _view(RoutineStepAdjustment(changedAt: _at(7, 2))
            .withAddedMinutes(10, at: _at(7, 2))),
      );
      expect(longer.currentStep(_at(7, 15))?.id, 'brush');
      expect(longer.endOf(_brush, _at(7, 15)), _at(7, 20));
    });
  });

  group('the dashboard status', () {
    test('a paused step is its own phase, with the time it has left', () {
      final v = _view(
        RoutineStepAdjustment(changedAt: _at(7, 4)).paused(at: _at(7, 4)),
      );
      final status = RoutineLockSummary.statusFor(
        routine: _routine(const [_brush]),
        step: _brush,
        view: v,
        now: _at(7, 30),
      );
      expect(status.phase, RoutineStepPhase.paused);
      expect(status.isPaused, isTrue);
      expect(status.isHolding, isFalse);
      expect(status.minutesLeft, 6);

      final summary = RoutineLockSummary.of(
        routines: [_routine(const [_brush])],
        view: v,
        now: _at(7, 30),
      );
      expect(summary.current, isNull);
      expect(summary.paused?.step.id, 'brush');
    });

    test('added time keeps the step waiting and says how much was added', () {
      final v = _view(RoutineStepAdjustment(changedAt: _at(7, 2))
          .withAddedMinutes(15, at: _at(7, 2)));
      final status = RoutineLockSummary.statusFor(
        routine: _routine(const [_brush]),
        step: _brush,
        view: v,
        now: _at(7, 12),
      );
      expect(status.phase, RoutineStepPhase.waiting);
      expect(status.endsAt, _at(7, 25));
      expect(status.addedMinutes, 15);
      expect(status.minutesLeft, 13);
    });
  });
}
