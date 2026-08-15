import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/race_presentation.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/memory_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/quiz_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/scramble_race_player.dart';

/// How the race *widgets* honour a [RacePresentation]: the two behaviours that
/// decide whether a learner with a motor, cognitive or visual profile can
/// actually finish a match — self-paced advance, and a score that isn't a
/// stopwatch — plus the narration seam a blind learner depends on.

const _questions = [
  MpQuestion(
    prompt: 'dog',
    promptLabel: 'What is this in Filipino?',
    options: ['aso', 'pusa'],
    correctIndex: 0,
  ),
  MpQuestion(
    prompt: 'cat',
    promptLabel: 'What is this in Filipino?',
    options: ['aso', 'pusa'],
    correctIndex: 1,
  ),
];

final _motor = RacePresentation.forProfile(
  DisabilityType.motor,
  const AppSettings(),
);
final _visual = RacePresentation.forProfile(
  DisabilityType.visual,
  const AppSettings(),
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('self-paced quiz', () {
    testWidgets('an answer never disappears on a timer', (tester) async {
      var finished = -1;
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _motor,
        onFinished: (s) => finished = s,
      )));

      await tester.tap(find.text('aso'));
      await tester.pump();

      // Far longer than the classic 900 ms advance.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('1/2'), findsOneWidget,
          reason: 'still on question 1 — nothing advanced behind the learner');
      expect(finished, -1);
    });

    testWidgets('the learner advances with the Next button', (tester) async {
      var finished = -1;
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _motor,
        onFinished: (s) => finished = s,
      )));

      expect(find.text('Next'), findsNothing,
          reason: 'no advance offered before answering');
      await tester.tap(find.text('aso'));
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);

      // Last question: the control becomes Finish and ends the match.
      await tester.tap(find.text('pusa'));
      await tester.pump();
      expect(find.text('Next'), findsNothing);
      expect(find.text('Finish'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(finished, 2);
    });

    testWidgets('the advance button is inert while paused', (tester) async {
      var finished = -1;
      Widget build(bool paused) => _host(QuizRacePlayer(
            questions: _questions,
            presentation: _motor,
            isPaused: paused,
            onFinished: (s) => finished = s,
          ));

      await tester.pumpWidget(build(false));
      await tester.tap(find.text('aso'));
      await tester.pump();

      await tester.pumpWidget(build(true));
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget, reason: 'paused means paused');

      await tester.pumpWidget(build(false));
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);
      expect(finished, -1);
    });

    testWidgets('a timed profile still auto-advances', (tester) async {
      var finished = -1;
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        onFinished: (s) => finished = s,
      )));

      await tester.tap(find.text('aso'));
      await tester.pump();
      expect(find.text('Next'), findsNothing,
          reason: 'the classic race has no manual advance');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('2/2'), findsOneWidget);
      expect(finished, -1);
    });
  });

  group('narration', () {
    testWidgets('a visual profile hears the prompt and every option',
        (tester) async {
      final spoken = <String>[];
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _visual,
        speak: spoken.add,
        onFinished: (_) {},
      )));
      await tester.pump();

      expect(spoken, isNotEmpty);
      expect(spoken.first, contains('What is this in Filipino?'));
      expect(spoken.first, contains('dog'));
      expect(spoken.first, contains('aso'),
          reason: 'options are unreachable otherwise');
      expect(spoken.first, contains('pusa'));
    });

    testWidgets('"Hear it again" repeats the round on demand', (tester) async {
      final spoken = <String>[];
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        presentation: _visual,
        speak: spoken.add,
        onFinished: (_) {},
      )));
      await tester.pump();
      final before = spoken.length;

      await tester.tap(find.text('Hear it again'));
      await tester.pump();
      expect(spoken.length, before + 1);
    });

    testWidgets('a profile that does not narrate never calls speak',
        (tester) async {
      final spoken = <String>[];
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: _questions,
        speak: spoken.add,
        onFinished: (_) {},
      )));
      await tester.pump();
      expect(spoken, isEmpty);
      expect(find.text('Hear it again'), findsNothing);
    });
  });

  group('self-paced scramble', () {
    const items = [
      MpScrambleItem(
        prompt: 'dog',
        promptEmoji: '🐶',
        answer: 'aso',
        letters: ['o', 's', 'a'],
      ),
    ];

    testWidgets('a wrong word waits for "Try again" instead of clearing',
        (tester) async {
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: items,
        presentation: _motor,
        onFinished: (_) {},
      )));

      // Spell "osa" — wrong.
      await tester.tap(find.text('O'));
      await tester.pump();
      await tester.tap(find.text('S'));
      await tester.pump();
      await tester.tap(find.text('A'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Try again'), findsOneWidget,
          reason: 'the mistake stays on screen until the learner is ready');

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a solved word waits for "Finish" on the last item',
        (tester) async {
      var finished = -1;
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: items,
        presentation: _motor,
        onFinished: (s) => finished = s,
      )));

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('S'));
      await tester.pump();
      await tester.tap(find.text('O'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      expect(finished, -1, reason: 'no timer ended the match');
      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(finished, greaterThan(0));
    });

    testWidgets('Skip reports progress so an online opponent bar moves',
        (tester) async {
      final progress = <int>[];
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: items,
        onProgress: (_, p) => progress.add(p),
        onFinished: (_) {},
      )));

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(progress, [1]);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('memory board', () {
    testWidgets('an unmatched pair stays up longer when self-paced',
        (tester) async {
      const layout = [
        MemoryCardSpec(cardId: 'a', emoji: '🐶', label: 'dog'),
        MemoryCardSpec(cardId: 'b', emoji: '🐱', label: 'cat'),
        MemoryCardSpec(cardId: 'a', emoji: '🐶', label: 'dog'),
        MemoryCardSpec(cardId: 'b', emoji: '🐱', label: 'cat'),
      ];
      await tester.pumpWidget(_host(MemoryRacePlayer(
        layout: layout,
        presentation: _motor,
        onFinished: (_) {},
      )));

      await tester.tap(find.text('❓').first);
      await tester.pump();
      await tester.tap(find.text('❓').first);
      await tester.pump();

      // The classic board would already have flipped these back.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('❓'), findsNWidgets(2),
          reason: 'two cards are still face-up for a longer look');

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('❓'), findsNWidgets(4));
    });
  });

  group('scoring without a clock', () {
    test('memory: a slow clear scores the same as a fast one', () {
      final fast = memoryRaceScore(
          pairs: 6, moves: 6, elapsedSeconds: 10, countTime: false);
      final slow = memoryRaceScore(
          pairs: 6, moves: 6, elapsedSeconds: 300, countTime: false);
      expect(fast, slow);
      // …and efficiency still decides the match.
      expect(
        memoryRaceScore(
            pairs: 6, moves: 6, elapsedSeconds: 10, countTime: false),
        greaterThan(memoryRaceScore(
            pairs: 6, moves: 14, elapsedSeconds: 10, countTime: false)),
      );
    });

    test('memory: the timed race is unchanged', () {
      expect(
        memoryRaceScore(pairs: 6, moves: 6, elapsedSeconds: 10),
        greaterThan(memoryRaceScore(pairs: 6, moves: 6, elapsedSeconds: 80)),
      );
    });

    test('scramble: only solved words and mistakes count', () {
      final fast =
          scrambleScore(solved: 4, wrong: 1, elapsedSeconds: 5, countTime: false);
      final slow = scrambleScore(
          solved: 4, wrong: 1, elapsedSeconds: 400, countTime: false);
      expect(fast, slow);
      expect(
        fast,
        greaterThan(scrambleScore(
            solved: 3, wrong: 1, elapsedSeconds: 5, countTime: false)),
      );
    });

    test('scramble: the timed race is unchanged', () {
      expect(
        scrambleScore(solved: 4, wrong: 0, elapsedSeconds: 5),
        greaterThan(scrambleScore(solved: 4, wrong: 0, elapsedSeconds: 100)),
      );
    });
  });
}
