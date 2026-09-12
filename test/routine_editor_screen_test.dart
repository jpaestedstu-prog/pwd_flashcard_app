import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_builder_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_editor_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_step_editor_sheet.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_media.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/routine_test_doubles.dart';

/// The educator side: the routine manager for one learner, the builder, and
/// the step editor where media and FSL content are attached.
///
/// Nothing here saves — a save would reach `RoutineService` and therefore
/// Hive, and one fire-and-forget `box.put` inside the fake-async zone poisons
/// the write queue for the rest of the run. Persistence is covered by the pure
/// model tests.

const _learnerId = 'learner-7';

Widget _app({required Widget home, List<Routine>? routines}) {
  return ProviderScope(
    overrides: routineOverrides(
      role: UserRole.teacher,
      profileId: _learnerId,
      routines: routines,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<void> _settle(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 900),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  List<Routine>? routines,
  DisabilityType accessibility = DisabilityType.cognitive,
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(
    routines: routines,
    home: RoutineEditorScreen(
      childProfileId: _learnerId,
      childDisplayName: 'Ana',
      learnerNoun: 'student',
      accessibility: accessibility,
    ),
  ));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/routine_editor_screen');
    for (final name in const ['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('the routine manager', () {
    testWidgets('is titled after the learner', (tester) async {
      await _pumpEditor(tester);
      expect(find.text('Routines — Ana'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty roster offers to build the first routine',
        (tester) async {
      await _pumpEditor(tester, routines: const []);
      expect(find.text('No routines yet'), findsOneWidget);
      expect(find.text('Create a routine'), findsOneWidget);
      expect(find.textContaining('Build a daily routine for Ana'),
          findsOneWidget);
      await _unmount(tester);
    });

    testWidgets("shows today's progress across the learner's routines",
        (tester) async {
      await _pumpEditor(tester);
      // ProSectionHeader renders its title uppercase.
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('0 of 4 activities done'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('lists each routine with its recurrence and step count',
        (tester) async {
      await _pumpEditor(tester, routines: [
        buildTestRoutine(days: const {1, 3, 5}),
      ]);
      expect(find.text('School Morning'), findsOneWidget);
      expect(find.text('4 steps · Mon, Wed, Fri'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the template sheet leads with the learner’s own suggestions',
        (tester) async {
      await _pumpEditor(tester, routines: const []);
      await tester.tap(find.text('Create a routine'));
      await _settle(tester);

      expect(find.text('Start from…'), findsOneWidget);
      expect(
        find.text('Suggested for Cognitive/Learning'),
        findsOneWidget,
      );
      // The cognitive-tailored templates, then the general ones.
      expect(find.text('Self-Care Basics'), findsOneWidget);
      expect(find.text('Calm Day'), findsOneWidget);
      expect(find.text('Full Day'), findsOneWidget);
      expect(find.text('Start from a blank routine'), findsOneWidget);

      // Close without creating: creating would reach the service and Hive.
      Navigator.of(tester.element(find.text('Start from…'))).pop();
      await _settle(tester);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the routine builder', () {
    Future<void> pumpBuilder(WidgetTester tester, {Routine? routine}) async {
      tester.view.physicalSize = const Size(900, 1800) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(
        home: RoutineBuilderScreen(
          routine: routine ?? buildTestRoutine(),
          learnerNoun: 'student',
          learnerName: 'Ana',
        ),
      ));
      await _settle(tester);
    }

    testWidgets('shows the routine’s name, days and steps', (tester) async {
      await pumpBuilder(tester);
      expect(find.text('Edit Routine'), findsOneWidget);
      expect(find.text('Runs every day'), findsOneWidget);
      expect(find.text('Morning Routine'), findsOneWidget);
      expect(find.text('Tidy the toys'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Save is disabled until something changes', (tester) async {
      await pumpBuilder(tester);
      final save = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(TextButton),
        ),
      );
      expect(save.onPressed, isNull);
      await _unmount(tester);
    });

    testWidgets('picking days marks the routine dirty and enables Save',
        (tester) async {
      await pumpBuilder(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Wed'));
      await _settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Runs on Wed'), findsOneWidget);
      final save = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(TextButton),
        ),
      );
      expect(save.onPressed, isNotNull);
      await _unmount(tester);
    });

    testWidgets('selecting all seven days normalises back to "every day"',
        (tester) async {
      // One representation in storage: an empty set. Otherwise "every day"
      // and "Mon–Sun" would be two different rows meaning the same thing.
      await pumpBuilder(tester);
      for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        await tester.tap(find.widgetWithText(FilterChip, d));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Runs every day'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the activity picker offers the brief’s fourteen activities '
        'plus a custom one', (tester) async {
      await pumpBuilder(tester);
      await tester.tap(find.text('Add activity'));
      await _settle(tester);

      expect(find.text('Choose an activity'), findsOneWidget);
      for (final label in const [
        'Morning Routine',
        'Brushing Teeth',
        'Breakfast',
        'Lunch',
        'Break Time',
        'Nap Time',
        'Dinner',
        'Bath Time',
        'Getting Dressed',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Later rows need a scroll on a phone-height sheet.
      await tester.dragUntilVisible(
        find.text('Custom activity'),
        find.byType(ListView).last,
        const Offset(0, -120),
      );
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Custom activity'), findsOneWidget);

      Navigator.of(tester.element(find.text('Custom activity'))).pop();
      await _settle(tester);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a step can be removed from the routine', (tester) async {
      await pumpBuilder(tester);
      expect(find.text('Breakfast'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Breakfast'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await _settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Delete').last);
      await _settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('3 steps · drag to reorder'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a step can be hidden from the learner without deleting it',
        (tester) async {
      await pumpBuilder(tester);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Breakfast'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await _settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Hide from learner'));
      await _settle(tester, const Duration(milliseconds: 400));
      // Still listed for the educator — struck through, not gone.
      expect(find.text('Breakfast'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('the step editor', () {
    Future<void> pumpSheet(WidgetTester tester, RoutineStep step) async {
      tester.view.physicalSize = const Size(900, 1800) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(
        home: Scaffold(
          body: RoutineStepEditorSheet(step: step, filipino: false),
        ),
      ));
      await _settle(tester);
    }

    testWidgets('offers a field for every media channel, each with its own '
        'placeholder hint', (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(id: 's', activity: RoutineActivity.brushingTeeth),
      );
      expect(find.text('Photo, GIF, video & sound'), findsOneWidget);
      expect(
        find.text('A photo of this step can be added here.'),
        findsOneWidget,
      );
      expect(
        find.text('A short looping GIF can be added here.'),
        findsOneWidget,
      );
      expect(
        find.text('A demonstration video can be added here.'),
        findsOneWidget,
      );
      expect(
        find.text('A recorded voice cue can be added here.'),
        findsOneWidget,
      );
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('previews the placeholders the learner would actually see',
        (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(id: 's', activity: RoutineActivity.brushingTeeth),
      );
      // Below the reminder controls and the "ask how they feel" switch, so
      // scrolled into view like the signs section below it.
      await tester.dragUntilVisible(
        find.text('What the learner will see'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.text('What the learner will see'), findsOneWidget);
      // Photo, GIF and video slots, all empty, all showing the designed
      // stand-in rather than a blank box.
      expect(find.byType(RoutineMediaPlaceholder), findsNWidgets(3));
      await _unmount(tester);
    });

    testWidgets('offers "ask how they feel", showing the exact question',
        (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(id: 's', activity: RoutineActivity.brushingTeeth),
      );
      await tester.dragUntilVisible(
        find.text('Ask how they feel after this step'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await _settle(tester, const Duration(milliseconds: 300));
      // The educator reads the words the learner will be asked, not a setting
      // name.
      expect(
        find.text('“How do you feel after brushing your teeth?”'),
        findsOneWidget,
      );
      final off = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(off.value, isFalse, reason: 'off unless the educator asks');

      await tester.tap(find.text('Ask how they feel after this step'));
      await _settle(tester, const Duration(milliseconds: 300));
      final on = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(on.value, isTrue);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a check-in step explains its pop-up instead of the switch',
        (tester) async {
      // A check-in step *is* a question; asking "how do you feel after your
      // check-in?" would be absurd, so the switch is replaced by what the
      // learner will actually get at that time.
      await pumpSheet(
        tester,
        const RoutineStep(
          id: 'ci',
          activity: RoutineActivity.moodCheckIn,
          hour: 9,
          minute: 0,
        ),
      );
      await tester.dragUntilVisible(
        find.textContaining('Please do your check-in now.'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.textContaining('notification and a pop-up'),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('names the built-in signs an activity already carries',
        (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(id: 's', activity: RoutineActivity.brushingTeeth),
      );
      // The FSL section sits at the bottom of a long sheet — below the media
      // slots and the reminder controls — so it has to be scrolled into view
      // before `find.text` can see it.
      // `.first` is the sheet's own vertical list — `.last` is the
      // horizontal preview strip nested inside it, which scrolls sideways
      // and will never bring this into view.
      await tester.dragUntilVisible(
        find.text('Built-in signs: Teeth · Water'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Built-in signs: Teeth · Water'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a custom activity gets no built-in signs and says so',
        (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(id: 's', activity: RoutineActivity.custom),
      );
      expect(find.textContaining('Built-in signs:'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('the time can be cleared, leaving a sequenced step',
        (tester) async {
      await pumpSheet(
        tester,
        const RoutineStep(
          id: 's',
          activity: RoutineActivity.lunch,
          hour: 12,
          minute: 0,
        ),
      );
      expect(find.text('12:00 PM'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await _settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Set a time'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
