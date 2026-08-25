import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/security/adult_gate.dart';
import 'package:pwdpwdpwd/core/security/pin_credential_helper.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/board_template_builder_screen.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/adult_gate_grace_provider.dart';
import 'package:pwdpwdpwd/providers/unlocking_educators_provider.dart';
import 'package:pwdpwdpwd/widgets/adult_gate_dialog.dart';

import 'support/board_test_doubles.dart';

/// The adult gate as the person in front of the tablet meets it: the dialog,
/// and the Talk Board button it guards.
///
/// No Hive writes — the educator list is provider-overridden rather than
/// seeded through classroom membership, and the board stores are in memory.

UserProfile _educatorWithPin(String pin, {String id = 'edu'}) =>
    PinCredentialHelper.applyPin(
      UserProfile(
        id: id,
        name: 'Grown Up',
        role: UserRole.parent,
        createdAt: DateTime(2026),
      ),
      pin,
    ).profile;

/// A pinned question: seed 0 gives a stable pair, so the test can type the
/// right answer instead of guessing.
final _fixedChallenge = AdultMathChallenge.random(Random(0));

Future<void> _pumpDialog(
  WidgetTester tester, {
  required AdultGateMode mode,
  List<UserProfile> candidates = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1280) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AdultGateDialog(
                  reason: 'to change this board',
                  candidates: candidates,
                  mode: mode,
                  random: Random(0),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Talk Board with a router, so the gated push has somewhere to go.
Future<void> _pumpBoard(
  WidgetTester tester, {
  required UserRole role,
  List<UserProfile> educators = const [],
  bool graceGranted = false,
}) async {
  tester.view.physicalSize = const Size(900, 1400) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/communication-board',
    routes: [
      GoRoute(
        path: '/communication-board',
        builder: (_, _) => const CommunicationBoardScreen(),
        routes: [
          GoRoute(
            path: 'builder',
            builder: (_, _) => const BoardTemplateBuilderScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...boardProfileOverrides(role: role),
        overrideBoardPhrases(FakeBoardPhraseStore()),
        overrideCustomBoard(FakeCustomBoardStore()),
        // Provider-overridden rather than seeded through Hive classroom
        // membership: the join is not what is under test here.
        unlockingEducatorsProvider.overrideWith((ref, id) async => educators),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));

  if (graceGranted) {
    final element = tester.element(find.byType(CommunicationBoardScreen));
    final container = ProviderScope.containerOf(element);
    container.read(adultGateGraceProvider.notifier).grant('board-test-profile');
    await tester.pump();
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Taps the app-bar button that opens the builder.
Future<void> _tapBuilderButton(WidgetTester tester) async {
  final build = find.bySemanticsLabel('Build my board');
  final edit = find.bySemanticsLabel('Edit my board');
  await tester.tap(build.evaluate().isNotEmpty ? build : edit);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/adult_gate_dialog');
    for (final name in const ['profiles', 'settings', 'progress', 'sessions']) {
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

  group('the PIN gate', () {
    testWidgets('asks for a parent or teacher PIN', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      expect(find.text('Ask an adult'), findsOneWidget);
      expect(find.textContaining('parent or teacher PIN'), findsOneWidget);
      // The PIN is masked — a learner watching over a shoulder learns nothing.
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await _unmount(tester);
    });

    testWidgets('the right PIN passes', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Ask an adult'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a wrong PIN keeps the gate shut and says so', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Ask an adult'), findsOneWidget);
      expect(find.textContaining('did not match'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a short PIN is refused without counting as an attempt',
        (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter the 4-digit PIN'), findsOneWidget);
      // A mistyped PIN must not eat into the attempts before a cooldown.
      expect(find.textContaining('Too many tries'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('repeated wrong PINs earn a cooldown', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      // The shared curve is quiet for the first four and bites on the fifth.
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField), '9999');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Too many tries'), findsOneWidget);

      // And the correct PIN is refused while the cooldown stands, so a learner
      // cannot simply keep going.
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Ask an adult'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('Cancel closes it without passing', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Ask an adult'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('tapping outside does not dismiss it', (tester) async {
      await _pumpDialog(
        tester,
        mode: AdultGateMode.pin,
        candidates: [_educatorWithPin('1234')],
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      // Barrier-dismissible would make the gate a formality.
      expect(find.text('Ask an adult'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('the question gate', () {
    testWidgets('shows an arithmetic question', (tester) async {
      await _pumpDialog(tester, mode: AdultGateMode.math);
      expect(find.textContaining('${_fixedChallenge.question} = ?'),
          findsOneWidget);
      // Not masked: there is nothing secret about a times table.
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      await _unmount(tester);
    });

    testWidgets('the right answer passes', (tester) async {
      await _pumpDialog(tester, mode: AdultGateMode.math);
      await tester.enterText(
          find.byType(TextField), '${_fixedChallenge.answer}');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Ask an adult'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a wrong answer keeps the gate shut', (tester) async {
      await _pumpDialog(tester, mode: AdultGateMode.math);
      await tester.enterText(
          find.byType(TextField), '${_fixedChallenge.answer + 1}');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Ask an adult'), findsOneWidget);
      expect(find.textContaining('Not quite'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('an empty answer is not a pass', (tester) async {
      await _pumpDialog(tester, mode: AdultGateMode.math);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Ask an adult'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the question is announced in words for a screen reader',
        (tester) async {
      await _pumpDialog(tester, mode: AdultGateMode.math);
      expect(
        find.bySemanticsLabel(
          'What is ${_fixedChallenge.a} times ${_fixedChallenge.b}?',
        ),
        findsOneWidget,
      );
      await _unmount(tester);
    });
  });

  group('the Talk Board button it guards', () {
    testWidgets('a learner meets the gate instead of the builder',
        (tester) async {
      await _pumpBoard(tester, role: UserRole.student);
      await _tapBuilderButton(tester);

      expect(find.text('Ask an adult'), findsOneWidget);
      // And the builder is not behind it.
      expect(find.text('Save Board'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('cancelling leaves the learner on Talk Board', (tester) async {
      await _pumpBoard(tester, role: UserRole.student);
      await _tapBuilderButton(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Talk Board'), findsOneWidget);
      expect(find.text('Save Board'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('answering the question opens the builder', (tester) async {
      await _pumpBoard(tester, role: UserRole.student);
      await _tapBuilderButton(tester);

      final challenge = tester
          .widget<AdultGateDialog>(find.byType(AdultGateDialog))
          .mode;
      expect(challenge, AdultGateMode.math);

      // The dialog picks its own question, so read it off the widget rather
      // than assuming a seed.
      final text = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(AdultGateDialog),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .firstWhere((d) => d != null && d.contains('= ?'))!;
      final parts = text.replaceAll(' = ?', '').split(' × ');
      final answer = int.parse(parts[0]) * int.parse(parts[1]);

      await tester.enterText(find.byType(TextField), '$answer');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Save Board'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a PIN-linked learner gets the PIN gate, and it opens',
        (tester) async {
      await _pumpBoard(
        tester,
        role: UserRole.student,
        educators: [_educatorWithPin('1234')],
      );
      await _tapBuilderButton(tester);
      expect(find.textContaining('parent or teacher PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Save Board'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a Player is not gated at all', (tester) async {
      // They edit their own board; there is no adult behind them to ask.
      await _pumpBoard(tester, role: UserRole.player);
      await _tapBuilderButton(tester);

      expect(find.text('Ask an adult'), findsNothing);
      expect(find.text('Save Board'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('an educator is not gated either', (tester) async {
      await _pumpBoard(tester, role: UserRole.teacher);
      await _tapBuilderButton(tester);
      expect(find.text('Ask an adult'), findsNothing);
      expect(find.text('Save Board'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a granted grace skips the second prompt', (tester) async {
      // An adult setting up a board goes in and out several times; re-asking
      // every time trains them to pick something short.
      await _pumpBoard(tester, role: UserRole.student, graceGranted: true);
      await _tapBuilderButton(tester);

      expect(find.text('Ask an adult'), findsNothing);
      expect(find.text('Save Board'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
