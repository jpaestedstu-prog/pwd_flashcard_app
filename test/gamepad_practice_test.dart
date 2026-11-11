import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_practice.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_practice_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// The practice screen teaches the controller **as this learner's settings
/// make it behave**: the A/B swap and a turned-off left stick included. A
/// practice page that described some other controller would teach a blind
/// learner the wrong buttons.

class _FakePad extends GamepadService {
  final _events = StreamController<GamepadEvent>.broadcast();
  @override
  Stream<GamepadEvent> get buttons => _events.stream;
  @override
  void start() {}
  @override
  Future<void> setCaptureEnabled(bool enabled) async {}

  void tap(GamepadButton button) {
    _events.add(GamepadEvent(button: button, pressed: true));
    _events.add(GamepadEvent(button: button, pressed: false));
  }
}

class _FakeTts extends TtsService {
  final List<String> spoken = [];
  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}
  @override
  Future<void> speak(String t) async => spoken.add(t);
  @override
  Future<void> speakEnglish(String t) async => spoken.add(t);
  @override
  Future<void> speakFilipino(String t) async => spoken.add(t);
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double s) async {}
  @override
  Future<void> dispose() async {}

  String get last => spoken.isEmpty ? '' : spoken.last;
}

class _FixedGamepad extends GamepadSettingsNotifier {
  _FixedGamepad(this.value);
  final GamepadSettings value;
  @override
  GamepadSettings build() => value;
}

class _NoGaze extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings();
}

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  late _FakePad pad;
  late _FakeTts tts;

  setUp(() {
    pad = _FakePad();
    tts = _FakeTts();
  });
  tearDown(() => gamepadPractice.value = false);

  Future<void> pumpPractice(
    WidgetTester tester, {
    GamepadSettings settings = const GamepadSettings(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          gamepadSettingsProvider.overrideWith(() => _FixedGamepad(settings)),
          gazeSettingsProvider.overrideWith(_NoGaze.new),
          settingsProvider.overrideWith(_StubAppSettings.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GamepadPracticeScreen(),
        ),
      ),
    );
    await tester.pump(); // the screen starts listening in a microtask
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, GamepadButton button) async {
    pad.tap(button);
    await tester.pump();
  }

  testWidgets('opens by saying how to leave', (tester) async {
    await pumpPractice(tester);
    expect(tts.last, contains('Press B twice to leave.'));
    expect(find.text('Press B twice to leave.'), findsOneWidget);
  });

  testWidgets('every press is named with its one job', (tester) async {
    await pumpPractice(tester);

    await tap(tester, GamepadButton.dpadLeft);
    expect(tts.last, 'D-pad left. Move left.');
    await tap(tester, GamepadButton.a);
    expect(tts.last, 'A. Choose what is highlighted.');
    await tap(tester, GamepadButton.r2);
    expect(tts.last, 'R2. Next item, one at a time.');
    await tap(tester, GamepadButton.b);
    expect(tts.last, 'B. Go back, or close. Press B again to leave.');
  });

  testWidgets('with the swap on, the button labelled A is named A',
      (tester) async {
    // Such a pad reports its A as B — the reason the swap exists. Naming the
    // report told a learner who pressed A that they had pressed B.
    await pumpPractice(
      tester,
      settings: const GamepadSettings(swapConfirmButtons: true),
    );

    await tap(tester, GamepadButton.b); // the button labelled A
    expect(tts.last, 'A. Choose what is highlighted.');
    await tap(tester, GamepadButton.a); // the button labelled B
    expect(tts.last, 'B. Go back, or close. Press B again to leave.');
  });

  testWidgets('a turned-off left stick says so, not "does nothing"',
      (tester) async {
    await pumpPractice(
      tester,
      settings: const GamepadSettings(leftStickMoves: false),
    );

    await tap(tester, GamepadButton.leftStickUp);
    expect(tts.last, contains('Turned off in the Game Controller settings'));
    expect(tts.last, isNot(contains('does nothing in this app')));
    // The D-pad is untouched.
    await tap(tester, GamepadButton.dpadUp);
    expect(tts.last, 'D-pad up. Move up.');
  });

  testWidgets('with the stick on, it moves like the D-pad', (tester) async {
    await pumpPractice(tester);

    await tap(tester, GamepadButton.leftStickRight);
    expect(tts.last, endsWith('Move right.'));
  });
}
