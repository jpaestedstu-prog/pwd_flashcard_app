import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/widgets/today_card.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_time_timer.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/mood_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// The picture of time running out on a learner's Home card.
///
/// A Student or Child whose step is on now sees how much of it is left without
/// reading a clock: a timer that empties, "4 min left", and until when. A step
/// an adult paused shows frozen, and says so. A Player's checklist keeps its
/// Done button and has no countdown.

const _profileId = 'countdown-learner';

class _Profile extends ProfileNotifier {
  _Profile(this.role, this.type);

  final UserRole role;
  final DisabilityType type;

  @override
  UserProfile? build() => UserProfile(
        id: _profileId,
        name: 'Ana',
        role: role,
        disabilityType: type,
        classroomId: 'class-1',
        createdAt: DateTime(2026),
      );
}

class _NoMoods extends MoodNotifier {
  _NoMoods() : super(_profileId) {
    state = const <MoodEntry>[];
  }
}

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// 7:00–7:10.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 7,
  minute: 0,
  durationMinutes: 10,
);

/// 8:00–8:20.
const _breakfast = RoutineStep(
  id: 'breakfast',
  activity: RoutineActivity.breakfast,
  hour: 8,
  minute: 0,
  durationMinutes: 20,
);

Routine get _routine => Routine(
      id: 'r',
      childProfileId: _profileId,
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush, _breakfast],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<void> _pump(
  WidgetTester tester, {
  required DateTime now,
  UserRole role = UserRole.student,
  DisabilityType type = DisabilityType.none,
  RoutineDayActions? actions,
  Set<String> done = const {},
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _Profile(role, type)),
        moodProvider.overrideWith((ref) => _NoMoods()),
        myRoutinesProvider.overrideWith((ref) => Stream.value([_routine])),
        routineDayLogProvider.overrideWith(
          (ref, key) => Stream.value(
            done.fold<RoutineDayLog>(
              RoutineDayLog.empty(_profileId, now),
              (log, id) => log.setDone(id, true, at: now),
            ),
          ),
        ),
        routineDayActionsProvider.overrideWith(
          (ref, key) => Stream.value(
            actions ?? RoutineDayActions.empty(_profileId, now),
          ),
        ),
        wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayCard(child: TodayDayPane(onOpen: () {})),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _paneLabel(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.label ?? '')
    .firstWhere((l) => l.startsWith('My Day.'), orElse: () => '');

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/routine_home_countdown');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'routines',
      'routine_logs',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  testWidgets('the step on now shows a timer emptying, and the time left',
      (tester) async {
    await _pump(tester, now: _today(7, 6));
    expect(find.byType(RoutineTimeTimer), findsOneWidget);
    expect(find.text('4 min left'), findsOneWidget);
    expect(find.text('until 7:10 AM'), findsOneWidget);
    expect(
      _paneLabel(tester),
      startsWith('My Day. Now: Brushing Teeth, until 7:10 AM. 4 min left.'),
    );
    // Nothing to press.
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('time an adult added moves the countdown', (tester) async {
    await _pump(
      tester,
      now: _today(7, 12),
      actions: RoutineDayActions.empty(_profileId, DateTime.now())
          .withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _today(7, 8))
            .withAddedMinutes(5, at: _today(7, 8)),
      ),
    );
    expect(find.text('3 min left'), findsOneWidget);
    expect(find.text('until 7:15 AM'), findsOneWidget);
  });

  testWidgets('a paused step shows frozen, and says who starts it again',
      (tester) async {
    await _pump(
      tester,
      now: _today(7, 20),
      actions: RoutineDayActions.empty(_profileId, DateTime.now())
          .withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _today(7, 4))
            .paused(at: _today(7, 4)),
      ),
    );
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Paused: Brushing Teeth'), findsOneWidget);
    expect(
      find.text('Your teacher or parent will start it again.'),
      findsOneWidget,
    );
    expect(_paneLabel(tester), startsWith('My Day. Paused: Brushing Teeth.'));
  });

  testWidgets('between steps there is no countdown, only what is next',
      (tester) async {
    // Brushing Teeth ran out at 7:10 and was recorded as finished.
    await _pump(tester, now: _today(7, 30), done: {'brush'});
    expect(find.byType(RoutineTimeTimer), findsNothing);
    expect(find.textContaining('Next: Breakfast'), findsOneWidget);
  });

  testWidgets('a Player keeps their checklist: Done, and no countdown',
      (tester) async {
    await _pump(tester, now: _today(7, 6), role: UserRole.player);
    expect(find.byType(RoutineTimeTimer), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });
}
