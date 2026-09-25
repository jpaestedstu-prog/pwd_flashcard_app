import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_timeline.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';

/// A routine's first day: steps whose time was already over when it was made
/// are not part of that day.
///
/// Found on the NDL W09: a teacher built a Morning Routine at 11:07 and the
/// student's Home at once read "That's all for today. 1 day finished in a
/// row." A Student's or Child's day runs on the clock — a step is finished
/// when its time ends — so every morning step was written into their day log
/// as finished, back-dated 6:45–7:40, before the learner had even seen the
/// routine. The dashboard said 4 of 4 and the history a perfect day.

RoutineStep _at(String id, int hour, int minute, {int minutes = 10}) =>
    RoutineStep(
      id: id,
      activity: RoutineActivity.custom,
      hour: hour,
      minute: minute,
      durationMinutes: minutes,
    );

Routine _made(
  DateTime createdAt, {
  List<RoutineStep>? steps,
  Set<int> days = const {},
  bool lock = false,
}) =>
    Routine(
      id: 'r',
      childProfileId: 'kid',
      setterProfileId: 'teacher',
      setterRole: UserRole.teacher,
      name: 'Morning',
      daysOfWeek: days,
      lockEnabled: lock,
      steps: steps ??
          [
            _at('wake', 6, 30, minutes: 15),
            _at('teeth', 6, 45, minutes: 5),
            _at('breakfast', 7, 0, minutes: 20),
            _at('dressed', 7, 30),
          ],
      createdAt: createdAt,
      updatedAt: createdAt,
    );

List<String> _ids(List<RoutineStep> steps) => [for (final s in steps) s.id];

void main() {
  // Friday 25 September 2026, the day it was found.
  final friday = DateTime(2026, 9, 25);
  final at1107 = DateTime(2026, 9, 25, 11, 7);

  group('Routine.stepsOn', () {
    test('a morning routine made at 11:07 has nothing left that day', () {
      final r = _made(at1107);
      expect(r.stepsOn(friday), isEmpty);
      expect(r.startsAfter(friday), isTrue);
    });

    test('the next day it is the whole routine again', () {
      final r = _made(at1107);
      final saturday = DateTime(2026, 9, 26);
      expect(_ids(r.stepsOn(saturday)), ['wake', 'teeth', 'breakfast', 'dressed']);
      expect(r.startsAfter(saturday), isFalse);
    });

    test('a step still running when it was made stays, and so do later ones',
        () {
      final r = _made(
        DateTime(2026, 9, 25, 7, 5),
        steps: [
          _at('wake', 6, 30, minutes: 15), // over at 6:45
          _at('breakfast', 7, 0, minutes: 20), // running until 7:20
          _at('dressed', 7, 30),
        ],
      );
      expect(_ids(r.stepsOn(friday)), ['breakfast', 'dressed']);
      expect(r.startsAfter(friday), isFalse);
    });

    test('a step ending exactly as the routine is made is already over', () {
      final r = _made(
        DateTime(2026, 9, 25, 6, 45),
        steps: [_at('wake', 6, 30, minutes: 15), _at('teeth', 6, 45)],
      );
      expect(_ids(r.stepsOn(friday)), ['teeth']);
    });

    test('an unscheduled step has no time to be over', () {
      final r = _made(
        at1107,
        steps: [
          _at('wake', 6, 30),
          const RoutineStep(id: 'tidy', activity: RoutineActivity.custom),
        ],
      );
      expect(_ids(r.stepsOn(friday)), ['tidy']);
      expect(r.startsAfter(friday), isFalse);
    });

    test('a routine with no steps never "starts later"', () {
      final r = _made(at1107, steps: const []);
      expect(r.startsAfter(friday), isFalse);
    });

    test('locking steps follow the same rule', () {
      final r = _made(
        DateTime(2026, 9, 25, 7, 5),
        lock: true,
        steps: [_at('wake', 6, 30), _at('breakfast', 7, 0, minutes: 20)],
      );
      expect(_ids(r.lockingStepsOn(friday)), ['breakfast']);
      expect(_ids(r.lockingStepsOn(DateTime(2026, 9, 26))), ['wake', 'breakfast']);
    });
  });

  group('what the day log freezes', () {
    test('the schedule recorded on the first day leaves the over steps out',
        () {
      final schedule = RoutineService.scheduleFor([_made(at1107)], friday);
      expect(
        schedule,
        isEmpty,
        reason: 'recorded as a rest day, not as four steps to score',
      );
    });

    test('a routine made the day before schedules everything', () {
      final schedule = RoutineService.scheduleFor(
        [_made(DateTime(2026, 9, 24, 21))],
        friday,
      );
      expect(schedule.map((s) => s.id), ['wake', 'teeth', 'breakfast', 'dressed']);
    });
  });

  group('routineNextDayWord', () {
    test('an every-day routine starts tomorrow', () {
      final r = _made(at1107);
      expect(routineNextDayWord(r, friday, filipino: false), 'tomorrow');
      expect(routineNextDayWord(r, friday, filipino: true), 'bukas');
    });

    test('a Mon/Wed/Fri routine made on a Friday starts on Monday', () {
      final r = _made(at1107, days: const {1, 3, 5});
      expect(routineNextDayWord(r, friday, filipino: false), 'Monday');
      expect(routineNextDayWord(r, friday, filipino: true), 'sa Lunes');
    });

    test('a weekday routine made on a Thursday starts tomorrow', () {
      final thursday = DateTime(2026, 9, 24);
      final r = _made(DateTime(2026, 9, 24, 11), days: const {1, 2, 3, 4, 5});
      expect(routineNextDayWord(r, thursday, filipino: false), 'tomorrow');
    });
  });
}
