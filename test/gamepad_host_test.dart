import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_sections.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_host.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart' show DpadSliderScope;

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

/// A learner's saved controller settings, without Hive.
class _FixedGamepadSettings extends GamepadSettingsNotifier {
  _FixedGamepadSettings(this.initial);
  final GamepadSettings initial;

  @override
  GamepadSettings build() => initial;
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

  Future<void> pumpHost(
    WidgetTester tester, {
    Widget body = const Text('app'),
    GamepadSettings? settings,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          if (settings != null)
            gamepadSettingsProvider
                .overrideWith(() => _FixedGamepadSettings(settings)),
        ],
        child: MaterialApp(
          home: GamepadHost(child: Scaffold(body: body)),
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
    testWidgets('R1 asks about the next section', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.r1);
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

      pad.press(GamepadButton.r1);
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

      pad.press(GamepadButton.r1);
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

    testWidgets('L1 walks the sections backwards', (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.l1);
      await tester.pump();
      expect(tts.last, contains('Progress section?'),
          reason: 'back from Home wraps to the last tab');
    });

    testWidgets('with no question open, A presses the highlighted tile',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.a);
      await tester.pump();
      expect(selectedSections, isEmpty);
      expect(opened, ['Flashcards']);
      expect(tts.said('Opening Flashcards'), isTrue);
    });

    testWidgets('a stale question cannot be answered later', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.r1); // asks about Cards
      await tester.pump();
      pad.press(GamepadButton.dpadDown); // the learner does something else
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();

      expect(selectedSections, isEmpty,
          reason: 'A must not answer a question the learner abandoned');
      expect(opened, ['Stories'],
          reason: 'it presses the tile the learner moved to instead');
    });

    testWidgets('the D-pad never answers a question', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.r1);
      await tester.pump();
      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(selectedSections, isEmpty);
      expect(tts.last, 'Games, 2 of 4.',
          reason: 'right moves along the row, exactly as with no question');
    });

    testWidgets('with the Nintendo swap, B says yes and A says no',
        (tester) async {
      await pumpHost(
        tester,
        settings: const GamepadSettings(swapConfirmButtons: true),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.r1); // Cards?
      await tester.pump();
      pad.press(GamepadButton.a); // reported as A, meant as "no"
      await tester.pump();
      expect(tts.last, contains('Games section?'));
      pad.press(GamepadButton.b); // reported as B, meant as "yes"
      await tester.pump();
      expect(selectedSections, [2]);
    });

    testWidgets('with asking turned off, R1 switches straight away',
        (tester) async {
      await pumpHost(
        tester,
        settings: const GamepadSettings(confirmSectionChange: false),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(selectedSections, [1]);
      expect(tts.last, "You're now in the Cards section.");
    });
  });

  group('moving over the hub tiles', () {
    testWidgets('the D-pad moves by direction, counting each tile',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      final heard = <String>[];
      for (final button in [
        GamepadButton.dpadRight,
        GamepadButton.dpadDown,
        GamepadButton.dpadLeft,
        GamepadButton.dpadUp,
      ]) {
        pad.press(button);
        await tester.pump();
        heard.add(tts.last);
      }
      expect(heard, [
        'Games, 2 of 4.',
        'Smart Review, 4 of 4.',
        'Stories, 3 of 4.',
        'Flashcards, 1 of 4.',
      ]);
    });

    testWidgets('left and right wrap within the row', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadLeft);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 4.', reason: 'left from the first wraps');
      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(tts.last, 'Flashcards, 1 of 4.');
    });

    testWidgets('draws the same focus ring the gaze D-pad uses', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 0);
      expect(gazeHomeGrid.focusCol, 1);
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 1);
      expect(gazeHomeGrid.focusCol, 1);
    });

    testWidgets('R2 and L2 walk the tiles one at a time in reading order',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      final heard = <String>[];
      for (var i = 0; i < 4; i++) {
        pad.press(GamepadButton.r2);
        await tester.pump();
        heard.add(tts.last);
      }
      expect(heard, [
        'Games, 2 of 4.',
        'Stories, 3 of 4.',
        'Smart Review, 4 of 4.',
        'Flashcards, 1 of 4.',
      ], reason: 'every tile of a 2-column grid, then round again');
      pad.press(GamepadButton.l2);
      await tester.pump();
      expect(tts.last, 'Smart Review, 4 of 4.');
    });

    testWidgets('the right stick jumps to the last and first tile',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.rightStickRight);
      await tester.pump();
      expect(tts.last, 'Smart Review, 4 of 4.');
      pad.press(GamepadButton.rightStickLeft);
      await tester.pump();
      expect(tts.last, 'Flashcards, 1 of 4.');
    });

    testWidgets('A opens the tile the learner is on', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight); // to Games
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();

      expect(opened, ['Games']);
      expect(tts.said('Opening Games'), isTrue);
    });

    testWidgets('the left stick moves too, unless it is turned off',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.leftStickRight);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 4.');
    });

    testWidgets('a left stick turned off does nothing at all', (tester) async {
      await pumpHost(
        tester,
        settings: const GamepadSettings(leftStickMoves: false),
      );
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      for (final stick in [
        GamepadButton.leftStickUp,
        GamepadButton.leftStickDown,
        GamepadButton.leftStickLeft,
        GamepadButton.leftStickRight,
      ]) {
        pad.press(stick);
        await tester.pump();
      }
      expect(tts.spoken, isEmpty, reason: 'a knocked stick must stay silent');
      expect(opened, isEmpty);

      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 4.', reason: 'the D-pad still moves');
    });

    testWidgets('a hub rebuilding under the learner keeps their tile',
        (tester) async {
      // A hub republishes its tiles on every build — coming back from a game
      // is one. The controller must still be on the tile that opened it.
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadRight); // Games
      await tester.pump();
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(opened, ['Games']);

      publishGrid();
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.start);
      await tester.pump();
      expect(tts.last, contains('Games'));
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Smart Review, 4 of 4.',
          reason: 'the next move carries on from Games, not from the top');
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
      expect(tts.said('Press B'), isTrue);
    });
  });

  group('moving on any other screen', () {
    // Four buttons in a square, with nothing else focusable: the screen a
    // keyboard's arrows would move round.
    Widget square() {
      Widget button(String label) => SizedBox(
            width: 140,
            height: 64,
            child: TextButton(
              onPressed: () => opened.add(label),
              child: Text(label),
            ),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [button('One'), button('Two')],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [button('Three'), button('Four')],
          ),
        ],
      );
    }

    Future<void> press(WidgetTester tester, GamepadButton button) async {
      pad.press(button);
      await tester.pump();
      await tester.pump(); // the focused label is read a frame later
    }

    testWidgets('the D-pad moves in all four directions, as arrow keys do',
        (tester) async {
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();

      final heard = <String>[];
      for (final button in [
        GamepadButton.dpadDown,
        GamepadButton.dpadRight,
        GamepadButton.dpadDown,
        GamepadButton.dpadLeft,
        GamepadButton.dpadUp,
      ]) {
        tts.clear();
        await press(tester, button);
        heard.add(tts.last);
      }
      expect(heard, [
        'One, 1 of 4.',
        'Two, 2 of 4.',
        'Four, 4 of 4.',
        'Three, 3 of 4.',
        'One, 1 of 4.',
      ]);
    });

    testWidgets('A presses the focused control', (tester) async {
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      await press(tester, GamepadButton.dpadRight);
      await press(tester, GamepadButton.a);
      expect(opened, ['Two']);
    });

    testWidgets('R2 and L2 step the focus one control at a time',
        (tester) async {
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();

      final heard = <String>[];
      for (var i = 0; i < 3; i++) {
        tts.clear();
        await press(tester, GamepadButton.r2);
        heard.add(tts.last);
      }
      expect(heard, ['One, 1 of 4.', 'Two, 2 of 4.', 'Three, 3 of 4.']);
      tts.clear();
      await press(tester, GamepadButton.l2);
      expect(tts.last, 'Two, 2 of 4.');
    });

    testWidgets('the right stick jumps to the last and first control',
        (tester) async {
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      tts.clear();
      await press(tester, GamepadButton.rightStickRight);
      expect(tts.last, 'Four, 4 of 4.');
      tts.clear();
      await press(tester, GamepadButton.rightStickLeft);
      expect(tts.last, 'One, 1 of 4.');
    });

    testWidgets('a focus parked on the root starts again from the first control',
        (tester) async {
      // Flutter parks the focus on its root scope while the app's window is
      // not focused (a system pop-up over it) and gives it back only if
      // nothing moved meanwhile. Seen twice on the tablet right after a
      // keyboard connected (29 Oct): every press said "Nothing more that way.
      // Still on Unnamed item", and the controller could not move at all.
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'One, 1 of 4.');

      FocusManager.instance.rootScope.requestFocus();
      await tester.pump();
      tts.clear();
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, isNot(contains('Nothing more that way')),
          reason: 'heard: ${tts.spoken}');
      expect(tts.last, contains('of 4.'),
          reason: 'it lands on a control again: ${tts.spoken}');
    });

    testWidgets('a move with nothing that way says where the learner still is',
        (tester) async {
      await pumpHost(
        tester,
        body: TextButton(onPressed: () {}, child: const Text('Only')),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Only, 1 of 1.');
      tts.clear();
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Nothing more that way. Still on Only.',
          reason: 'the same name again would sound like a move');
    });

    testWidgets('never leaves a press silent, even with nothing to focus',
        (tester) async {
      // Whatever the focus does or does not find, the learner hears
      // *something*. A silent press reads as a broken controller, and there
      // is no other cue available to someone who cannot see the screen.
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.spoken, isNotEmpty,
          reason: 'a press with no audible result is indistinguishable from a '
              'dead button');
    });

    testWidgets('a slider turns with left and right and is left with down',
        (tester) async {
      var volume = 2.0;
      await pumpHost(
        tester,
        body: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('Before')),
              Semantics(
                container: true,
                label: 'Volume. ${volume.round()}',
                child: DpadSliderScope(
                  child: Slider(
                    value: volume,
                    max: 3,
                    divisions: 3,
                    onChanged: (v) => setState(() => volume = v),
                  ),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Before, 1 of 3.');
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Volume. 2, 2 of 3.');

      tts.clear();
      await press(tester, GamepadButton.dpadRight);
      expect(volume, 3);
      expect(tts.last, 'Volume. 3', reason: 'the new value is read back');

      tts.clear();
      await press(tester, GamepadButton.dpadRight);
      expect(volume, 3);
      expect(tts.last, isNot('Volume. 3'),
          reason: 'at the end it says so, rather than repeating itself');
      expect(tts.last, contains('Volume. 3'));

      tts.clear();
      await press(tester, GamepadButton.a);
      expect(tts.last, 'Volume. 3. Use left and right to change it.');
      expect(volume, 3, reason: 'A never changes the value');

      await press(tester, GamepadButton.dpadLeft);
      expect(volume, 2);

      tts.clear();
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'After, 3 of 3.', reason: 'down leaves the slider');
      expect(volume, 2, reason: 'and does not turn it');
    });

    testWidgets('a named slider says its name and its value', (tester) async {
      // DpadSliderScope(name:) puts only the name in the label; the value
      // comes from the formatter, which TalkBack reads as the slider moves.
      // The controller reads both, so a turn still sounds like one.
      final semantics = tester.ensureSemantics();
      var volume = 2.0;
      await pumpHost(
        tester,
        body: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('Before')),
              DpadSliderScope(
                name: 'Volume',
                child: Slider(
                  value: volume,
                  max: 3,
                  divisions: 3,
                  semanticFormatterCallback: (v) => '${v.round()} points',
                  onChanged: (v) => setState(() => volume = v),
                ),
              ),
            ],
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      // What Android is sent: the merged node's data.
      final data = tester.getSemantics(find.byType(Slider)).getSemanticsData();
      expect(data.label, 'Volume', reason: 'the name, once, on the slider');
      expect(data.value, '2 points');
      expect(data.increasedValue, '3 points',
          reason: 'what TalkBack says as it moves up');
      expect(data.hasAction(SemanticsAction.increase), isTrue,
          reason: 'and the slider can still be turned');

      await press(tester, GamepadButton.dpadDown);
      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Volume. 2 points, 2 of 2.');

      tts.clear();
      await press(tester, GamepadButton.dpadRight);
      expect(volume, 3);
      expect(tts.last, 'Volume. 3 points', reason: 'the new value is read back');

      tts.clear();
      await press(tester, GamepadButton.dpadRight);
      expect(tts.last, isNot('Volume. 3 points'),
          reason: 'at the end it says so, rather than repeating itself');
      expect(tts.last, contains('Volume. 3 points'));
      semantics.dispose();
    });

    testWidgets('B goes back from a pushed screen, and says so',
        (tester) async {
      await pumpHost(
        tester,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Inner page')),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Inner page'), findsOneWidget);
      tts.clear();

      pad.press(GamepadButton.b);
      await tester.pumpAndSettle();
      expect(find.text('Inner page'), findsNothing);
      expect(tts.said('Going back'), isTrue);
    });

    testWidgets('after B, the focus is back on the control that opened '
        'the page', (tester) async {
      await pumpHost(
        tester,
        body: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('First')),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: TextButton(
                        onPressed: () {},
                        child: const Text('Inside'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown); // First
      await press(tester, GamepadButton.dpadDown); // Open
      expect(tts.last, 'Open, 2 of 2.');
      pad.press(GamepadButton.a);
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsOneWidget);
      // Let the arrival announcement's grace period run out.
      await tester.pump(const Duration(milliseconds: 1300));

      pad.press(GamepadButton.b);
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsNothing);
      tts.clear();
      pad.press(GamepadButton.start);
      await tester.pump();
      expect(tts.last, contains('Open'),
          reason: 'where am I names the control the learner left from');
      tts.clear();
      await press(tester, GamepadButton.dpadUp);
      expect(tts.last, 'First, 1 of 2.',
          reason: 'and the next move carries on from there');
    });

    testWidgets('a switch row says its state on arrival and after A',
        (tester) async {
      // Its label never mentions the state, so the same words before and
      // after A told a learner who cannot see the switch nothing.
      var on = true;
      await pumpHost(
        tester,
        body: StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            title: const Text('Vibrate'),
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Vibrate, on, 1 of 1.');
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();
      await tester.pump();
      expect(on, isFalse);
      expect(tts.last, 'Vibrate, off');
      await tester.pump(const Duration(milliseconds: 1300));
    });

    testWidgets('a row whose label already says its state is not told twice',
        (tester) async {
      var on = true;
      await pumpHost(
        tester,
        // The Settings rows' pattern: the full label, state included, inside
        // the focusable part, where the label reader looks first.
        body: StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            title: Semantics(
              label: 'Sound Effects. ${on ? 'On' : 'Off'}. Game sounds',
              excludeSemantics: true,
              child: const Text('Sound Effects'),
            ),
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, 'Sound Effects. On. Game sounds, 1 of 1.');
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();
      await tester.pump();
      expect(tts.spoken, ['Sound Effects. Off. Game sounds'],
          reason: 'the new label says it; no extra ", off"');
      await tester.pump(const Duration(milliseconds: 1300));
    });

    testWidgets('X reads every control on an ordinary screen',
        (tester) async {
      // The guide promises X reads the whole screen. Off the hubs it used to
      // say only the focused control and how to move.
      await pumpHost(tester, body: square());
      publishShell();
      pad.connect();
      await tester.pump();
      await press(tester, GamepadButton.dpadDown); // One
      tts.clear();

      pad.press(GamepadButton.x);
      await tester.pump();
      expect(tts.last, '4 items here: One, Two, Three, Four.');
    });

    testWidgets('B in a text box leaves the box, not the screen',
        (tester) async {
      await pumpHost(
        tester,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Above')),
                      const TextField(key: Key('box')),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      publishShell();
      pad.connect();
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final above = Focus.of(tester.element(find.text('Above')));
      above.requestFocus();
      await tester.pump();
      await press(tester, GamepadButton.dpadDown); // into the box
      final box = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(box.hasPrimaryFocus, isTrue);
      tts.clear();

      pad.press(GamepadButton.b);
      await tester.pumpAndSettle();
      expect(box.hasFocus, isFalse, reason: 'B left the box');
      expect(find.byKey(const Key('box')), findsOneWidget,
          reason: '…and kept the screen');
      expect(above.hasPrimaryFocus, isTrue,
          reason: 'back on the control the learner came from');
      expect(tts.said('Left the text box.'), isTrue);

      pad.press(GamepadButton.b);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box')), findsNothing,
          reason: 'a second B leaves the screen');
    });

    testWidgets('B at the root says there is nowhere to go back to',
        (tester) async {
      await pumpHost(tester);
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.said('main screen'), isTrue);
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
      expect(tts.last, 'Stories, 3 of 4.');
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
      expect(tts.last, contains('A: choose what is highlighted'));
      expect(tts.last, contains('Left joystick: the same as the D-pad.'));
    });

    testWidgets('the spoken guide leaves out a stick that is turned off',
        (tester) async {
      await pumpHost(
        tester,
        settings: const GamepadSettings(leftStickMoves: false),
      );
      publishShell();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.select);
      await tester.pump();
      expect(tts.last, contains('Button guide'));
      expect(tts.last, isNot(contains('Left joystick: the same')));
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

    testWidgets('X reads the whole screen', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.x);
      await tester.pump();
      expect(tts.last, contains('4 items'));
      expect(tts.last, contains('Flashcards'));
      expect(tts.last, contains('Smart Review'));
    });

    testWidgets('Y repeats the last thing said', (tester) async {
      await pumpHost(tester);
      publishShell();
      publishGrid();
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      final wasSaid = tts.last;
      pad.press(GamepadButton.y);
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

    testWidgets('a turned-off stick still clicks Home', (tester) async {
      await pumpHost(
        tester,
        settings: const GamepadSettings(leftStickMoves: false),
      );
      publishShell(current: 3);
      pad.connect();
      await tester.pump();

      pad.press(GamepadButton.leftStickClick);
      await tester.pump();
      expect(selectedSections, [0],
          reason: 'only the stick\'s movement is turned off');
    });
  });

  group('ignored input', () {
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
