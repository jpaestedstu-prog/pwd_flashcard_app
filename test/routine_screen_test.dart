import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_screen.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_step_card.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/routine_test_doubles.dart';

/// The learner's day, per accessibility category.
///
/// No Hive and no Firestore: both providers are overridden (see
/// `support/routine_test_doubles.dart`), so nothing here can trip the
/// fake-async Hive write trap.

Widget _app({required List<Override> overrides, Widget? home}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const RoutineScreen(),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  DisabilityType disability = DisabilityType.none,
  UserRole role = UserRole.student,
  List<Routine>? routines,
  Set<String> completed = const <String>{},
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_app(
    overrides: routineOverrides(
      role: role,
      disability: disability,
      routines: routines,
      completed: completed,
    ),
  ));
  await _settle(tester);
}

/// Advances the clock in small steps.
///
/// Never `pumpAndSettle`: the gradient backdrop repeats forever. Small steps
/// rather than one big jump, because a one-shot timer scheduled *during* a
/// pump (flutter_animate schedules one from `initState`, and the empty states
/// are built on it) is only created at the end of that pump — a single large
/// pump would leave it pending and trip the framework's "a Timer is still
/// pending after the widget tree was disposed" check at teardown.
Future<void> _settle(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 900),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// Unmounts so the screen's TTS teardown runs inside the test.
Future<void> _unmount(WidgetTester tester) async {
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // `settingsProvider` (the EN/FIL switch) reads the settings box on the
    // first build. Opened read-only here — nothing in this file writes, which
    // is what keeps it clear of the fake-async Hive write trap.
    Hive.init('./build/test_cache/routine_screen');
    for (final name in const ['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
    // flutter_tts has no platform side under flutter_test, and the screen
    // speaks on open for some accessibility categories. Without a stub the
    // unawaited invocation raises MissingPluginException and fails whichever
    // test happens to be running when it lands.
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

  testWidgets('shows every step of the day for a learner with no assigned '
      'accessibility category', (tester) async {
    await _pump(tester);
    for (final step in defaultTestSteps()) {
      expect(find.text(testTitleOf(step)), findsOneWidget,
          reason: '${step.id} is missing from the day');
    }
    expect(find.text('0 of 4 done'), findsOneWidget);
    await _unmount(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the day is in time order, with the unscheduled step last',
      (tester) async {
    await _pump(tester);
    final cards = tester.widgetList<RoutineStepCard>(
      find.byType(RoutineStepCard),
    );
    expect(
      cards.map((c) => c.step.id),
      ['step-wake', 'step-brush', 'step-breakfast', 'step-tidy'],
    );
    await _unmount(tester);
  });

  testWidgets('a cognitive learner sees one step at a time, with a way to '
      'see the whole day', (tester) async {
    await _pump(tester, disability: DisabilityType.cognitive);
    expect(find.byType(RoutineStepCard), findsOneWidget);
    expect(find.text('Morning Routine'), findsOneWidget);
    expect(find.text('Brushing Teeth'), findsNothing);

    await tester.tap(find.text('Show the whole day (4)'));
    await _settle(tester, const Duration(milliseconds: 400));
    expect(find.byType(RoutineStepCard), findsNWidgets(4));

    // …and a way back to the calm view.
    await tester.tap(find.text('One step at a time'));
    await _settle(tester, const Duration(milliseconds: 400));
    expect(find.byType(RoutineStepCard), findsOneWidget);
    await _unmount(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the collapsed view advances to the next incomplete step',
      (tester) async {
    await _pump(
      tester,
      disability: DisabilityType.cognitive,
      completed: {'step-wake', 'step-brush'},
    );
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('2 of 4 done'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a finished day shows the celebration, not an empty screen',
      (tester) async {
    await _pump(
      tester,
      disability: DisabilityType.cognitive,
      completed: {
        'step-wake',
        'step-brush',
        'step-breakfast',
        'step-tidy',
      },
    );
    expect(find.byType(RoutineStepCard), findsNWidgets(4));
    expect(find.text('The whole day is done!'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('motor and cognitive learners tick off from a full-width '
      'button, not a checkbox', (tester) async {
    for (final type in [DisabilityType.motor, DisabilityType.cognitive]) {
      await _pump(tester, disability: type);
      expect(find.byType(Checkbox), findsNothing, reason: '$type');
      expect(find.text('Mark as done'), findsWidgets, reason: '$type');
      await _unmount(tester);
    }
  });

  testWidgets('a learner with no accessibility category gets the compact '
      'checkbox', (tester) async {
    await _pump(tester);
    expect(find.byType(Checkbox), findsNWidgets(4));
    await _unmount(tester);
  });

  testWidgets('a rest day says so, and is not confused with having no routine',
      (tester) async {
    // A routine that exists but does not run today.
    final tomorrow = DateTime.now().add(const Duration(days: 1)).weekday;
    await _pump(tester, routines: [buildTestRoutine(days: {tomorrow})]);
    expect(find.text('Nothing scheduled today'), findsOneWidget);
    expect(find.text('No routine yet'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('no routine at all explains who sets one up', (tester) async {
    await _pump(tester, routines: const []);
    expect(find.text('No routine yet'), findsOneWidget);
    expect(
      find.textContaining('Your teacher or parent can set up'),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('a disabled routine is hidden from the learner', (tester) async {
    await _pump(tester, routines: [buildTestRoutine(enabled: false)]);
    expect(find.byType(RoutineStepCard), findsNothing);
    expect(find.text('Nothing scheduled today'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('an educator preview is read-only and named after the learner',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(
      overrides: routineOverrides(
        role: UserRole.parent,
        profileId: 'learner-7',
      ),
      home: const RoutineScreen(
        profileId: 'learner-7',
        displayName: 'Ana',
        accessibility: DisabilityType.motor,
        readOnly: true,
      ),
    ));
    await _settle(tester);

    expect(find.text("Ana's Day"), findsOneWidget);
    // The learner's own category shapes the preview, not the educator's:
    // motor collapses to one step with a big button.
    expect(find.byType(RoutineStepCard), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await _unmount(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole day carries one screen-reader label per step',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    // The card merges its own children, so a screen reader hears the title,
    // the time and the done-state as one node rather than four.
    expect(
      find.bySemanticsLabel(
        RegExp(r'Brushing Teeth, 6:45 AM, 2 min, not done yet'),
      ),
      findsOneWidget,
    );
    handle.dispose();
    await _unmount(tester);
  });
}
