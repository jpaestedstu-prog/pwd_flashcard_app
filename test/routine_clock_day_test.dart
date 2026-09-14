import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_timeline.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';

/// A Student's or Child's day runs on the clock.
///
/// No "Done", no "I did it!", no "Ask a grown-up": a step starts at its time,
/// is finished when its time ends, and only an adult may finish it early —
/// and only on a step the educator allowed to end early. These are the rules
/// underneath every learner surface, tested without a widget.

const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

const _timed = RoutineStep(
  id: 'dress',
  activity: RoutineActivity.gettingDressed,
  hour: 7,
  minute: 0,
  durationMinutes: 25,
);

const _anyTime = RoutineStep(
  id: 'tidy',
  activity: RoutineActivity.custom,
  title: 'Tidy the toys',
);

DateTime _at(int h, int m) => DateTime(2026, 9, 15, h, m);

void main() {
  group('how long a step lasts', () {
    test('its own duration, or ten minutes when it has none', () {
      expect(_timed.lockMinutes, 25);
      expect(kRoutineDefaultStepMinutes, 10);
      expect(_brush.lockMinutes, kRoutineDefaultStepMinutes);
    });

    test('starts at its time and ends that long after, on the day asked about',
        () {
      expect(_brush.startsOn(_at(0, 0)), _at(6, 45));
      expect(_brush.endsOn(_at(23, 59)), _at(6, 55));
      expect(_timed.endsOn(_at(12, 0)), _at(7, 25));
    });

    test('an unscheduled step has neither', () {
      expect(_anyTime.startsOn(_at(9, 0)), isNull);
      expect(_anyTime.endsOn(_at(9, 0)), isNull);
    });

    test('the end reads as a clock time, across noon too', () {
      expect(formatStepEnd(_brush), '6:55 AM');
      expect(formatStepEnd(_brush.copyWith(hour: 11, minute: 55)), '12:05 PM');
      expect(formatStepEnd(_anyTime), '');
    });
  });

  group('early release', () {
    test('is off unless the educator turns it on — including on a step saved '
        'before it existed', () {
      expect(_brush.releaseEarly, isFalse);
      final old = _brush.toJson()..remove('release_early');
      expect(RoutineStep.fromJson(old).releaseEarly, isFalse);
    });

    test('round-trips, and survives other edits', () {
      final on = _brush.copyWith(releaseEarly: true);
      expect(RoutineStep.fromJson(on.toJson()).releaseEarly, isTrue);
      expect(on.copyWith(askMood: true).releaseEarly, isTrue);
    });
  });

  group('where a step stands', () {
    RoutineStepMoment moment(
      RoutineStep s,
      DateTime now, {
      bool done = false,
      bool excused = false,
    }) =>
        routineStepMoment(s, now: now, done: done, excused: excused);

    test('before, during and after its time', () {
      expect(moment(_brush, _at(6, 44)), RoutineStepMoment.upcoming);
      expect(moment(_brush, _at(6, 45)), RoutineStepMoment.now);
      expect(moment(_brush, _at(6, 54)), RoutineStepMoment.now);
      expect(moment(_brush, _at(6, 55)), RoutineStepMoment.earlier);
    });

    test('an adult finishing it early moves it to earlier at once', () {
      expect(moment(_brush, _at(6, 50), done: true), RoutineStepMoment.earlier);
    });

    test('an excused step is not today', () {
      expect(
        moment(_brush, _at(6, 50), excused: true),
        RoutineStepMoment.excused,
      );
    });

    test('a step with no time is any time', () {
      expect(moment(_anyTime, _at(6, 50)), RoutineStepMoment.anyTime);
    });

    test('the labels say where it stands, never that it is "done"', () {
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.now, filipino: false),
        'Now · until 6:55 AM',
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.now, filipino: true),
        'Ngayon · hanggang 6:55 AM',
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.earlier, filipino: false),
        'Earlier today',
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.excused, filipino: false),
        'Not today',
      );
      expect(
        routineMomentLabel(_brush, RoutineStepMoment.upcoming, filipino: false),
        '',
      );
      for (final m in RoutineStepMoment.values) {
        for (final fil in [false, true]) {
          final words = '${routineMomentLabel(_brush, m, filipino: fil)} '
                  '${routineMomentSpoken(_brush, m, filipino: fil)}'
              .toLowerCase();
          expect(words, isNot(contains('done')), reason: '$m fil=$fil');
          expect(words, isNot(contains('tapos')), reason: '$m fil=$fil');
        }
      }
    });
  });

  group("today's current step", () {
    TodayRoutine day({
      Set<String> done = const {},
      Set<String> excused = const {},
    }) =>
        TodayRoutine(
          steps: const [_brush, _timed, _anyTime],
          log: RoutineDayLog(
            profileId: 'ana',
            day: _at(0, 0),
            completedStepIds: done,
            updatedAt: _at(0, 0),
          ),
          streak: 0,
          hasEducator: true,
          excusedIds: excused,
        );

    test('is the one whose time is running', () {
      expect(day().currentStep(_at(6, 50))!.id, 'brush');
      expect(day().currentStep(_at(7, 10))!.id, 'dress');
      expect(day().currentStep(_at(6, 58)), isNull);
    });

    test('is never a finished or excused one', () {
      expect(day(done: {'brush'}).currentStep(_at(6, 50)), isNull);
      expect(day(excused: {'dress'}).currentStep(_at(7, 10)), isNull);
    });
  });

  group('who runs on the clock', () {
    test('a Student and a Child; a Player ticks their own', () {
      expect(canBeLockedByRoutine(UserRole.student), isTrue);
      expect(canBeLockedByRoutine(UserRole.child), isTrue);
      expect(canBeLockedByRoutine(UserRole.player), isFalse);
      expect(canBeLockedByRoutine(UserRole.teacher), isFalse);
    });
  });

  // Plain `test()`s: these await real Hive writes, which hang inside
  // `testWidgets`. Firebase is not configured, so the local mirror is what is
  // checked — which is also what the learner's device reads the day from.
  group('recording a step as finished when its time ends', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/routine_clock_day');
      if (!Hive.isBoxOpen('routine_logs')) {
        await Hive.openBox('routine_logs');
      }
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <void>[],
      );
    });

    var serial = 0;
    String newLearner() => 'clock-learner-${serial++}';
    const service = RoutineService();
    final today = DateTime(2026, 9, 15);
    final rose = UserProfile(
      id: 'rose',
      name: 'Rose',
      role: UserRole.teacher,
      createdAt: DateTime(2026),
    );

    test('stamps each ended step with the moment its time ended', () async {
      final id = newLearner();
      final log = await service.finishEndedSteps(
        id,
        today,
        const [_brush, _timed, _anyTime],
        now: _at(7, 5),
      );
      expect(log, isNotNull);
      final saved = HiveService.getRoutineDayLog(id, today);
      expect(saved.completedStepIds, {'brush'});
      expect(saved.completedAt['brush'], _at(6, 55));
    });

    test('leaves a running step, an unscheduled step and an excused step alone',
        () async {
      final id = newLearner();
      await service.excuseStep(
        childProfileId: id,
        day: today,
        stepId: 'brush',
        by: rose,
      );
      await service.finishEndedSteps(
        id,
        today,
        const [_brush, _timed, _anyTime],
        now: _at(7, 10),
      );
      final view = RoutineService.viewFromCache(id, today);
      expect(view.isDone('brush'), isFalse);
      expect(view.isExcused('brush'), isTrue);
      expect(view.isDone('dress'), isFalse);
      expect(view.isDone('tidy'), isFalse);
    });

    test('writes nothing twice', () async {
      final id = newLearner();
      expect(
        await service.finishEndedSteps(id, today, const [_brush], now: _at(7, 0)),
        isNotNull,
      );
      expect(
        await service.finishEndedSteps(id, today, const [_brush], now: _at(7, 30)),
        isNull,
      );
      expect(
        HiveService.getRoutineDayLog(id, today).completedAt['brush'],
        _at(6, 55),
      );
    });

    test('an adult who finished it early keeps their own time', () async {
      final id = newLearner();
      await service.setStepDone(id, today, 'brush', true);
      final earlier = HiveService.getRoutineDayLog(id, today).completedAt['brush'];
      expect(
        await service.finishEndedSteps(id, today, const [_brush], now: _at(7, 0)),
        isNull,
      );
      expect(
        HiveService.getRoutineDayLog(id, today).completedAt['brush'],
        earlier,
      );
    });
  });
}
