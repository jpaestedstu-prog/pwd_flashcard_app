import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_presentation.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_step_screen.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_media.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

import 'support/routine_test_doubles.dart';

/// One routine step, full screen — the surface that carries the brief's
/// accessibility content: visual instructions, photo / GIF / video / audio,
/// the FSL button, and the timer.

const _brushing = RoutineStep(
  id: 'step-brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
  durationMinutes: 2,
);

Widget _app({
  required RoutineStep step,
  required DisabilityType type,
  bool readOnly = false,
  bool canTick = true,
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      ...routineOverrides(disability: type),
      if (now != null)
        wallClockTickerProvider.overrideWith((ref) => Stream.value(now)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RoutineStepScreen(
        step: step,
        presentation: RoutinePresentation.forType(type),
        profileId: kTestProfileId,
        day: DateTime.now(),
        readOnly: readOnly,
        canTick: canTick,
      ),
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

Future<void> _pump(
  WidgetTester tester, {
  RoutineStep step = _brushing,
  DisabilityType type = DisabilityType.none,
  bool readOnly = false,
  Size size = const Size(800, 1600),
  bool canTick = true,
  DateTime? now,
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(
    step: step,
    type: type,
    readOnly: readOnly,
    canTick: canTick,
    now: now,
  ));
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/routine_step_screen');
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

  group('visual instructions', () {
    testWidgets('a built-in activity arrives with a numbered picture sequence',
        (tester) async {
      // The "none" policy collapses them, so open the panel first — the
      // content is always there, the policy only decides whether it starts
      // open.
      await _pump(tester);
      expect(find.text('How to do it'), findsOneWidget);
      expect(find.text('4 steps'), findsOneWidget,
          reason: 'a learner with no assigned category gets them collapsed');
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Wet the toothbrush'), findsOneWidget);
      expect(find.text('Brush for two minutes'), findsOneWidget);
      expect(find.text('Rinse with water'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cognitive learner gets them already open', (tester) async {
      await _pump(tester, type: DisabilityType.cognitive);
      expect(find.text('Wet the toothbrush'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('media placeholders', () {
    testWidgets('a step with no media still has a picture and says what is '
        'missing', (tester) async {
      await _pump(tester);
      // The activity emoji is the visual anchor when nothing is attached.
      expect(find.text('🪥'), findsWidgets);
      expect(
        find.textContaining('No photo or video here yet'),
        findsOneWidget,
      );
      // No broken-image glyph, and no media buttons that lead nowhere.
      expect(find.text('Photo'), findsNothing);
      expect(find.text('Video'), findsNothing);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a photo URL replaces the placeholder with a real image',
        (tester) async {
      await _pump(
        tester,
        step: _brushing.copyWith(photoUrl: 'assets/images/nope.png'),
      );
      expect(find.byType(RoutineImage), findsWidgets);
      expect(find.text('Photo'), findsOneWidget,
          reason: 'the media button appears once a photo is supplied');
      await _unmount(tester);
    });

    testWidgets('a broken image falls back to the placeholder, never a '
        'broken glyph', (tester) async {
      // `assets/images/nope.png` is not in the bundle, so Image.asset's
      // errorBuilder runs — the learner must still see the activity.
      await _pump(
        tester,
        step: _brushing.copyWith(photoUrl: 'assets/images/nope.png'),
      );
      await _settle(tester);
      expect(find.byType(RoutineMediaPlaceholder), findsWidgets);
      expect(find.textContaining('Photo coming soon'), findsWidgets);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a video shows a poster rather than autoplaying',
        (tester) async {
      await _pump(
        tester,
        step: _brushing.copyWith(videoUrl: 'https://example.test/brush.mp4'),
      );
      expect(find.text('Watch the video'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('an audio URL adds a Listen control', (tester) async {
      await _pump(
        tester,
        step: _brushing.copyWith(audioUrl: 'https://example.test/brush.mp3'),
      );
      expect(find.text('Listen'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('spoken cue', () {
    testWidgets('every learner can ask for the step to be read out',
        (tester) async {
      // Offered whatever the policy: a learner who wants to hear the step
      // should not have to change a setting first.
      for (final type in DisabilityType.values) {
        await _pump(tester, type: type);
        expect(find.text('Read it to me'), findsOneWidget, reason: '$type');
        await _unmount(tester);
      }
    });

    testWidgets('an educator note replaces the default cue', (tester) async {
      await _pump(
        tester,
        step: _brushing.copyWith(note: 'Use the small blue brush'),
      );
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Use the small blue brush'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('timer', () {
    testWidgets('a step with a duration offers a countdown', (tester) async {
      await _pump(tester);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the countdown runs when started', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Start'));
      await _settle(tester, const Duration(seconds: 3));
      expect(find.text('02:00'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await _settle(tester, const Duration(milliseconds: 300));
      expect(find.text('02:00'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cognitive learner gets a shrinking bar, not a clock',
        (tester) async {
      await _pump(tester, type: DisabilityType.cognitive);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('02:00'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a step with no duration has no timer at all', (tester) async {
      await _pump(tester, step: _brushing.copyWith(durationMinutes: 0));
      expect(find.text('Timer'), findsNothing);
      await _unmount(tester);
    });
  });

  group('completion', () {
    testWidgets('the learner gets a big "I did it" button', (tester) async {
      await _pump(tester);
      expect(find.text('I did it!'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('an educator preview cannot tick the step off', (tester) async {
      // The day log is the learner's record of what *they* did.
      await _pump(tester, readOnly: true);
      expect(find.text('I did it!'), findsNothing);
      expect(
        find.textContaining('the learner ticks this off themselves'),
        findsOneWidget,
      );
      await _unmount(tester);
    });
  });

  group('custom activities', () {
    testWidgets('a custom step renders its own title, emoji and note',
        (tester) async {
      await _pump(
        tester,
        step: const RoutineStep(
          id: 'c1',
          activity: RoutineActivity.custom,
          title: 'Feed the cat',
          emoji: '🐈',
          note: 'Half a cup, morning only',
        ),
      );
      expect(find.text('Feed the cat'), findsWidgets);
      expect(find.text('🐈'), findsWidgets);
      expect(find.text('Half a cup, morning only'), findsOneWidget);
      // No catalog instructions to inherit — the section is absent rather
      // than empty.
      expect(find.text('How to do it'), findsNothing);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('a Student’s step runs on the clock', () {
    DateTime at(int h, int m) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day, h, m);
    }

    testWidgets('no "I did it!" — it says the step is on now, and until when',
        (tester) async {
      await _pump(
        tester,
        canTick: false,
        now: at(6, 46),
        size: const Size(800, 4000),
      );
      expect(find.text('I did it!'), findsNothing);
      expect(
        find.text('This is happening now, until 6:47 AM.'),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('before its time it says when it starts', (tester) async {
      await _pump(
        tester,
        canTick: false,
        now: at(6, 30),
        size: const Size(800, 4000),
      );
      expect(find.text('This starts at 6:45 AM.'), findsOneWidget);
      expect(find.text('I did it!'), findsNothing);
      await _unmount(tester);
    });
  });
}
