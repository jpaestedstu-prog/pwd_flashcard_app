import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/focused_label.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/controllers/companion_controller.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_host.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;

/// The AI Tutor panel with the D-pad and Back.
///
/// Found on the tablet (29 Oct), with the game controller and with TalkBack
/// off as well: once the panel opened, the D-pad stayed on its "Full screen"
/// button ("Nothing more that way") and B said "You're at the main screen",
/// so a learner on the controller could neither use the tutor nor leave it.
class _Student extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'panel-student',
        name: 'Ana',
        role: UserRole.student,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
      );
}

class _FakePad extends GamepadService {
  final _buttons = StreamController<GamepadEvent>.broadcast();
  final _connections = StreamController<GamepadConnectionEvent>.broadcast();

  @override
  Stream<GamepadEvent> get buttons => _buttons.stream;

  @override
  Stream<GamepadConnectionEvent> get connections => _connections.stream;

  @override
  void start() {}

  @override
  Future<void> setCaptureEnabled(bool enabled) async {}

  void press(GamepadButton button) {
    _buttons.add(GamepadEvent(button: button, pressed: true));
    _buttons.add(GamepadEvent(button: button, pressed: false));
  }

  void connect() => _connections.add(
        const GamepadConnectionEvent(
          deviceId: 80,
          name: 'GamePadPlus V3',
          connected: true,
        ),
      );

  @override
  Future<void> dispose() async {
    await _buttons.close();
    await _connections.close();
  }
}

class _FakeTts extends TtsService {
  final List<String> spoken = [];

  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> speakEnglish(String text) async => spoken.add(text);

  @override
  Future<void> speakFilipino(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}
}

/// `implements`, so the real `AudioPlayer()` (a platform channel) never
/// starts: the tutor plays a sound with its greeting.
class _SilentSound implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

GoRouter _router() => GoRouter(
      initialLocation: '/games',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              BottomNavShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/games',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Hub button'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

String? _focused() =>
    FocusedLabel.of(FocusManager.instance.primaryFocus?.context);

void main() {
  setUpAll(() => openSweepBoxes('companion_panel'));
  tearDownAll(closeSweepBoxes);

  late _FakePad pad;
  late _FakeTts tts;
  setUp(() {
    pad = _FakePad();
    tts = _FakeTts();
  });

  /// The app's own nesting (main.dart): the controller's host around the AI
  /// Buddy's, both beside the router, inside the field exits.
  Future<ProviderContainer> pumpOpenPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The tablet's learner reads at Extra Large.
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Student.new),
          routerProvider.overrideWithValue(router),
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          soundServiceProvider.overrideWithValue(_SilentSound()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          shortcuts: dpadShortcuts,
          actions: dpadActions,
          routerConfig: router,
          builder: (context, child) => DpadFieldExits(
            child: GamepadHost(
              child: CompanionHost(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
    for (var t = 0; t < 10; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    pad.connect();
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(CompanionHost)));
    // In real time: the tutor saves its greeting, and a write begun on the
    // test's fake clock never finishes.
    await tester.runAsync(() async {
      container.read(companionControllerProvider.notifier).open();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var t = 0; t < 10; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var t = 0; t < 4; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the arrow keys step through the open panel', (tester) async {
    await pumpOpenPanel(tester);
    final seen = <String?>[_focused()];
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      seen.add(_focused());
    }
    expect(seen.toSet().length, greaterThan(3),
        reason: 'down moved through the panel: $seen');
    expect(seen, isNot(contains('Hub button')),
        reason: 'and never onto the page behind it');
  });

  testWidgets('the controller steps through the open panel', (tester) async {
    await pumpOpenPanel(tester);
    final seen = <String?>[_focused()];
    for (var i = 0; i < 6; i++) {
      tts.spoken.clear();
      pad.press(GamepadButton.dpadDown);
      await settle(tester);
      seen.add(_focused());
      debugPrint('PANEL pad $i: ${_focused()} | said ${tts.spoken}');
    }
    expect(seen.toSet().length, greaterThan(3),
        reason: 'the D-pad moved through the panel: $seen');
    expect(seen, isNot(contains('Hub button')));
  });

  testWidgets('a focus parked on the root, the controller still moves',
      (tester) async {
    // Flutter parks the focus on its root scope while the window is not
    // focused, and gives it back only if nothing moved meanwhile.
    await pumpOpenPanel(tester);
    pad.press(GamepadButton.dpadDown);
    await settle(tester);
    final before = _focused();
    FocusManager.instance.rootScope.requestFocus();
    await settle(tester);
    tts.spoken.clear();
    pad.press(GamepadButton.dpadDown);
    await settle(tester);
    debugPrint('PANEL parked: $before -> ${_focused()} | said ${tts.spoken}');
    expect(tts.spoken.join(' '), isNot(contains('Nothing more that way')),
        reason: 'said ${tts.spoken}');
    expect(_focused(), isNotNull);
  });

  testWidgets('Android\'s Back closes the panel and stays in the app',
      (tester) async {
    // On the tablet (4 Nov): with the panel open on Home, Back left the app.
    final container = await pumpOpenPanel(tester);
    expect(container.read(companionControllerProvider).isOpen, isTrue);
    var leftTheApp = false;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') leftTheApp = true;
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(companionControllerProvider).isOpen, isFalse);
    expect(leftTheApp, isFalse);

    // Closed, Back is the app's again.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(leftTheApp, isTrue);
  });

  testWidgets('Escape closes the panel', (tester) async {
    final container = await pumpOpenPanel(tester);
    expect(container.read(companionControllerProvider).isOpen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(companionControllerProvider).isOpen, isFalse);
  });

  testWidgets('B closes the panel', (tester) async {
    final container = await pumpOpenPanel(tester);
    pad.press(GamepadButton.b);
    await settle(tester);
    expect(container.read(companionControllerProvider).isOpen, isFalse,
        reason: 'B said "${tts.spoken.join(' / ')}"');
  });
}
