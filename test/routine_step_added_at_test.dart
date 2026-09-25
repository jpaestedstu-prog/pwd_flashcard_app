import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_copy.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';

/// A step added after its time is not part of that day.
///
/// `routine_first_day_test` covers a whole routine made late in the day. This
/// covers one step added later to a routine the learner already follows: at
/// 2 PM an educator adds "Break Time, 1:30 PM" to a routine made at 8 AM. The
/// routine is old enough that the first-day rule never looked at it, so on a
/// Student's or Child's clock (a step is finished when its time ends) the new
/// step was written as finished, back-dated to 1:40, the moment it arrived —
/// a completion that never happened, on the dashboard and in the history.
///
/// The fix is a per-step timestamp, [RoutineStep.addedAt], stamped by
/// [RoutineService.save]. Plain `test()` with real Hive: the stamp is decided
/// against the cached copy, and awaited Hive writes must not run inside
/// `testWidgets`.

RoutineStep _at(String id, int hour, int minute, {DateTime? addedAt}) =>
    RoutineStep(
      id: id,
      activity: RoutineActivity.custom,
      hour: hour,
      minute: minute,
      durationMinutes: 10,
      addedAt: addedAt,
    );

Routine _routine({
  String id = 'r1',
  required DateTime createdAt,
  required List<RoutineStep> steps,
}) =>
    Routine(
      id: id,
      childProfileId: 'kid',
      setterProfileId: 'teacher',
      setterRole: UserRole.teacher,
      name: 'School Day',
      steps: steps,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

List<String> _ids(List<RoutineStep> steps) => [for (final s in steps) s.id];

void main() {
  final friday = DateTime(2026, 9, 25);
  final eightAm = DateTime(2026, 9, 25, 8);
  final twoPm = DateTime(2026, 9, 25, 14);

  group('RoutineStep.addedAt on the day', () {
    test('a step added at 2 PM with a 1:30 PM time is not part of that day',
        () {
      final r = _routine(
        createdAt: eightAm,
        steps: [
          _at('class', 9, 0),
          _at('break', 13, 30, addedAt: twoPm),
          _at('play', 15, 0, addedAt: twoPm),
        ],
      );
      expect(
        _ids(r.stepsOn(friday)),
        ['class', 'play'],
        reason: 'the rest of the day, and a later step added at 2 PM, stay',
      );
      expect(r.startsAfter(friday), isFalse);
    });

    test('the next day the added step is part of the day', () {
      final r = _routine(
        createdAt: eightAm,
        steps: [_at('class', 9, 0), _at('break', 13, 30, addedAt: twoPm)],
      );
      expect(_ids(r.stepsOn(DateTime(2026, 9, 26))), ['class', 'break']);
    });

    test('its own stamp decides, not the routine\'s creation', () {
      // Made the evening before, so the routine-level rule never applied.
      final r = _routine(
        createdAt: DateTime(2026, 9, 24, 20),
        steps: [_at('break', 13, 30, addedAt: twoPm)],
      );
      expect(r.stepsOn(friday), isEmpty);
      expect(r.startsAfter(friday), isTrue);
    });

    test('a step saved before stamps existed counts from the routine', () {
      final r = _routine(
        createdAt: eightAm,
        steps: [_at('wake', 6, 30), _at('class', 9, 0)],
      );
      expect(_ids(r.stepsOn(friday)), ['class']);
      expect(_ids(r.stepsOn(DateTime(2026, 9, 26))), ['wake', 'class']);
    });

    test('added_at survives JSON, and is absent on an unstamped step', () {
      final stamped = _at('break', 13, 30, addedAt: twoPm);
      final back = RoutineStep.fromJson(stamped.toJson());
      expect(back.addedAt, twoPm);
      expect(_at('class', 9, 0).toJson().containsKey('added_at'), isFalse);
      expect(RoutineStep.fromJson(_at('class', 9, 0).toJson()).addedAt, isNull);
    });
  });

  group('RoutineService stamps steps as they are saved', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/routine_step_added_at');
      if (!Hive.isBoxOpen('routines')) {
        await Hive.openBox('routines', compactionStrategy: (_, _) => false);
      }
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <void>[],
      );
    });

    test('a new routine stamps every step with the moment it is saved',
        () async {
      final write = await const RoutineService().save(
        _routine(id: '', createdAt: eightAm, steps: [_at('a', 9, 0)]),
      );
      final step = write.routine.steps.single;
      expect(step.addedAt, isNotNull);
      expect(step.addedAt, write.routine.createdAt);
    });

    test('a step added later is stamped; the old ones keep their stamp',
        () async {
      final first = await const RoutineService().save(
        _routine(id: '', createdAt: eightAm, steps: [_at('class', 9, 0)]),
      );
      final classStamp = first.routine.steps.single.addedAt;

      // The builder's draft: the old step without its stamp (an editor may
      // rebuild a step from its fields), plus a brand-new one.
      final draft = first.routine.copyWith(
        steps: [_at('class', 9, 0), _at('break', 13, 30)],
      );
      final second = await const RoutineService().save(draft);
      final byId = {for (final s in second.routine.steps) s.id: s};

      expect(byId['class']!.addedAt, classStamp,
          reason: 'a save can never move an existing step\'s stamp');
      expect(byId['break']!.addedAt, isNotNull);
      expect(byId['break']!.addedAt, second.routine.updatedAt);
      // And the cache — what the learner's day reads — carries both.
      final cached = HiveService.getCachedRoutine(second.routine.id)!;
      expect(
        {for (final s in cached.steps) s.id: s.addedAt},
        {'class': classStamp, 'break': second.routine.updatedAt},
      );
    });

    test('an unstamped step already on the routine is not stamped now',
        () async {
      // A routine saved before stamps existed, already in the cache.
      final legacy = _routine(
        id: 'legacy',
        createdAt: DateTime(2026, 9),
        steps: [_at('wake', 6, 30)],
      );
      await HiveService.cacheRoutine(legacy, cloudSynced: true);
      final write = await const RoutineService().save(
        legacy.copyWith(name: 'Renamed'),
      );
      expect(
        write.routine.steps.single.addedAt,
        isNull,
        reason: 'stamping it now would take its time off today\'s day',
      );
    });

    test('an existing routine this device never cached is left alone', () {
      final unknown = _routine(
        id: 'not-cached',
        createdAt: DateTime(2026, 9),
        steps: [_at('wake', 6, 30)],
      );
      final stamped = RoutineService.stampAddedSteps(
        unknown,
        isNew: false,
        now: twoPm,
      );
      expect(stamped.steps.single.addedAt, isNull);
    });

    test('a copy for another learner is new to them: every step restamped',
        () {
      final source = _routine(
        createdAt: DateTime(2026, 9),
        steps: [_at('wake', 6, 30, addedAt: DateTime(2026, 9))],
      );
      var n = 0;
      final copy = RoutineCopy.forLearner(
        source,
        childProfileId: 'kid2',
        setterProfileId: 'teacher',
        setterRole: UserRole.teacher,
        newId: () => 'copy-${n++}',
        now: twoPm,
      );
      final stamped =
          RoutineService.stampAddedSteps(copy, isNew: true, now: twoPm);
      expect(stamped.steps.single.addedAt, twoPm);
    });
  });
}
