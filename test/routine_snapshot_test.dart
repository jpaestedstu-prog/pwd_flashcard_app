import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_history.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';

/// The per-day schedule snapshot.
///
/// Without it, history is scored against the routine as it is *today*, so
/// editing a routine silently re-writes the past: a learner who finished four
/// of four last Tuesday is shown as four of six once two steps are added. The
/// learner's device now freezes what was actually scheduled on each day it
/// sees, and these tests pin that the freeze survives every path that touches
/// a day log.

RoutineStep _step(
  String id, {
  int hour = 7,
  bool enabled = true,
  RoutineActivity activity = RoutineActivity.breakfast,
}) =>
    RoutineStep(
      id: id,
      activity: activity,
      hour: hour,
      minute: 0,
      enabled: enabled,
    );

Routine _routine({
  List<RoutineStep> steps = const [],
  Set<int> days = const {},
  bool enabled = true,
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
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

/// A log whose schedule was frozen at [scheduledIds] — what the learner's
/// device actually saw that day.
RoutineDayLog _snapshot(
  DateTime day, {
  required List<String> scheduledIds,
  Set<String> done = const {},
}) =>
    RoutineDayLog(
      profileId: 'child',
      day: day,
      completedStepIds: done,
      scheduled: [
        for (final id in scheduledIds)
          RoutineDayStep(id: id, activity: RoutineActivity.breakfast),
      ],
      snapshotAt: day,
      updatedAt: day,
    );

/// A log from before snapshots existed, or from a day the device never saw.
RoutineDayLog _bare(DateTime day, {Set<String> done = const {}}) =>
    RoutineDayLog(
      profileId: 'child',
      day: day,
      completedStepIds: done,
      updatedAt: day,
    );

RoutineHistory _history(List<Routine> routines, List<RoutineDayLog> logs) =>
    RoutineHistory.from(
      routines: routines,
      logs: logs,
      titleOf: (s) => 'Step ${s.id}',
      emojiOf: (_) => '🍳',
    );

// 2026-09-07 is a Monday.
final DateTime _mon = DateTime(2026, 9, 7);
DateTime _d(int offset) => _mon.add(Duration(days: offset));

void main() {
  group('scoring against the frozen schedule', () {
    test('a snapshot day is scored against what was actually scheduled', () {
      // The routine has grown to three steps since; the snapshot says the day
      // only ever had two, and the learner did both.
      final now = _routine(steps: [_step('a'), _step('b'), _step('c')]);
      final h = _history([now], [
        _snapshot(_d(0), scheduledIds: ['a', 'b'], done: {'a', 'b'}),
      ]);
      final day = h.days.single;
      expect(day.scheduled, 2);
      expect(day.done, 2);
      expect(day.isComplete, isTrue,
          reason: 'editing the routine must not un-complete a finished day');
      expect(day.fromSnapshot, isTrue);
      expect(day.isEstimated, isFalse);
    });

    test('editing a routine no longer re-writes a completed past day', () {
      // This is the whole point of the feature.
      final log = _snapshot(_d(0), scheduledIds: ['a'], done: {'a'});
      expect(_history([_routine(steps: [_step('a')])], [log]).completionRate,
          1.0);

      final after = _routine(steps: [_step('a'), _step('b'), _step('c')]);
      expect(_history([after], [log]).completionRate, 1.0,
          reason: 'the past day still had one step, and it was done');
    });

    test('a day with no snapshot falls back to the current routine and is '
        'flagged as an estimate', () {
      final r = _routine(steps: [_step('a'), _step('b')]);
      final h = _history([r], [_bare(_d(0), done: {'a'})]);
      final day = h.days.single;
      expect(day.scheduled, 2);
      expect(day.fromSnapshot, isFalse);
      expect(day.isEstimated, isTrue);
    });

    test('a snapshot keeps a step that has since been deleted', () {
      // The learner did it that day; the record should still say so even
      // though the step is gone from the routine now.
      final now = _routine(steps: [_step('a')]);
      final h = _history([now], [
        _snapshot(_d(0), scheduledIds: ['a', 'gone'], done: {'a', 'gone'}),
      ]);
      expect(h.days.single.scheduled, 2);
      expect(h.days.single.done, 2);
      expect(h.steps.map((s) => s.stepId), containsAll(['a', 'gone']));
    });

    test('an empty snapshot day is a known rest day, not an estimate', () {
      final r = _routine(steps: [_step('a')]);
      final h = _history([r], [_snapshot(_d(0), scheduledIds: const [])]);
      final day = h.days.single;
      expect(day.isRestDay, isTrue);
      expect(day.isEstimated, isFalse,
          reason: 'a rest day the device saw is known, not guessed');
    });

    test('the window reports how much of it is a real record', () {
      final r = _routine(steps: [_step('a')]);
      final mixed = _history([r], [
        _snapshot(_d(2), scheduledIds: ['a'], done: {'a'}),
        _bare(_d(1), done: {'a'}),
        _snapshot(_d(0), scheduledIds: ['a'], done: {'a'}),
      ]);
      expect(mixed.activeDays, hasLength(3));
      expect(mixed.recordedDays, 2);
      expect(mixed.isFullyRecorded, isFalse);

      final all = _history([r], [
        _snapshot(_d(1), scheduledIds: ['a'], done: {'a'}),
        _snapshot(_d(0), scheduledIds: ['a'], done: {'a'}),
      ]);
      expect(all.isFullyRecorded, isTrue);
      expect(all.recordedDays, 2);
    });

    test('a snapshot overrides a routine that no longer runs that weekday',
        () {
      // The educator narrowed the routine to Mondays *after* the fact. The
      // frozen Tuesday must not become a rest day retroactively.
      final narrowed = _routine(steps: [_step('a')], days: {1});
      final h = _history([narrowed], [
        _snapshot(_d(1), scheduledIds: ['a'], done: {'a'}), // a Tuesday
      ]);
      expect(h.days.single.isRestDay, isFalse);
      expect(h.days.single.isComplete, isTrue);
    });
  });

  group('the frozen row', () {
    test('still localises through the catalog', () {
      // Stores the activity and overrides, not a rendered string, so a day
      // frozen while the app was in English still reads in Filipino later.
      const frozen = RoutineDayStep(id: 's', activity: RoutineActivity.lunch);
      expect(RoutineCatalog.titleFor(frozen.toStep(), filipino: true),
          'Tanghalian');
      expect(RoutineCatalog.titleFor(frozen.toStep(), filipino: false),
          'Lunch');
    });

    test('carries the educator overrides', () {
      final step = _step('a').copyWith(
        activity: RoutineActivity.bathTime,
        title: 'Wash up',
        titleFilipino: 'Maligo',
        emoji: '🛁',
      );
      final frozen = RoutineDayStep.of(step);
      expect(frozen.activity, RoutineActivity.bathTime);
      expect(frozen.title, 'Wash up');
      expect(frozen.titleFilipino, 'Maligo');
      expect(frozen.emoji, '🛁');
      expect(RoutineCatalog.emojiFor(frozen.toStep()), '🛁');
    });

    test('an unknown activity index degrades rather than throwing', () {
      final decoded = RoutineDayStep.fromJson({'id': 's', 'activity': 9999});
      expect(decoded.activity, RoutineActivity.custom);
    });
  });

  group('persistence', () {
    test('json round trip keeps the frozen schedule', () {
      final log = _snapshot(_d(0), scheduledIds: ['a', 'b'], done: {'a'});
      final decoded = RoutineDayLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.hasSnapshot, isTrue);
      expect(decoded.scheduled.map((s) => s.id), ['a', 'b']);
      expect(decoded.completedStepIds, {'a'});
    });

    test('an empty frozen schedule is still a record', () {
      // The distinction that a bare `scheduled.isEmpty` check collapsed: a
      // device that saw the day and found nothing is not the same as a device
      // that was switched off.
      final recorded = _snapshot(_d(0), scheduledIds: const []);
      expect(recorded.hasSnapshot, isTrue);
      expect(_bare(_d(0)).hasSnapshot, isFalse);
    });

    test('a log written before snapshots existed decodes without one', () {
      final decoded = RoutineDayLog.fromJson({
        'profile_id': 'child',
        'day': '2026-09-07',
        'completed_step_ids': ['a'],
      });
      expect(decoded.hasSnapshot, isFalse);
      expect(decoded.completedStepIds, {'a'});
    });

    test('one malformed row does not cost the whole snapshot', () {
      final json = jsonDecode(jsonEncode(
        _snapshot(_d(0), scheduledIds: ['good']).toJson(),
      )) as Map<String, dynamic>;
      (json['scheduled'] as List).insert(0, 'not a map');
      final decoded = RoutineDayLog.fromJson(json);
      expect(decoded.scheduled.map((s) => s.id), ['good']);
    });

    test('ticking a step keeps the frozen schedule', () {
      // The tick path rebuilds the log; dropping `scheduled` there would
      // un-freeze the day the moment the learner completed something.
      final after = _snapshot(_d(0), scheduledIds: ['a', 'b']).toggle('a');
      expect(after.hasSnapshot, isTrue);
      expect(after.scheduled.map((s) => s.id), ['a', 'b']);
      expect(after.completedStepIds, {'a'});
    });

    test('withSchedule replaces rather than merges', () {
      final log = _snapshot(_d(0), scheduledIds: ['a', 'b'], done: {'a'});
      final next = log.withSchedule([
        const RoutineDayStep(id: 'c', activity: RoutineActivity.lunch),
      ]);
      expect(next.scheduled.map((s) => s.id), ['c']);
      expect(next.completedStepIds, {'a'}, reason: 'ticks are not touched');
    });
  });

  group('what the service freezes', () {
    test('only enabled routines that run that day, in learner order', () {
      final everyDay = _routine(steps: [_step('a'), _step('b', hour: 8)]);
      final mondays = _routine(id: 'r2', steps: [_step('c')], days: {1});

      // 2026-09-07 is a Monday, so both run.
      expect(
        RoutineService.scheduleFor([everyDay, mondays], _d(0)).map((s) => s.id),
        ['a', 'b', 'c'],
      );
      // Tuesday: only the every-day one.
      expect(
        RoutineService.scheduleFor([everyDay, mondays], _d(1)).map((s) => s.id),
        ['a', 'b'],
      );
    });

    test('a disabled routine or step is not frozen in', () {
      final r = _routine(steps: [_step('a'), _step('b', enabled: false)]);
      expect(RoutineService.scheduleFor([r], _d(0)).map((s) => s.id), ['a']);

      final off = _routine(steps: [_step('a')], enabled: false);
      expect(RoutineService.scheduleFor([off], _d(0)), isEmpty);
    });

    test('no routines yields an empty schedule, not a crash', () {
      expect(RoutineService.scheduleFor(const [], _d(0)), isEmpty);
    });

    test('the frozen order matches what the learner saw', () {
      // Steps are frozen in `orderedSteps` order — time first, unscheduled
      // last — so the history reads in the same order as the day did.
      final r = _routine(steps: [
        _step('late', hour: 18),
        _step('early', hour: 6),
      ]);
      expect(
        RoutineService.scheduleFor([r], _d(0)).map((s) => s.id),
        ['early', 'late'],
      );
    });
  });
}
