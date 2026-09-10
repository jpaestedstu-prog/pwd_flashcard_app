import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_history.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';

/// Scoring a learner's routine history.
///
/// The arithmetic here decides what an educator is told about a child, so the
/// thing these tests care most about is that a **rest day is not a failure**.
/// A Mon/Wed/Fri routine leaves four blank days a week; averaging those in as
/// zeroes would report a learner doing exactly what was asked as being at 43%.

RoutineStep _step(String id, {int hour = 7, bool enabled = true}) => RoutineStep(
      id: id,
      activity: RoutineActivity.breakfast,
      hour: hour,
      minute: 0,
      enabled: enabled,
    );

Routine _routine({
  List<RoutineStep> steps = const [],
  Set<int> days = const {},
  bool enabled = true,
}) =>
    Routine(
      id: 'r1',
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

/// Newest-first, like `HiveService.getRoutineHistory`.
List<RoutineDayLog> _logs(Map<DateTime, Set<String>> byDay) {
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      RoutineDayLog(
        profileId: 'child',
        day: d,
        completedStepIds: byDay[d]!,
        updatedAt: d,
      ),
  ];
}

RoutineHistory _history(List<Routine> routines, List<RoutineDayLog> logs) =>
    RoutineHistory.from(
      routines: routines,
      logs: logs,
      titleOf: (s) => 'Step ${s.id}',
      emojiOf: (_) => '🍳',
    );

// 2026-09-07 is a Monday.
DateTime _mon = DateTime(2026, 9, 7);
DateTime _d(int offset) => _mon.add(Duration(days: offset));

void main() {
  group('a rest day is not a failure', () {
    test('a day with nothing scheduled is a rest day, not zero percent', () {
      final r = _routine(steps: [_step('a')], days: {1, 3, 5}); // Mon/Wed/Fri
      final h = _history([r], _logs({
        _d(0): {'a'}, // Mon — done
        _d(1): {}, // Tue — nothing scheduled
        _d(2): {'a'}, // Wed — done
      }));

      final tue = h.days.firstWhere((x) => x.day == _d(1));
      expect(tue.isRestDay, isTrue);
      expect(tue.fraction, isNull, reason: 'null, so nobody averages a zero');
      expect(tue.isComplete, isFalse);

      // Two active days, both complete.
      expect(h.activeDays, hasLength(2));
      expect(h.completionRate, 1.0);
    });

    test('rest days do not break a streak', () {
      final r = _routine(steps: [_step('a')], days: {1, 3, 5});
      final h = _history([r], _logs({
        _d(4): {'a'}, // Fri
        _d(3): <String>{}, // Thu — rest
        _d(2): {'a'}, // Wed
        _d(1): <String>{}, // Tue — rest
        _d(0): {'a'}, // Mon
      }));
      expect(h.streak(now: _d(4)), 3);
    });

    test('a window of only rest days reports no rate rather than zero', () {
      final r = _routine(steps: [_step('a')], days: {6, 7}); // weekend only
      final h = _history([r], _logs({_d(0): {}, _d(1): {}}));
      expect(h.completionRate, isNull);
      expect(h.isEmpty, isTrue);
    });
  });

  group('completion', () {
    test('counts done over scheduled across active days', () {
      final r = _routine(steps: [_step('a'), _step('b'), _step('c')]);
      final h = _history([r], _logs({
        _d(0): {'a', 'b', 'c'}, // 3/3
        _d(1): {'a'}, // 1/3
      }));
      expect(h.completionRate, closeTo(4 / 6, 0.001));
      expect(h.completeDays, 1);
    });

    test('a disabled routine contributes nothing', () {
      final on = _routine(steps: [_step('a')]);
      final off = Routine(
        id: 'r2',
        childProfileId: 'child',
        setterProfileId: 'adult',
        setterRole: UserRole.parent,
        name: 'Off',
        steps: [_step('z')],
        enabled: false,
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      );
      final h = _history([on, off], _logs({_d(0): {'a'}}));
      expect(h.days.single.scheduled, 1);
      expect(h.completionRate, 1.0);
    });

    test('a disabled step is not scheduled', () {
      final r = _routine(steps: [_step('a'), _step('b', enabled: false)]);
      final h = _history([r], _logs({_d(0): {'a'}}));
      expect(h.days.single.scheduled, 1);
      expect(h.days.single.isComplete, isTrue);
    });
  });

  group('streak', () {
    test('an unfinished today does not end the streak', () {
      // A streak evaporating at 9am because the day is not over yet would be
      // the streak-revocation bug this project has been bitten by before.
      final r = _routine(steps: [_step('a'), _step('b')]);
      final h = _history([r], _logs({
        _d(2): {'a'}, // today, half done
        _d(1): {'a', 'b'},
        _d(0): {'a', 'b'},
      }));
      expect(h.streak(now: _d(2)), 2);
    });

    test('a missed day in the past does end it', () {
      final r = _routine(steps: [_step('a')]);
      final h = _history([r], _logs({
        _d(2): {'a'},
        _d(1): <String>{}, // missed
        _d(0): {'a'},
      }));
      expect(h.streak(now: _d(2)), 1);
    });
  });

  group('where it stalls', () {
    test('ranks the most-missed step first and omits the reliable ones', () {
      final r = _routine(steps: [_step('good'), _step('bad'), _step('mid')]);
      final h = _history([r], _logs({
        _d(0): {'good', 'mid'},
        _d(1): {'good'},
        _d(2): {'good', 'mid'},
        _d(3): {'good'},
      }));
      final stalls = h.stalls;
      expect(stalls.first.stepId, 'bad');
      expect(stalls.first.missed, 4);
      expect(stalls.map((s) => s.stepId), isNot(contains('good')),
          reason: 'a step that never stalls is not a problem to report');
      expect(stalls.map((s) => s.stepId), contains('mid'));
    });

    test('reports a usable rate and title for each stall', () {
      final r = _routine(steps: [_step('a')]);
      final h = _history([r], _logs({_d(0): {}, _d(1): {'a'}}));
      final s = h.stalls.single;
      expect(s.title, 'Step a');
      expect(s.emoji, '🍳');
      expect(s.scheduled, 2);
      expect(s.done, 1);
      expect(s.missed, 1);
      expect(s.rate, 0.5);
    });

    test('nothing stalls when everything is done', () {
      final r = _routine(steps: [_step('a')]);
      final h = _history([r], _logs({_d(0): {'a'}, _d(1): {'a'}}));
      expect(h.stalls, isEmpty);
    });
  });

  group('edges', () {
    test('no routines at all is empty, not a crash', () {
      final h = _history(const [], _logs({_d(0): {}}));
      expect(h.isEmpty, isTrue);
      expect(h.completionRate, isNull);
      expect(h.stalls, isEmpty);
      expect(h.streak(now: _d(0)), 0);
    });

    test('no logs at all is empty', () {
      final h = _history([_routine(steps: [_step('a')])], const []);
      expect(h.days, isEmpty);
      expect(h.isEmpty, isTrue);
    });

    test('a tick for a step that no longer exists is ignored', () {
      // Routines get edited; the log keeps ids of steps since deleted.
      final r = _routine(steps: [_step('a')]);
      final h = _history([r], _logs({
        _d(0): {'a', 'deleted-step'},
      }));
      expect(h.days.single.scheduled, 1);
      expect(h.days.single.done, 1);
    });
  });
}
