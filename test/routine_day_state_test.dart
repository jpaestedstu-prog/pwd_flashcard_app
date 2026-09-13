import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_lock_status.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';

/// The data behind a routine lock that more than one device touches.
///
/// A learner's tablet ticks and excuses on the lock; a Teacher's phone
/// approves, excuses, revokes and starts the day over. Neither sees the other
/// instantly, both keep a copy, and the copies are merged. Everything here is
/// about those copies agreeing on the truth — in particular that a revocation
/// or a reset made on one device is not undone by a stale copy on the other.

const _learner = 'ana';
final _day = DateTime(2026, 9, 14);
DateTime _t(int h, int m) => DateTime(2026, 9, 14, h, m);

RoutineStepMark _mark(
  DateTime at, {
  String by = 'Rose',
  RoutineMarkSource source = RoutineMarkSource.educator,
}) =>
    RoutineStepMark(
      at: at,
      byProfileId: 'rose',
      byName: by,
      byRole: UserRole.teacher,
      source: source,
    );

RoutineDayLog _empty() => RoutineDayLog.empty(_learner, _day);
RoutineDayActions _noActions() => RoutineDayActions.empty(_learner, _day);

const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

const _dress = RoutineStep(
  id: 'dress',
  activity: RoutineActivity.gettingDressed,
  hour: 7,
  minute: 30,
  remindMinutesBefore: 10,
);

Routine _routine({int escalateAfter = 15, bool locks = true}) => Routine(
      id: 'morning',
      childProfileId: _learner,
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush, _dress],
      lockEnabled: locks,
      escalateAfterMinutes: escalateAfter,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('a step mark', () {
    test('the newer of two copies wins', () {
      final early = _mark(_t(6, 50));
      final late = _mark(_t(7, 0), by: 'Kevin');
      expect(RoutineStepMark.latest(early, late)!.byName, 'Kevin');
      expect(RoutineStepMark.latest(late, early)!.byName, 'Kevin');
      expect(RoutineStepMark.latest(null, early), same(early));
    });

    test('a revocation outranks the grant it revokes', () {
      final granted = _mark(_t(6, 50));
      final revoked = granted.revoke(at: _t(7, 5), byName: 'Rose');
      expect(revoked.isActive, isFalse);
      expect(revoked.lastChanged, _t(7, 5));
      expect(RoutineStepMark.latest(granted, revoked)!.isActive, isFalse);
    });

    test('survives a round trip, and garbage is simply no mark', () {
      final m = _mark(_t(6, 50)).revoke(at: _t(7, 0), byName: 'Kevin');
      final back = RoutineStepMark.tryFromJson(m.toJson())!;
      expect(back.at, m.at);
      expect(back.byRole, UserRole.teacher);
      expect(back.source, RoutineMarkSource.educator);
      expect(back.revokedAt, _t(7, 0));
      expect(back.revokedByName, 'Kevin');
      expect(RoutineStepMark.tryFromJson('nonsense'), isNull);
      expect(RoutineStepMark.tryFromJson({'by_name': 'no time'}), isNull);
    });
  });

  group('a learner day log', () {
    test('a tick records when it happened, an un-tick forgets it', () {
      final ticked = _empty().setDone('brush', true, at: _t(6, 52));
      expect(ticked.completedStepIds, {'brush'});
      expect(ticked.completedAt['brush'], _t(6, 52));
      final unticked = ticked.setDone('brush', false);
      expect(unticked.completedStepIds, isEmpty);
      expect(unticked.completedAt, isEmpty);
    });

    test('a reset drops what came before it and keeps what came after', () {
      final log = _empty()
          .setDone('brush', true, at: _t(6, 52))
          .setDone('dress', true, at: _t(7, 40))
          .withLockShown('brush', _t(6, 45))
          .withExcuse('dress', _mark(_t(7, 35)));
      final after = log.applyReset(_t(7, 0));
      expect(after.completedStepIds, {'dress'});
      expect(after.lockShownAt, isEmpty);
      expect(after.excused.keys, {'dress'});
      expect(after.resetAt, _t(7, 0));
    });

    test('the first lock sighting stands', () {
      final log = _empty().withLockShown('brush', _t(6, 45));
      expect(identical(log.withLockShown('brush', _t(6, 50)), log), isTrue);
    });

    test('starting over keeps the frozen schedule', () {
      final log = _empty()
          .withSchedule(const [RoutineDayStep(id: 'brush', activity: RoutineActivity.brushingTeeth)])
          .setDone('brush', true, at: _t(6, 52));
      final reset = log.resetAll(at: _t(7, 0));
      expect(reset.completedStepIds, isEmpty);
      expect(reset.scheduled, hasLength(1));
      expect(reset.resetAt, _t(7, 0));
    });

    group('merging two copies', () {
      test('ticks are a union — nothing earned is taken away', () {
        final a = _empty().setDone('brush', true, at: _t(6, 52));
        final b = _empty().setDone('dress', true, at: _t(7, 32));
        expect(RoutineDayLog.merge(a, b).completedStepIds, {'brush', 'dress'});
      });

      test('a stale copy cannot bring back ticks from before a reset', () {
        // The tablet never saw the reset; the educator's copy did.
        final stale = _empty().setDone('brush', true, at: _t(6, 52));
        final reset = _empty().resetAll(at: _t(7, 0));
        final merged = RoutineDayLog.merge(stale, reset);
        expect(merged.completedStepIds, isEmpty);
        expect(merged.resetAt, _t(7, 0));
        // …in either direction.
        expect(RoutineDayLog.merge(reset, stale).completedStepIds, isEmpty);
      });

      test('a tick made after the reset survives it', () {
        final retick = _empty()
            .setDone('brush', true, at: _t(6, 52))
            .applyReset(_t(7, 0))
            .setDone('brush', true, at: _t(7, 10));
        final other = _empty().resetAll(at: _t(7, 0));
        expect(RoutineDayLog.merge(other, retick).completedStepIds, {'brush'});
      });

      test('the lock keeps its earliest sighting', () {
        final a = _empty().withLockShown('brush', _t(6, 47));
        final b = _empty().withLockShown('brush', _t(6, 45));
        expect(RoutineDayLog.merge(a, b).lockShownAt['brush'], _t(6, 45));
      });

      test('a day that was never reset keeps ticks written before timestamps', () {
        final legacy = RoutineDayLog(
          profileId: _learner,
          day: _day,
          completedStepIds: const {'brush'},
          updatedAt: _t(6, 52),
        );
        expect(RoutineDayLog.merge(legacy, _empty()).completedStepIds, {'brush'});
      });
    });

    test('every new field round-trips, and an old row still parses', () {
      final log = _empty()
          .setDone('brush', true, at: _t(6, 52))
          .withExcuse('dress', _mark(_t(7, 35), source: RoutineMarkSource.learnerDevice))
          .withLockShown('brush', _t(6, 45))
          .withEscalated('brush', _t(7, 0))
          .applyReset(_t(6, 0));
      final back = RoutineDayLog.fromJson(log.toJson());
      expect(back.completedAt['brush'], _t(6, 52));
      expect(back.excused['dress']!.source, RoutineMarkSource.learnerDevice);
      expect(back.lockShownAt['brush'], _t(6, 45));
      expect(back.escalatedAt['brush'], _t(7, 0));
      expect(back.resetAt, _t(6, 0));

      final old = RoutineDayLog.fromJson({
        'profile_id': _learner,
        'day': '2026-09-14',
        'completed_step_ids': ['brush'],
      });
      expect(old.completedStepIds, {'brush'});
      expect(old.completedAt, isEmpty);
      expect(old.resetAt, isNull);
    });
  });

  group('educator actions', () {
    test('merge per step, and the latest reset wins', () {
      final a = _noActions()
          .withExcuse('brush', _mark(_t(6, 50)))
          .withReset(at: _t(6, 0), byName: 'Rose');
      final b = _noActions()
          .withApproval('dress', _mark(_t(7, 40), by: 'Kevin'))
          .withReset(at: _t(7, 20), byName: 'Kevin');
      final merged = RoutineDayActions.merge(a, b);
      expect(merged.excused.keys, {'brush'});
      expect(merged.approved.keys, {'dress'});
      expect(merged.resetAt, _t(7, 20));
      expect(merged.resetByName, 'Kevin');
    });

    test('round-trip', () {
      final a = _noActions()
          .withExcuse('brush', _mark(_t(6, 50)))
          .withApproval('dress', _mark(_t(7, 40)))
          .withReset(at: _t(6, 0), byName: 'Rose');
      final back = RoutineDayActions.fromJson(a.toJson());
      expect(back.excused['brush']!.at, _t(6, 50));
      expect(back.approved['dress']!.at, _t(7, 40));
      expect(back.resetAt, _t(6, 0));
      expect(back.resetByName, 'Rose');
    });
  });

  group('the joined day', () {
    RoutineDayView view({RoutineDayLog? log, RoutineDayActions? actions}) =>
        RoutineDayView.of(
          profileId: _learner,
          day: _day,
          log: log,
          actions: actions,
        );

    test('an educator approval counts as done', () {
      final v = view(actions: _noActions().withApproval('brush', _mark(_t(6, 55))));
      expect(v.isDone('brush'), isTrue);
      expect(v.isTicked('brush'), isFalse);
      expect(v.doneAt('brush'), _t(6, 55));
      expect(v.effectiveLog.completedStepIds, {'brush'});
    });

    test('an excused step is settled but not done', () {
      final v = view(actions: _noActions().withExcuse('brush', _mark(_t(6, 55))));
      expect(v.isExcused('brush'), isTrue);
      expect(v.isDone('brush'), isFalse);
      expect(v.isSettled('brush'), isTrue);
      expect(v.effectiveLog.completedStepIds, isEmpty);
    });

    test('doing an excused step anyway makes it done', () {
      final v = view(
        log: _empty().setDone('brush', true, at: _t(7, 0)),
        actions: _noActions().withExcuse('brush', _mark(_t(6, 55))),
      );
      expect(v.isDone('brush'), isTrue);
      expect(v.isExcused('brush'), isFalse);
    });

    test('an educator can revoke an excuse granted on the tablet', () {
      final onTablet = _mark(_t(6, 50), source: RoutineMarkSource.learnerDevice);
      final v = view(
        log: _empty().withExcuse('brush', onTablet),
        actions: _noActions().withExcuse(
          'brush',
          onTablet.revoke(at: _t(7, 0), byName: 'Rose'),
        ),
      );
      expect(v.excuse('brush'), isNull);
      expect(v.isSettled('brush'), isFalse);
    });

    test("an educator's reset hides the morning before it, not after", () {
      final v = view(
        log: _empty()
            .setDone('brush', true, at: _t(6, 52))
            .setDone('dress', true, at: _t(7, 40)),
        actions: _noActions()
            .withApproval('brush', _mark(_t(6, 53)))
            .withReset(at: _t(7, 0), byName: 'Rose'),
      );
      expect(v.isDone('brush'), isFalse);
      expect(v.isDone('dress'), isTrue);
      expect(v.doneIds, {'dress'});
    });
  });

  group('the lock summary', () {
    RoutineLockSummary at(
      DateTime now, {
      RoutineDayLog? log,
      RoutineDayActions? actions,
      int escalateAfter = 15,
    }) =>
        RoutineLockSummary.of(
          routines: [_routine(escalateAfter: escalateAfter)],
          view: RoutineDayView.of(
            profileId: _learner,
            day: _day,
            log: log,
            actions: actions,
          ),
          now: now,
        );

    RoutineStepPhase phaseOf(RoutineLockSummary s, String id) =>
        s.steps.firstWhere((x) => x.step.id == id).phase;

    test('walks a step through its morning', () {
      expect(phaseOf(at(_t(6, 0)), 'brush'), RoutineStepPhase.later);
      expect(phaseOf(at(_t(6, 41)), 'brush'), RoutineStepPhase.upcoming);
      expect(phaseOf(at(_t(6, 45)), 'brush'), RoutineStepPhase.waiting);
      expect(phaseOf(at(_t(6, 59)), 'brush'), RoutineStepPhase.waiting);
      expect(phaseOf(at(_t(7, 0)), 'brush'), RoutineStepPhase.needsHelp);
      expect(phaseOf(at(_t(7, 46)), 'brush'), RoutineStepPhase.lapsed);
    });

    test("a step's own reminder sets how early it counts as upcoming", () {
      // Getting Dressed reminds ten minutes early, so it is upcoming at 7:21.
      expect(phaseOf(at(_t(7, 21)), 'dress'), RoutineStepPhase.upcoming);
      expect(phaseOf(at(_t(7, 19)), 'dress'), RoutineStepPhase.later);
    });

    test('escalation switched off never asks for help', () {
      expect(
        phaseOf(at(_t(7, 30), escalateAfter: 0), 'brush'),
        RoutineStepPhase.waiting,
      );
    });

    test('done, approved and excused are read from the joined day', () {
      final s = at(
        _t(7, 35),
        log: _empty()
            .withLockShown('brush', _t(6, 45))
            .setDone('brush', true, at: _t(6, 53)),
        actions: _noActions().withExcuse('dress', _mark(_t(7, 31))),
      );
      final brush = s.steps.firstWhere((x) => x.step.id == 'brush');
      expect(brush.phase, RoutineStepPhase.done);
      expect(brush.wasApproved, isFalse);
      expect(brush.minutesHeld, 8);
      expect(phaseOf(s, 'dress'), RoutineStepPhase.excused);
      expect(s.excused.single.mark!.byName, 'Rose');
      expect(s.isHolding, isFalse);

      final approved = at(
        _t(6, 50),
        actions: _noActions().withApproval('brush', _mark(_t(6, 48))),
      );
      expect(approved.approved.single.step.id, 'brush');
    });

    test('the current step is the earliest one holding the device', () {
      final s = at(_t(7, 31));
      expect(s.current!.step.id, 'brush');
      expect(s.needsHelp, isTrue);
      expect(s.current!.minutesWaiting, 46);
    });

    test('a routine that does not lock has nothing to summarise', () {
      final s = RoutineLockSummary.of(
        routines: [_routine(locks: false)],
        view: RoutineDayView.of(profileId: _learner, day: _day),
        now: _t(6, 50),
      );
      expect(s.isEmpty, isTrue);
    });
  });

  group('the audit trail', () {
    test('lists what happened, newest first, including what was undone', () {
      final tabletExcuse =
          _mark(_t(7, 31), by: '', source: RoutineMarkSource.learnerDevice);
      final log = _empty()
          .withLockShown('brush', _t(6, 45))
          .setDone('brush', true, at: _t(6, 53))
          .withEscalated('dress', _t(7, 45))
          .withExcuse('dress', tabletExcuse);
      final actions = _noActions().withExcuse(
        'dress',
        tabletExcuse.revoke(at: _t(7, 50), byName: 'Rose'),
      );

      final events = RoutineLockEvent.forDay(log: log, actions: actions);
      final kinds = events.map((e) => e.kind).toList();
      expect(kinds.first, RoutineLockEventKind.excuseRevoked);
      expect(events.first.byName, 'Rose');
      expect(kinds, contains(RoutineLockEventKind.escalated));
      expect(kinds, contains(RoutineLockEventKind.lockShown));
      final done = events.firstWhere((e) => e.kind == RoutineLockEventKind.done);
      expect(done.minutesHeld, 8);
      expect(kinds.last, RoutineLockEventKind.lockShown);
    });

    test('an excuse taken back from the tablet is listed once', () {
      // Taking back copies the tablet's mark, revoked, into the educator's
      // document; the same excuse now sits in both. Found on the tablet.
      final tabletExcuse =
          _mark(_t(7, 31), by: '', source: RoutineMarkSource.learnerDevice);
      final events = RoutineLockEvent.forDay(
        log: _empty().withExcuse('dress', tabletExcuse),
        actions: _noActions().withExcuse(
          'dress',
          tabletExcuse.revoke(at: _t(7, 50), byName: 'Rose'),
        ),
      );
      expect(events.map((e) => e.kind), [
        RoutineLockEventKind.excuseRevoked,
        RoutineLockEventKind.excused,
      ]);
    });

    test('two separate excuses of one step are both kept', () {
      final first =
          _mark(_t(7, 31), by: '', source: RoutineMarkSource.learnerDevice);
      final events = RoutineLockEvent.forDay(
        log: _empty().withExcuse('dress', first),
        actions: _noActions().withExcuse('dress', _mark(_t(7, 40))),
      );
      expect(
        events.where((e) => e.kind == RoutineLockEventKind.excused),
        hasLength(2),
      );
    });

    test('a reset is recorded with who did it', () {
      final events = RoutineLockEvent.forDay(
        log: _empty(),
        actions: _noActions().withReset(at: _t(7, 0), byName: 'Rose'),
      );
      expect(events.single.kind, RoutineLockEventKind.reset);
      expect(events.single.byName, 'Rose');
    });
  });

  group('escalation setting', () {
    test('defaults to fifteen minutes and is clamped below the lock window', () {
      final base = _routine().toJson()..remove('escalate_after_minutes');
      expect(Routine.fromJson(base).escalateAfterMinutes, 15);
      final huge = _routine().toJson()..['escalate_after_minutes'] = 90;
      expect(Routine.fromJson(huge).escalateAfterMinutes, 45);
      final off = _routine(escalateAfter: 0).toJson();
      expect(Routine.fromJson(off).escalateAfterMinutes, 0);
    });
  });
}
