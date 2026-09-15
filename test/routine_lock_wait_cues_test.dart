import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/lock_announcer.dart';
import 'package:pwdpwdpwd/core/services/lock_enforcer.dart';
import 'package:pwdpwdpwd/core/services/lock_presentation.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_lock_screen.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_lock_recorder.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_time_timer.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/lock_announcement_provider.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// "Please wait", for every learner: the routine lock shows the wait as a
/// picture timer, adds a First / Then card for a learner with a cognitive
/// disability, and says the time left out loud for the learners who are told
/// the time rather than shown it.

const _id = 'wait-learner';

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// 6:45–6:55.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

const _lunch = RoutineStep(
  id: 'lunch',
  activity: RoutineActivity.lunch,
  hour: 12,
  minute: 0,
);

class _FixedProfile extends ProfileNotifier {
  _FixedProfile(this._profile);

  final UserProfile _profile;

  @override
  UserProfile? build() => _profile;
}

class _FixedSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

class _NoRecorder extends RoutineLockRecorder {
  @override
  Future<void> lockShown(String profileId, String stepId) async {}
}

class _Voice implements LockAnnouncer {
  final List<String> said = [];

  @override
  Future<void> announce({
    required LockPresentation presentation,
    required String message,
    bool alarmEnabled = true,
    bool voiceEnabled = true,
    bool speakFilipino = false,
  }) async =>
      said.add(message);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Future<_Voice> _pumpLock(
  WidgetTester tester, {
  required DisabilityType type,
  required DateTime now,
  RoutineDayActions? actions,
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final voice = _Voice();
  final key = routineDayKey(_id, now);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          () => _FixedProfile(
            UserProfile(
              id: _id,
              name: 'Ana',
              role: UserRole.student,
              disabilityType: type,
              createdAt: DateTime(2026),
            ),
          ),
        ),
        settingsProvider.overrideWith(_FixedSettings.new),
        lockStateProvider(_id).overrideWithValue(const RoutineStepDue(_brush)),
        routineLockRecorderProvider.overrideWithValue(_NoRecorder()),
        lockAnnouncerProvider.overrideWith((ref) => voice),
        wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
        routineDayViewProvider(key).overrideWithValue(
          RoutineDayView.of(profileId: _id, day: now, actions: actions),
        ),
        todayRoutineProvider.overrideWithValue(
          TodayRoutine(
            steps: const [_brush, _lunch],
            log: RoutineDayLog.empty(_id, now),
            streak: 0,
            hasEducator: true,
          ),
        ),
      ],
      child: const MaterialApp(home: RoutineLockScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return voice;
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/routine_lock_wait_cues');
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

  testWidgets('every learner sees the wait as a picture timer',
      (tester) async {
    for (final type in DisabilityType.values) {
      await _pumpLock(tester, type: type, now: _today(6, 48));
      expect(find.byType(RoutineTimeTimer), findsOneWidget, reason: '$type');
    }
  });

  testWidgets('a learner with a cognitive disability gets First / Then, and '
      'hears "5 minutes left"', (tester) async {
    final voice = await _pumpLock(
      tester,
      type: DisabilityType.cognitive,
      now: _today(6, 50),
    );
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Then'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(voice.said, contains('5 minutes left.'));
  });

  testWidgets('a learner with low vision hears "One minute left"',
      (tester) async {
    final voice = await _pumpLock(
      tester,
      type: DisabilityType.visual,
      now: _today(6, 54),
    );
    expect(voice.said, contains('One minute left.'));
    expect(find.text('First'), findsNothing);
  });

  testWidgets('no First / Then and nothing spoken where the category does '
      'not call for it', (tester) async {
    final voice = await _pumpLock(
      tester,
      type: DisabilityType.none,
      now: _today(6, 50),
    );
    expect(find.text('First'), findsNothing);
    expect(voice.said.where((m) => m.contains('minutes left')), isEmpty);
  });

  testWidgets('time an adult added is the time the lock waits for',
      (tester) async {
    await _pumpLock(
      tester,
      type: DisabilityType.none,
      now: _today(6, 52),
      actions: RoutineDayActions.empty(_id, DateTime.now()).withAdjustment(
        'brush',
        RoutineStepAdjustment(changedAt: _today(6, 50))
            .withAddedMinutes(10, at: _today(6, 50)),
      ),
    );
    expect(find.text('Please wait. This ends at 7:05 AM.'), findsOneWidget);
    expect(find.text('13 minutes left'), findsOneWidget);
  });
}
