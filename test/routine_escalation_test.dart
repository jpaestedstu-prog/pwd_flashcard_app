import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/lock_warning.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_lock_recorder.dart';
import 'package:pwdpwdpwd/features/routine/widgets/educator_routine_section.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// Warning before a routine step locks, and escalation after it has held for
/// too long — the learner is told the lock is coming, and the educator is told
/// when a learner has been stuck.

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

DateTime _at(int h, int m) => DateTime(2026, 9, 14, h, m);

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

class _MemoryAlerter extends RoutineHelpAlerter {
  final List<String> bodies = [];

  @override
  Future<void> alert({
    required String key,
    required String title,
    required String body,
  }) async {
    bodies.add(body);
  }
}

void main() {
  group('the warning before a step locks', () {
    LockWarning? warn(DateTime now, {Set<String> settled = const {}}) =>
        LockWarningEvaluator.evaluate(
          limit: null,
          minutesUsedToday: 0,
          alarms: const [],
          now: now,
          routineSteps: const [_brush, _dress],
          settledStepIds: settled,
        );

    test('arrives five minutes before, even with no time limit set', () {
      expect(warn(_at(6, 39)), isNull);
      final w = warn(_at(6, 40))!;
      expect(w.cause, LockWarningCause.routineStep);
      expect(w.minutesLeft, 5);
      expect(w.title, '5 minutes left');
      expect(w.body(''), 'Then it will be time for Brushing Teeth. Get ready to finish up.');
      expect(w.bodyFilipino(''), contains('Pagkatapos, oras na para sa'));
    });

    test("a step's own reminder lead sets how early the warning comes", () {
      final w = warn(_at(7, 20), settled: {'brush'})!;
      expect(w.stepId, 'dress');
      expect(w.minutesLeft, 10);
    });

    test('each step is its own event, so both get warned about', () {
      expect(warn(_at(6, 42))!.eventKey, 'routineStep:brush');
      expect(warn(_at(7, 25), settled: {'brush'})!.eventKey, 'routineStep:dress');
    });

    test('a step already done or excused is not warned about', () {
      expect(warn(_at(6, 42), settled: {'brush'}), isNull);
    });

    test('no warning once the step is holding the device', () {
      expect(warn(_at(6, 46)), isNull);
    });
  });

  group("the educator's needs-help alert", () {
    Future<_MemoryAlerter> pump(
      WidgetTester tester, {
      required DateTime now,
      RoutineDayActions? actions,
    }) async {
      final alerter = _MemoryAlerter();
      final key = routineDayKey('ana', now);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
            routineHelpAlerterProvider.overrideWithValue(alerter),
            routineListProvider('ana').overrideWith(
              (ref) => Stream.value([
                Routine(
                  id: 'morning',
                  childProfileId: 'ana',
                  setterProfileId: 'rose',
                  setterRole: UserRole.teacher,
                  name: 'Morning',
                  steps: const [_brush],
                  lockEnabled: true,
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ]),
            ),
            routineDayLogProvider(key).overrideWith(
              (ref) => Stream.value(RoutineDayLog.empty('ana', now)),
            ),
            routineDayActionsProvider(key).overrideWith(
              (ref) => Stream.value(
                actions ?? RoutineDayActions.empty('ana', now),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EducatorRoutineSection(
                  learners: [
                    EducatorRoutineLearner(
                      profileId: 'ana',
                      name: 'Ana',
                      avatarEmoji: '🐣',
                      accessibility: DisabilityType.cognitive,
                    ),
                  ],
                  learnerNounPlural: 'students',
                  learnerNoun: 'student',
                  filipino: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      return alerter;
    }

    testWidgets('fires once, with a snackbar, when a learner needs help', (
      tester,
    ) async {
      final alerter = await pump(tester, now: _today(7, 5));
      expect(alerter.bodies, ['Ana needs help with Brushing Teeth (20 min)']);
      expect(
        find.text('Ana needs help with Brushing Teeth (20 min)'),
        findsOneWidget,
      );
      expect(find.textContaining('Needs help: Brushing Teeth'), findsOneWidget);

      // Ten seconds later it is the same learner on the same step.
      await tester.pump(const Duration(seconds: 1));
      expect(alerter.bodies, hasLength(1));
    });

    testWidgets('a learner who is only waiting raises no alert', (
      tester,
    ) async {
      final alerter = await pump(tester, now: _today(6, 50));
      expect(alerter.bodies, isEmpty);
      expect(find.textContaining('Waiting on Brushing Teeth'), findsOneWidget);
    });

    testWidgets('an excused step raises no alert', (tester) async {
      final now = _today(7, 5);
      final alerter = await pump(
        tester,
        now: now,
        actions: RoutineDayActions.empty('ana', now).withExcuse(
          'brush',
          RoutineStepMark(
            at: _today(7, 1),
            byProfileId: 'rose',
            byName: 'Rose',
            source: RoutineMarkSource.educator,
          ),
        ),
      );
      expect(alerter.bodies, isEmpty);
    });
  });
}
