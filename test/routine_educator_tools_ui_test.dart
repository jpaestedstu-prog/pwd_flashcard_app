import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/educator_step_alerts.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_lock_status.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/educator_routine_alerts.dart';
import 'package:pwdpwdpwd/features/routine/widgets/educator_routine_section.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_educator_actions.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_lock_status_line.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_time_timer.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_wait_report_section.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// The educator's new routine tools, on screen: pause and add time from the
/// dashboard, the paused status line, routine alerts, the picture timer and
/// the weekly waiting report.
///
/// Every provider is overridden and nothing writes to Hive: the dialogs are
/// opened and cancelled, and the writes behind them are covered by the plain
/// tests of the models they build.

const _learner = 'ana';

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

class _Educator extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'rose',
        name: 'Rose',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );
}

/// 6:45–6:55, locks.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

Routine _routine() => Routine(
      id: 'morning',
      childProfileId: _learner,
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush],
      lockEnabled: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineDayActions _withAdjustment(RoutineStepAdjustment a) =>
    RoutineDayActions.empty(_learner, DateTime.now()).withAdjustment('brush', a);

RoutineStepLockStatus _status({RoutineDayActions? actions, DateTime? now}) {
  final at = now ?? _today(6, 50);
  return RoutineLockSummary.statusFor(
    routine: _routine(),
    step: _brush,
    view: RoutineDayView.of(profileId: _learner, day: at, actions: actions),
    now: at,
  );
}

Future<void> _pumpBar(WidgetTester tester, RoutineStepLockStatus status) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith(_Educator.new)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RoutineStepActionBar(
                childProfileId: _learner,
                learnerName: 'Ana',
                status: status,
                filipino: false,
              ),
            ),
          ),
        ),
      ),
    );

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

class _RecordingSink implements EducatorRoutineAlertSink {
  final List<List<EducatorStepAlert>> scheduled = [];
  final List<EducatorStepAlert> shown = [];

  @override
  Future<void> schedule(List<EducatorStepAlert> alerts) async =>
      scheduled.add(alerts);

  @override
  Future<void> showNow(EducatorStepAlert alert) async => shown.add(alert);
}

void main() {
  group('pause and add time from the dashboard', () {
    testWidgets('a waiting step offers pause and more time, and each asks '
        'first', (tester) async {
      await _pumpBar(tester, _status());
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Add time'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Pause Brushing Teeth for Ana?'), findsOneWidget);
      expect(find.textContaining('the clock stops'), findsOneWidget);
      expect(find.textContaining('5 min will be left'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add time'));
      await tester.pumpAndSettle();
      expect(find.text('Add time to Brushing Teeth?'), findsOneWidget);
      expect(find.textContaining('It ends at 6:55 AM now'), findsOneWidget);
      for (final m in kRoutineAddTimeChoices) {
        expect(find.text('+$m min'), findsOneWidget);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add time to Brushing Teeth?'), findsNothing);
    });

    testWidgets('a paused step offers resume — not pause, mark done or the '
        'unlock', (tester) async {
      final paused = _withAdjustment(
        RoutineStepAdjustment(changedAt: _today(6, 48))
            .paused(at: _today(6, 48)),
      );
      await _pumpBar(tester, _status(actions: paused));
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Unlock 30 min'), findsNothing);
      expect(find.text('Excuse today'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Resume Brushing Teeth for Ana?'), findsOneWidget);
      // Paused at 6:48 with 7 minutes to go; still 7 at 6:50.
      expect(
        find.text('The lock comes back on Ana’s device for 7 min.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('no more than two extra hours can be added', (tester) async {
      final nearly = _withAdjustment(
        RoutineStepAdjustment(changedAt: _today(6, 46))
            .withAddedMinutes(112, at: _today(6, 46)),
      );
      await _pumpBar(tester, _status(actions: nearly));
      await tester.tap(find.text('Add time'));
      await tester.pumpAndSettle();
      expect(find.text('+5 min'), findsOneWidget);
      expect(find.text('+10 min'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final full = _withAdjustment(
        RoutineStepAdjustment(changedAt: _today(6, 46))
            .withAddedMinutes(kRoutineMaxAddedMinutes, at: _today(6, 46)),
      );
      await _pumpBar(tester, _status(actions: full));
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Add time'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Filipino labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileProvider.overrideWith(_Educator.new)],
          child: MaterialApp(
            home: Scaffold(
              body: RoutineStepActionBar(
                childProfileId: _learner,
                learnerName: 'Ana',
                status: _status(),
                filipino: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Pahintuin'), findsOneWidget);
      expect(find.text('Magdagdag ng oras'), findsOneWidget);
    });
  });

  group('the dashboard status line', () {
    Future<void> pumpStatus(
      WidgetTester tester, {
      required DateTime now,
      RoutineDayActions? actions,
    }) async {
      final key = routineDayKey(_learner, now);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
            routineListProvider(_learner)
                .overrideWith((ref) => Stream.value([_routine()])),
            routineDayLogProvider(key).overrideWith(
              (ref) => Stream.value(RoutineDayLog.empty(_learner, now)),
            ),
            routineDayActionsProvider(key).overrideWith(
              (ref) => Stream.value(
                actions ?? RoutineDayActions.empty(_learner, now),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RoutineLearnerLockStatus(
                profileId: _learner,
                filipino: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a paused step says so, and what is left for later',
        (tester) async {
      await pumpStatus(
        tester,
        now: _today(7, 30),
        actions: _withAdjustment(
          RoutineStepAdjustment(changedAt: _today(6, 48))
              .paused(at: _today(6, 48)),
        ),
      );
      expect(find.textContaining('Paused: Brushing Teeth'), findsOneWidget);
      expect(find.text('7 min left when you resume it'), findsOneWidget);
      expect(
        find.text('The lock is lifted on their device until you resume it.'),
        findsOneWidget,
      );
    });

    testWidgets('added time shows in the holding line', (tester) async {
      await pumpStatus(
        tester,
        now: _today(6, 58),
        actions: _withAdjustment(
          RoutineStepAdjustment(changedAt: _today(6, 50))
              .withAddedMinutes(10, at: _today(6, 50)),
        ),
      );
      expect(find.textContaining('Locked on Brushing Teeth'), findsOneWidget);
      expect(
        find.text('6:45 AM–7:05 AM · 7 min left · +10 min added'),
        findsOneWidget,
      );
    });
  });

  group('routine alerts', () {
    testWidgets('the educator picks which steps they are told about',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileProvider.overrideWith(_Educator.new)],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: EducatorRoutineAlertsButton(filipino: false)),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Routine alerts: Locked steps'), findsOneWidget);
      await tester.tap(find.byTooltip('Routine alerts: Locked steps'));
      await tester.pumpAndSettle();
      expect(find.text('Routine alerts'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Every step with a time'), findsOneWidget);

      await tester.tap(find.text('Every step with a time'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Routine alerts: Every step with a time'),
        findsOneWidget,
      );
    });

    testWidgets('the dashboard schedules the start and end of a locked step',
        (tester) async {
      final now = _today(6, 0);
      final key = routineDayKey(_learner, now);
      final sink = _RecordingSink();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_Educator.new),
            wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
            routineListProvider(_learner)
                .overrideWith((ref) => Stream.value([_routine()])),
            routineDayLogProvider(key).overrideWith(
              (ref) => Stream.value(RoutineDayLog.empty(_learner, now)),
            ),
            routineDayActionsProvider(key).overrideWith(
              (ref) => Stream.value(RoutineDayActions.empty(_learner, now)),
            ),
            educatorRoutineAlertSinkProvider.overrideWithValue(sink),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EducatorRoutineAlertSync(
                learners: [
                  EducatorRoutineLearner(
                    profileId: _learner,
                    name: 'Ana',
                    avatarEmoji: '🙂',
                    accessibility: DisabilityType.cognitive,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(sink.scheduled, isNotEmpty);
      final today = sink.scheduled.last
          .where((a) => a.at.day == now.day)
          .toList();
      expect(today.map((a) => a.kind), [
        EducatorStepAlertKind.started,
        EducatorStepAlertKind.ended,
      ]);
      expect(today.first.title, '🔒 Ana: Brushing Teeth');
      expect(sink.shown, isEmpty);
    });
  });

  group('the picture timer', () {
    test('how much colour is left is how much time is left', () {
      expect(
        RoutineTimeTimer.remainingFraction(
          start: _today(7, 0),
          end: _today(7, 10),
          now: _today(7, 5),
        ),
        0.5,
      );
      expect(
        RoutineTimeTimer.remainingFraction(
          start: _today(7, 0),
          end: _today(7, 10),
          now: _today(7, 20),
        ),
        0,
      );
    });

    testWidgets('words beside it: time left, until when, or paused',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RoutineNowCountdown(
                  start: _today(7, 0),
                  end: _today(7, 10),
                  now: _today(7, 6),
                  filipino: false,
                  emoji: '🪥',
                ),
                RoutineNowCountdown(
                  start: _today(7, 0),
                  end: _today(7, 10),
                  now: _today(7, 6),
                  filipino: false,
                  paused: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('4 min left'), findsOneWidget);
      expect(find.text('until 7:10 AM'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(
        RoutineNowCountdown.leftLabel(
          end: _today(7, 10),
          now: _today(7, 9, ),
          filipino: false,
        ),
        'Almost done',
      );
    });
  });

  group('the weekly waiting report', () {
    testWidgets('totals, who ended steps early, and a line per step',
        (tester) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
      final log = RoutineDayLog.empty(_learner, day)
          .withLockShown('brush', at(6, 45));
      final actions = RoutineDayActions.empty(_learner, day).withApproval(
        'brush',
        RoutineStepMark(
          at: at(6, 49),
          byProfileId: 'rose',
          byName: 'Rose',
          source: RoutineMarkSource.educator,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
            routineListProvider(_learner)
                .overrideWith((ref) => Stream.value([_routine()])),
            routineRecentDaysSyncProvider(_learner)
                .overrideWith((ref) async {}),
            routineHistoryProvider(_learner).overrideWithValue([log]),
            routineActionsHistoryProvider(_learner)
                .overrideWithValue([actions]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoutineWaitReportSection(
                  profileId: _learner,
                  filipino: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Rose ×1'), findsOneWidget);
      expect(
        find.text('Locked 1 day · waited 4 min · ended early 1×'),
        findsOneWidget,
      );
    });
  });
}
