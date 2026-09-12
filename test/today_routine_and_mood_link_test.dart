import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/widgets/today_card.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_context.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_summary.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_insights_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/services/quick_mood_check_in.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_mood_prompt.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/mood_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';

/// The join between "My Day" and "Mood Check-In": overdue steps, the
/// completion streak, and the after-my-day question that pairs how a learner
/// felt with a routine an adult can actually change.
///
/// The pure halves are tested as plain `test()` cases so the arithmetic an
/// educator will act on is verifiable without a clock, Hive or Firestore.

const _profileId = 'link-learner';

class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: _profileId,
    name: 'Link Learner',
    role: UserRole.student,
    classroomId: 'class-1',
    createdAt: DateTime(2026),
  );
}

class _FakeMood extends MoodNotifier {
  _FakeMood(List<MoodEntry> entries) : super(_profileId) {
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

RoutineStep _step(String id, {int? hour, int? minute}) => RoutineStep(
  id: id,
  activity: RoutineActivity.brushingTeeth,
  hour: hour,
  minute: minute,
);

RoutineDayLog _log(Set<String> done, {DateTime? day}) => RoutineDayLog(
  profileId: _profileId,
  day: day ?? DateTime.now(),
  completedStepIds: done,
  updatedAt: DateTime.now(),
);

MoodEntry _entry(
  MoodType mood,
  DateTime at, {
  MoodContext context = MoodContext.general,
}) => MoodEntry(
  id: 'm-${at.microsecondsSinceEpoch}-${mood.index}',
  profileId: _profileId,
  mood: mood,
  timestamp: at,
  activityContext: context.storageKey,
);

/// A day log carrying a frozen schedule, which is what the streak is scored
/// against (see `RoutineHistory`).
RoutineDayLog _recordedDay(
  DateTime day, {
  required List<String> scheduled,
  required Set<String> done,
}) => RoutineDayLog(
  profileId: _profileId,
  day: DateTime(day.year, day.month, day.day),
  completedStepIds: done,
  scheduled: [
    for (final id in scheduled)
      RoutineDayStep(
        id: id,
        activity: RoutineActivity.brushingTeeth,
        title: 'Step $id',
        emoji: '🦷',
      ),
  ],
  snapshotAt: day,
  updatedAt: day,
);

void main() {
  group('overdue', () {
    TodayRoutine routine(List<RoutineStep> steps, Set<String> done) =>
        TodayRoutine(
          steps: steps,
          log: _log(done),
          streak: 0,
          hasEducator: true,
        );

    test('a scheduled step whose time has passed is overdue', () {
      final today = routine([_step('s1', hour: 7, minute: 0)], const {});
      expect(today.isOverdue(DateTime(2026, 9, 11, 7, 30)), isTrue);
    });

    test('a scheduled step still to come is not', () {
      final today = routine([_step('s1', hour: 7, minute: 0)], const {});
      expect(today.isOverdue(DateTime(2026, 9, 11, 6, 30)), isFalse);
    });

    test('an unscheduled step is never overdue', () {
      // "After breakfast" is meaningful and cannot be late — a real shape for
      // a cognitive-accessibility routine, and one that must not be scolded.
      final today = routine([_step('s1')], const {});
      expect(today.isOverdue(DateTime(2026, 9, 11, 23, 59)), isFalse);
    });

    test('a finished day is never overdue', () {
      final today = routine([_step('s1', hour: 7, minute: 0)], {'s1'});
      expect(today.isOverdue(DateTime(2026, 9, 11, 23, 59)), isFalse);
      expect(today.allDone, isTrue);
      expect(today.nextStep, isNull);
    });

    test('an empty day is never overdue', () {
      expect(
        TodayRoutine.none.isOverdue(DateTime(2026, 9, 11, 23, 59)),
        isFalse,
      );
    });
  });

  group('answering the same question twice', () {
    test('a morning check-in does not answer the after-my-day one', () {
      final entries = [_entry(MoodType.happy, DateTime.now())];
      expect(hasCheckedInFor(entries, MoodContext.afterRoutine), isFalse);
      expect(hasCheckedInFor(entries, MoodContext.general), isTrue);
    });

    test('an after-my-day check-in does', () {
      final entries = [
        _entry(
          MoodType.tired,
          DateTime.now(),
          context: MoodContext.afterRoutine,
        ),
      ];
      expect(hasCheckedInFor(entries, MoodContext.afterRoutine), isTrue);
    });

    test("yesterday's answer does not count for today", () {
      final entries = [
        _entry(
          MoodType.tired,
          DateTime.now().subtract(const Duration(days: 1)),
          context: MoodContext.afterRoutine,
        ),
      ];
      expect(hasCheckedInFor(entries, MoodContext.afterRoutine), isFalse);
    });

    test('an entry written before contexts existed reads as general', () {
      final legacy = MoodEntry(
        id: 'legacy',
        profileId: _profileId,
        mood: MoodType.happy,
        timestamp: DateTime.now(),
      );
      expect(hasCheckedInFor([legacy], MoodContext.general), isTrue);
      expect(hasCheckedInFor([legacy], MoodContext.afterRoutine), isFalse);
    });
  });

  group('MoodSummary pairs the routine with the feeling', () {
    test('it counts only the after-my-day check-ins', () {
      final now = DateTime.now();
      final summary = MoodSummary.fromEntries([
        _entry(MoodType.happy, now),
        _entry(MoodType.tired, now, context: MoodContext.afterRoutine),
        _entry(
          MoodType.tired,
          now.subtract(const Duration(days: 1)),
          context: MoodContext.afterRoutine,
        ),
        _entry(
          MoodType.happy,
          now.subtract(const Duration(days: 2)),
          context: MoodContext.afterGame,
        ),
      ], now: now);

      expect(summary.entryCount, 4);
      expect(summary.routineCount, 2);
      expect(summary.routineDominantMood, MoodType.tired);
      expect(
        summary.routineLabelOf(isFilipino: false),
        'My Day check-ins: mostly Tired (2)',
      );
    });

    test('a learner who never answered it gets no line at all', () {
      final summary = MoodSummary.fromEntries([
        _entry(MoodType.happy, DateTime.now()),
      ]);
      expect(summary.hasRoutineMoods, isFalse);
      expect(summary.routineLabelOf(isFilipino: false), isNull);
    });

    test('a tie breaks toward the lower mood, as the overall one does', () {
      final now = DateTime.now();
      final summary = MoodSummary.fromEntries([
        _entry(MoodType.happy, now, context: MoodContext.afterRoutine),
        _entry(
          MoodType.sad,
          now.subtract(const Duration(hours: 1)),
          context: MoodContext.afterRoutine,
        ),
      ], now: now);

      expect(summary.routineDominantMood, MoodType.sad);
    });

    test('the Filipino line is Filipino', () {
      final summary = MoodSummary.fromEntries([
        _entry(
          MoodType.tired,
          DateTime.now(),
          context: MoodContext.afterRoutine,
        ),
      ]);
      expect(
        summary.routineLabelOf(isFilipino: true),
        contains('Check-in sa Araw Ko'),
      );
    });
  });

  group('widgets', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/today_link');
      for (final name in const <String>[
        'profiles',
        'settings',
        'progress',
        'routines',
        'routine_logs',
        'sessions',
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

    testWidgets('the streak the history screen computes reaches the learner', (
      tester,
    ) async {
      // Two complete days behind today, then today in progress. The streak
      // must not evaporate at 9am because today is unfinished.
      final now = DateTime.now();
      final logs = [
        _recordedDay(now, scheduled: ['s1', 's2'], done: {'s1'}),
        _recordedDay(
          now.subtract(const Duration(days: 1)),
          scheduled: ['s1', 's2'],
          done: {'s1', 's2'},
        ),
        _recordedDay(
          now.subtract(const Duration(days: 2)),
          scheduled: ['s1', 's2'],
          done: {'s1', 's2'},
        ),
      ];

      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfile.new),
            moodProvider.overrideWith((ref) => _FakeMood(const [])),
            myRoutinesProvider.overrideWith(
              (ref) => Stream.value([
                Routine(
                  id: 'r1',
                  childProfileId: _profileId,
                  setterProfileId: 'teacher',
                  setterRole: UserRole.teacher,
                  name: 'Morning',
                  steps: [_step('s1'), _step('s2')],
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ]),
            ),
            routineDayLogProvider.overrideWith(
              (ref, key) => Stream.value(_log({'s1'})),
            ),
            routineHistoryProvider.overrideWith((ref, id) => logs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TodayCard(child: TodayDayPane(onOpen: () {})),
                    TodayCard(child: TodayMoodPane(onOpen: () {})),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('🔥 2'), findsOneWidget);
      expect(find.text('1 of 2 done'), findsOneWidget);
    });

    testWidgets('finishing the day asks how it went, and records the context', (
      tester,
    ) async {
      final mood = _FakeMood(const []);

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
                    onPressed: () => showRoutineMoodPrompt(context, ref),
                    child: const Text('finish'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();

      // The sheet names the moment rather than asking a generic question.
      expect(
        find.text('You finished your day! How do you feel?'),
        findsOneWidget,
      );
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Tired'));
      await tester.pump();

      // The note comes *after* the face, and saving is the learner's own act.
      // A sheet that recorded on the tap of a face would have nowhere to put
      // the sentence — which is the whole reason the field exists.
      expect(
        find.text('Write why you feel this way (optional)...'),
        findsOneWidget,
      );
      expect(mood.added, isEmpty, reason: 'the face only chose; Save records');

      await tester.enterText(find.byType(TextField), 'my legs hurt');
      await tester.tap(find.bySemanticsLabel('Save how you feel'));
      await tester.pumpAndSettle();

      expect(mood.added, hasLength(1));
      expect(mood.added.single.mood, MoodType.tired);
      expect(mood.added.single.note, 'my legs hurt');
      expect(
        mood.added.single.activityContext,
        'after_routine',
        reason: 'this is the one context an adult can act on',
      );

      // Asked once. A learner who has answered is not asked again today.
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.text('Not now'), findsNothing);
    });

    testWidgets('Mood Insights names the pairing instead of burying it', (
      tester,
    ) async {
      // The activity chart gains an "After My Day" bar for free once the
      // context is written, but one bar among six is skimmed. The named
      // comparison above it is the thing a learner actually reads.
      final now = DateTime.now();
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfile.new),
            moodProvider.overrideWith(
              (ref) => _FakeMood([
                _entry(
                  MoodType.tired,
                  now.subtract(const Duration(days: 1)),
                  context: MoodContext.afterRoutine,
                ),
                _entry(
                  MoodType.tired,
                  now.subtract(const Duration(days: 2)),
                  context: MoodContext.afterRoutine,
                ),
                _entry(MoodType.happy, now.subtract(const Duration(days: 3))),
              ]),
            ),
          ],
          child: const MaterialApp(home: MoodInsightsScreen()),
        ),
      );
      await tester.pump();

      // The named breakdown, which is the point of the addition: the
      // day-end answers read as a row of their own…
      expect(find.text('During My Day'), findsOneWidget);
      expect(find.text('Finishing the day'), findsOneWidget);
      expect(find.text('Mostly Tired · 2 times'), findsOneWidget);
      // …and the activity chart's own bucket, which the context write
      // populates for free. Before contexts were written every entry fell
      // into a single `general` bucket and that chart was one meaningless bar.
      expect(find.text('After My Day'), findsOneWidget);

      // The screen's entrance animations schedule one-shot timers; advance in
      // small steps and unmount, or `testWidgets` ends with them pending.
      // (Never `pumpAndSettle` — the gradient backdrop repeats forever.)
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('"Not now" records nothing', (tester) async {
      final mood = _FakeMood(const []);

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
                    onPressed: () => showRoutineMoodPrompt(context, ref),
                    child: const Text('finish'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(mood.added, isEmpty);
    });
  });
}
