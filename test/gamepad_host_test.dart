import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_sections.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_host.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';

/// End-to-end contract for [GamepadHost]: real controller events in, real
/// navigation and real announcements out — with only the platform channel and
/// the TTS engine faked. This is where the feature's *behaviour* is pinned,
/// as opposed to the pure rules covered by `gamepad_logic_test.dart`.

/// Stands in for the native bridge, so a test can press buttons.
class _FakeGamepadService extends GamepadService {
  final _buttonController = StreamController<GamepadEvent>.broadcast();
  final _connectionController =
      StreamController<GamepadConnectionEvent>.broadcast();

  bool captureEnabled = false;

  @override
  Stream<GamepadEvent> get buttons => _buttonController.stream;

  @override
  Stream<GamepadConnectionEvent> get connections =>
      _connectionController.stream;

  @override
  void start() {}

  @override
  Future<void> setCaptureEnabled(bool enabled) async {
    captureEnabled = enabled;
  }

  /// A complete press: down then up, the way the native bridge always reports.
  void press(GamepadButton button) {
    _buttonController.add(GamepadEvent(button: button, pressed: true));
    _buttonController.add(GamepadEvent(button: button, pressed: false));
  }

  /// A press reported *without* its release — used to exercise duplicates.
  void down(GamepadButton button) {
    _buttonController.add(GamepadEvent(button: button, pressed: true));
  }

  void connect({String name = 'GamePadPlus V3', int id = 80}) {
    _connectionController.add(
      GamepadConnectionEvent(deviceId: id, name: name, connected: true),
    );
  }

  void disconnect({int id = 80}) {
    _connectionController.add(
      GamepadConnectionEvent(deviceId: id, name: '', connected: false),
    );
  }

  @override
  Future<void> dispose() async {
    await _buttonController.close();
    await _connectionController.close();
  }
}

/// Records what the app tried to say instead of reaching a TTS engine.
class _FakeTts extends TtsService {
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> speakEnglish(String text) async => spoken.add(text);

  @override
  Future<void> speakFilipino(String text) async => spoken.add('[fil] $text');

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> setSpeed(double speed) async => rate = speed;

  double rate = 0.5;

  @override
  Future<void> dispose() async {}

  String get last => spoken.isEmpty ? '' : spoken.last;
  bool said(String needle) => spoken.any((s) => s.contains(needle));
  void clear() => spoken.clear();
}

void main() {
  late _FakeGamepadService pad;
  late _FakeTts tts;
  late List<int> selectedSections;

  const tabs = ['Home', 'Cards', 'Games', 'Stories', 'Progress'];

  /// Stands in for the navigation shell publishing its tab set.
  void publishShell({int current = 0}) {
    gamepadSections.publish(
      labels: tabs,
      currentIndex: current,
      onSelect: selectedSections.add,
    );
  }

  /// Stands in for a hub publishing its feature tiles — two rows of two, the
  /// shape the real Home screen uses.
  List<String> opened = [];
  void publishGrid() {
    gazeHomeGrid.publishGrid([
      [
        GazeTileCell(label: 'Flashcards', onActivate: () => opened.add('Flashcards')),
        GazeTileCell(label: 'Games', onActivate: () => opened.add('Games')),
      ],
      [
        GazeTileCell(label: 'Stories', onActivate: () => opened.add('Stories')),
        GazeTileCell(label: 'Smart Review', onActivate: () => opened.add('Smart Review')),
      ],
    ]);
  }

  setUp(() {
    pad = _FakeGamepadService();
    tts = _FakeTts();
    selectedSections = [];
    opened = [];
  });

  tearDown(() {
    // These are app-wide singletons; a leftover grid would bleed into the next
    // test exactly as it would bleed between screens in the app.
    gazeHomeGrid.clearGrid();
    gamepadSections.clear();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
        ],
        child: const MaterialApp(
          home: GamepadHost(child: Scaffold(body: Text('app'))),
        ),
      ),
    );
    // The host arms itself in a microtask so it never touches providers
    // mid-build.
    await tester.pump();
  }

  group('connecting', () {
    testWidgets('welcomes the learner into the section they are in',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      await tester.pump();
      pad.connect();
      await tester.pump();

      expect(tts.said('welcome'), isTrue);
      expect(tts.said('Home section'), isTrue,
          reason: 'the welcome must say where the learner has landed');
    });

    testWidgets('holds the welcome until a section actually exists',
        (tester) async {
      // A controller often connects on the splash or profile picker, before
      // any hub has published. Announcing an empty section there would be
      // worse than a short silence.
      await pumpHost(tester);
      pad.connect();
      await tester.pump();
      expect(tts.said('welcome'), isFalse);

      publishShell();
      await tester.pump();
      expect(tts.said('welcome'), isTrue);
    });

    testWidgets('turns on native capture only once it is listening',
        (tester) async {
      await pumpHost(tester);
      expect(pad.captureEnabled, isTrue);
    });

    testWidgets('one pad arriving as two devices still gets one welcome',
        (tester) async {
      // The X3 exposes a gamepad interface *and* a Consumer Control interface,
      // and Android hands out fresh device ids across reconnects. Treating the
      // second arrival as a reconnection swallowed the welcome outright on the
      // real tablet: the learner picked up a controller that said nothing.
      await pumpHost(tester);
      pad.connect(id: 81);
      await tester.pump();
      pad.connect(id: 82);
      await tester.pump();
      publishShell();
      await tester.pump();

      expect(tts.said('welcome'), isTrue);
      expect(
        tts.spoken.where((s) => s.contains('welcome')).length,
        1,
        reason: 'exactly one greeting, however many interfaces the pad has',
      );
      expect(tts.said('reconnected'), isFalse);
    });

    testWidgets('losing one of a pad\'s two interfaces is not a disconnect',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect(id: 81);
      pad.connect(id: 82);
      await tester.pump();
      tts.clear();

      pad.disconnect(id: 82);
      await tester.pump();
      expect(tts.said('disconnected'), isFalse,
          reason: 'the learner still has a working controller in their hands');

      pad.disconnect(id: 81);
      await tester.pump();
      expect(tts.said('disconnected'), isTrue);
    });
  });

  group('the ask-before-you-move flow', () {
    testWidgets('D-pad right asks about the next section', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadRight);
      await tester.pump();

      expect(tts.last, contains('Do you want to go to the Cards section?'));
      expect(tts.last, contains('A for yes'));
      expect(selectedSections, isEmpty,
          reason: 'asking must not move the learner');
    });

    testWidgets('A confirms and lands in the new section', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();

      expect(selectedSections, [1]);
      expect(tts.last, "You're now in the Cards section.");
    });

    testWidgets('B declines and offers the one after it', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.last, contains('Games section?'));

      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.last, contains('Stories section?'));

      expect(selectedSections, isEmpty,
          reason: 'declining never moves the learner');
    });

    testWidgets('A is directional again once no question is open',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      // No question open: A means "next item", not "yes".
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(selectedSections, isEmpty);
      expect(tts.last, contains('of 4'));
    });

    testWidgets('a stale question cannot be answered later', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight); // asks about Cards
      await tester.pump();
      pad.press(GamepadButton.dpadDown); // the learner does something else
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();

      expect(selectedSections, isEmpty,
          reason: 'A must not answer a question the learner abandoned');
    });

    testWidgets('D-pad left walks the sections backwards', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadLeft);
      await tester.pump();
      expect(tts.last, contains('Progress section?'),
          reason: 'left from Home wraps to the last tab');
    });
  });

  group('moving through items', () {
    testWidgets('announces each item with its position', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 4.');

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Stories, 3 of 4.');
    });

    testWidgets('reaches every cell of a 2-column grid with down alone',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      final heard = <String>[];
      for (var i = 0; i < 4; i++) {
        pad.press(GamepadButton.dpadDown);
        await tester.pump();
        heard.add(tts.last);
      }
      // Started on item 1, so stepping four times wraps back to it.
      expect(heard.where((s) => s.contains('Games')), isNotEmpty);
      expect(heard.where((s) => s.contains('Smart Review')), isNotEmpty);
    });

    testWidgets('draws the same focus ring the gaze D-pad uses', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 0);
      expect(gazeHomeGrid.focusCol, 1);
    });

    testWidgets('R1 opens the item the learner is on', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadDown); // to Games
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.r1);
      await tester.pump();

      expect(opened, ['Games']);
      expect(tts.said('Opening Games'), isTrue);
    });

    testWidgets('never leaves a press silent, even with no grid published',
        (tester) async {
      // The invariant that matters on an unadopted screen: whatever the focus
      // traversal does or does not find, the learner hears *something*. A
      // silent press reads as a broken controller, and there is no other cue
      // available to someone who cannot see the screen.
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      await tester.pump(); // the focused label is read a frame later

      expect(tts.spoken, isNotEmpty,
          reason: 'a press with no audible result is indistinguishable from a '
              'dead button');
    });

    testWidgets('a dead end always names the way out', (tester) async {
      await pumpHost(tester);
      publishShell();
      // A published-but-empty grid is the unambiguous "nothing here" case.
      gazeHomeGrid.publishGrid(const [<GazeTileCell>[]]);
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.said('no items'), isTrue);
      expect(tts.said('L1'), isTrue);
    });
  });

  group('duplicate and accidental input', () {
    testWidgets('the X3 dual-interface double-report moves the cursor once',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      // One physical press, reported twice: once as the ABS_HAT0X axis, once
      // as KEY_DOWN from the Consumer Control interface, with no release
      // between them.
      pad.down(GamepadButton.dpadDown);
      pad.down(GamepadButton.dpadDown);
      await tester.pump();

      expect(tts.spoken.length, 1);
      expect(tts.last, 'Games, 2 of 4.');
    });

    testWidgets('a held button does not stampede through the screen',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      for (var i = 0; i < 10; i++) {
        pad.down(GamepadButton.dpadDown);
      }
      await tester.pump();
      expect(tts.spoken.length, 1);
    });
  });

  group('disconnecting and reconnecting', () {
    testWidgets('says the controller is gone, and how to carry on',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.disconnect();
      await tester.pump();

      expect(tts.said('disconnected'), isTrue);
      expect(tts.said('touch screen'), isTrue,
          reason: 'a learner left without a controller needs the alternative');
    });

    testWidgets('a reconnect confirms where the learner still is',
        (tester) async {
      await pumpHost(tester);
      publishShell(current: 1);
      pad.connect();
      await tester.pump();
      pad.disconnect();
      await tester.pump();
      tts.clear();

      pad.connect();
      await tester.pump();

      expect(tts.said('reconnected'), isTrue);
      expect(tts.said('Cards'), isTrue);
      expect(tts.said('welcome'), isFalse,
          reason: 'the full welcome would be wrong the second time');
    });

    testWidgets('the controller works again after reconnecting',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      pad.disconnect();
      await tester.pump();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('of 4'));
    });

    testWidgets('a button held as the link drops is not stuck afterwards',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      // Down, then the link drops — the release never arrives.
      pad.down(GamepadButton.dpadDown);
      await tester.pump();
      pad.disconnect();
      await tester.pump();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.spoken.length, 1,
          reason: 'the same button must work after a reconnect');
    });
  });

  group('listening aids', () {
    testWidgets('Select speaks the button guide', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.select);
      await tester.pump();
      expect(tts.last, contains('Button guide'));
      expect(tts.last, contains('R1'));
    });

    testWidgets('Start says where the learner is', (tester) async {
      await pumpHost(tester);
      publishShell(current: 2);
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.start);
      await tester.pump();
      expect(tts.last, contains('Games section'));
      expect(tts.last, contains('Flashcards'),
          reason: 'where am I means both the section and the item');
    });

    testWidgets('R2 reads the whole screen', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.r2);
      await tester.pump();
      expect(tts.last, contains('4 items'));
      expect(tts.last, contains('Flashcards'));
      expect(tts.last, contains('Smart Review'));
    });

    testWidgets('L2 repeats the last thing said', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      final wasSaid = tts.last;
      pad.press(GamepadButton.l2);
      await tester.pump();
      expect(tts.last, wasSaid);
    });

    testWidgets('the right stick click silences a long announcement',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      final before = tts.stops;

      pad.press(GamepadButton.rightStickClick);
      await tester.pump();
      expect(tts.stops, greaterThan(before));
    });

    testWidgets('the left stick click goes straight Home', (tester) async {
      await pumpHost(tester);
      publishShell(current: 3);
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.leftStickClick);
      await tester.pump();
      expect(selectedSections, [0]);
      expect(tts.said('Home'), isTrue);
    });
  });

  group('when the feature is switched off', () {
    testWidgets('L1 at the root says there is nowhere to go back to',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.l1);
      await tester.pump();
      expect(tts.said('main screen'), isTrue);
    });

    testWidgets('the mode button is ignored rather than acted on',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.mode);
      await tester.pump();
      expect(tts.spoken, isEmpty);
      expect(selectedSections, isEmpty);
    });
  });
}
