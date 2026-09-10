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

    test('D-pad left/right walk sections, up/down walk items', () {
      expect(resolveGamepadAction(GamepadButton.dpadLeft),
          GamepadAction.previousSection);
      expect(resolveGamepadAction(GamepadButton.dpadRight),
          GamepadAction.nextSection);
      expect(resolveGamepadAction(GamepadButton.dpadUp),
          GamepadAction.previousItem);
      expect(resolveGamepadAction(GamepadButton.dpadDown),
          GamepadAction.nextItem);
    });

    test('face buttons mirror the D-pad diamond: X left, B right, Y up, A down',
        () {
      expect(resolveGamepadAction(GamepadButton.x),
          resolveGamepadAction(GamepadButton.dpadLeft));
      expect(resolveGamepadAction(GamepadButton.b),
          resolveGamepadAction(GamepadButton.dpadRight));
      expect(resolveGamepadAction(GamepadButton.y),
          resolveGamepadAction(GamepadButton.dpadUp));
      expect(resolveGamepadAction(GamepadButton.a),
          resolveGamepadAction(GamepadButton.dpadDown));
    });

    test('the left stick mirrors the D-pad exactly', () {
      expect(resolveGamepadAction(GamepadButton.leftStickLeft),
          resolveGamepadAction(GamepadButton.dpadLeft));
      expect(resolveGamepadAction(GamepadButton.leftStickRight),
          resolveGamepadAction(GamepadButton.dpadRight));
      expect(resolveGamepadAction(GamepadButton.leftStickUp),
          resolveGamepadAction(GamepadButton.dpadUp));
      expect(resolveGamepadAction(GamepadButton.leftStickDown),
          resolveGamepadAction(GamepadButton.dpadDown));
    });

    test('A and B become yes/no only while a question is open', () {
      expect(resolveGamepadAction(GamepadButton.a, awaitingAnswer: true),
          GamepadAction.answerYes);
      expect(resolveGamepadAction(GamepadButton.b, awaitingAnswer: true),
          GamepadAction.answerNo);
      // …and nothing else changes meaning under a question, so the learner can
      // still move or leave without answering.
      expect(resolveGamepadAction(GamepadButton.dpadUp, awaitingAnswer: true),
          GamepadAction.previousItem);
      expect(resolveGamepadAction(GamepadButton.r1, awaitingAnswer: true),
          GamepadAction.activate);
      expect(resolveGamepadAction(GamepadButton.l1, awaitingAnswer: true),
          GamepadAction.back);
    });

    test('shoulders open and leave; triggers and centre buttons speak', () {
      expect(resolveGamepadAction(GamepadButton.r1), GamepadAction.activate);
      expect(resolveGamepadAction(GamepadButton.l1), GamepadAction.back);
      expect(resolveGamepadAction(GamepadButton.r2), GamepadAction.readScreen);
      expect(resolveGamepadAction(GamepadButton.l2), GamepadAction.repeatLast);
      expect(resolveGamepadAction(GamepadButton.start), GamepadAction.whereAmI);
      expect(
          resolveGamepadAction(GamepadButton.select), GamepadAction.buttonGuide);
    });

    test('stick clicks: left goes home, right silences speech', () {
      expect(resolveGamepadAction(GamepadButton.leftStickClick),
          GamepadAction.goHome);
      expect(resolveGamepadAction(GamepadButton.rightStickClick),
          GamepadAction.stopSpeech);
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
      // The reason item movement is linear rather than 2-D: a learner who
      // cannot see a 2-column grid would never reach column 2 with up/down.
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
      expect(en.screenContents('Home', const []), contains('L1'));
      expect(en.nothingHere, contains('L1'));
    });

    test('the spoken guide covers every control group', () {
      final guide = en.buttonGuide;
      for (final needle in [
        'D-pad',
        'X',
        'B',
        'Y',
        'A',
        'R1',
        'L1',
        'R2',
        'L2',
        'Start',
        'Select',
        'Left joystick',
        'Right joystick',
      ]) {
        expect(guide, contains(needle), reason: '$needle missing from the guide');
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
    test('documents every control group the resolver acts on', () {
      final text = [
        for (final group in kGamepadGuide)
          for (final entry in group.entries) '${entry.control} ${entry.meaning}',
      ].join(' | ');

      for (final needle in [
        'D-pad ◀ / ▶',
        'D-pad ▲ / ▼',
        'Left joystick',
        'X (left)',
        'B (right)',
        'Y (up)',
        'A (down)',
        'R1',
        'L1',
        'R2',
        'L2',
        'Start',
        'Select',
        'Right joystick click',
        'Left joystick click',
      ]) {
        expect(text, contains(needle), reason: '$needle undocumented');
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
    });

    test('round-trips through Hive', () {
      const s = GamepadSettings(
        enabled: false,
        speak: false,
        dedupeMs: 300,
        swapConfirmButtons: true,
      );
      final back = GamepadSettings.fromMap(s.toMap());
      expect(back.enabled, isFalse);
      expect(back.speak, isFalse);
      expect(back.dedupeMs, 300);
      expect(back.swapConfirmButtons, isTrue);
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
