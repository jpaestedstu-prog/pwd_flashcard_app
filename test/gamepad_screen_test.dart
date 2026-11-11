import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_actions.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_speech.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_practice.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_sections.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_host.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';

/// Contract for the second wave of gamepad work: pushed screens publishing
/// themselves, content being read aloud, games being playable, hold-to-repeat
/// and the practice screen.
///
/// A screen that publishes itself is *read* through the bridge (X, Start) but
/// *driven* through its own buttons, which the D-pad reaches by focus exactly
/// as a keyboard's arrows do.

class _FakeGamepadService extends GamepadService {
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

  void press(GamepadButton b) {
    _buttons.add(GamepadEvent(button: b, pressed: true));
    _buttons.add(GamepadEvent(button: b, pressed: false));
  }

  void down(GamepadButton b) =>
      _buttons.add(GamepadEvent(button: b, pressed: true));
  void up(GamepadButton b) =>
      _buttons.add(GamepadEvent(button: b, pressed: false));

  void connect() => _connections.add(
        const GamepadConnectionEvent(
          deviceId: 90,
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
  Future<void> speak(String t) async => spoken.add(t);
  @override
  Future<void> speakEnglish(String t) async => spoken.add(t);
  @override
  Future<void> speakFilipino(String t) async => spoken.add('[fil] $t');
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double s) async {}
  @override
  Future<void> dispose() async {}

  String get last => spoken.isEmpty ? '' : spoken.last;
  bool said(String needle) => spoken.any((s) => s.contains(needle));
  void clear() => spoken.clear();
}

/// Gamepad settings with hold-to-repeat armed, bypassing Hive.
class _RepeatOnNotifier extends GamepadSettingsNotifier {
  @override
  GamepadSettings build() => const GamepadSettings(
        holdToRepeat: true,
        repeatDelayMs: 300,
        repeatRateMs: 150,
      );
}

/// A Nintendo-layout pad: A and B exchanged.
class _SwappedNotifier extends GamepadSettingsNotifier {
  @override
  GamepadSettings build() => const GamepadSettings(swapConfirmButtons: true);
}

void main() {
  late _FakeGamepadService pad;
  late _FakeTts tts;
  late List<String> chosen;

  setUp(() {
    pad = _FakeGamepadService();
    tts = _FakeTts();
    chosen = [];
    gamepadPractice.value = false;
  });

  tearDown(() {
    gamepadScreen.clear();
    gazeHomeGrid.clearGrid();
    gamepadSections.clear();
    gamepadPractice.value = false;
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Widget body = const Text('app'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          ...overrides,
        ],
        child: MaterialApp(
          home: GamepadHost(child: Scaffold(body: body)),
        ),
      ),
    );
    await tester.pump();
    gamepadSections.publish(
      labels: const ['Home', 'Cards', 'Games'],
      currentIndex: 0,
      onSelect: (_) {},
    );
    pad.connect();
    await tester.pump();
    tts.clear();
  }

  /// The quiz's answers as the buttons a game draws, one under the other.
  Widget quizBody() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final word in ['Dog', 'Cat', 'Bird', 'Fish'])
            TextButton(
              onPressed: () => chosen.add(word),
              child: Text(word),
            ),
        ],
      );

  /// One D-pad press, and the frame the focused label is read on.
  Future<void> press(WidgetTester tester, GamepadButton button) async {
    pad.press(button);
    await tester.pump();
    await tester.pump();
  }

  /// Stands in for a game or quiz publishing its round.
  void publishQuiz() {
    gamepadScreen.publish(
      title: 'Word Match',
      narration: const ['What is the English for "aso"?'],
      items: [
        for (final word in ['Dog', 'Cat', 'Bird', 'Fish'])
          GamepadItem(label: word, onActivate: () => chosen.add(word)),
      ],
    );
  }

  group('a pushed screen that publishes itself', () {
    testWidgets('takes priority over the hub grid behind it', (tester) async {
      await pumpHost(tester, body: quizBody());
      // The hub is still mounted underneath, grid and all.
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'Flashcards', onActivate: () {})],
      ]);
      publishQuiz();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown);
      expect(tts.last, contains('Dog'),
          reason: 'the foreground screen owns the D-pad, not the hub');
      expect(tts.last, isNot(contains('Flashcards')));
    });

    testWidgets('the D-pad moves over its buttons, with counts',
        (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();

      final heard = <String>[];
      for (var i = 0; i < 3; i++) {
        await press(tester, GamepadButton.dpadDown);
        heard.add(tts.last);
      }
      expect(heard, ['Dog, 1 of 4.', 'Cat, 2 of 4.', 'Bird, 3 of 4.']);
    });

    testWidgets('A answers the question', (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown); // Dog
      await press(tester, GamepadButton.dpadDown); // Cat
      await press(tester, GamepadButton.a);
      expect(chosen, ['Cat']);
    });

    testWidgets('X reads the question before the choices', (tester) async {
      // The whole point of narration: a learner can operate the buttons
      // without it, but cannot know what is being asked.
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.x);
      await tester.pump();
      final said = tts.last;
      expect(said, contains('What is the English for "aso"?'));
      expect(said, contains('4 choices'));
      expect(said, contains('Dog, Cat, Bird, Fish'));
      expect(
        said.indexOf('aso'),
        lessThan(said.indexOf('4 choices')),
        reason: 'the question must come before the answers',
      );
    });

    testWidgets('X says which choices cannot be used yet', (tester) async {
      await pumpHost(tester);
      gamepadScreen.publish(
        title: 'Spelling Bee',
        items: [
          GamepadItem(label: 'C', enabled: false, onActivate: () {}),
          GamepadItem(label: 'A', onActivate: () {}),
        ],
      );
      await tester.pump();

      pad.press(GamepadButton.x);
      await tester.pump();
      expect(tts.last, contains('C (not available), A'),
          reason: 'a letter already placed is not worth looking for');
    });

    testWidgets('Start reports the screen, not the tab behind it',
        (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();

      await press(tester, GamepadButton.dpadDown); // Dog
      pad.press(GamepadButton.start);
      await tester.pump();
      expect(tts.last, contains('Word Match'));
      expect(tts.last, contains('Dog'));
    });

    testWidgets('clearing hands the D-pad back to the hub', (tester) async {
      await pumpHost(tester, body: quizBody());
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'Flashcards', onActivate: () {}),
          GazeTileCell(label: 'Games', onActivate: () {}),
        ],
      ]);
      publishQuiz();
      await tester.pump();
      gamepadScreen.clear();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 2.',
          reason: 'leaving a game returns control to the hub underneath');
    });
  });

  group('floating controls', () {
    /// The hub, as a hub publishes it.
    void publishHub() {
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'Flashcards', onActivate: () {}),
          GazeTileCell(label: 'Games', onActivate: () {}),
        ],
      ]);
    }

    testWidgets('come after the hub tiles, never instead of them',
        (tester) async {
      // Published as ordinary screen content the tutor launcher would have
      // *replaced* the hub, leaving the learner able to reach nothing else.
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () => chosen.add('tutor')),
      ]);
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.r2);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 3.');
      pad.press(GamepadButton.r2);
      await tester.pump();
      expect(tts.last, 'Open the tutor, 3 of 3.',
          reason: 'the floating control is last, after every hub tile');
    });

    testWidgets('sit on their own row under the hub', (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () {}),
      ]);
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Open the tutor, 3 of 3.');
      pad.press(GamepadButton.dpadUp);
      await tester.pump();
      expect(tts.last, 'Flashcards, 1 of 3.');
    });

    testWidgets('can be opened like any other item', (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () => chosen.add('tutor')),
      ]);
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(chosen, ['tutor']);
    });

    testWidgets('a disabled one is announced but cannot be opened',
        (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(
          label: 'AI Tutor',
          enabled: false,
          onActivate: () => chosen.add('tutor'),
        ),
      ]);
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('Not available'),
          reason: 'a learner who cannot see it greyed out must be told');
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(chosen, isEmpty);
    });

    testWidgets('are named as things, so "Opening X" reads naturally',
        (tester) async {
      // A label phrased as an action read back as "Opening Open the tutor".
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'AI Tutor', onActivate: () {}),
      ]);
      await tester.pump();
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(tts.last, 'Opening AI Tutor.');
    });

    testWidgets('are included when the screen is read out', (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () {}),
      ]);
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.x);
      await tester.pump();
      expect(tts.last, contains('Open the tutor'));
      expect(tts.last, contains('3 items'));
    });

    testWidgets('withdrawing one shrinks the list again', (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () {}),
      ]);
      await tester.pump();
      gamepadScreen.clearFloating();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.r2);
      await tester.pump();
      expect(tts.last, contains('of 2'),
          reason: 'a launcher that is no longer on screen must not be reachable');
    });
  });

  group('handing over between screens', () {
    testWidgets('X reads the newest screen, not the one it replaced',
        (tester) async {
      // During a push both screens briefly coexist; the reading must follow
      // the one that published last.
      await pumpHost(tester);
      gamepadScreen.publish(
        title: 'FSL Practice',
        items: [
          for (final m in ['Sign to Word', 'Word to Sign', 'Sign It'])
            GamepadItem(label: m, onActivate: () {}),
        ],
        owner: 'first',
      );
      await tester.pump();
      gamepadScreen.publish(
        title: 'Choose Categories',
        items: [
          GamepadItem(label: 'Start', onActivate: () {}),
          GamepadItem(label: 'Animals', onActivate: () {}),
        ],
        owner: 'second',
      );
      await tester.pump();
      gamepadScreen.clear(owner: 'first'); // the old screen disposing late
      await tester.pump();

      pad.press(GamepadButton.x);
      await tester.pump();
      expect(tts.last, contains('Choose Categories'));
      expect(tts.last, contains('Start, Animals'));
      expect(tts.last, isNot(contains('Sign It')));
    });
  });

  group('the right stick', () {
    // The stick directions themselves arrive as axes, which no tooling can
    // inject for Z/RZ — but the *actions* they resolve to are ordinary host
    // behaviour and are pinned here. The axis→button conversion they rely on
    // is the same `bipolar` the left stick exercises on real hardware.
    testWidgets('left and right jump to the first and last control',
        (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();
      await press(tester, GamepadButton.dpadDown); // Dog
      tts.clear();

      await press(tester, GamepadButton.rightStickRight);
      expect(tts.last, 'Fish, 4 of 4.', reason: 'right jumps to the last');

      await press(tester, GamepadButton.rightStickLeft);
      expect(tts.last, 'Dog, 1 of 4.', reason: 'left jumps back to the first');
    });

    testWidgets('clicking it silences a long announcement', (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.rightStickClick);
      await tester.pump();
      // Nothing to assert on the fake beyond not throwing; the contract is
      // that it resolves to stopSpeech and never navigates.
      expect(chosen, isEmpty);
      expect(
        resolveGamepadAction(GamepadButton.rightStickClick),
        GamepadAction.stopSpeech,
      );
    });

    test('its four directions map to reading aids, not navigation', () {
      // Deliberately *not* section changes: a stick is easy to knock, and a
      // stray section change is the one move a blind learner cannot see coming.
      expect(resolveGamepadAction(GamepadButton.rightStickUp),
          GamepadAction.scrollUp);
      expect(resolveGamepadAction(GamepadButton.rightStickDown),
          GamepadAction.scrollDown);
      expect(resolveGamepadAction(GamepadButton.rightStickLeft),
          GamepadAction.firstItem);
      expect(resolveGamepadAction(GamepadButton.rightStickRight),
          GamepadAction.lastItem);
    });

    test('scrolling repeats on hold; jumping to an end does not', () {
      expect(repeatsOnHold(GamepadAction.scrollUp), isTrue);
      expect(repeatsOnHold(GamepadAction.scrollDown), isTrue);
      expect(repeatsOnHold(GamepadAction.firstItem), isFalse);
      expect(repeatsOnHold(GamepadAction.lastItem), isFalse);
    });
  });

  group('the triggers', () {
    test('L2 and R2 step one item at a time, and repeat when held', () {
      // They arrive both as keys (BTN_TL2/TR2) and as analogue axes
      // (BRAKE/GAS); either way they resolve here.
      expect(resolveGamepadAction(GamepadButton.l2), GamepadAction.previousItem);
      expect(resolveGamepadAction(GamepadButton.r2), GamepadAction.nextItem);
      expect(repeatsOnHold(GamepadAction.previousItem), isTrue);
      expect(repeatsOnHold(GamepadAction.nextItem), isTrue);
    });

    test('reading and repeating never repeat on hold', () {
      expect(repeatsOnHold(GamepadAction.readScreen), isFalse,
          reason: 'holding X must not read the screen over and over');
      expect(repeatsOnHold(GamepadAction.repeatLast), isFalse);
    });

    testWidgets('holding X reads the screen exactly once', (tester) async {
      await pumpHost(tester, overrides: [
        gamepadSettingsProvider.overrideWith(_RepeatOnNotifier.new),
      ]);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.x);
      await tester.pump(const Duration(seconds: 2));
      pad.up(GamepadButton.x);
      await tester.pump();
      expect(tts.spoken.length, 1);
    });
  });

  group('sliders', () {
    Future<void> pumpSlider(
      WidgetTester tester, {
      required double start,
      required void Function(double) onValue,
      required FocusNode node,
    }) async {
      var value = start;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamepadServiceProvider.overrideWithValue(pad),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(
            home: GamepadHost(
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Semantics(
                    container: true,
                    label: 'Speech Speed. ${(value * 10).round()} of 10',
                    child: Slider(
                      focusNode: node,
                      value: value,
                      divisions: 10,
                      onChanged: (v) {
                        setState(() => value = v);
                        onValue(v);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      gamepadSections.publish(
        labels: const ['Home', 'Cards'],
        currentIndex: 0,
        onSelect: (_) {},
      );
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      tts.clear();
    }

    testWidgets('A on a slider says how to turn it, and changes nothing',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final values = <double>[];
      await pumpSlider(tester, start: 0.5, onValue: values.add, node: node);

      await press(tester, GamepadButton.a);
      expect(tts.last,
          'Speech Speed. 5 of 10. Use left and right to change it.');
      expect(values, isEmpty);
    });

    testWidgets('left and right turn it, with no mode to enter first',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final values = <double>[];
      await pumpSlider(tester, start: 0.5, onValue: values.add, node: node);

      await press(tester, GamepadButton.dpadRight);
      expect(values.last, closeTo(0.6, 1e-9), reason: 'right turns it up');
      expect(tts.last, 'Speech Speed. 6 of 10');
      // Pumped between presses: a Slider recomputes from its current value,
      // so two key events inside one frame both act on the pre-rebuild value.
      // Real presses are frames apart.
      await press(tester, GamepadButton.dpadLeft);
      await press(tester, GamepadButton.dpadLeft);
      expect(values.last, closeTo(0.4, 1e-9), reason: 'left turns it down');
    });

    testWidgets('at the end of a slider it says so, once labels are honest',
        (tester) async {
      // Only truthful because every reachable slider now changes its spoken
      // label on every step: an unchanged label really does mean the end.
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpSlider(tester, start: 1.0, onValue: (_) {}, node: node);

      await press(tester, GamepadButton.dpadRight); // already at the top
      expect(tts.said('as far as it goes'), isTrue,
          reason: 'two identical readings would sound like a dead button');
    });

    test('every action still has a spoken name', () {
      const en = GamepadPhrases('en');
      for (final action in GamepadAction.values) {
        expect(en.actionName(action), isNotEmpty, reason: action.name);
      }
    });
  });

  group('pressing a control that changes its own label', () {
    testWidgets('a switch says its new state after A', (tester) async {
      // A sighted learner sees a switch flip. Spoken, the row used to say the
      // same words before and after the press, so the one fact the learner
      // needed — is it on now? — was the one thing they never heard.
      bool value = true;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamepadServiceProvider.overrideWithValue(pad),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(
            home: GamepadHost(
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Semantics(
                    container: true,
                    label: 'Sound Effects. ${value ? 'On' : 'Off'}. '
                        'Game sounds & feedback',
                    excludeSemantics: true,
                    child: Switch(
                      focusNode: node,
                      value: value,
                      onChanged: (v) => setState(() => value = v),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.a);
      await tester.pump();
      await tester.pump();

      expect(value, isFalse, reason: 'A presses the switch');
      expect(tts.said('Off'), isTrue,
          reason: 'the learner must hear what it became');
    });

    testWidgets('a press that opens a screen names where it landed',
        (tester) async {
      // The screen that just opened introduces itself; re-reading the button
      // that opened it would put two voices on top of each other.
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamepadServiceProvider.overrideWithValue(pad),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(
            home: GamepadHost(
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    focusNode: node,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Backup codes'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Backup & Restore. Keep a copy in the '
                        'cloud'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.a);
      await tester.pumpAndSettle();

      expect(tts.spoken, isEmpty,
          reason: 'the screen that just opened gets the first word');

      // …but the arrival must not stay silent either. A screen that says
      // nothing for itself is named after the grace period, so pressing a row
      // never sounds like a dead button.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(tts.said('Backup & Restore'), isTrue,
          reason: 'the destination is named, not whatever holds focus there');
      expect(tts.said('cloud'), isFalse,
          reason: "the row's descriptive tail is for choosing, not arriving");
    });

    testWidgets('a screen that introduces itself is not announced twice',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamepadServiceProvider.overrideWithValue(pad),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp(
            home: GamepadHost(
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    focusNode: node,
                    onPressed: () {
                      gamepadScreen.publish(
                        owner: 'quiz',
                        title: 'Quiz',
                        narration: const ['What sound does a dog make?'],
                        items: const [],
                      );
                      gamepadScreen.announce('What sound does a dog make?');
                    },
                    child: const Text('Start quiz'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.a);
      await tester.pump();
      await tester.pump();
      final spokenNow = tts.spoken.length;
      await tester.pump(const Duration(milliseconds: 1400));
      expect(tts.spoken.length, spokenNow,
          reason: 'the screen already spoke; the host must stay quiet');
    });
  });

  group('live announcements', () {
    testWidgets('a screen can narrate itself as it changes', (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();
      tts.clear();

      gamepadScreen.announce('Correct!');
      await tester.pump();
      expect(tts.said('Correct!'), isTrue);
    });

    testWidgets('the same words twice are both spoken', (tester) async {
      // Two correct answers running must not collapse into one announcement —
      // the second press would sound like it did nothing.
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();
      tts.clear();

      gamepadScreen.announce('Correct!');
      await tester.pump();
      gamepadScreen.announce('Correct!');
      await tester.pump();
      expect(tts.spoken.where((s) => s == 'Correct!').length, 2);
    });

    testWidgets('an empty announcement is ignored', (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();
      tts.clear();

      gamepadScreen.announce('   ');
      await tester.pump();
      expect(tts.spoken, isEmpty);
    });
  });

  group('hold to repeat', () {
    testWidgets('is off by default — one press is one move', (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.dpadDown);
      await tester.pump(const Duration(seconds: 2));
      expect(tts.spoken.length, 1);
      pad.up(GamepadButton.dpadDown);
    });

    testWidgets('repeats movement while held, once switched on',
        (tester) async {
      await pumpHost(tester, body: quizBody(), overrides: [
        gamepadSettingsProvider.overrideWith(_RepeatOnNotifier.new),
      ]);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.dpadDown);
      await tester.pump(const Duration(milliseconds: 320)); // past the delay
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 160));
      pad.up(GamepadButton.dpadDown);
      await tester.pump();

      expect(tts.spoken.length, greaterThan(1),
          reason: 'holding should keep stepping');
    });

    testWidgets('stops the moment the control is released', (tester) async {
      await pumpHost(tester, body: quizBody(), overrides: [
        gamepadSettingsProvider.overrideWith(_RepeatOnNotifier.new),
      ]);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.dpadDown);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 160));
      pad.up(GamepadButton.dpadDown);
      await tester.pump();
      final settled = tts.spoken.length;

      await tester.pump(const Duration(seconds: 2));
      expect(tts.spoken.length, settled,
          reason: 'a released button must not keep walking the list');
    });

    testWidgets('a lost release cannot leave the cursor walking forever',
        (tester) async {
      // Bluetooth drops packets, and a dropped *release* is what strands a
      // repeat. Without a ceiling the app would talk to itself indefinitely,
      // and a learner who cannot see the screen would have no idea which
      // button stops it.
      await pumpHost(tester, body: quizBody(), overrides: [
        gamepadSettingsProvider.overrideWith(_RepeatOnNotifier.new),
      ]);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.dpadDown); // …and the release never arrives.
      await tester.pump(const Duration(milliseconds: 320));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 160));
      }
      final settled = tts.spoken.length;
      expect(settled, lessThan(80), reason: 'the repeat must give up on its own');

      await tester.pump(const Duration(seconds: 10));
      expect(tts.spoken.length, settled, reason: 'and stay stopped');
    });

    testWidgets('never repeats opening, going back or changing section',
        (tester) async {
      // The policy that keeps a hold from firing a burst of navigation.
      expect(repeatsOnHold(GamepadAction.moveDown), isTrue);
      expect(repeatsOnHold(GamepadAction.moveRight), isTrue);
      expect(repeatsOnHold(GamepadAction.nextItem), isTrue);
      expect(repeatsOnHold(GamepadAction.previousItem), isTrue);
      expect(repeatsOnHold(GamepadAction.scrollDown), isTrue);
      for (final action in [
        GamepadAction.activate,
        GamepadAction.back,
        GamepadAction.nextSection,
        GamepadAction.previousSection,
        GamepadAction.answerYes,
        GamepadAction.answerNo,
        GamepadAction.goHome,
      ]) {
        expect(repeatsOnHold(action), isFalse, reason: action.name);
      }
    });
  });

  group('practice mode', () {
    testWidgets('stands the app down so presses only teach', (tester) async {
      await pumpHost(tester, body: quizBody());
      publishQuiz();
      await tester.pump();
      gamepadPractice.value = true;
      tts.clear();

      await press(tester, GamepadButton.dpadDown);
      await press(tester, GamepadButton.a);
      await press(tester, GamepadButton.r1);

      expect(chosen, isEmpty,
          reason: 'pressing A to learn what A does must not open anything');
      expect(tts.spoken, isEmpty,
          reason: 'the practice screen does the talking, not the host');
    });

    testWidgets('one B does not leave, so B itself can be explored',
        (tester) async {
      // Ejecting on the first press would make the one control a learner most
      // needs to understand the one they cannot safely try.
      await pumpHost(tester);
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.spoken, isEmpty,
          reason: 'the host stays quiet; the practice screen names the press');
    });

    testWidgets('a second B does leave, so the mode is never a trap',
        (tester) async {
      await pumpHost(tester);
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.b);
      await tester.pump();
      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.spoken, isNotEmpty,
          reason: 'the exit must not depend on the practice screen behaving');
    });

    testWidgets('with the Nintendo swap, the exit follows the swap',
        (tester) async {
      await pumpHost(tester, overrides: [
        gamepadSettingsProvider.overrideWith(_SwappedNotifier.new),
      ]);
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.b); // means A on this pad
      await tester.pump();
      pad.press(GamepadButton.b);
      await tester.pump();
      expect(tts.spoken, isEmpty, reason: 'B is "choose" on a swapped pad');

      pad.press(GamepadButton.a); // means B
      await tester.pump();
      pad.press(GamepadButton.a);
      await tester.pump();
      expect(tts.spoken, isNotEmpty);
    });
  });

  group('phrases for the new surfaces', () {
    const en = GamepadPhrases('en');

    test('a title repeated as the first line of prose is not said twice', () {
      // Both game pickers publish their heading as narration too; saying it
      // twice sounds like a stutter rather than a heading.
      final said = en.screenReading(
        'Choose Categories',
        const ['Choose Categories', 'Pick which vocabulary to practice'],
        const ['Start'],
      );
      expect('Choose Categories'.allMatches(said).length, 1);
      expect(said, contains('Pick which vocabulary to practice'));
    });

    test('a screen reading leads with the prose, then counts the choices', () {
      final said = en.screenReading(
        'Word Match',
        const ['What is the English for "aso"?'],
        const ['Dog', 'Cat'],
      );
      expect(said.startsWith('Word Match.'), isTrue);
      expect(said, contains('What is the English for "aso"?'));
      expect(said, contains('2 choices: Dog, Cat.'));
    });

    test('a line already ending in ! or ? gets no extra full stop', () {
      // Screen copy is written for the eye; some TTS voices pronounce the
      // stray stop in "below!." out loud.
      final said = en.screenReading(
        'FSL Practice',
        const ['Choose a practice mode below!', 'Ready?'],
        const ['Sign to Word'],
      );
      expect(said, contains('below!'));
      expect(said, isNot(contains('below!.')));
      expect(said, isNot(contains('Ready?.')));
    });

    test('a prose-only screen says there is nothing to choose', () {
      final said = en.screenReading('The Way Back Home', const ['Page 1.'], const []);
      expect(said, contains('nothing to choose'));
      expect(said, contains('Press B'));
    });

    test('a single choice is not "1 choices"', () {
      final said = en.screenReading('Daily Reward', const [], const ['Collect']);
      expect(said, contains('1 choice: Collect.'));
      expect(said, isNot(contains('1 choices')));
    });

    test('a long choice list is summarised', () {
      final many = [for (var i = 1; i <= 30; i++) 'Card $i'];
      final said = en.screenReading('Memory Match', const [], many);
      expect(said, contains('30 choices'));
      expect(said, contains('and 18 more'));
    });

    test('memory cards are announced by position and state', () {
      expect(en.memoryCard(3, 12), 'Card 3 of 12, face down.');
      expect(en.memoryCard(3, 12, word: 'dog'), 'Card 3 of 12, dog, face up.');
      expect(
        en.memoryCard(3, 12, word: 'dog', matched: true),
        'Card 3 of 12, dog, already matched.',
      );
    });

    test('a choice that cannot be used yet is marked in a reading', () {
      expect(en.unavailableChoice('C'), 'C (not available)');
      expect(const GamepadPhrases('fil').unavailableChoice('C'),
          'C (hindi pa magagamit)');
    });

    test('an item can carry a detail line and an unavailable note', () {
      expect(en.item('Dog', 1, 4, detail: 'aso'), 'Dog, 1 of 4. aso');
      expect(
        en.item('Card 2', 2, 6, unavailable: true),
        'Card 2, 2 of 6. Not available yet.',
      );
    });

    test('every control and action has a spoken name', () {
      for (final button in GamepadButton.values) {
        expect(en.buttonName(button), isNotEmpty);
      }
      for (final action in GamepadAction.values) {
        expect(en.actionName(action), isNotEmpty);
      }
    });
  });

  group('GamepadSettings for repeat', () {
    test('hold-to-repeat is off by default', () {
      expect(const GamepadSettings().holdToRepeat, isFalse);
    });

    test('repeat timings round-trip and clamp', () {
      const s = GamepadSettings(
        holdToRepeat: true,
        repeatDelayMs: 900,
        repeatRateMs: 200,
      );
      final back = GamepadSettings.fromMap(s.toMap());
      expect(back.holdToRepeat, isTrue);
      expect(back.repeatDelayMs, 900);
      expect(back.repeatRateMs, 200);

      expect(GamepadSettings.fromMap({'repeatDelayMs': 1}).repeatDelayMs,
          GamepadSettings.minRepeatDelayMs);
      expect(GamepadSettings.fromMap({'repeatRateMs': 99999}).repeatRateMs,
          GamepadSettings.maxRepeatRateMs);
    });
  });
}
