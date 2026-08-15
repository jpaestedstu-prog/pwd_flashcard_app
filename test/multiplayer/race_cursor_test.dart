import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/race_presentation.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/memory_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/quiz_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/race_cursor.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/scramble_race_player.dart';

/// The hands-free seam. `GameCatalog._motor` offers a Motor Impairment learner
/// Play Together by name, so the race behind it has to be playable without a
/// tap — and because only one gaze camera may run app-wide, the cursor has to
/// be steerable from the screen while the targets live in the player widget.

const _questions = [
  MpQuestion(
    prompt: 'dog',
    promptLabel: 'What is this in Filipino?',
    options: ['aso', 'pusa', 'ibon', 'isda'],
    correctIndex: 0,
  ),
  MpQuestion(
    prompt: 'cat',
    promptLabel: 'What is this in Filipino?',
    options: ['aso', 'pusa', 'ibon', 'isda'],
    correctIndex: 1,
  ),
];

final _motor = RacePresentation.forProfile(
  DisabilityType.motor,
  const AppSettings(),
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RaceCursor on its own', () {
    test('does nothing until a player attaches targets', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      expect(c.canMove, isFalse);
      expect(c.canChoose, isFalse);
      c.move(1);
      expect(c.index, 0);
    });

    test('wraps around the ends', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      c.attach(count: 3, enabled: true, onChoose: () {});
      c.move(-1);
      expect(c.index, 2, reason: 'left from the first lands on the last');
      c.move(1);
      expect(c.index, 0);
    });

    test('skips targets the player marked unreachable', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      // Only 0 and 3 are live (e.g. two face-down cards left on the board).
      c.attach(
        count: 4,
        enabled: true,
        onChoose: () {},
        isEnabledAt: (i) => i == 0 || i == 3,
      );
      c.move(1);
      expect(c.index, 3, reason: 'hops straight over the cleared pair');
      c.move(1);
      expect(c.index, 0);
    });

    test('will not move when every target but one is unreachable', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      c.attach(
        count: 4,
        enabled: true,
        onChoose: () {},
        isEnabledAt: (i) => i == 2,
      );
      expect(c.canMove, isFalse, reason: 'nowhere else to go');
      expect(c.canChoose, isTrue);
      expect(c.index, 2, reason: 'parked on the only live target');
    });

    test('a shrinking target list never leaves the cursor out of bounds', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      c.attach(count: 4, enabled: true, onChoose: () {});
      c.move(1);
      c.move(1);
      expect(c.index, 2);
      c.attach(count: 1, enabled: true, onChoose: () {});
      expect(c.index, 0);
    });

    test('choose runs the player callback, and only when it can', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      var chosen = 0;
      c.attach(count: 2, enabled: false, onChoose: () => chosen++);
      c.choose();
      expect(chosen, 0, reason: 'a paused player is not choosable');
      c.attach(count: 2, enabled: true, onChoose: () => chosen++);
      c.choose();
      expect(chosen, 1);
    });

    test('detach stops a stale choose reaching a disposed widget', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      var chosen = 0;
      c.attach(count: 2, enabled: true, onChoose: () => chosen++);
      c.detach();
      c.choose();
      expect(chosen, 0);
    });

    test('the highlight only shows when the screen turns it on', () {
      final c = RaceCursor();
      addTearDown(c.dispose);
      c.attach(count: 2, enabled: true, onChoose: () {});
      expect(c.isFocused(0), isFalse, reason: 'touch-only learners see no ring');
      c.highlight = true;
      expect(c.isFocused(0), isTrue);
    });
  });

  group('the quiz player publishes its targets', () {
    testWidgets('the options before answering, the advance after',
        (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _motor,
        cursor: cursor,
        onFinished: (_) {},
      )));

      expect(cursor.count, 4, reason: 'four options to aim at');
      expect(cursor.canChoose, isTrue);

      // Choose the second option hands-free.
      cursor.move(1);
      cursor.choose();
      await tester.pump();

      expect(cursor.count, 1, reason: 'only the Next button is left');
      cursor.choose();
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);
      expect(cursor.index, 0, reason: 'a fresh round starts at the first option');
    });

    testWidgets('a hands-free choice scores like a tap', (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      var finished = -1;
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _motor,
        cursor: cursor,
        onFinished: (s) => finished = s,
      )));

      // Q1's correct answer is index 0; Q2's is index 1.
      cursor.choose();
      await tester.pump();
      cursor.choose(); // Next
      await tester.pump();
      cursor.move(1);
      cursor.choose();
      await tester.pump();
      cursor.choose(); // Finish
      await tester.pump();
      expect(finished, 2, reason: 'both correct, chosen without a tap');
    });

    testWidgets('a timed race leaves nothing to aim at after answering',
        (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        cursor: cursor,
        onFinished: (_) {},
      )));
      cursor.choose();
      await tester.pump();
      expect(cursor.count, 0, reason: 'the timer advances it, not the learner');
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('a paused player cannot be steered', (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _motor,
        isPaused: true,
        cursor: cursor,
        onFinished: (_) {},
      )));
      expect(cursor.canChoose, isFalse);
      expect(cursor.canMove, isFalse);
    });
  });

  group('the memory board publishes its targets', () {
    const layout = [
      MemoryCardSpec(cardId: 'a', emoji: '🐶', label: 'dog'),
      MemoryCardSpec(cardId: 'b', emoji: '🐱', label: 'cat'),
      MemoryCardSpec(cardId: 'a', emoji: '🐶', label: 'dog'),
      MemoryCardSpec(cardId: 'b', emoji: '🐱', label: 'cat'),
    ];

    testWidgets('every card, with cleared pairs skipped', (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(MemoryRacePlayer(
        layout: layout,
        presentation: _motor,
        cursor: cursor,
        onFinished: (_) {},
      )));
      expect(cursor.count, 4);

      // Turn the matching pair (indices 0 and 2) hands-free.
      cursor.choose();
      await tester.pump();
      expect(cursor.index, isNot(0),
          reason: 'the card just turned is spent, so the ring steps off it');

      // Walk to the other half of the pair.
      for (var i = 0; i < layout.length && cursor.index != 2; i++) {
        cursor.move(1);
      }
      expect(cursor.index, 2);
      cursor.choose();
      await tester.pump();

      // Those two are cleared now, so the cursor must never park on them.
      for (var i = 0; i < layout.length; i++) {
        expect(cursor.index, anyOf(1, 3),
            reason: 'a cleared pair is not a hands-free target');
        cursor.move(1);
      }
    });
  });

  group('the scramble player publishes its targets', () {
    const items = [
      MpScrambleItem(
        prompt: 'dog',
        promptEmoji: '🐶',
        answer: 'aso',
        letters: ['o', 's', 'a'],
      ),
    ];

    testWidgets('letters, then Clear and Skip', (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: items,
        presentation: _motor,
        cursor: cursor,
        onFinished: (_) {},
      )));
      expect(cursor.count, 5, reason: '3 letters + Clear + Skip');

      // Spell "aso" hands-free: letters are ['o','s','a'] → 2, 1, 0.
      cursor.move(2);
      expect(cursor.index, 2);
      cursor.choose();
      await tester.pump();
      cursor.move(-1);
      cursor.choose();
      await tester.pump();
      cursor.move(-1);
      cursor.choose();
      await tester.pump();

      expect(find.text('Finish'), findsOneWidget,
          reason: 'the word was solved without a tap');
    });

    testWidgets('a placed letter is skipped over', (tester) async {
      final cursor = RaceCursor();
      addTearDown(cursor.dispose);
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: items,
        presentation: _motor,
        cursor: cursor,
        onFinished: (_) {},
      )));
      cursor.choose(); // place letter 0
      await tester.pump();
      cursor.move(-1);
      expect(cursor.index, isNot(0), reason: 'letter 0 is spent');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
