import 'dart:async';

import 'package:camera/camera.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_practice_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/grid_scanner.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/scan_clock.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/scan_cycler.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_switch_input.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_session.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_traversal_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_hints.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;
import 'package:pwdpwdpwd/widgets/app_back_button.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// Switch scanning as a learner at the tablet found it in the 1.2.5 hands-on
/// round: presses landing one late, the controller's stick picking, Back a
/// whole page away, names cut off by the next step, and face tracking frozen
/// by one detection that never came back.

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

/// A detector whose reading never comes back — what froze the tablet.
class _HangingDetector implements GazeDetector {
  int calls = 0;
  bool closed = false;
  @override
  Future<FaceSignal> detect(InputImage image) {
    calls++;
    return Completer<FaceSignal>().future;
  }

  @override
  Future<void> close() async => closed = true;
}

class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// Speech that goes nowhere; the test plays the engine's part by setting
/// [TtsService.speaking].
class _QuietTts extends TtsService {
  @override
  Future<void> speakEnglish(String text) async {}
  @override
  Future<void> speakFilipino(String text) async {}
  @override
  Future<void> stop() async {}
}

/// A controller that presses on command.
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

Future<List<CameraDescription>> _noCameras() async => const [];

/// Past the moment in which a press still counts for what was lit before.
const _reaction = Duration(milliseconds: 500);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── The clock ────────────────────────────────────────────────────────
  group('ScanClock', () {
    test('steps every step; a press just after a move is late', () {
      fakeAsync((async) {
        var steps = 0;
        final clock = ScanClock(
          step: const Duration(milliseconds: 2000),
          onStep: () => steps++,
        )..start();
        async.elapse(const Duration(milliseconds: 1999));
        expect(steps, 0);
        expect(clock.justMoved, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(steps, 1);
        expect(clock.forgiveness, const Duration(milliseconds: 400));
        expect(clock.justMoved, isTrue);
        async.elapse(const Duration(milliseconds: 399));
        expect(clock.justMoved, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(clock.justMoved, isFalse,
            reason: 'by then the learner is reacting to the new control');
        async.elapse(const Duration(milliseconds: 1600));
        expect(steps, 2);
        clock.stop();
        async.elapse(const Duration(seconds: 10));
        expect(steps, 2);
      });
    });

    test('a fast scan forgives a quarter of its step', () {
      final clock = ScanClock(
        step: const Duration(milliseconds: 1000),
        onStep: () {},
      );
      expect(clock.forgiveness, const Duration(milliseconds: 250));
    });

    test('a late press is credited once, and a restart forgives nothing', () {
      fakeAsync((async) {
        var steps = 0;
        final clock = ScanClock(
          step: const Duration(milliseconds: 1000),
          onStep: () => steps++,
        )..start();
        async.elapse(const Duration(milliseconds: 1000));
        expect(clock.takeJustMoved(), isTrue);
        expect(clock.takeJustMoved(), isFalse);

        // A manual step or a pick: a full step from now, nothing to forgive.
        async.elapse(const Duration(milliseconds: 600));
        clock.restart();
        expect(clock.justMoved, isFalse);
        async.elapse(const Duration(milliseconds: 999));
        expect(steps, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(steps, 2);
        clock.stop();
      });
    });

    test('after the learner steers, the highlight waits for them', () {
      fakeAsync((async) {
        var steps = 0;
        final clock = ScanClock(
          step: const Duration(milliseconds: 2500),
          onStep: () => steps++,
        )..start();
        async.elapse(const Duration(milliseconds: 1000));
        clock.steered();
        async.elapse(ScanClock.steerPause - const Duration(milliseconds: 1));
        expect(steps, 0, reason: 'stays where it was put');
        async.elapse(const Duration(milliseconds: 1));
        expect(steps, 1, reason: 'left alone: the scan comes back by itself');
        expect(clock.justMoved, isTrue);

        // Steering again, then a pick: back to the ordinary step.
        clock.steered();
        async.elapse(const Duration(seconds: 3));
        clock.restart();
        async.elapse(const Duration(milliseconds: 2500));
        expect(steps, 2);
        clock.stop();
      });
    });

    test('a hold keeps the highlight until it lifts — never for ever', () {
      fakeAsync((async) {
        var steps = 0;
        var holding = true;
        final clock = ScanClock(
          step: const Duration(milliseconds: 1000),
          onStep: () => steps++,
          holdFor: () =>
              holding ? const Duration(milliseconds: 150) : Duration.zero,
        )..start();
        async.elapse(const Duration(milliseconds: 3000));
        expect(steps, 0, reason: 'held while the name is read');
        holding = false;
        async.elapse(const Duration(milliseconds: 150));
        expect(steps, 1);

        // An engine that never says it finished cannot freeze the scan (the
        // hold is polled, so allow one poll past the cap).
        holding = true;
        async.elapse(const Duration(milliseconds: 1150) + ScanClock.maxHold);
        expect(steps, 2);
        clock.stop();
      });
    });
  });

  // ─── The scanners ─────────────────────────────────────────────────────
  group('GridScanner undo and step back', () {
    test('undoStep puts the highlight back where the last step found it', () {
      final s = GridScanner([2, 1, 3]);
      expect((s.row, s.col), (0, null));
      s.step();
      expect((s.row, s.col), (1, null));
      expect(s.undoStep(), isTrue);
      expect((s.row, s.col), (0, null));
      expect(s.undoStep(), isFalse, reason: 'only the last step');

      // The end of a pass hands back to the row phase; a late press there
      // still means the row's last control.
      expect(s.select(), isNull); // into row 0
      s.step(); // its second control
      s.step(); // pass over: the whole row again
      expect(s.onWholeRow, isTrue);
      expect(s.undoStep(), isTrue);
      expect((s.row, s.col), (0, 1));
      expect(s.select(), (row: 0, col: 1));
    });

    test('the stick steers like a D-pad: rows up and down, along a row '
        'left and right', () {
      final s = GridScanner([2, 0, 3]);
      s.steer(GazeZone.up);
      expect((s.row, s.col), (2, null), reason: 'wraps to the last row');
      s.steer(GazeZone.right);
      expect((s.row, s.col), (2, 0), reason: '▶ steps into a lit row');
      s.steer(GazeZone.right);
      s.steer(GazeZone.right);
      s.steer(GazeZone.right);
      expect(s.col, 2, reason: 'stops at the end of the row');
      s.steer(GazeZone.up);
      expect((s.row, s.col), (0, 1),
          reason: 'the nearest control in the row above, past the empty one');
      s.steer(GazeZone.left);
      s.steer(GazeZone.left);
      expect(s.col, 0);
      s.steer(GazeZone.down);
      expect((s.row, s.col), (2, 0));

      final t = GridScanner([2, 3]);
      t.steer(GazeZone.left);
      expect((t.row, t.col), (0, 1), reason: '◀ steps into a row at its end');
    });

    test('a single row is walked by every direction', () {
      final s = GridScanner([3]);
      expect(s.col, 0);
      s.steer(GazeZone.up);
      expect(s.col, 2);
      s.steer(GazeZone.down);
      expect(s.col, 0);
      s.steer(GazeZone.right);
      expect(s.col, 1);
    });

    test('wholeRow lights the row again, not the control', () {
      final s = GridScanner([2, 1]);
      expect(s.select(), isNull);
      s.step();
      expect((s.row, s.col), (0, 1));
      s.wholeRow();
      expect((s.row, s.col), (0, null));
      final single = GridScanner([3]);
      single.wholeRow();
      expect(single.col, 0, reason: 'a lone row has no row phase');
    });

    test('ScanCycler steps back, wrapping', () {
      final c = ScanCycler(count: 3);
      expect(c.back(), 2);
      expect(c.back(), 1);
      expect(c.advance(), 2);
      expect(ScanCycler(count: 0).back(), -1);
    });
  });

  // ─── The controller ───────────────────────────────────────────────────
  group("a controller's buttons and directions", () {
    final input = GazeSwitchInput.instance;
    setUp(input.reset);
    tearDown(input.reset);

    test('only buttons pick; the D-pad and both sticks steer', () {
      for (final b in GamepadButton.values) {
        final name = b.name;
        final isDirection = name.startsWith('dpad') ||
            (name.contains('Stick') && !name.endsWith('Click'));
        if (isDirection) {
          expect(GazeSwitchInput.directionOf(b), isNotNull, reason: name);
          expect(GazeSwitchInput.picksWith(b), isFalse, reason: name);
        } else if (b == GamepadButton.mode) {
          expect(GazeSwitchInput.directionOf(b), isNull);
          expect(GazeSwitchInput.picksWith(b), isFalse,
              reason: 'the vendor button switches the pad, not the app');
        } else {
          expect(GazeSwitchInput.directionOf(b), isNull, reason: name);
          expect(GazeSwitchInput.picksWith(b), isTrue, reason: name);
        }
      }
      expect(GazeSwitchInput.directionOf(GamepadButton.dpadDown), GazeZone.down);
      expect(GazeSwitchInput.directionOf(GamepadButton.dpadRight),
          GazeZone.right);
      expect(GazeSwitchInput.directionOf(GamepadButton.leftStickUp), GazeZone.up);
      expect(GazeSwitchInput.directionOf(GamepadButton.rightStickLeft),
          GazeZone.left);
    });

    test('a stick steps and never presses; any button presses', () async {
      final pad = _FakePad();
      var presses = 0;
      final steps = <GazeZone>[];
      var now = DateTime(2026, 10, 5, 9);
      input.clock = () => now;
      final token = input.attach(
        onPress: () => presses++,
        onSteer: steps.add,
        service: pad,
      );
      pad.tap(GamepadButton.leftStickDown);
      await pumpEventQueue();
      now = now.add(const Duration(milliseconds: 400));
      pad.tap(GamepadButton.dpadUp);
      pad.tap(GamepadButton.mode);
      await pumpEventQueue();
      expect(steps, [GazeZone.down, GazeZone.up]);
      expect(presses, 0);

      pad.tap(GamepadButton.a);
      await pumpEventQueue();
      expect(presses, 1);
      now = now.add(const Duration(seconds: 1));
      pad.tap(GamepadButton.r2);
      await pumpEventQueue();
      expect(presses, 2);
      expect(input.debugHistory.last, endsWith('r2 press'));
      expect(input.debugHistory, contains(endsWith('mode not a switch')));
      input.detach(token);
    });

    test('a diagonal push is one step, not two', () {
      var now = DateTime(2026, 10, 5, 9);
      input.clock = () => now;
      final steps = <GazeZone>[];
      final token = input.attach(onPress: () {}, onSteer: steps.add);
      input.steer(GazeZone.down, source: 'rightStickDown');
      now = now.add(const Duration(milliseconds: 17));
      input.steer(GazeZone.right, source: 'rightStickRight');
      expect(steps, [GazeZone.down]);
      expect(input.debugHistory.last, endsWith('rightStickRight same push'));
      now = now.add(const Duration(milliseconds: 300));
      input.steer(GazeZone.up, source: 'dpadUp');
      expect(steps, [GazeZone.down, GazeZone.up],
          reason: 'a separate push still counts');
      input.detach(token);
    });

    test('a surface that does not scan takes no steps', () {
      var presses = 0;
      final token = input.attach(onPress: () => presses++);
      input.steer(GazeZone.down);
      expect(presses, 0);
      expect(input.debugHistory.last, endsWith('no steering here'));
      input.detach(token);
    });
  });

  // ─── The shell, scanning ──────────────────────────────────────────────
  group('the shell scanning with a switch', () {
    setUp(() {
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
      TtsService.speaking.value = false;
    });
    tearDown(() {
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
      TtsService.speaking.value = false;
    });

    Future<void> pumpShell(
      WidgetTester tester,
      GazeSettings settings,
      void Function(NavGazeState) onState,
    ) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(settings)),
        settingsProvider.overrideWith(_StubAppSettings.new),
        ttsServiceProvider.overrideWithValue(_QuietTts()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 3,
            onCommit: (_) {},
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return const Scaffold(body: Text('hub'));
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    const switchScan = GazeSettings(
      enabled: true,
      scanMode: true,
      scanStepMs: 1000,
      pickWith: GazePick.switchButton,
    );

    testWidgets('a press as the highlight moves on picks what it had lit',
        (tester) async {
      final opened = <String>[];
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'one', onActivate: () => opened.add('one'))],
        [GazeTileCell(label: 'two', onActivate: () => opened.add('two'))],
      ]);
      var now = DateTime(2026, 10, 5, 9);
      GazeSwitchInput.instance.clock = () => now;
      await pumpShell(tester, switchScan, (_) {});
      expect(gazeHomeGrid.focusRow, 0);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(gazeHomeGrid.focusRow, 1);
      // Pressed on "one" — the tablet saw it a moment after "two" lit.
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(opened, ['one']);

      // Pressed on a control well after it lit: that control.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(gazeHomeGrid.focusRow, 1);
      await tester.pump(_reaction);
      now = now.add(const Duration(seconds: 2));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(opened, ['one', 'two']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets("a controller's stick moves the highlight and never picks",
        (tester) async {
      final opened = <String>[];
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'one', onActivate: () => opened.add('one'))],
        [GazeTileCell(label: 'two', onActivate: () => opened.add('two'))],
        [GazeTileCell(label: 'three', onActivate: () => opened.add('3'))],
      ]);
      late NavGazeState last;
      var now = DateTime(2026, 10, 5, 9);
      GazeSwitchInput.instance.clock = () => now;
      void push(GazeZone direction) {
        now = now.add(const Duration(milliseconds: 400));
        GazeSwitchInput.instance.steer(direction);
      }

      await pumpShell(tester, switchScan, (s) => last = s);
      expect(gazeHomeGrid.focusRow, 0);

      await tester.pump(const Duration(milliseconds: 600));
      push(GazeZone.down);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 1);
      push(GazeZone.down);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 2);
      push(GazeZone.up);
      push(GazeZone.up);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 0);
      push(GazeZone.up);
      await tester.pump();
      expect(last.wholeNavRow, isTrue, reason: 'back from the top: the tabs');
      expect(opened, isEmpty);

      // Steered by hand: the highlight waits there, then scanning resumes.
      await tester.pump(const Duration(milliseconds: 9999));
      expect(last.wholeNavRow, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(gazeHomeGrid.focusRow, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a name read aloud is heard to the end before the highlight '
        'moves on', (tester) async {
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'one', onActivate: () {})],
        [GazeTileCell(label: 'two', onActivate: () {})],
        [GazeTileCell(label: 'three', onActivate: () {})],
      ]);
      gazeDebugSpoken.clear();
      await pumpShell(
        tester,
        switchScan.copyWith(speakHighlight: true),
        (_) {},
      );

      await tester.pump(const Duration(milliseconds: 1000));
      expect(gazeHomeGrid.focusRow, 1);
      expect(gazeDebugSpoken.last, 'two');
      // The engine starts reading "two", and takes its time.
      TtsService.speaking.value = true;
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(gazeHomeGrid.focusRow, 1, reason: 'not cut off mid-name');

      // Finished: a moment to react to what was heard, then on.
      TtsService.speaking.value = false;
      await tester.pump(const Duration(milliseconds: 900));
      expect(gazeHomeGrid.focusRow, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(gazeHomeGrid.focusRow, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // ─── A long page ──────────────────────────────────────────────────────
  group('scanning a long page', () {
    setUp(() {
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      GazeSwitchInput.instance.reset();
    });
    tearDown(GazeSwitchInput.instance.reset);

    bool onExit() => VoiceControlMixin.debugScopes
        .where((s) => s.mounted)
        .map((s) => s.debugDescribe())
        .firstWhere((d) => d['scope'] == 'standalone')['onExit'] as bool;

    Future<List<FocusNode>> pumpPage(
      WidgetTester tester,
      List<int> pressed, {
      bool speak = false,
    }) async {
      final nodes = List.generate(12, (i) => FocusNode(debugLabel: 'b$i'));
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final container = ProviderContainer(overrides: [
        settingsProvider.overrideWith(_StubAppSettings.new),
        ttsServiceProvider.overrideWithValue(_QuietTts()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: GazeTraversalScope(
              settingsOverride: GazeSettings(
                enabled: true,
                scanMode: true,
                scanStepMs: 1000,
                pickWith: GazePick.switchButton,
                speakHighlight: speak,
              ),
              camerasLoader: _noCameras,
              detectorFactory: _FakeDetector.new,
              child: ListView(
                children: [
                  for (var i = 0; i < 12; i++)
                    TextButton(
                      focusNode: nodes[i],
                      onPressed: () => pressed.add(i),
                      child: Text('b$i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      return nodes;
    }

    testWidgets('a sheet whose only control is its close button offers Back',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GazeTraversalScope(
            settingsOverride: GazeSettings(
              enabled: true,
              scanMode: true,
              scanStepMs: 1000,
              pickWith: GazePick.switchButton,
            ),
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            child: Scaffold(body: Center(child: CloseButton())),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(onExit(), isTrue,
          reason: 'the close button is left to the pill, so the pill lights');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Back is offered every six controls, then scanning carries on',
        (tester) async {
      gazeDebugSpoken.clear();
      final nodes = await pumpPage(tester, [], speak: true);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
        expect(nodes[i].hasPrimaryFocus, isTrue, reason: 'b$i');
      }
      expect(onExit(), isFalse);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(onExit(), isTrue, reason: 'Back, part-way down the page');
      expect(gazeDebugSpoken.last, 'Back',
          reason: 'not the name of the control it was lit after');

      await tester.pump(const Duration(milliseconds: 1000));
      expect(onExit(), isFalse);
      expect(nodes[6].hasPrimaryFocus, isTrue,
          reason: 'on from where it was, not back to the top');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a late press means the control lit before; steering up '
        'from the first reaches Back', (tester) async {
      final pressed = <int>[];
      var now = DateTime(2026, 10, 5, 9);
      GazeSwitchInput.instance.clock = () => now;
      final nodes = await pumpPage(tester, pressed);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(nodes[2].hasPrimaryFocus, isTrue);
      GazeSwitchInput.instance.press(); // as b2 lit: meant for b1
      await tester.pump();
      expect(pressed, [1]);
      expect(nodes[1].hasPrimaryFocus, isTrue,
          reason: 'the ring goes back to what was pressed');

      await tester.pump(_reaction);
      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(pressed, [1, 1]);

      void push(GazeZone direction) {
        now = now.add(const Duration(milliseconds: 400));
        GazeSwitchInput.instance.steer(direction);
      }

      push(GazeZone.up);
      await tester.pump();
      expect(nodes[0].hasPrimaryFocus, isTrue);
      push(GazeZone.up);
      await tester.pump();
      expect(onExit(), isTrue, reason: '▲ from the first control: Back');
      push(GazeZone.down);
      await tester.pump();
      await tester.pump();
      expect(onExit(), isFalse);
      expect(nodes[0].hasPrimaryFocus, isTrue);
      expect(pressed, [1, 1], reason: 'steps never press');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('pages and coming back', () {
    setUp(() {
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
    });
    tearDown(() {
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
    });

    testWidgets("scanning passes over a page's own back button",
        (tester) async {
      final nodes = List.generate(3, (i) => FocusNode(debugLabel: 'c$i'));
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final container = ProviderContainer(overrides: [
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GazeTraversalScope(
            settingsOverride: const GazeSettings(
              enabled: true,
              scanMode: true,
              scanStepMs: 1000,
              pickWith: GazePick.switchButton,
            ),
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            child: Scaffold(
              appBar: AppBar(leading: const AppBackButton()),
              body: Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    TextButton(
                      focusNode: nodes[i],
                      onPressed: () {},
                      child: Text('c$i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 1000));
      expect(nodes[0].hasPrimaryFocus, isTrue,
          reason: 'the first thing lit is the page, not its back button');
      // Round the page: c1, c2, then Back, then from the top again.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1000));
      }
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(nodes[0].hasPrimaryFocus, isTrue,
          reason: 'round again: the page first, not its back button');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('back on Home, the whole row lights again, so a stray press '
        'cannot reopen the page', (tester) async {
      final opened = <String>[];
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'a', onActivate: () => opened.add('a')),
          GazeTileCell(label: 'b', onActivate: () => opened.add('b')),
        ],
      ]);
      var now = DateTime(2026, 10, 5, 9);
      GazeSwitchInput.instance.clock = () => now;
      final navKey = GlobalKey<NavigatorState>();
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(
          () => _FixedSettings(const GazeSettings(
            enabled: true,
            scanMode: true,
            scanStepMs: 3000,
            pickWith: GazePick.switchButton,
          )),
        ),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 3,
            onCommit: (_) {},
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) =>
                const Scaffold(body: Text('hub')),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Into the row, then onto "b", and open it.
      GazeSwitchInput.instance.press();
      await tester.pump();
      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.steer(GazeZone.right);
      await tester.pump();
      expect((gazeHomeGrid.focusRow, gazeHomeGrid.focusCol), (0, 1));
      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(opened, ['b']);

      // The page it opened, then back.
      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('page')),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      navKey.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 700));
      expect(gazeHomeGrid.focusRow, 0);
      expect(gazeHomeGrid.focusCol, isNull, reason: 'the whole row');

      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(opened, ['b'], reason: 'a press steps into the row again');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // ─── Saying what the controller does ─────────────────────────────────
  group('while Gaze Control has the controller', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/gaze_switch_scanning');
      for (final name in const <String>[
        'active_time_logs', 'alerts', 'error_logs', 'profiles', 'progress',
        'sessions', 'settings', 'sync_queue',
      ]) {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name, compactionStrategy: (_, _) => false);
        }
      }
    });
    tearDownAll(() async {
      await Hive.deleteFromDisk()
          .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
    });

    final overrides = [
      gazeSettingsProvider.overrideWith(
        () => _FixedSettings(
          const GazeSettings(enabled: true, pickWith: GazePick.switchButton),
        ),
      ),
    ];

    testWidgets('the Game Controller page says so, and fits at large text',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const GamepadSettingsScreen(),
        devices: kNarrowPortrait,
        textScales: kLargeTextScales,
        overrides: overrides,
      );
    });

    testWidgets('so does the practice screen', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const GamepadPracticeScreen(),
        devices: kNarrowPortrait,
        textScales: kLargeTextScales,
        overrides: overrides,
      );
    });

    testWidgets('the notice shows only then', (tester) async {
      Future<void> pumpWith(GazeSettings settings) async {
        await tester.pumpWidget(ProviderScope(
          // A fresh scope each time: overrides are read once per container.
          key: UniqueKey(),
          overrides: [
            gazeSettingsProvider.overrideWith(() => _FixedSettings(settings)),
            settingsProvider.overrideWith(_StubAppSettings.new),
          ],
          child: const MaterialApp(home: GamepadSettingsScreen()),
        ));
        await tester.pump();
      }

      final t = AppLocalizationsEn();
      await pumpWith(
        const GazeSettings(enabled: true, pickWith: GazePick.switchButton),
      );
      expect(find.text(t.gpGazeUsesTitle), findsOneWidget);
      await pumpWith(const GazeSettings(enabled: true));
      expect(find.text(t.gpGazeUsesTitle), findsNothing,
          reason: 'blink picking: the controller is the Game Controller');
      await pumpWith(const GazeSettings(pickWith: GazePick.switchButton));
      expect(find.text(t.gpGazeUsesTitle), findsNothing,
          reason: 'Gaze Control off');
    });

    test('the switch hints say "a button" and that the stick moves it', () {
      const s = GazeSettings(
        enabled: true,
        scanMode: true,
        pickWith: GazePick.switchButton,
      );
      for (final t in [AppLocalizationsEn(), AppLocalizationsFil()]) {
        final hint = GazeHints.scan(t, s);
        expect(hint.toLowerCase(), contains('button'));
        expect(hint, contains('stick'));
        expect(hint.toLowerCase(), isNot(contains('switch')));
      }
    });

    test('a whole lit row says a press goes into it', () {
      const s = GazeSettings(
        enabled: true,
        scanMode: true,
        pickWith: GazePick.switchButton,
      );
      for (final t in [AppLocalizationsEn(), AppLocalizationsFil()]) {
        expect(GazeHints.scanRow(t, s), isNot(GazeHints.scan(t, s)));
        expect(GazeHints.scanRow(t, s), contains('stick'));
      }
      expect(GazeHints.scanRow(AppLocalizationsEn(), s),
          startsWith('Press a button to go into this row'));
      expect(
        GazeHints.scanRow(
          AppLocalizationsEn(),
          const GazeSettings(enabled: true, scanMode: true),
        ),
        'Blink to go into this row',
      );
    });
  });

  // ─── Face tracking that froze ─────────────────────────────────────────
  test('a detection that never answers is written off and the detector '
      'replaced', () {
    fakeAsync((async) {
      final made = <_HangingDetector>[];
      final controller = GazeController(
        settings: const GazeSettings(enabled: true),
        detectorFactory: () {
          final d = _HangingDetector();
          made.add(d);
          return d;
        },
      );
      expect(made, hasLength(1));
      final input = InputImage.fromBytes(
        bytes: Uint8List(4),
        metadata: InputImageMetadata(
          size: const Size(2, 2),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 2,
        ),
      );
      var done = false;
      controller.debugDetectFrame(input, Duration.zero).then((_) => done = true);
      async.elapse(GazeController.detectTimeout - const Duration(milliseconds: 1));
      expect(done, isFalse);
      async.elapse(const Duration(milliseconds: 2));
      expect(done, isTrue, reason: 'the next frame is no longer blocked');
      expect(made, hasLength(2));
      expect(made.first.closed, isTrue);
      expect(controller.faceVisible, isFalse,
          reason: 'a frozen reading must not pass for a face');
      expect(controller.debugDetectorRestarts, 1);

      controller.debugDetectFrame(input, Duration.zero).ignore();
      expect(made.last.calls, 1, reason: 'the fresh detector reads the frames');
      controller.dispose();
      async.flushTimers();
    });
  });

  // ─── The speech engine's callbacks ────────────────────────────────────
  test("speech callbacks fan out: speaking for scanning, TV Cast's one-shot "
      'on a natural finish only', () async {
    final tts = TtsService();
    var finished = 0;
    tts.setCompletionHandler(() => finished++);
    Future<void> engine(String method) => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
          (_) {},
        );
    await engine('speak.onStart');
    expect(TtsService.speaking.value, isTrue);
    await engine('speak.onCancel');
    expect(TtsService.speaking.value, isFalse);
    expect(finished, 0, reason: 'a stop is not a finish');
    await engine('speak.onStart');
    await engine('speak.onComplete');
    expect(TtsService.speaking.value, isFalse);
    expect(finished, 1);

    // A stop ends "speaking" even when the engine never says so (cut off
    // with the app in the background) — or the scan would wait on it.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('flutter_tts');
    messenger.setMockMethodCallHandler(channel, (_) async => 1);
    await engine('speak.onStart');
    expect(TtsService.speaking.value, isTrue);
    await tts.stop();
    expect(TtsService.speaking.value, isFalse);
    expect(finished, 1, reason: 'and a stop is still not a finish');
    messenger.setMockMethodCallHandler(channel, null);
    tts.setCompletionHandler(() {});
  });
}
