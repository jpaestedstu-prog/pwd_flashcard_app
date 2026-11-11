import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_actions.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_cursor.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_debouncer.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/gamepad_speech.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/section_confirm.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_guide.dart';

/// Pure-logic contract for Bluetooth gamepad control. Everything here runs
/// without a device, a camera or a controller — the parts that need real
/// hardware are the native bridge and the TTS engine, and both are deliberately
/// thin so that everything worth testing lives on this side of the channel.

void main() {
  group('resolveGamepadAction', () {
    test('every control resolves — no silently dead button', () {
      for (final button in GamepadButton.values) {
        // Must not throw: the switch is exhaustive by construction.
        final action = resolveGamepadAction(button);
        if (button == GamepadButton.mode) {
          expect(action, GamepadAction.none,
              reason: 'the pad\'s own HID-mode button is unmapped on purpose');
        } else {
          expect(action, isNot(GamepadAction.none),
              reason: '${button.name} must do something');
        }
      }
    });

    test('the D-pad only moves — one direction each', () {
      expect(resolveGamepadAction(GamepadButton.dpadUp), GamepadAction.moveUp);
      expect(
          resolveGamepadAction(GamepadButton.dpadDown), GamepadAction.moveDown);
      expect(
          resolveGamepadAction(GamepadButton.dpadLeft), GamepadAction.moveLeft);
      expect(resolveGamepadAction(GamepadButton.dpadRight),
          GamepadAction.moveRight);
    });

    test('every face button has its own job, none of them a direction', () {
      expect(resolveGamepadAction(GamepadButton.a), GamepadAction.activate);
      expect(resolveGamepadAction(GamepadButton.b), GamepadAction.back);
      expect(resolveGamepadAction(GamepadButton.x), GamepadAction.readScreen);
      expect(resolveGamepadAction(GamepadButton.y), GamepadAction.repeatLast);
    });

    test('shoulders switch sections; triggers step one item at a time', () {
      expect(
          resolveGamepadAction(GamepadButton.l1), GamepadAction.previousSection);
      expect(resolveGamepadAction(GamepadButton.r1), GamepadAction.nextSection);
      expect(
          resolveGamepadAction(GamepadButton.l2), GamepadAction.previousItem);
      expect(resolveGamepadAction(GamepadButton.r2), GamepadAction.nextItem);
    });

    test('centre buttons speak', () {
      expect(resolveGamepadAction(GamepadButton.start), GamepadAction.whereAmI);
      expect(
          resolveGamepadAction(GamepadButton.select), GamepadAction.buttonGuide);
    });

    test('the right stick scrolls and jumps to the ends', () {
      expect(resolveGamepadAction(GamepadButton.rightStickUp),
          GamepadAction.scrollUp);
      expect(resolveGamepadAction(GamepadButton.rightStickDown),
          GamepadAction.scrollDown);
      expect(resolveGamepadAction(GamepadButton.rightStickLeft),
          GamepadAction.firstItem);
      expect(resolveGamepadAction(GamepadButton.rightStickRight),
          GamepadAction.lastItem);
    });

    test('stick clicks: left goes home, right silences speech', () {
      expect(resolveGamepadAction(GamepadButton.leftStickClick),
          GamepadAction.goHome);
      expect(resolveGamepadAction(GamepadButton.rightStickClick),
          GamepadAction.stopSpeech);
    });

    test('the left stick moves like the D-pad, and can be turned off', () {
      const pairs = {
        GamepadButton.leftStickUp: GamepadButton.dpadUp,
        GamepadButton.leftStickDown: GamepadButton.dpadDown,
        GamepadButton.leftStickLeft: GamepadButton.dpadLeft,
        GamepadButton.leftStickRight: GamepadButton.dpadRight,
      };
      pairs.forEach((stick, dpad) {
        expect(isLeftStickMove(stick), isTrue);
        expect(isLeftStickMove(dpad), isFalse);
        expect(resolveGamepadAction(stick), resolveGamepadAction(dpad));
        expect(resolveGamepadAction(stick, leftStickMoves: false),
            GamepadAction.none,
            reason: '${stick.name} turned off must do nothing at all');
        // Turning the stick off never changes the D-pad.
        expect(resolveGamepadAction(dpad, leftStickMoves: false),
            resolveGamepadAction(dpad));
      });
    });

    // The redesign's whole point: one control, one job. The face buttons used
    // to double as a second D-pad and the D-pad's left and right switched
    // sections, so the same press meant different things.
    test('no two controls share a job, except the documented left stick', () {
      Map<GamepadAction, Set<GamepadButton>> jobs({
        bool awaitingAnswer = false,
        bool leftStickMoves = true,
      }) {
        final out = <GamepadAction, Set<GamepadButton>>{};
        for (final button in GamepadButton.values) {
          final action = resolveGamepadAction(
            button,
            awaitingAnswer: awaitingAnswer,
            leftStickMoves: leftStickMoves,
          );
          if (action == GamepadAction.none) continue;
          out.putIfAbsent(action, () => {}).add(button);
        }
        return out;
      }

      const moves = {
        GamepadAction.moveUp,
        GamepadAction.moveDown,
        GamepadAction.moveLeft,
        GamepadAction.moveRight,
      };
      for (final awaiting in [false, true]) {
        final withStick = jobs(awaitingAnswer: awaiting);
        withStick.forEach((action, buttons) {
          if (moves.contains(action)) {
            expect(buttons.length, 2, reason: '$action: D-pad + left stick');
            expect(buttons.where(isLeftStickMove).length, 1);
          } else {
            expect(buttons, hasLength(1),
                reason: '$action is reached by $buttons');
          }
        });
        // With the stick off, every single action has exactly one control.
        jobs(awaitingAnswer: awaiting, leftStickMoves: false)
            .forEach((action, buttons) {
          expect(buttons, hasLength(1),
              reason: '$action is reached by $buttons');
        });
      }
      // Yes and no exist only while a question is asked.
      expect(jobs().keys, isNot(contains(GamepadAction.answerYes)));
      expect(jobs().keys, isNot(contains(GamepadAction.answerNo)));
      // And nothing is lost: every real action has a control.
      final reachable = {...jobs().keys, ...jobs(awaitingAnswer: true).keys};
      for (final action in GamepadAction.values) {
        if (action == GamepadAction.none) continue;
        expect(reachable, contains(action), reason: '$action has no control');
      }
    });

    test('A and B answer yes and no only while a question is open', () {
      expect(resolveGamepadAction(GamepadButton.a, awaitingAnswer: true),
          GamepadAction.answerYes);
      expect(resolveGamepadAction(GamepadButton.b, awaitingAnswer: true),
          GamepadAction.answerNo);
      // …and nothing else changes meaning under a question, so the learner can
      // still move, listen or switch without answering.
      for (final button in GamepadButton.values) {
        if (button == GamepadButton.a || button == GamepadButton.b) continue;
        expect(resolveGamepadAction(button, awaitingAnswer: true),
            resolveGamepadAction(button),
            reason: '${button.name} must not change under a question');
      }
    });

    test('the Nintendo swap exchanges A and B and nothing else', () {
      expect(swapConfirmButton(GamepadButton.a), GamepadButton.b);
      expect(swapConfirmButton(GamepadButton.b), GamepadButton.a);
      for (final button in GamepadButton.values) {
        if (button == GamepadButton.a || button == GamepadButton.b) continue;
        expect(swapConfirmButton(button), button);
      }
      // Swapped twice is back where it started.
      for (final button in GamepadButton.values) {
        expect(swapConfirmButton(swapConfirmButton(button)), button);
      }
    });

    test('only movement repeats when held', () {
      const repeating = {
        GamepadAction.moveUp,
        GamepadAction.moveDown,
        GamepadAction.moveLeft,
        GamepadAction.moveRight,
        GamepadAction.previousItem,
        GamepadAction.nextItem,
        GamepadAction.scrollUp,
        GamepadAction.scrollDown,
      };
      for (final action in GamepadAction.values) {
        expect(repeatsOnHold(action), repeating.contains(action),
            reason: '$action');
      }
    });
  });

  group('GamepadDebouncer', () {
    late DateTime clock;
    GamepadDebouncer make({Duration window = const Duration(milliseconds: 140)}) {
      clock = DateTime(2026);
      return GamepadDebouncer(window: window, now: () => clock);
    }

    GamepadEvent down(GamepadButton b) =>
        GamepadEvent(button: b, pressed: true);
    GamepadEvent up(GamepadButton b) => GamepadEvent(button: b, pressed: false);

    test('a press is accepted; its release never produces an action', () {
      final d = make();
      expect(d.accept(down(GamepadButton.dpadRight)), isTrue);
      expect(d.accept(up(GamepadButton.dpadRight)), isFalse);
    });

    test('the X3 double-report is collapsed to one move', () {
      // One physical D-pad press reaches the app twice: once as an ABS_HAT0X
      // axis from the gamepad interface, once as KEY_LEFT from the Consumer
      // Control interface, a few milliseconds apart.
      final d = make();
      expect(d.accept(down(GamepadButton.dpadLeft)), isTrue);
      clock = clock.add(const Duration(milliseconds: 8));
      expect(d.accept(down(GamepadButton.dpadLeft)), isFalse,
          reason: 'the duplicate report must not move the cursor twice');
    });

    test('a held button does not auto-repeat', () {
      final d = make();
      expect(d.accept(down(GamepadButton.dpadDown)), isTrue);
      for (var i = 0; i < 20; i++) {
        clock = clock.add(const Duration(milliseconds: 50));
        expect(d.accept(down(GamepadButton.dpadDown)), isFalse,
            reason: 'holding a button must not stampede through the screen');
      }
    });

    test('a deliberate press-release-press is always honoured', () {
      final d = make();
      expect(d.accept(down(GamepadButton.a)), isTrue);
      d.accept(up(GamepadButton.a));
      // Even well inside the debounce window: the release proved the first
      // press ended, so the second is intent, not bounce.
      clock = clock.add(const Duration(milliseconds: 20));
      expect(d.accept(down(GamepadButton.a)), isTrue);
    });

    test('different controls never block each other', () {
      final d = make();
      expect(d.accept(down(GamepadButton.dpadRight)), isTrue);
      expect(d.accept(down(GamepadButton.a)), isTrue,
          reason: 'answering yes right after moving must work');
    });

    test('a fresh press after the window is accepted', () {
      final d = make();
      expect(d.accept(down(GamepadButton.dpadRight)), isTrue);
      d.accept(up(GamepadButton.dpadRight));
      clock = clock.add(const Duration(milliseconds: 200));
      expect(d.accept(down(GamepadButton.dpadRight)), isTrue);
    });

    test('a lost release does not leave the button dead forever', () {
      // Bluetooth drops packets, and losing a release is what strands a
      // control in the held state. A blind learner gets no cue that a button
      // has stopped working, so the debouncer has to recover on its own.
      final d = make();
      expect(d.accept(down(GamepadButton.r1)), isTrue);
      // …the ACTION_UP never arrives. The learner presses again a moment later.
      clock = clock.add(const Duration(seconds: 8));
      expect(d.accept(down(GamepadButton.r1)), isTrue,
          reason: 'silence proves nothing is held; believe the new press');
    });

    test('a genuinely held button stays suppressed however long it is held', () {
      // The escape hatch above keys off a *gap* in the stream, not elapsed
      // time — so a button that keeps reporting is never mistaken for one
      // whose release went missing.
      final d = make();
      expect(d.accept(down(GamepadButton.dpadDown)), isTrue);
      for (var i = 0; i < 100; i++) {
        clock = clock.add(const Duration(milliseconds: 50));
        expect(d.accept(down(GamepadButton.dpadDown)), isFalse,
            reason: 'held for ${(i + 1) * 50} ms and still must not repeat');
      }
    });

    test('reset clears held state, so a pad that drops mid-press recovers', () {
      final d = make();
      d.accept(down(GamepadButton.r1));
      // Link drops while the button is physically down; no release ever comes.
      d.reset();
      expect(d.accept(down(GamepadButton.r1)), isTrue);
    });
  });

  group('GamepadCursor', () {
    test('walks a ragged grid in reading order', () {
      // Two 2-wide rows then a 3-wide row = 7 cells.
      final c = GamepadCursor(rowLengths: [2, 2, 3]);
      expect(c.length, 7);
      final visited = <String>[];
      for (var i = 0; i < 7; i++) {
        visited.add('${c.row},${c.col}');
        c.next();
      }
      expect(visited, [
        '0,0', '0,1',
        '1,0', '1,1',
        '2,0', '2,1', '2,2',
      ]);
    });

    test('every cell of a multi-column grid is reachable with next alone', () {
      // L2 and R2's one-at-a-time walk: a learner who cannot picture a
      // 2-column grid still reaches every cell with a single "next".
      final c = GamepadCursor(rowLengths: [2, 2, 2]);
      final seen = <String>{};
      for (var i = 0; i < c.length; i++) {
        seen.add('${c.row},${c.col}');
        c.next();
      }
      expect(seen.length, 6);
    });

    test('wraps in both directions', () {
      final c = GamepadCursor(rowLengths: [2, 1]);
      c.previous();
      expect([c.row, c.col], [1, 0], reason: 'back from the first wraps to last');
      c.next();
      expect([c.row, c.col], [0, 0]);
    });

    test('empty grid is inert', () {
      final c = GamepadCursor();
      expect(c.isEmpty, isTrue);
      c.next();
      c.previous();
      expect(c.index, 0);
      expect(c.row, 0);
      expect(c.col, 0);
    });

    test('re-shaping clamps rather than resetting to the top', () {
      final c = GamepadCursor(rowLengths: [3, 3]);
      c.last(); // index 5
      expect(c.index, 5);
      // A banner disappears and the grid shrinks.
      c.setRows([3]);
      expect(c.index, 2, reason: 'clamped to the new end, not thrown to the top');
      // A row is added back; position is kept.
      c.setRows([3, 3]);
      expect(c.index, 2, reason: 'a rebuild must not lose the learner\'s place');
    });

    test('moveTo follows an external focus change', () {
      final c = GamepadCursor(rowLengths: [2, 3]);
      c.moveTo(1, 2);
      expect(c.index, 4);
      // Out-of-range input is clamped, never thrown.
      c.moveTo(9, 9);
      expect(c.row, 1);
      expect(c.col, 2);
    });

    test('rows of zero width are skipped', () {
      final c = GamepadCursor(rowLengths: [0, 2, 0]);
      expect(c.length, 2);
      expect([c.row, c.col], [1, 0]);
      c.next();
      expect([c.row, c.col], [1, 1]);
    });

    test('up and down keep the column; left and right stay in the row', () {
      final c = GamepadCursor(rowLengths: [3, 3, 3]);
      c.moveHorizontal(1);
      expect([c.row, c.col], [0, 1]);
      c.moveVertical(1);
      expect([c.row, c.col], [1, 1], reason: 'straight down, same column');
      c.moveHorizontal(1);
      c.moveHorizontal(1);
      expect([c.row, c.col], [1, 0], reason: 'right wraps within the row');
      c.moveHorizontal(-1);
      expect([c.row, c.col], [1, 2], reason: 'left wraps within the row');
      c.moveVertical(-1);
      c.moveVertical(-1);
      expect([c.row, c.col], [2, 2], reason: 'up from the top wraps');
    });

    test('a short row clamps the column but remembers the one wanted', () {
      // Home's layout: a full row, a single banner, a full row.
      final c = GamepadCursor(rowLengths: [3, 1, 3]);
      c.moveHorizontal(1);
      c.moveHorizontal(1);
      expect([c.row, c.col], [0, 2]);
      c.moveVertical(1);
      expect([c.row, c.col], [1, 0], reason: 'the banner is one wide');
      c.moveVertical(1);
      expect([c.row, c.col], [2, 2],
          reason: 'through the banner and back to the column it came from');
    });

    test('a sideways move or a jump forgets the remembered column', () {
      final c = GamepadCursor(rowLengths: [3, 1, 3]);
      c.moveHorizontal(-1); // (0, 2)
      c.moveVertical(1); // (1, 0), wanting column 2
      c.moveHorizontal(1); // the only cell — now *chosen* as column 0
      c.moveVertical(1);
      expect([c.row, c.col], [2, 0]);

      c.moveHorizontal(-1); // (2, 2)
      c.moveVertical(-1); // (1, 0), wanting 2
      c.next(); // L2/R2 move: back to reading order
      expect([c.row, c.col], [2, 0]);
      c.moveVertical(-1);
      c.moveVertical(-1);
      expect([c.row, c.col], [0, 0], reason: 'column 2 was forgotten');
    });

    test('vertical moves skip rows of zero width', () {
      final c = GamepadCursor(rowLengths: [2, 0, 2]);
      c.moveHorizontal(1);
      c.moveVertical(1);
      expect([c.row, c.col], [2, 1]);
      c.moveVertical(1);
      expect([c.row, c.col], [0, 1], reason: 'wraps, and skips the gap again');
    });

    test('directional moves on an empty grid are inert', () {
      final c = GamepadCursor();
      c.moveVertical(1);
      c.moveHorizontal(-1);
      expect(c.index, 0);
    });
  });

  group('SectionConfirm', () {
    const tabs = ['Home', 'Cards', 'Games', 'Stories', 'Progress'];

    SectionConfirm make({int current = 0}) =>
        SectionConfirm(sections: tabs, current: current);

    test('the flow the feature was asked for: right, then yes', () {
      final c = make();
      expect(c.awaitingAnswer, isFalse);
      expect(c.offerNext(), 1);
      expect(c.pendingLabel, 'Cards');
      expect(c.awaitingAnswer, isTrue,
          reason: 'A and B must become yes/no while the question stands');
      expect(c.accept(), 1);
      expect(c.current, 1);
      expect(c.awaitingAnswer, isFalse);
    });

    test('no keeps walking through the sections', () {
      final c = make();
      c.offerNext();
      expect(c.pendingLabel, 'Cards');
      expect(c.decline(), 2);
      expect(c.pendingLabel, 'Games');
      expect(c.decline(), 3);
      expect(c.pendingLabel, 'Stories');
      // Declining never moves the learner.
      expect(c.current, 0);
    });

    test('offers wrap around the whole tab set', () {
      final c = make(current: 4);
      expect(c.offerNext(), 0, reason: 'past the last tab wraps to the first');
      final b = make();
      expect(b.offerPrevious(), 4);
    });

    test('left and right walk the offer in opposite directions', () {
      final c = make();
      c.offerNext(); // Cards
      c.offerNext(); // Games
      expect(c.pendingLabel, 'Games');
      expect(c.offerPrevious(), 1);
      expect(c.pendingLabel, 'Cards');
    });

    test('accept with nothing pending does nothing', () {
      final c = make();
      expect(c.accept(), isNull);
      expect(c.current, 0);
    });

    test('a touch elsewhere drops a stale question', () {
      final c = make();
      c.offerNext();
      expect(c.awaitingAnswer, isTrue);
      // The learner tapped Games with a finger while the question was open.
      c.sync(sections: tabs, current: 2);
      expect(c.awaitingAnswer, isFalse,
          reason: 'answering yes now would move them a second time, unasked');
      expect(c.current, 2);
    });

    test('a role switch re-shapes the tab set and drops the question', () {
      final c = make();
      c.offerNext();
      c.sync(sections: const ['Home', 'Students', 'Analytics'], current: 0);
      expect(c.awaitingAnswer, isFalse);
      expect(c.sections.length, 3);
    });

    test('a shell with no tabs has nothing to offer', () {
      final c = SectionConfirm(sections: const ['Home']);
      expect(c.offerNext(), isNull);
      expect(c.awaitingAnswer, isFalse);
      final empty = SectionConfirm();
      expect(empty.offerNext(), isNull);
      expect(empty.currentLabel, isNull);
    });

    test('cancel abandons without moving', () {
      final c = make();
      c.offerNext();
      c.cancel();
      expect(c.awaitingAnswer, isFalse);
      expect(c.current, 0);
    });
  });

  group('GamepadPhrases', () {
    const en = GamepadPhrases('en');
    const fil = GamepadPhrases('fil');

    test('the welcome names the section the learner is in', () {
      expect(en.welcome('Home'), contains('Home section'));
      expect(en.welcome('Home'), contains('welcome'));
    });

    test('every question says which buttons answer it', () {
      // A and B change meaning while a question is open, so a prompt that did
      // not say so would leave a blind learner guessing.
      final q = en.sectionQuestion('Cards');
      expect(q, contains('Do you want to go to the Cards section?'));
      expect(q, contains('A'));
      expect(q, contains('B'));
      expect(fil.sectionQuestion('Cards'), contains('A'));
      expect(fil.sectionQuestion('Cards'), contains('B'));
    });

    test('arrival is confirmed in the requested wording', () {
      expect(en.sectionEntered('Cards'), "You're now in the Cards section.");
    });

    test('items are counted, so a list has an audible end', () {
      expect(en.item('Games', 3, 8), 'Games, 3 of 8.');
    });

    test('a long screen is summarised rather than read forever', () {
      final many = [for (var i = 1; i <= 40; i++) 'Item $i'];
      final said = en.screenContents('Home', many);
      expect(said, contains('40 items'));
      expect(said, contains('and 28 more'));
      expect(said, isNot(contains('Item 20')));
    });

    test('a short screen is read in full with no summary', () {
      final said = en.screenContents('Home', const ['A', 'B']);
      expect(said, contains('A, B'));
      expect(said, isNot(contains('more')));
    });

    test('an empty screen still tells the learner how to leave', () {
      expect(en.screenContents('Home', const []), contains('Press B'));
      expect(en.nothingHere, contains('Press B'));
      expect(en.screenReading('Quiz', const [], const []), contains('Press B'));
      expect(fil.nothingHere, contains('ang B'));
    });

    test('the spoken guide gives every control its one job', () {
      for (final phrases in [en, fil]) {
        final guide = phrases.buttonGuide;
        for (final needle in [
          'D-pad:',
          'A:',
          'B:',
          'X:',
          'Y:',
          'L1 ',
          'R1:',
          'L2 ',
          'R2:',
          'Start:',
          'Select:',
          'joystick',
        ]) {
          expect(guide, contains(needle),
              reason: '$needle missing from the ${phrases.locale} guide');
        }
      }
    });

    test('the spoken guide leaves out a left stick that is turned off', () {
      expect(en.buttonGuide, contains('Left joystick: the same as the D-pad.'));
      final off = en.buttonGuideFor(leftStickMoves: false);
      expect(off, isNot(contains('Left joystick: the same')));
      // Its click still goes Home — only the stick's movement is turned off.
      expect(off, contains('Click the left joystick to go straight Home.'));
      expect(fil.buttonGuideFor(leftStickMoves: false),
          isNot(contains('Kaliwang joystick: tulad ng D-pad.')));
    });

    test('nothing spoken still describes the old mapping', () {
      final said = <String>[
        for (final p in [en, fil]) ...[
          p.buttonGuide,
          p.buttonGuideFor(leftStickMoves: false),
          p.traversalMode,
          p.nothingHere,
          p.practiceIntro,
          p.welcome('Home'),
          p.sectionQuestion('Cards'),
          p.screenReading('Quiz', const [], const []),
          for (final action in GamepadAction.values) p.actionName(action),
        ],
      ];
      for (final line in said) {
        for (final stale in [
          'R1 to',
          'L1 to',
          'Press L1',
          'R1 para',
          'L1 para',
          'ang L1',
          'X is left',
          'A is down',
          'open the item you are on',
          'R2: read',
          'L2: repeat',
        ]) {
          expect(line, isNot(contains(stale)), reason: '"$stale" in: $line');
        }
      }
    });

    test('a switch is named with its state, unless the label says it', () {
      expect(en.withState('Left joystick moves too', true),
          'Left joystick moves too, on');
      expect(en.withState('Vibrate.', false), 'Vibrate, off');
      expect(en.withState('Sound Effects. On. Game sounds', false),
          'Sound Effects. On. Game sounds',
          reason: 'the Settings rows carry their state already');
      expect(en.withState('Turn on the camera', false),
          'Turn on the camera, off',
          reason: 'a word in a sentence is not a state');
      expect(fil.withState('Mag-vibrate', true), 'Mag-vibrate, naka-on');
      expect(fil.withState('Tunog. Naka-off. Mga tunog', true),
          'Tunog. Naka-off. Mga tunog');
    });

    test('a reading of an ordinary screen counts and lists its controls',
        () {
      expect(en.screenItems(const ['Back', 'Save']), '2 items here: Back, Save.');
      expect(en.screenItems(const ['Back']), '1 item here: Back.');
      final many = [for (var i = 1; i <= 20; i++) 'Row $i'];
      expect(en.screenItems(many), contains('and 8 more'));
      expect(fil.screenItems(const ['Back', 'Save']),
          'May 2 item dito: Back, Save.');
      expect(fil.leftTextBox, isNot(en.leftTextBox));
    });

    test('a move with nothing that way says where the learner still is', () {
      expect(en.stillOn('Games'), 'Nothing more that way. Still on Games.');
      expect(fil.stillOn('Games'), contains('Games'));
      expect(fil.stillOn('Games'), isNot(en.stillOn('Games')));
    });

    test('A on a slider says how to turn it, without a doubled full stop', () {
      expect(en.sliderHint('Speech speed. Normal'),
          'Speech speed. Normal. Use left and right to change it.');
      expect(en.sliderHint('Volume.'),
          'Volume. Use left and right to change it.');
      expect(fil.sliderHint('Bilis'), contains('kaliwa at kanan'));
    });

    test('the move actions are named for the practice screen', () {
      for (final action in [
        GamepadAction.moveUp,
        GamepadAction.moveDown,
        GamepadAction.moveLeft,
        GamepadAction.moveRight,
      ]) {
        expect(en.actionName(action), startsWith('Move '));
        expect(fil.actionName(action), startsWith('Gumalaw '));
      }
    });

    test('Filipino is a real translation, not a fallback to English', () {
      expect(fil.welcome('Home'), isNot(en.welcome('Home')));
      expect(fil.sectionEntered('Cards'), contains('Nasa'));
      expect(fil.item('Games', 3, 8), 'Games, 3 ng 8.');
    });

    test('an unknown locale falls back to English', () {
      expect(const GamepadPhrases('de').welcome('Home'), en.welcome('Home'));
    });
  });

  group('written button guide', () {
    /// Every control the app acts on has to appear in the printed guide too —
    /// a control that works but is documented nowhere is, for a learner who
    /// cannot see the screen, a control that does not exist.
    /// The guide entry that documents each physical control.
    String controlFor(GamepadButton button) => switch (button) {
      GamepadButton.dpadUp ||
      GamepadButton.dpadDown ||
      GamepadButton.dpadLeft ||
      GamepadButton.dpadRight => 'D-pad ▲ ▼ ◀ ▶',
      GamepadButton.leftStickUp ||
      GamepadButton.leftStickDown ||
      GamepadButton.leftStickLeft ||
      GamepadButton.leftStickRight => 'Left joystick',
      GamepadButton.a => 'A',
      GamepadButton.b => 'B',
      GamepadButton.x => 'X',
      GamepadButton.y => 'Y',
      GamepadButton.l1 || GamepadButton.r1 => 'L1 / R1',
      GamepadButton.l2 || GamepadButton.r2 => 'L2 / R2',
      GamepadButton.start => 'Start',
      GamepadButton.select => 'Select',
      GamepadButton.rightStickUp ||
      GamepadButton.rightStickDown => 'Right joystick ▲ / ▼',
      GamepadButton.rightStickLeft ||
      GamepadButton.rightStickRight => 'Right joystick ◀ / ▶',
      GamepadButton.leftStickClick => 'Left joystick click',
      GamepadButton.rightStickClick => 'Right joystick click',
      GamepadButton.mode => '',
    };

    test('documents every control the resolver acts on, once', () {
      final controls = [
        for (final group in kGamepadGuide)
          for (final entry in group.entries) entry.control,
      ];
      for (final button in GamepadButton.values) {
        if (resolveGamepadAction(button) == GamepadAction.none) continue;
        expect(controls.where((c) => c == controlFor(button)), hasLength(1),
            reason: '${button.name} must have exactly one guide entry');
      }
    });

    test('the Filipino guide is the same page in the same order', () {
      expect(kGamepadGuideFilipino.length, kGamepadGuide.length);
      for (var g = 0; g < kGamepadGuide.length; g++) {
        final en = kGamepadGuide[g].entries;
        final fil = kGamepadGuideFilipino[g].entries;
        expect(fil.length, en.length, reason: 'group $g');
        for (var i = 0; i < en.length; i++) {
          expect(fil[i].meaning, isNot(en[i].meaning),
              reason: '${en[i].control} is not translated');
          // Button names are printed on the pad, so they stay as they are.
          if (!en[i].control.contains('joystick') &&
              !en[i].control.contains(' and ')) {
            expect(fil[i].control, en[i].control);
          }
        }
      }
    });

    test('explains that A and B change meaning under a question', () {
      final text = [
        for (final group in kGamepadGuide)
          for (final entry in group.entries) entry.meaning,
      ].join(' ');
      expect(text.toLowerCase(), contains('yes'));
      expect(text.toLowerCase(), contains('no'));
    });
  });

  group('GamepadSettings', () {
    test('defaults suit a blind learner out of the box', () {
      const s = GamepadSettings();
      expect(s.enabled, isTrue,
          reason: 'a learner should not have to find a toggle they cannot see');
      expect(s.speak, isTrue);
      expect(s.confirmSectionChange, isTrue);
      expect(s.announceItems, isTrue);
      expect(s.leftStickMoves, isTrue,
          reason: 'the stick moves until someone turns it off');
    });

    test('round-trips through Hive', () {
      const s = GamepadSettings(
        enabled: false,
        speak: false,
        dedupeMs: 300,
        swapConfirmButtons: true,
        leftStickMoves: false,
      );
      final back = GamepadSettings.fromMap(s.toMap());
      expect(back.enabled, isFalse);
      expect(back.speak, isFalse);
      expect(back.dedupeMs, 300);
      expect(back.swapConfirmButtons, isTrue);
      expect(back.leftStickMoves, isFalse);
    });

    test('settings saved by 1.4.3 keep the stick moving', () {
      // 1.4.3 never wrote the key: a learner updating must not find their
      // stick dead.
      final old = const GamepadSettings(swapConfirmButtons: true).toMap()
        ..remove('leftStickMoves');
      final back = GamepadSettings.fromMap(old);
      expect(back.leftStickMoves, isTrue);
      expect(back.swapConfirmButtons, isTrue);
      expect(GamepadSettings.fromMap({'leftStickMoves': 'nonsense'})
          .leftStickMoves, isTrue);
    });

    test('copyWith changes only the stick', () {
      const s = GamepadSettings(swapConfirmButtons: true, dedupeMs: 200);
      final off = s.copyWith(leftStickMoves: false);
      expect(off.leftStickMoves, isFalse);
      expect(off.swapConfirmButtons, isTrue);
      expect(off.dedupeMs, 200);
      expect(off.copyWith().leftStickMoves, isFalse);
    });

    test('an older or corrupt blob falls back to defaults, never crashes', () {
      expect(GamepadSettings.fromMap(null).enabled, isTrue);
      expect(GamepadSettings.fromMap({'dedupeMs': 'nonsense'}).dedupeMs, 140);
      expect(GamepadSettings.fromMap({'enabled': 'yes'}).enabled, isTrue);
    });

    test('the dedupe window is clamped to a sane range', () {
      expect(GamepadSettings.fromMap({'dedupeMs': 10}).dedupeMs,
          GamepadSettings.minDedupeMs);
      expect(GamepadSettings.fromMap({'dedupeMs': 99999}).dedupeMs,
          GamepadSettings.maxDedupeMs);
    });
  });

  group('GamepadButton wire format', () {
    test('every enum value round-trips through the native name', () {
      for (final b in GamepadButton.values) {
        expect(GamepadButton.fromWire(b.name), b);
      }
    });

    test('an unknown control from a newer bridge is ignored, not fatal', () {
      expect(GamepadButton.fromWire('paddle4'), isNull);
    });
  });
}
