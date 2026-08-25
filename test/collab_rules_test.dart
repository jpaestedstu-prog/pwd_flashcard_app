import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_models.dart';

/// Peer Collab's rules, tested without a widget.
///
/// The whole point of moving them into [CollabSession] is that "was that answer
/// right?" is now a pure function. Before this, nothing in Peer Collab was ever
/// checked: every turn scored +1 for *both* players whatever was typed, so
/// entering "zqx" into a three-letter Word Relay filled all three blanks and
/// finished the game 5–5.
CollabRound _round(String word, {List<String>? choices}) => CollabRound(
      cardId: 'card-$word',
      word: word,
      wordFilipino: '$word-fil',
      choices: choices ?? [word, 'other', 'another', 'more'],
    );

CollabSession _session(
  CollabActivityType type, {
  required List<CollabRound> rounds,
}) =>
    CollabSession(
      id: 'test',
      activityType: type,
      player1Name: 'Ana',
      player2Name: 'Ben',
      rounds: rounds,
    );

void main() {
  group('Word Relay checks the letter', () {
    test('a right letter reveals exactly one blank and scores its player', () {
      final s = _session(CollabActivityType.wordRelay,
          rounds: [_round('cat')]).applyTurn('c');

      expect(s.revealed, 'c');
      expect(s.player1Score, 1, reason: 'the player who placed it scores');
      expect(s.player2Score, 0, reason: 'their partner did not');
      expect(s.turns.single.isCorrect, isTrue);
      expect(s.currentPlayerIndex, 1, reason: 'the turn passes');
    });

    test('a wrong letter reveals nothing and scores nobody', () {
      final s = _session(CollabActivityType.wordRelay,
          rounds: [_round('cat')]).applyTurn('z');

      expect(s.revealed, isEmpty);
      expect(s.teamScore, 0);
      expect(s.turns.single.isCorrect, isFalse);
      expect(s.turns.single.isChecked, isTrue);
    });

    // The original defect, pinned: a multi-character answer used to be appended
    // whole, filling every remaining blank in one turn.
    test('a multi-character answer still advances only one blank', () {
      final s = _session(CollabActivityType.wordRelay,
          rounds: [_round('cat')]).applyTurn('zqx');

      expect(s.revealed, isEmpty, reason: 'zqx is not "c"');
      expect(s.teamScore, 0);

      final right = _session(CollabActivityType.wordRelay,
          rounds: [_round('cat')]).applyTurn('cat');
      expect(right.revealed, 'c',
          reason: 'forgiving about shape, strict about the letter');
    });

    test('two wrong tries gives the letter away, unscored', () {
      var s = _session(CollabActivityType.wordRelay, rounds: [_round('cat')]);
      s = s.applyTurn('z');
      expect(s.revealed, isEmpty);
      expect(s.wrongAttempts, 1);

      s = s.applyTurn('q');
      expect(s.revealed, 'c', reason: 'mercy: the pair is never stuck');
      expect(s.teamScore, 0, reason: 'but a given letter is not earned');
      expect(s.wrongAttempts, 0);
    });

    test('finishing the word moves to the next round and a new word', () {
      var s = _session(CollabActivityType.wordRelay,
          rounds: [_round('go'), _round('up')]);
      expect(s.currentRound!.word, 'go');

      s = s.applyTurn('g').applyTurn('o');

      expect(s.roundIndex, 1);
      expect(s.currentRound!.word, 'up', reason: 'the word rotates per round');
      expect(s.revealed, isEmpty, reason: 'blanks reset for the new word');
      expect(s.isComplete, isFalse);
    });
  });

  group('Guessing rounds check the guess', () {
    test('the describer clues, then the guesser answers', () {
      final start =
          _session(CollabActivityType.pictureGuess, rounds: [_round('tree')]);
      expect(start.isCluePhase, isTrue);
      expect(start.currentPlayerIndex, start.describerIndex);

      final clued = start.applyTurn('it is tall');
      expect(clued.isCluePhase, isFalse);
      expect(clued.turns.single.isClue, isTrue);
      expect(clued.turns.single.isChecked, isFalse,
          reason: 'a clue has no right answer');
      expect(clued.currentPlayerIndex, clued.guesserIndex);
      expect(clued.teamScore, 0, reason: 'cluing does not score by itself');
    });

    test('a right guess scores for both players', () {
      final s = _session(CollabActivityType.pictureGuess,
              rounds: [_round('tree'), _round('sun')])
          .applyTurn('clue')
          .applyTurn('TrEe');

      expect(s.player1Score, 1);
      expect(s.player2Score, 1, reason: 'cooperative: the describer earned it');
      expect(s.turns.last.isCorrect, isTrue);
    });

    test('a wrong guess scores nobody but still ends the round', () {
      final s = _session(CollabActivityType.pictureGuess,
              rounds: [_round('tree'), _round('sun')])
          .applyTurn('clue')
          .applyTurn('banana');

      expect(s.teamScore, 0);
      expect(s.turns.last.isCorrect, isFalse);
      expect(s.roundIndex, 1,
          reason: 'a round a child cannot leave is worse than a lost point');
      expect(s.currentRound!.word, 'sun');
    });

    test('a written clue is readable back; a spoken one is not', () {
      final start =
          _session(CollabActivityType.pictureGuess, rounds: [_round('tree')]);
      expect(start.writtenClue, isNull, reason: 'nothing clued yet');

      final written = start.applyTurn('It has 4 letters.');
      expect(written.writtenClue?.content, 'It has 4 letters.');

      // Clued aloud or in sign: the marker is filtered here, in the model, so
      // no widget can render "__spoken__" as if it were a hint.
      final spoken = start.applyTurn(CollabSession.spokenClue);
      expect(spoken.clueGiven, isTrue, reason: 'the turn still passed over');
      expect(spoken.writtenClue, isNull);
    });

    test('a clue does not leak across rounds', () {
      var s = _session(CollabActivityType.pictureGuess,
          rounds: [_round('tree'), _round('sun')]);
      s = s.applyTurn('a written clue').applyTurn('tree');

      expect(s.roundIndex, 1);
      expect(s.writtenClue, isNull,
          reason: 'round 2 has not been clued yet, whatever round 1 said');
    });

    test('only guessing activities have a clue at all', () {
      final story =
          _session(CollabActivityType.storyBuilder, rounds: [_round('x')])
              .applyTurn('Once upon a time');
      expect(story.writtenClue, isNull);
    });

    // The other original defect: the word was only ever shown to player 0, so
    // player 1 could never be the describer.
    test('the describer swaps every round', () {
      var s = _session(CollabActivityType.signChallenge,
          rounds: [_round('a'), _round('b'), _round('c')]);

      expect(s.describerIndex, 0);
      s = s.applyTurn('clue').applyTurn('a');
      expect(s.describerIndex, 1, reason: 'round 2 is the partner turn to clue');
      expect(s.currentPlayerIndex, 1);

      s = s.applyTurn('clue').applyTurn('b');
      expect(s.describerIndex, 0);
    });
  });

  group('Story Builder is open by design', () {
    test('every contribution counts and is not marked "correct"', () {
      final s = _session(CollabActivityType.storyBuilder, rounds: [_round('x')])
          .applyTurn('Once upon a time');

      expect(s.turns.single.isChecked, isFalse,
          reason: 'there is no right next sentence');
      expect(s.player1Score, 1);
      expect(CollabActivityType.storyBuilder.isOpenEnded, isTrue);
    });

    test('a round is one contribution each', () {
      var s = _session(CollabActivityType.storyBuilder,
          rounds: [_round('x'), _round('y')]);
      s = s.applyTurn('one');
      expect(s.roundIndex, 0);
      s = s.applyTurn('two');
      expect(s.roundIndex, 1);
      expect(s.teamScore, 2);
    });
  });

  group('Ready-made clue facts', () {
    test('a two-word card counts letters, not characters', () {
      // The bug the tablet caught: "Partly Cloudy" was announced as thirteen
      // letters, because the space was counted.
      final facts = CollabClueFacts.of('Partly Cloudy');
      expect(facts.letterCount, 12);
      expect(facts.firstLetter, 'P');
    });

    test('a one-word card is unsurprising', () {
      final facts = CollabClueFacts.of('tree');
      expect(facts.letterCount, 4);
      expect(facts.firstLetter, 'T', reason: 'shown upper-cased');
    });

    test('surrounding whitespace never leaks into a clue', () {
      final facts = CollabClueFacts.of('  ice cream  ');
      expect(facts.letterCount, 8);
      expect(facts.firstLetter, 'I');
    });

    test('an empty word offers nothing rather than a false clue', () {
      final facts = CollabClueFacts.of('   ');
      expect(facts.isUsable, isFalse);
      expect(facts.firstLetter, isEmpty);
      expect(facts.letterCount, 0);
    });
  });

  group('Session shape', () {
    test('an empty answer changes nothing', () {
      final start =
          _session(CollabActivityType.wordRelay, rounds: [_round('cat')]);
      expect(identical(start.applyTurn('   '), start), isTrue);
    });

    test('finishing the last round completes the session', () {
      var s = _session(CollabActivityType.pictureGuess, rounds: [_round('a')]);
      s = s.applyTurn('clue').applyTurn('a');

      expect(s.isComplete, isTrue);
      expect(s.currentRound, isNull);
      expect(s.roundsCurrent, 1,
          reason: 'a finished session reads 1/1, never 2/1');
      expect(s.applyTurn('more'), same(s), reason: 'and accepts nothing more');
    });

    test('maxTeamScore matches what each activity can actually award', () {
      expect(
        _session(CollabActivityType.pictureGuess,
            rounds: [_round('a'), _round('b')]).maxTeamScore,
        4,
        reason: 'both players, once per round',
      );
      expect(
        _session(CollabActivityType.wordRelay,
            rounds: [_round('go'), _round('cat')]).maxTeamScore,
        5,
        reason: 'one point per letter',
      );
      expect(
        _session(CollabActivityType.storyBuilder,
            rounds: [_round('a'), _round('b')]).maxTeamScore,
        4,
        reason: 'one point per contribution',
      );
    });

    test('a perfect guessing game reaches maxTeamScore exactly', () {
      var s = _session(CollabActivityType.pictureGuess,
          rounds: [_round('a'), _round('b'), _round('c')]);
      while (!s.isComplete) {
        s = s.applyTurn('clue').applyTurn(s.currentRound!.word);
      }
      expect(s.teamScore, s.maxTeamScore);
    });

    test('only guessing activities have roles', () {
      expect(CollabActivityType.pictureGuess.hasRoles, isTrue);
      expect(CollabActivityType.signChallenge.hasRoles, isTrue);
      expect(CollabActivityType.wordRelay.hasRoles, isFalse);
      expect(CollabActivityType.storyBuilder.hasRoles, isFalse);
    });
  });
}
