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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          ...overrides,
        ],
        child: const MaterialApp(
          home: GamepadHost(child: Scaffold(body: Text('app'))),
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
      await pumpHost(tester);
      // The hub is still mounted underneath, grid and all.
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'Flashcards', onActivate: () {})],
      ]);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('Cat'),
          reason: 'the foreground screen owns the cursor, not the hub');
      expect(tts.last, isNot(contains('Flashcards')));
    });

    testWidgets('walks its items with counts', (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Cat, 2 of 4.');
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Bird, 3 of 4.');
    });

    testWidgets('R1 answers the question', (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.dpadDown); // to Cat
      await tester.pump();
      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(chosen, ['Cat']);
    });

    testWidgets('R2 reads the question before the choices', (tester) async {
      // The whole point of narration: a learner can operate the buttons
      // without it, but cannot know what is being asked.
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.r2);
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

    testWidgets('Start reports the screen, not the tab behind it',
        (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();

      pad.press(GamepadButton.start);
      await tester.pump();
      expect(tts.last, contains('Word Match'));
      expect(tts.last, contains('Dog'));
    });

    testWidgets('a disabled item is announced but cannot be opened',
        (tester) async {
      await pumpHost(tester);
      gamepadScreen.publish(
        title: 'Memory Match',
        items: [
          GamepadItem(label: 'Card 1', onActivate: () => chosen.add('1')),
          GamepadItem(
            label: 'Card 2',
            enabled: false,
            onActivate: () => chosen.add('2'),
          ),
        ],
      );
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('Not available'),
          reason: 'a learner who cannot see it greyed out must be told');

      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(chosen, isEmpty);
    });

    testWidgets('clearing hands the cursor back to the hub', (tester) async {
      await pumpHost(tester);
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

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('Games'),
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

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Games, 2 of 3.');
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, 'Open the tutor, 3 of 3.',
          reason: 'the floating control is last, after every hub tile');
    });

    testWidgets('can be opened like any other item', (tester) async {
      await pumpHost(tester);
      publishHub();
      gamepadScreen.publishFloating([
        GamepadItem(label: 'Open the tutor', onActivate: () => chosen.add('tutor')),
      ]);
      await tester.pump();

      pad.press(GamepadButton.dpadDown);
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(chosen, ['tutor']);
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
      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      tts.clear();
      pad.press(GamepadButton.r1);
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

      pad.press(GamepadButton.r2);
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

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      expect(tts.last, contains('of 2'),
          reason: 'a launcher that is no longer on screen must not be reachable');
    });
  });

  group('handing over between screens', () {
    testWidgets('a new screen starts the cursor at its first item',
        (tester) async {
      // During a push both screens briefly coexist. Carrying the old cursor
      // index into the new list made R1 activate whatever sat at that index —
      // on the category sheet that silently toggled a category instead of
      // pressing Start.
      final first = Object();
      final second = Object();
      await pumpHost(tester);
      gamepadScreen.publish(
        title: 'FSL Practice',
        items: [
          for (final m in ['Sign to Word', 'Word to Sign', 'Sign It'])
            GamepadItem(label: m, onActivate: () {}),
        ],
        owner: first,
      );
      await tester.pump();
      pad.press(GamepadButton.dpadDown);
      pad.press(GamepadButton.dpadDown);
      await tester.pump(); // cursor now on item 3

      gamepadScreen.publish(
        title: 'Choose Categories',
        items: [
          GamepadItem(label: 'Start', onActivate: () => chosen.add('start')),
          GamepadItem(label: 'Animals', onActivate: () => chosen.add('animals')),
          GamepadItem(label: 'Numbers', onActivate: () => chosen.add('numbers')),
        ],
        owner: second,
      );
      await tester.pump();
      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(chosen, ['start'],
          reason: 'a fresh screen begins at its first item');
    });

    testWidgets('a screen republishing its own items keeps the cursor',
        (tester) async {
      // Spelling Bee republishes on every letter (a used letter is disabled).
      // Resetting there would throw the learner back to the first tile after
      // every single move.
      final owner = Object();
      await pumpHost(tester);
      gamepadScreen.publish(
        title: 'Spelling Bee',
        items: [
          for (final l in ['R', 'C', 'I', 'E'])
            GamepadItem(label: l, onActivate: () => chosen.add(l)),
        ],
        owner: owner,
      );
      await tester.pump();
      pad.press(GamepadButton.dpadDown);
      pad.press(GamepadButton.dpadDown);
      await tester.pump(); // on 'I'

      gamepadScreen.publish(
        title: 'Spelling Bee',
        items: [
          GamepadItem(label: 'R', enabled: false, onActivate: () {}),
          for (final l in ['C', 'I', 'E'])
            GamepadItem(label: l, onActivate: () => chosen.add(l)),
        ],
        owner: owner,
      );
      await tester.pump();
      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(chosen, ['I'], reason: 'the learner keeps their place');
    });
  });

  group('the right stick', () {
    // The stick directions themselves arrive as axes, which no tooling can
    // inject for Z/RZ — but the *actions* they resolve to are ordinary host
    // behaviour and are pinned here. The axis→button conversion they rely on
    // is the same `bipolar` the left stick exercises on real hardware.
    testWidgets('left and right jump to the first and last item',
        (tester) async {
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.rightStickRight);
      await tester.pump();
      expect(tts.last, 'Fish, 4 of 4.', reason: 'right jumps to the last item');

      pad.press(GamepadButton.rightStickLeft);
      await tester.pump();
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
    test('L2 and R2 are reading aids and never repeat on hold', () {
      // They arrive both as keys (BTN_TL2/TR2) and as analogue axes
      // (BRAKE/GAS); either way they resolve here.
      expect(resolveGamepadAction(GamepadButton.l2), GamepadAction.repeatLast);
      expect(resolveGamepadAction(GamepadButton.r2), GamepadAction.readScreen);
      expect(repeatsOnHold(GamepadAction.repeatLast), isFalse);
      expect(repeatsOnHold(GamepadAction.readScreen), isFalse,
          reason: 'holding R2 must not read the screen over and over');
    });

    testWidgets('holding R2 reads the screen exactly once', (tester) async {
      await pumpHost(tester, overrides: [
        gamepadSettingsProvider.overrideWith(_RepeatOnNotifier.new),
      ]);
      publishQuiz();
      await tester.pump();
      tts.clear();

      pad.down(GamepadButton.r2);
      await tester.pump(const Duration(seconds: 2));
      pad.up(GamepadButton.r2);
      await tester.pump();
      expect(tts.spoken.length, 1);
    });
  });

  group('adjusting a value', () {
    testWidgets('R1 on a slider starts adjusting instead of pressing it',
        (tester) async {
      double value = 0.5;
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
                    label: 'Speech Speed. ${(value * 10).round()}',
                    child: Slider(
                      focusNode: node,
                      value: value,
                      divisions: 10,
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
      gamepadSections.publish(
        labels: const ['Home', 'Cards', 'Games'],
        currentIndex: 0,
        onSelect: (_) {},
      );
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.r1);
      await tester.pump();
      await tester.pump();
      expect(tts.said('Adjusting'), isTrue);
      expect(tts.said('Left and right to change'), isTrue,
          reason: 'a mode that changes what the buttons mean must say so');

      // Now left/right nudge the value rather than offering a section.
      final before = value;
      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      await tester.pump();
      expect(value, greaterThan(before), reason: 'right turns it up');

      // Pumped between presses: a Slider recomputes from its current value, so
      // two key events inside one frame both act on the pre-rebuild value.
      // Real presses are frames apart.
      pad.press(GamepadButton.dpadLeft);
      await tester.pump();
      await tester.pump();
      pad.press(GamepadButton.dpadLeft);
      await tester.pump();
      await tester.pump();
      expect(value, lessThan(before), reason: 'left turns it down');

      tts.clear();
      pad.press(GamepadButton.r1);
      await tester.pump();
      expect(tts.said('Done'), isTrue);

      // And left/right are section controls again.
      tts.clear();
      pad.press(GamepadButton.dpadRight);
      await tester.pump();
      expect(tts.said('Do you want to go to'), isTrue);
    });

    testWidgets('at the end of a slider it says so, once labels are honest',
        (tester) async {
      // Only truthful because every reachable slider now changes its spoken
      // label on every step: an unchanged label really does mean the end.
      double value = 1.0; // already at the maximum
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
                    label: 'Speech Speed. ${(value * 10).round()} of 10',
                    child: Slider(
                      focusNode: node,
                      value: value,
                      divisions: 10,
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
      gamepadSections.publish(
        labels: const ['Home', 'Cards'],
        currentIndex: 0,
        onSelect: (_) {},
      );
      pad.connect();
      await tester.pump();
      node.requestFocus();
      await tester.pump();

      pad.press(GamepadButton.r1); // enter adjust
      await tester.pump();
      await tester.pump();
      tts.clear();

      pad.press(GamepadButton.dpadRight); // already at the top
      await tester.pump();
      await tester.pump();
      expect(tts.said('as far as it goes'), isTrue,
          reason: 'two identical readings would sound like a dead button');
    });

    test('left and right change meaning only while adjusting', () {
      expect(resolveGamepadAction(GamepadButton.dpadLeft, adjusting: true),
          GamepadAction.decrease);
      expect(resolveGamepadAction(GamepadButton.dpadRight, adjusting: true),
          GamepadAction.increase);
      expect(resolveGamepadAction(GamepadButton.r1, adjusting: true),
          GamepadAction.finishAdjust);
      expect(resolveGamepadAction(GamepadButton.l1, adjusting: true),
          GamepadAction.finishAdjust);
      // Everything else keeps its everyday meaning, so the learner can always
      // walk away from a slider.
      expect(resolveGamepadAction(GamepadButton.dpadDown, adjusting: true),
          GamepadAction.nextItem);
      expect(resolveGamepadAction(GamepadButton.select, adjusting: true),
          GamepadAction.buttonGuide);
      // …and nothing changes when not adjusting.
      expect(resolveGamepadAction(GamepadButton.dpadLeft),
          GamepadAction.previousSection);
    });

    test('nudging repeats on hold, but finishing never does', () {
      // Dragging a slider end to end one press at a time would be absurd, and
      // every step is undone by nudging back.
      expect(repeatsOnHold(GamepadAction.decrease), isTrue);
      expect(repeatsOnHold(GamepadAction.increase), isTrue);
      expect(repeatsOnHold(GamepadAction.finishAdjust), isFalse);
    });

    test('every action still has a spoken name', () {
      const en = GamepadPhrases('en');
      for (final action in GamepadAction.values) {
        expect(en.actionName(action), isNotEmpty, reason: action.name);
      }
    });
  });

  group('pressing a control that changes its own label', () {
    testWidgets('a switch says its new state after R1', (tester) async {
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

      pad.press(GamepadButton.r1);
      await tester.pump();
      await tester.pump();

      expect(value, isFalse, reason: 'R1 presses the switch');
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

      pad.press(GamepadButton.r1);
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

      pad.press(GamepadButton.r1);
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
      await pumpHost(tester);
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
      await pumpHost(tester, overrides: [
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
      await pumpHost(tester, overrides: [
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
      await pumpHost(tester, overrides: [
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
      await pumpHost(tester);
      publishQuiz();
      await tester.pump();
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.dpadDown);
      await tester.pump();
      pad.press(GamepadButton.r1);
      await tester.pump();

      expect(chosen, isEmpty,
          reason: 'pressing R1 to learn what R1 does must not open anything');
      expect(tts.spoken, isEmpty,
          reason: 'the practice screen does the talking, not the host');
    });

    testWidgets('one L1 does not leave, so L1 itself can be explored',
        (tester) async {
      // Ejecting on the first press would make the one control a learner most
      // needs to understand the one they cannot safely try.
      await pumpHost(tester);
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.l1);
      await tester.pump();
      expect(tts.spoken, isEmpty,
          reason: 'the host stays quiet; the practice screen names the press');
    });

    testWidgets('a second L1 does leave, so the mode is never a trap',
        (tester) async {
      await pumpHost(tester);
      gamepadPractice.value = true;
      tts.clear();

      pad.press(GamepadButton.l1);
      await tester.pump();
      pad.press(GamepadButton.l1);
      await tester.pump();
      expect(tts.spoken, isNotEmpty,
          reason: 'the exit must not depend on the practice screen behaving');
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
      expect(said, contains('L1'));
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
