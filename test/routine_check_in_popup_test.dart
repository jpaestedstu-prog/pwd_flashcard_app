import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_context.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_check_in_watcher.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_mood_prompt.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';
import 'package:pwdpwdpwd/providers/mood_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// The questions "My Day" asks, as the learner meets them.
///
///  * the scheduled check-in pop-up — "Check-in time! Please do your check-in
///    now." — raised by the watcher when a Check-In Time step comes due, and
///  * the per-step question — "How do you feel after brushing your teeth?".
///
/// No Hive writes here: moods go to an in-memory notifier, and nothing a test
/// taps ticks a step (an awaited `box.put` inside `testWidgets` hangs the
/// whole file — see the project's Hive-hang notes). Ticking is covered by the
/// routine service tests; this file covers who is asked what, and when.

const _profileId = 'popup-learner';

class _StubProfile extends ProfileNotifier {
  _StubProfile({this.role = UserRole.student});

  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: _profileId,
    name: 'Popup Learner',
    role: role,
    classroomId: 'class-1',
    createdAt: DateTime(2026),
  );
}

class _FakeMood extends MoodNotifier {
  _FakeMood([List<MoodEntry> entries = const []]) : super(_profileId) {
    state = entries;
  }

  final List<MoodEntry> added = [];

  @override
  Future<MoodEntry> addMood({
    required MoodType mood,
    String? note,
    MoodContext context = MoodContext.general,
    String? routineStepId,
    int? routineActivity,
    String? routineStepTitle,
  }) async {
    final entry = MoodEntry(
      id: 'new-${added.length}',
      profileId: _profileId,
      mood: mood,
      note: note,
      timestamp: DateTime.now(),
      activityContext: context.storageKey,
      routineStepId: routineStepId,
      routineActivity: routineActivity,
      routineStepTitle: routineStepTitle,
    );
    added.add(entry);
    state = [...state, entry];
    return entry;
  }
}

const _checkIn = RoutineStep(
  id: 'ci-9',
  activity: RoutineActivity.moodCheckIn,
  hour: 9,
  minute: 0,
);

const _brushing = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
  askMood: true,
);

/// A harness exposing a button that runs [action] with a real context + ref.
Future<_FakeMood> _pumpHarness(
  WidgetTester tester,
  Future<void> Function(BuildContext, WidgetRef) action, {
  List<MoodEntry> moods = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final mood = _FakeMood(moods);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(_StubProfile.new),
        moodProvider.overrideWith((ref) => mood),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => action(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return mood;
}

/// Pumps the watcher alone at [location] and [now], with [today] as the day.
Future<_FakeMood> _pumpWatcher(
  WidgetTester tester, {
  required String location,
  required DateTime now,
  required TodayRoutine today,
  UserRole role = UserRole.student,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final mood = _FakeMood();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _StubProfile(role: role)),
        moodProvider.overrideWith((ref) => mood),
        todayRoutineProvider.overrideWithValue(today),
        wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
        lockStateProvider(_profileId).overrideWithValue(null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RoutineCheckInWatcher(location: location),
              const Center(child: Text('hub')),
            ],
          ),
        ),
      ),
    ),
  );
  // One frame for the stream, one for the post-frame callback, one for the
  // dialog's entrance.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return mood;
}

TodayRoutine _today(List<RoutineStep> steps, {Set<String> done = const {}}) =>
    TodayRoutine(
      steps: steps,
      log: RoutineDayLog(
        profileId: _profileId,
        day: DateTime.now(),
        completedStepIds: done,
        updatedAt: DateTime.now(),
      ),
      streak: 0,
      hasEducator: true,
    );

DateTime _todayAt(int h, [int m = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/check_in_popup');
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

  group('the check-in pop-up', () {
    testWidgets('says what the brief asked for, and offers the faces', (
      tester,
    ) async {
      await _pumpHarness(tester, (c, r) async {
        await showCheckInPopup(c, r, _checkIn);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Check-in time!'), findsOneWidget);
      expect(find.text('Please do your check-in now.'), findsOneWidget);
      expect(find.text('How are you feeling right now?'), findsOneWidget);
      expect(find.bySemanticsLabel('Happy'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('picking a face records a check-in against the step', (
      tester,
    ) async {
      bool? answered;
      final mood = await _pumpHarness(tester, (c, r) async {
        answered = await showCheckInPopup(c, r, _checkIn);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pumpAndSettle();

      expect(answered, isTrue);
      final entry = mood.added.single;
      expect(entry.mood, MoodType.happy);
      expect(entry.activityContext, 'check_in');
      expect(entry.routineStepId, 'ci-9');
      expect(entry.routineStepTitle, 'Check-In Time');
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('"Later" records nothing and says so to the caller', (
      tester,
    ) async {
      bool? answered;
      final mood = await _pumpHarness(tester, (c, r) async {
        answered = await showCheckInPopup(c, r, _checkIn);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(answered, isFalse);
      expect(mood.added, isEmpty);
    });

    testWidgets('an accidental tap outside is not an answer', (tester) async {
      // A real risk for a learner with a motor disability: brushing the
      // screen beside the dialog must neither answer nor dismiss it.
      final mood = await _pumpHarness(tester, (c, r) async {
        await showCheckInPopup(c, r, _checkIn);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Check-in time!'), findsOneWidget);
      expect(mood.added, isEmpty);
    });

    testWidgets('survives the largest font on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfile.new),
            moodProvider.overrideWith((ref) => _FakeMood()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showCheckInPopup(context, ref, _checkIn),
                      child: const Text('go'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // "Later" stays reachable by scrolling rather than being clipped off.
      await tester.scrollUntilVisible(find.text('Later'), 100);
      expect(find.text('Later'), findsOneWidget);
    });
  });

  group('the per-step question', () {
    testWidgets('asks about the step just finished, in its own words', (
      tester,
    ) async {
      final mood = await _pumpHarness(tester, (c, r) async {
        await askAboutStep(c, r, _brushing);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('How do you feel after brushing your teeth?'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Sad'));
      await tester.pumpAndSettle();

      final entry = mood.added.single;
      expect(entry.activityContext, 'after_step');
      expect(entry.routineStepId, 'brush');
      expect(entry.routineActivity, RoutineActivity.brushingTeeth.index);
      expect(entry.routineStepTitle, 'Brushing Teeth');
    });

    testWidgets('is asked once per step per day', (tester) async {
      final answered = MoodEntry(
        id: 'earlier',
        profileId: _profileId,
        mood: MoodType.happy,
        timestamp: DateTime.now(),
        activityContext: MoodContext.afterStep.storageKey,
        routineStepId: 'brush',
      );
      await _pumpHarness(tester, (c, r) async {
        await askAboutStep(c, r, _brushing);
      }, moods: [answered]);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('How do you feel after brushing your teeth?'),
        findsNothing,
      );
    });

    testWidgets('waking up is asked the natural way', (tester) async {
      await _pumpHarness(tester, (c, r) async {
        await askAboutStep(
          c,
          r,
          const RoutineStep(
            id: 'wake',
            activity: RoutineActivity.morningRoutine,
            askMood: true,
          ),
        );
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('How did you feel when you woke up?'), findsOneWidget);
    });
  });

  group('the watcher raises the pop-up at check-in time', () {
    testWidgets('at 9:00 on Home, it asks', (tester) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(9),
        today: _today([_brushing, _checkIn]),
      );
      expect(find.text('Check-in time!'), findsOneWidget);
      expect(find.text('Please do your check-in now.'), findsOneWidget);
    });

    testWidgets('at 8:59, it waits', (tester) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(8, 59),
        today: _today([_checkIn]),
      );
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('mid-game, it waits for a calmer moment', (tester) async {
      await _pumpWatcher(
        tester,
        location: '/games/word-match',
        now: _todayAt(9, 5),
        today: _today([_checkIn]),
      );
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('once answered, it never asks again today', (tester) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(11),
        today: _today([_checkIn], done: {'ci-9'}),
      );
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('an educator is never asked', (tester) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(9),
        today: _today([_checkIn]),
        role: UserRole.teacher,
      );
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('"Later" closes it and it does not bounce straight back', (
      tester,
    ) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(9),
        today: _today([_checkIn]),
      );
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      // Several more frames at the same clock: the snooze holds.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Check-in time!'), findsNothing);
    });

    testWidgets('never lands on top of another dialog; asks once it closes',
        (tester) async {
      // The daily-reward dialog, a level-up, anything already open: two
      // pop-ups stacked is one the learner never asked for. The check-in
      // waits, then arrives the moment the other one is dismissed.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final clock = StreamController<DateTime>();
      addTearDown(clock.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfile.new),
            moodProvider.overrideWith((ref) => _FakeMood()),
            todayRoutineProvider.overrideWithValue(_today([_checkIn])),
            wallClockTickerProvider.overrideWith((ref) => clock.stream),
            lockStateProvider(_profileId).overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Stack(
                  children: [
                    const RoutineCheckInWatcher(location: '/home'),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('Daily reward'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Collect'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('reward'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      clock.add(_todayAt(8, 59));
      await tester.pump();
      await tester.tap(find.text('reward'));
      await tester.pumpAndSettle();

      // 9:00 arrives while the reward is still up.
      clock.add(_todayAt(9));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Daily reward'), findsOneWidget);
      expect(find.text('Check-in time!'), findsNothing);

      // Dismissed — now it is the check-in's turn.
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();
      expect(find.text('Check-in time!'), findsOneWidget);
    });

    testWidgets('a question already being answered counts as "busy"', (
      tester,
    ) async {
      // The step question sits on the shell's own navigator in the real app,
      // where the watcher's route check cannot see it; the open-question
      // count is what keeps the two from stacking there.
      await _pumpHarness(tester, (c, r) async {
        await askAboutStep(c, r, _brushing);
      });
      expect(isMoodQuestionOpen, isFalse);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(isMoodQuestionOpen, isTrue);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(isMoodQuestionOpen, isFalse);
    });

    testWidgets('a question torn down unanswered does not stay "busy"', (
      tester,
    ) async {
      // The leak this guards against: a sheet removed with its screen never
      // completes its future. Counting on the future would leave the app
      // "busy" forever and no check-in would ever pop again.
      await _pumpHarness(tester, (c, r) async {
        await askAboutStep(c, r, _brushing);
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(isMoodQuestionOpen, isTrue);

      // Tear the whole tree down with the sheet still up.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(isMoodQuestionOpen, isFalse);
    });

    testWidgets('a learner without a check-in step is left entirely alone', (
      tester,
    ) async {
      await _pumpWatcher(
        tester,
        location: '/home',
        now: _todayAt(23),
        today: _today([_brushing]),
      );
      expect(find.text('Check-in time!'), findsNothing);
      expect(find.text('hub'), findsOneWidget);
    });
  });
}
