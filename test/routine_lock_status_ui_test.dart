import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_lock_status.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_lock_log.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_lock_status_line.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// What an educator sees about a learner's routine lock: the live status on
/// the dashboard row, and the audit trail in the routine history.
///
/// No Hive and no Firestore: every provider the widgets read is overridden, so
/// these are about the words and when they appear.

const _learner = 'ana';

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

Routine _routine({bool locks = true}) => Routine(
      id: 'morning',
      childProfileId: _learner,
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush],
      lockEnabled: locks,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineStepMark _mark(DateTime at, {String by = 'Rose'}) => RoutineStepMark(
      at: at,
      byProfileId: 'rose',
      byName: by,
      byRole: UserRole.teacher,
      source: RoutineMarkSource.educator,
    );

Future<void> _pumpStatus(
  WidgetTester tester, {
  required DateTime now,
  Routine? routine,
  RoutineDayLog? log,
  RoutineDayActions? actions,
  RoutineStatusActionBuilder? actionsFor,
}) async {
  final key = routineDayKey(_learner, now);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
        routineListProvider(_learner).overrideWith(
          (ref) => Stream.value([routine ?? _routine()]),
        ),
        routineDayLogProvider(key).overrideWith(
          (ref) => Stream.value(log ?? RoutineDayLog.empty(_learner, now)),
        ),
        routineDayActionsProvider(key).overrideWith(
          (ref) =>
              Stream.value(actions ?? RoutineDayActions.empty(_learner, now)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: RoutineLearnerLockStatus(
            profileId: _learner,
            filipino: false,
            actionsFor: actionsFor,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('live status on the dashboard row', () {
    testWidgets('a due step says until when it holds, and that the lock has '
        'not shown', (tester) async {
      await _pumpStatus(tester, now: _today(6, 52));
      expect(find.textContaining('Locked on Brushing Teeth'), findsOneWidget);
      // No length of its own, so the lock lasts the ten-minute default.
      expect(find.text('6:45 AM–6:55 AM · 3 min left'), findsOneWidget);
      expect(
        find.text("Their device hasn't shown the lock yet — it may be off."),
        findsOneWidget,
      );
    });

    testWidgets('a step with its own length says when its lock lets go',
        (tester) async {
      final long = Routine(
        id: 'morning',
        childProfileId: _learner,
        setterProfileId: 'rose',
        setterRole: UserRole.teacher,
        name: 'Morning',
        steps: const [
          RoutineStep(
            id: 'brush',
            activity: RoutineActivity.brushingTeeth,
            hour: 6,
            minute: 45,
            durationMinutes: 30,
          ),
        ],
        lockEnabled: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await _pumpStatus(
        tester,
        now: _today(7, 5),
        routine: long,
        log: RoutineDayLog.empty(_learner, _today(7, 5))
            .withLockShown('brush', _today(6, 45)),
      );
      expect(find.textContaining('Locked on Brushing Teeth'), findsOneWidget);
      expect(find.text('6:45 AM–7:15 AM · 10 min left'), findsOneWidget);
      expect(find.text('The lock is showing on their device.'), findsOneWidget);
      expect(find.textContaining('Needs help'), findsNothing);
    });

    testWidgets('the host supplies the buttons for the step holding the device',
        (tester) async {
      await _pumpStatus(
        tester,
        now: _today(6, 52),
        actionsFor: (context, status) => Text('act on ${status.step.id}'),
      );
      expect(find.text('act on brush'), findsOneWidget);
    });

    testWidgets('an excused step says who excused it and when', (tester) async {
      await _pumpStatus(
        tester,
        now: _today(6, 55),
        actions: RoutineDayActions.empty(_learner, _today(6, 55))
            .withExcuse('brush', _mark(_today(6, 50))),
      );
      expect(find.textContaining('Locked on'), findsNothing);
      expect(
        find.text('Brushing Teeth excused by Rose at 6:50 AM'),
        findsOneWidget,
      );
    });

    testWidgets('an approval reads as marked done by the educator',
        (tester) async {
      await _pumpStatus(
        tester,
        now: _today(6, 55),
        actions: RoutineDayActions.empty(_learner, _today(6, 55))
            .withApproval('brush', _mark(_today(6, 51))),
      );
      expect(
        find.text('Brushing Teeth marked done by Rose at 6:51 AM'),
        findsOneWidget,
      );
    });

    testWidgets('a routine that does not lock shows nothing at all',
        (tester) async {
      await _pumpStatus(
        tester,
        now: _today(6, 52),
        routine: _routine(locks: false),
      );
      expect(find.textContaining('Brushing Teeth'), findsNothing);
    });
  });

  group('the lock & excuse log', () {
    testWidgets('lists a day of lock activity in plain sentences',
        (tester) async {
      final day = _today(0, 0);
      final log = RoutineDayLog.empty(_learner, day)
          .withLockShown('brush', _today(6, 45))
          .setDone('brush', true, at: _today(6, 53));
      final actions = RoutineDayActions.empty(_learner, day)
          .withExcuse('brush', _mark(_today(6, 50)))
          .withReset(at: _today(6, 40), byName: 'Rose');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineRecentDaysSyncProvider(_learner).overrideWith((ref) async {}),
            routineHistoryProvider(_learner).overrideWithValue([log]),
            routineActionsHistoryProvider(_learner).overrideWithValue([actions]),
            routineListProvider(_learner).overrideWith(
              (ref) => Stream.value([_routine()]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoutineLockLogSection(
                  profileId: _learner,
                  filipino: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('LOCK & EXCUSE LOG'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(
        find.text('🪥 Brushing Teeth — Done after 8 min locked'),
        findsOneWidget,
      );
      expect(find.text('🪥 Brushing Teeth — Excused by Rose'), findsOneWidget);
      expect(find.text('🪥 Brushing Teeth — Lock appeared'), findsOneWidget);
      expect(find.text('Day started over by Rose'), findsOneWidget);
    });

    testWidgets('a quiet fortnight shows no section', (tester) async {
      final day = _today(0, 0);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineRecentDaysSyncProvider(_learner).overrideWith((ref) async {}),
            routineHistoryProvider(_learner)
                .overrideWithValue([RoutineDayLog.empty(_learner, day)]),
            routineActionsHistoryProvider(_learner).overrideWithValue(
              [RoutineDayActions.empty(_learner, day)],
            ),
            routineListProvider(_learner).overrideWith(
              (ref) => Stream.value([_routine()]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RoutineLockLogSection(profileId: _learner, filipino: false),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LOCK & EXCUSE LOG'), findsNothing);
    });

    test('a tablet excuse is named as one, not as a person', () {
      final e = RoutineLockEvent(
        kind: RoutineLockEventKind.excused,
        at: _today(6, 50),
        stepId: 'brush',
        source: RoutineMarkSource.learnerDevice,
      );
      expect(
        RoutineLockLogSection.sentence(e, filipino: false),
        'Excused on the tablet (adult check)',
      );
    });
  });
}
