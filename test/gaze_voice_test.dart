import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/voice_commands.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';

void _noop() {}

GazeAction _a(GazeZone zone, String label, {bool enabled = true}) => GazeAction(
      zone: zone,
      label: label,
      icon: Icons.abc_rounded,
      color: Colors.teal,
      enabled: enabled,
      onSelect: _noop,
    );

void main() {
  // A typical flashcard-viewer action set.
  final actions = [
    _a(GazeZone.left, 'Prev'),
    _a(GazeZone.right, 'Next'),
    _a(GazeZone.up, 'Hear'),
    _a(GazeZone.down, 'Flip'),
  ];

  VoiceCommandResult r(String s) => resolveVoiceCommand(s, actions);

  group('resolveVoiceCommand', () {
    test('empty / gibberish → none', () {
      expect(r('').intent, VoiceIntent.none);
      expect(r('banana split').intent, VoiceIntent.none);
    });

    test('directional words map to the action on that edge', () {
      expect(r('next'), _action(1)); // right
      expect(r('previous'), _action(0)); // left
      expect(r('back'), _action(0)); // "back" = previous item
      expect(r('up'), _action(2));
      expect(r('down'), _action(3));
    });

    test('label words match their action', () {
      expect(r('flip'), _action(3));
      expect(r('hear').intent, VoiceIntent.action); // up / Hear
      expect(r('flip the card'), _action(3)); // substring
    });

    test('fuzzy match tolerates small mis-hearings', () {
      // "flop" → "flip" (edit distance 1, label length ≥ 4).
      expect(r('flop'), _action(3));
    });

    test('scroll commands beat the bare directional word', () {
      expect(r('scroll down').intent, VoiceIntent.scrollDown);
      expect(r('scroll up').intent, VoiceIntent.scrollUp);
    });

    test('leaving the screen is distinct from "back" (previous)', () {
      expect(r('go back').intent, VoiceIntent.goBack);
      expect(r('exit').intent, VoiceIntent.goBack);
      expect(r('close').intent, VoiceIntent.goBack);
      // plain "back" is still previous-item, not navigation.
      expect(r('back'), _action(0));
    });

    test('a disabled action is not selectable by voice', () {
      final disabled = [
        _a(GazeZone.left, 'Prev', enabled: false),
        _a(GazeZone.right, 'Next'),
      ];
      expect(resolveVoiceCommand('previous', disabled).intent, VoiceIntent.none);
      expect(resolveVoiceCommand('next', disabled).intent, VoiceIntent.action);
    });

    test('Filipino directional words work', () {
      expect(r('susunod'), _action(1)); // next
      expect(r('kaliwa'), _action(0)); // left
    });

    test('select words fire the blink action', () {
      expect(r('select').intent, VoiceIntent.select);
      expect(r('piliin').intent, VoiceIntent.select);
      // …but a label always wins over a bare select word ("choose" could be
      // a label on a picker screen).
      final chooser = [_a(GazeZone.up, 'Choose')];
      expect(resolveVoiceCommand('choose', chooser).intent, VoiceIntent.action);
    });

    test('whole-word matching: "groups" is not "up"', () {
      expect(r('groups').intent, VoiceIntent.none);
      expect(r('countdown').intent, VoiceIntent.none);
    });
  });

  // The flashcard viewer's bottom bar drives a labelled D-pad (no edge zones),
  // so it resolves voice by label via `resolveDpadVoiceCommand`.
  group('resolveDpadVoiceCommand', () {
    GazeDpadCell cell(String label, {bool enabled = true}) =>
        GazeDpadCell(label: label, enabled: enabled, onActivate: () {});

    // A typical viewer row: Previous (disabled on the first card), FSL, Flip, Next.
    List<List<GazeDpadCell>> rows() => [
          [
            cell('Previous', enabled: false),
            cell('FSL'),
            cell('Flip'),
            cell('Next'),
          ],
        ];

    DpadVoiceResult d(String s, [List<List<GazeDpadCell>>? r]) =>
        resolveDpadVoiceCommand(s, r ?? rows());

    test('empty / gibberish → none', () {
      expect(d('').intent, DpadVoiceIntent.none);
      expect(d('banana split').intent, DpadVoiceIntent.none);
    });

    test('label words activate their cell', () {
      expect(d('next'), _cell(0, 3));
      expect(d('flip'), _cell(0, 2));
      expect(d('fsl'), _cell(0, 1));
      expect(d('flip the card'), _cell(0, 2)); // substring
    });

    test('directional synonyms open the matching labelled button', () {
      // "back"/"previous" must reach a *Previous* button even though
      // "back" isn't its literal label — but only when it's enabled.
      final enabledPrev = [
        [cell('Previous'), cell('Next')],
      ];
      expect(d('back', enabledPrev), _cell(0, 0));
      expect(d('previous', enabledPrev), _cell(0, 0));
      expect(d('susunod', enabledPrev), _cell(0, 1)); // next
    });

    test('directional words move the D-pad cursor, like the head gestures', () {
      expect(d('left').intent, DpadVoiceIntent.moveLeft);
      expect(d('right').intent, DpadVoiceIntent.moveRight);
      expect(d('up').intent, DpadVoiceIntent.moveUp);
      expect(d('down').intent, DpadVoiceIntent.moveDown);
      // Natural carrier phrases work too.
      expect(d('move left').intent, DpadVoiceIntent.moveLeft);
      expect(d('go up').intent, DpadVoiceIntent.moveUp);
      // Filipino equivalents.
      expect(d('kaliwa').intent, DpadVoiceIntent.moveLeft);
      expect(d('kanan').intent, DpadVoiceIntent.moveRight);
      expect(d('taas').intent, DpadVoiceIntent.moveUp);
      expect(d('baba').intent, DpadVoiceIntent.moveDown);
    });

    test('tolerates what recognisers actually emit for a spoken command', () {
      // Punctuation / casing (resolver lowercases; "Left." arrives as such).
      expect(d('left.').intent, DpadVoiceIntent.moveLeft);
      // Filipino words split into two ("kali wa") or misheard as an English
      // homophone ("cannon" for kanan, "write" for right).
      expect(d('kali wa').intent, DpadVoiceIntent.moveLeft);
      expect(d('pa baba').intent, DpadVoiceIntent.moveDown);
      expect(d('cannon').intent, DpadVoiceIntent.moveRight);
      expect(d('write').intent, DpadVoiceIntent.moveRight);
      // Same-length near-misses one edit away.
      expect(d('lift').intent, DpadVoiceIntent.moveLeft);
      expect(d('dawn').intent, DpadVoiceIntent.moveDown);
      // …but different-length lookalikes never pass ("black" is not "back").
      expect(d('black').intent, DpadVoiceIntent.none);
    });

    test('an accumulated transcript fires the most recent directional', () {
      // One recogniser session can deliver several commands in one final —
      // the newest spoken word must win, not the first in list order.
      expect(d('left right').intent, DpadVoiceIntent.moveRight);
      expect(d('right left').intent, DpadVoiceIntent.moveLeft);
      expect(d('up up').intent, DpadVoiceIntent.moveUp);
    });

    test('"next"/"back" fall back to a cursor move on grids without such a '
        'button (hub tiles)', () {
      final hub = [
        [cell('Flashcards'), cell('Games')],
        [cell('Stories'), cell('Progress')],
      ];
      expect(d('next', hub).intent, DpadVoiceIntent.moveRight);
      expect(d('back', hub).intent, DpadVoiceIntent.moveLeft);
      expect(d('forward', hub).intent, DpadVoiceIntent.moveRight);
    });

    test('select words commit the focused cell', () {
      expect(d('select').intent, DpadVoiceIntent.select);
      expect(d('open').intent, DpadVoiceIntent.select);
      expect(d('piliin').intent, DpadVoiceIntent.select);
      expect(d('this one').intent, DpadVoiceIntent.select);
      // …while "open <label>" still opens that label directly.
      final hub = [
        [cell('Flashcards'), cell('Games')],
      ];
      expect(d('open games', hub), _cell(0, 1));
    });

    test('whole-word matching keeps labels containing directional words safe',
        () {
      final hub = [
        [cell('Groups'), cell('Countdown')],
      ];
      // Saying the label opens the label — never a cursor move.
      expect(d('groups', hub), _cell(0, 0));
      expect(d('countdown', hub), _cell(0, 1));
    });

    test('a story title containing "back" is not a Previous button', () {
      final stories = [
        [cell('The Way Back Home'), cell('Big Day')],
      ];
      // Bare "back" moves the cursor; the full title opens the story.
      expect(d('back', stories).intent, DpadVoiceIntent.moveLeft);
      expect(d('the way back home', stories), _cell(0, 0));
    });

    test('fuzzy match tolerates small mis-hearings', () {
      expect(d('flop'), _cell(0, 2)); // "flip", edit distance 1
    });

    test('scroll commands resolve to scroll intents', () {
      expect(d('scroll down').intent, DpadVoiceIntent.scrollDown);
      expect(d('scroll up').intent, DpadVoiceIntent.scrollUp);
      expect(d('scroll').intent, DpadVoiceIntent.scrollDown); // sensible default
      expect(d('i-scroll pababa').intent, DpadVoiceIntent.scrollDown);
      expect(d('i-scroll pataas').intent, DpadVoiceIntent.scrollUp);
    });

    test('leaving the screen is distinct from a button', () {
      expect(d('go back').intent, DpadVoiceIntent.goBack);
      expect(d('exit').intent, DpadVoiceIntent.goBack);
      expect(d('close').intent, DpadVoiceIntent.goBack);
    });

    test('a disabled cell is not selectable by voice', () {
      // "back"/"previous" name the disabled Previous → the button doesn't
      // fire; the phrase degrades to a harmless cursor move instead.
      expect(d('back').intent, DpadVoiceIntent.moveLeft);
      expect(d('previous').intent, DpadVoiceIntent.moveLeft);
      // Saying the disabled label directly also never activates it.
      expect(d('previous card').intent, isNot(DpadVoiceIntent.activate));
    });

    test('English words reach Filipino-labelled buttons and vice versa', () {
      // A Filipino-locale viewer bar: Nakaraan / I-flip / Susunod.
      final filRows = [
        [cell('Nakaraan'), cell('I-flip'), cell('Susunod')],
      ];
      expect(d('back', filRows), _cell(0, 0));
      expect(d('next', filRows), _cell(0, 2));
      // "flip" is inside the label "I-flip" (spoken word ≥ 4 chars).
      expect(d('flip', filRows), _cell(0, 1));
      // And the Filipino word still reaches the English "Next".
      expect(d('susunod'), _cell(0, 3));
      // Previous is disabled → degrades to a cursor move, never activates.
      expect(d('nakaraan').intent, DpadVoiceIntent.moveLeft);
    });
  });
}

Matcher _action(int index) => predicate<VoiceCommandResult>(
      (res) => res.intent == VoiceIntent.action && res.actionIndex == index,
      'action #$index',
    );

Matcher _cell(int row, int col) => predicate<DpadVoiceResult>(
      (res) =>
          res.intent == DpadVoiceIntent.activate &&
          res.row == row &&
          res.col == col,
      'activate cell ($row,$col)',
    );
