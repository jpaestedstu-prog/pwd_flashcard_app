import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/widgets/today_card.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_context.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_presentation.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/mood_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';

/// The Home "Today" card — Mood Check-In and My Day in one card, both halves
/// live **and** actionable in place.
///
/// What these tests protect is the reason the two tiles were merged and moved
/// to the top of Home: the card shows today's state, and it lets the learner
/// change that state without a screen change. A card that reads the same all
/// day, or that only navigates, is the pair of dead tiles it replaced.
///
/// Everything is driven through provider overrides rather than Hive: an
/// awaited `box.put` from inside `testWidgets` poisons the write queue for the
/// whole file (see the project's Hive-hang notes).

const _profileId = 'today-learner';

class _StubProfile extends ProfileNotifier {
  _StubProfile({this.classroomId = 'class-1', this.role = UserRole.student});

  final String? classroomId;
  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: _profileId,
    name: 'Today Learner',
    role: role,
    classroomId: classroomId,
    createdAt: DateTime(2026),
  );
}

/// In-memory mood store: records what the card wrote without touching Hive.
class _FakeMood extends MoodNotifier {
  _FakeMood(List<MoodEntry> entries) : super(_profileId) {
    state = entries;
  }

  final List<MoodEntry> added = [];
  final List<String> updated = [];

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

  @override
  Future<void> updateMood(
    String entryId,
    MoodType mood, {
    String? note,
  }) async {
    updated.add(entryId);
    state = [
      for (final e in state)
        if (e.id == entryId) e.copyWith(mood: mood) else e,
    ];
  }
}

MoodEntry _entry(
  MoodType mood,
  DateTime at, {
  MoodContext context = MoodContext.general,
  String? stepId,
  String? title,
}) => MoodEntry(
  id: 'm-${at.microsecondsSinceEpoch}',
  profileId: _profileId,
  mood: mood,
  timestamp: at,
  activityContext: context.storageKey,
  routineStepId: stepId,
  routineStepTitle: title,
);

/// The semantic label of the card whose label starts with [prefix] — the
/// sentence a screen reader actually reads out for that card.
String _openLabel(WidgetTester tester, String prefix) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.label ?? '')
    .firstWhere((l) => l.startsWith(prefix), orElse: () => '');

RoutineStep _step(
  String id,
  RoutineActivity activity, {
  int? hour,
  int? minute,
  bool enabled = true,
}) => RoutineStep(
  id: id,
  activity: activity,
  hour: hour,
  minute: minute,
  enabled: enabled,
);

Routine _routine(List<RoutineStep> steps, {Set<int> days = const {}}) =>
    Routine(
      id: 'r1',
      childProfileId: _profileId,
      setterProfileId: 'teacher',
      setterRole: UserRole.teacher,
      name: 'Morning',
      daysOfWeek: days,
      steps: steps,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineDayLog _log(Set<String> done) => RoutineDayLog(
  profileId: _profileId,
  day: DateTime.now(),
  completedStepIds: done,
  updatedAt: DateTime.now(),
);

/// Pumps the card. Returns the mood store so a test can assert what was
/// written and with which context.
Future<_FakeMood> _pump(
  WidgetTester tester, {
  List<MoodEntry> moods = const [],
  List<Routine> routines = const [],
  Set<String> done = const {},
  Size size = const Size(900, 700),
  double textScale = 1.0,
  String? classroomId = 'class-1',
  List<Override> extra = const [],
  UserRole role = UserRole.student,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final mood = _FakeMood(moods);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          () => _StubProfile(classroomId: classroomId, role: role),
        ),
        moodProvider.overrideWith((ref) => mood),
        myRoutinesProvider.overrideWith((ref) => Stream.value(routines)),
        routineDayLogProvider.overrideWith(
          (ref, key) => Stream.value(_log(done)),
        ),
        ...extra,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              // The two cards as Home stacks them: My Day, then Mood
              // Check-In.
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
    ),
  );
  await tester.pump();
  return mood;
}

/// Finds a mood face button by its accessibility label.
Finder _face(MoodType mood, {bool selected = false}) => find.bySemanticsLabel(
  selected
      ? '${mood.label}. This is how you feel today.'
      : 'Check in as ${mood.label}',
);

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/today_card');
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

  group('the card shows today', () {
    testWidgets('a learner who has done neither is invited to do both', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Mood Check-In'), findsOneWidget);
      expect(find.text('My Day'), findsOneWidget);
      expect(find.text('How are you today?'), findsOneWidget);
    });

    testWidgets("today's check-in is shown back, not re-requested", (
      tester,
    ) async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      // Anchored to today rather than "3 hours ago": for the first hours after
      // midnight that was yesterday, and this test failed whenever the suite
      // ran then. Never later than now, so no entry is in the future.
      DateTime todayAt(Duration sinceMidnight) {
        final t = midnight.add(sinceMidnight);
        return t.isAfter(now) ? now : t;
      }
      await _pump(
        tester,
        moods: [
          // Yesterday's entry must not be mistaken for today's, and the
          // latest of today's wins — a learner who corrects their face should
          // see the correction.
          _entry(MoodType.sad, now.subtract(const Duration(days: 1))),
          _entry(MoodType.tired, todayAt(Duration.zero)),
          _entry(MoodType.happy, todayAt(const Duration(microseconds: 1))),
        ],
      );

      expect(find.text('Feeling Happy'), findsOneWidget);
      expect(find.text('How are you today?'), findsNothing);
    });

    testWidgets('My Day counts the steps that run today and rings them', (
      tester,
    ) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine),
            _step('s2', RoutineActivity.brushingTeeth),
            _step('s3', RoutineActivity.breakfast),
          ]),
        ],
        done: {'s1'},
      );

      // A Student's day runs on the clock: where they are in it, not "done".
      expect(find.text('Step 2 of 3'), findsOneWidget);

      final rings = tester
          .widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .toList();
      expect(rings, hasLength(1), reason: 'only My Day carries a ring');
      expect(rings.single.value, closeTo(1 / 3, 0.001));
    });

    testWidgets('a step disabled by the educator drops out of the count', (
      tester,
    ) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine),
            _step('s2', RoutineActivity.brushingTeeth, enabled: false),
          ]),
        ],
      );

      expect(find.text('Step 1 of 1'), findsOneWidget);
    });

    testWidgets('a routine that does not run today is not counted', (
      tester,
    ) async {
      final days = <int>{
        for (var d = 1; d <= 7; d++)
          if (d != DateTime.now().weekday) d,
      };
      await _pump(
        tester,
        routines: [
          _routine([_step('s1', RoutineActivity.morningRoutine)], days: days),
        ],
      );

      expect(find.text('Ask your teacher or parent'), findsOneWidget);
    });
  });

  group('one-tap check-in', () {
    testWidgets('tapping a face records it without leaving Home', (
      tester,
    ) async {
      final mood = await _pump(tester);

      await tester.tap(_face(MoodType.happy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(mood.added, hasLength(1));
      expect(mood.added.single.mood, MoodType.happy);
      expect(find.text('Feeling Happy'), findsOneWidget);
    });

    testWidgets("the faces offered are the profile's own set", (tester) async {
      // Cognitive / multiple-disability learners get three faces on the full
      // screen. A shortcut offering a different vocabulary would skew the very
      // data the insights are drawn from, so it offers the same three.
      await _pump(
        tester,
        extra: [
          moodPresentationProvider.overrideWithValue(
            const MoodPresentation(
              choices: MoodPresentation.simpleChoices,
              showNote: false,
              showNumericAverage: false,
              speakSelection: false,
              animate: false,
            ),
          ),
        ],
      );

      expect(_face(MoodType.happy), findsOneWidget);
      expect(_face(MoodType.neutral), findsOneWidget);
      expect(_face(MoodType.sad), findsOneWidget);
      expect(_face(MoodType.frustrated), findsNothing);
      expect(_face(MoodType.excited), findsNothing);
    });

    testWidgets(
      're-tapping corrects today rather than filing a second entry',
      (tester) async {
        final mood = await _pump(
          tester,
          moods: [_entry(MoodType.sad, DateTime.now())],
        );

        await tester.tap(_face(MoodType.happy));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(mood.added, isEmpty, reason: 'the same moment is corrected');
        expect(mood.updated, hasLength(1));
        expect(find.text('Feeling Happy'), findsOneWidget);
      },
    );

    testWidgets('a morning check-in and an after-my-day one both stand', (
      tester,
    ) async {
      // Two different questions, two facts. Overwriting the first with the
      // second would erase the pattern the insights exist to show.
      final mood = await _pump(
        tester,
        moods: [
          _entry(
            MoodType.tired,
            DateTime.now(),
            context: MoodContext.afterRoutine,
          ),
        ],
      );

      await tester.tap(_face(MoodType.happy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(mood.updated, isEmpty);
      expect(mood.added, hasLength(1));
      expect(mood.added.single.activityContext, 'general');
    });

    testWidgets("today's face is marked as selected for a screen reader", (
      tester,
    ) async {
      await _pump(tester, moods: [_entry(MoodType.tired, DateTime.now())]);

      expect(_face(MoodType.tired, selected: true), findsOneWidget);
      expect(_face(MoodType.happy), findsOneWidget);
    });
  });

  group('the next step, its time, and Done', () {
    testWidgets('the next step names itself and its clock time', (
      tester,
    ) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine, hour: 6, minute: 30),
            _step('s2', RoutineActivity.brushingTeeth, hour: 18, minute: 5),
          ]),
        ],
        done: {'s1'},
      );

      expect(find.textContaining('Brushing Teeth'), findsOneWidget);
      expect(find.textContaining('6:05 PM'), findsOneWidget);
    });

    testWidgets('an unscheduled step shows no time and is never overdue', (
      tester,
    ) async {
      // "After breakfast" is a real and common shape for a cognitive-
      // accessibility routine, and it cannot be late.
      await _pump(
        tester,
        routines: [
          _routine([_step('s1', RoutineActivity.brushingTeeth)]),
        ],
      );

      expect(find.textContaining('Brushing Teeth'), findsOneWidget);
      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('PM'), findsNothing);
    });

    testWidgets('a Player’s Done is present and big enough to hit', (
      tester,
    ) async {
      await _pump(
        tester,
        role: UserRole.player,
        classroomId: null,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine),
            _step('s2', RoutineActivity.brushingTeeth),
          ]),
        ],
      );

      final done = find.bySemanticsLabel('Mark Morning Routine as done');
      expect(done, findsOneWidget);
      expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a Student has no Done — the card only says what is next', (
      tester,
    ) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine),
            _step('s2', RoutineActivity.brushingTeeth),
          ]),
        ],
      );

      expect(
        find.bySemanticsLabel('Mark Morning Routine as done'),
        findsNothing,
      );
      expect(find.text('Done'), findsNothing);
      expect(find.textContaining('Next: Morning Routine'), findsOneWidget);
    });

    testWidgets(
      'a finished day celebrates instead of counting, and hides Done',
      (tester) async {
        await _pump(
          tester,
          routines: [
            _routine([
              _step('s1', RoutineActivity.morningRoutine),
              _step('s2', RoutineActivity.brushingTeeth),
            ]),
          ],
          done: {'s1', 's2'},
        );

        expect(find.text('That’s all for today 🎉'), findsOneWidget);
        expect(find.text('All done! 🎉'), findsNothing);
        expect(find.textContaining('Mark '), findsNothing);
      },
    );

    testWidgets('a Player’s finished day still says all done', (tester) async {
      await _pump(
        tester,
        role: UserRole.player,
        classroomId: null,
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine),
            _step('s2', RoutineActivity.brushingTeeth),
          ]),
        ],
        done: {'s1', 's2'},
      );

      expect(find.text('All done! 🎉'), findsOneWidget);
    });
  });

  group('the empty day', () {
    testWidgets('a learner with an educator is told who can fill it', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Ask your teacher or parent'), findsOneWidget);
    });

    testWidgets('a learner with nobody to ask is not sent to ask them', (
      tester,
    ) async {
      // A Player profile belongs to no class and no family group. Telling them
      // to ask their teacher points at nobody.
      await _pump(tester, classroomId: null);
      expect(find.text('Ask your teacher or parent'), findsNothing);
      expect(find.text('Nothing planned today'), findsOneWidget);
    });
  });

  group('My Day + Mood', () {
    // What makes the first card "My Day + Mood": the answers the *routine*
    // collected. Not a second check-in control — the Mood Check-In card owns
    // that — and not a claim about answers the routine never asked for.
    //
    // Read through the semantic label, because the chip itself sits inside the
    // header's excluded subtree: the sentence below is the only form of it a
    // screen reader ever gets, so it is the one worth testing.
    testWidgets('My Day names the mood its own question collected', (
      tester,
    ) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.brushingTeeth, hour: 7, minute: 0),
          ]),
        ],
        moods: [
          _entry(
            MoodType.sad,
            DateTime.now(),
            context: MoodContext.afterStep,
            stepId: 's1',
            title: 'Brushing Teeth',
          ),
        ],
      );

      expect(
        _openLabel(tester, 'My Day'),
        contains('You felt Sad after Brushing Teeth.'),
      );
    });

    testWidgets('the day-end answer speaks for the day itself', (tester) async {
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.brushingTeeth, hour: 7, minute: 0),
          ]),
        ],
        moods: [
          _entry(
            MoodType.tired,
            DateTime.now(),
            context: MoodContext.afterRoutine,
          ),
        ],
      );

      expect(
        _openLabel(tester, 'My Day'),
        contains('You said today felt Tired.'),
      );
    });

    testWidgets('a plain Home check-in is not claimed by My Day', (
      tester,
    ) async {
      // Answering "how are you today?" on Home says nothing about the
      // routine, and a schedule that implied otherwise would be inventing
      // data for the educator's wellbeing view to read.
      await _pump(
        tester,
        routines: [
          _routine([
            _step('s1', RoutineActivity.brushingTeeth, hour: 7, minute: 0),
          ]),
        ],
        moods: [_entry(MoodType.happy, DateTime.now())],
      );

      expect(_openLabel(tester, 'My Day'), isNot(contains('You felt')));
      expect(_openLabel(tester, 'My Day'), isNot(contains('today felt')));
      // …and the Mood Check-In card still shows it, because that is the card
      // it belongs to.
      expect(find.text('Feeling Happy'), findsOneWidget);
    });
  });

  group('layout', () {
    // The two cards go to different screens, so they must stay two separate
    // "open" targets — and the in-place controls must sit outside them, or a
    // learner reaching for a face would navigate instead.
    testWidgets('each card has its own open target', (tester) async {
      await _pump(tester);

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.button == true)
          .map((s) => s.properties.label ?? '')
          .where((l) => l.isNotEmpty)
          .toList();

      expect(labels.where((l) => l.startsWith('Mood check-in')), hasLength(1));
      expect(labels.where((l) => l.startsWith('My Day')), hasLength(1));
    });

    // The worst case from the app's overflow matrix: a small phone at the
    // largest font setting. Full-width cards have room to grow downwards;
    // what this guards is that the title row — now carrying a streak chip and
    // a mood chip beside the title — still does not overflow sideways.
    testWidgets('survives 2.0x on a small phone', (tester) async {
      await _pump(
        tester,
        size: const Size(360, 640),
        textScale: 2.0,
        moods: [_entry(MoodType.frustrated, DateTime.now())],
        routines: [
          _routine([
            _step('s1', RoutineActivity.morningRoutine, hour: 7, minute: 0),
            _step('s2', RoutineActivity.brushingTeeth),
          ]),
        ],
        done: {'s1'},
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Mood Check-In'), findsOneWidget);
      expect(find.text('My Day'), findsOneWidget);
    });

    testWidgets('Mood Check-In is a card of its own, under My Day', (
      tester,
    ) async {
      // The order the learner asked for: the day first, then the question.
      // Two cards, not two halves of one — see the note on [TodayCard].
      await _pump(tester);

      expect(find.byType(TodayCard), findsNWidgets(2));
      final day = tester.getTopLeft(find.byType(TodayDayPane));
      final mood = tester.getTopLeft(find.byType(TodayMoodPane));
      expect(day.dy, lessThan(mood.dy));
      expect(
        day.dx,
        mood.dx,
        reason: 'full width each, one under the other',
      );
    });

    testWidgets('the Child home can rename the mood card', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfile.new),
            moodProvider.overrideWith((ref) => _FakeMood(const [])),
            myRoutinesProvider.overrideWith(
              (ref) => Stream.value(const <Routine>[]),
            ),
            routineDayLogProvider.overrideWith(
              (ref, key) => Stream.value(_log(const {})),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TodayCard(
                child: TodayMoodPane(onOpen: () {}, title: 'My Feelings'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('My Feelings'), findsOneWidget);
      expect(find.text('Mood Check-In'), findsNothing);
    });
  });
}
