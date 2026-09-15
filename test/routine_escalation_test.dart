import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/lock_warning.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/educator_routine_section.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// The educator looking at the dashboard — the section's routine-alerts
/// control is theirs.
class _Educator extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'rose',
        name: 'Rose',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );
}

/// Warning before a routine step locks, and what the educator sees while it
/// holds — the learner is told the lock is coming, and the educator is told
/// until when it lasts.
///
/// There is no "needs help" any more. A step's lock lets go by itself when its
/// time ends, so a Student or Child is never stuck on one and has nobody to
/// fetch; the educator's row says when the wait is over instead.

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

  group('the dashboard row while a step holds the device', () {
    Future<void> pump(
      WidgetTester tester, {
      required DateTime now,
      RoutineDayActions? actions,
    }) async {
      final key = routineDayKey('ana', now);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_Educator.new),
            wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
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
    }

    testWidgets('names the step and when its lock lets go', (tester) async {
      await pump(tester, now: _today(6, 50));
      expect(find.textContaining('Locked on Brushing Teeth'), findsOneWidget);
      // No length of its own, so the lock lasts the ten-minute default.
      expect(find.text('6:45 AM–6:55 AM · 5 min left'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('once its time is over there is nothing to wait on — and no '
        'alarm about it', (tester) async {
      await pump(tester, now: _today(7, 5));
      expect(find.textContaining('Locked on'), findsNothing);
      expect(find.textContaining('needs help'), findsNothing);
      expect(find.textContaining('Needs help'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an excused step holds nothing', (tester) async {
      final now = _today(6, 50);
      await pump(
        tester,
        now: now,
        actions: RoutineDayActions.empty('ana', now).withExcuse(
          'brush',
          RoutineStepMark(
            at: _today(6, 47),
            byProfileId: 'rose',
            byName: 'Rose',
            source: RoutineMarkSource.educator,
          ),
        ),
      );
      expect(find.textContaining('Locked on'), findsNothing);
    });
  });
}
