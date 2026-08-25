import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_models.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/services/collab_session_store.dart';

/// The Peer Collab resume snapshot, tested against real Hive.
///
/// Deliberately a plain `test()` file with no widgets in it: Hive serialises
/// writes per box, so one fire-and-forget `put` from inside a `testWidgets`
/// fake-async zone stalls every later awaited box operation in the same file.
/// Widget-side resume behaviour lives in `peer_collab_overflow_test.dart`,
/// which never awaits a box.
const _profileId = 'store-test-profile';

CollabRound _round(String word) => CollabRound(
      cardId: 'card-$word',
      word: word,
      wordFilipino: '$word-fil',
      choices: [word, 'other'],
    );

CollabSession _session({
  CollabActivityType type = CollabActivityType.pictureGuess,
  List<CollabRound>? rounds,
}) =>
    CollabSession(
      id: 'session',
      activityType: type,
      player1Name: 'Ana',
      player2Name: 'Ben',
      rounds: rounds ?? [_round('tree'), _round('sun')],
    );

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/collab_store');
    if (!Hive.isBoxOpen('progress')) {
      // Compaction renames the box file mid-write on Windows and trips
      // PathAccessException in a suite that writes this often.
      await Hive.openBox('progress',
          compactionStrategy: (total, deleted) => false);
    }
  });

  setUp(() => CollabSessionStore.clear(_profileId));

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('what is worth keeping', () {
    test('a session in play round-trips intact', () async {
      final played = _session().applyTurn('clue').applyTurn('tree');
      CollabSessionStore.save(profileId: _profileId, session: played);

      final snapshot = CollabSessionStore.read(_profileId);
      expect(snapshot, isNotNull);
      expect(snapshot!.activityType, CollabActivityType.pictureGuess);
      expect(snapshot.player1Name, 'Ana');
      expect(snapshot.player2Name, 'Ben');
      expect(snapshot.cardIds, ['card-tree', 'card-sun']);
      expect(snapshot.roundIndex, 1);
      expect(snapshot.player1Score, 1);
      expect(snapshot.player2Score, 1);
      expect(snapshot.turns, hasLength(2));
      expect(snapshot.turns.first.isClue, isTrue);
      expect(snapshot.turns.last.isChecked, isTrue);
      expect(snapshot.roundNumber, 2);
      expect(snapshot.roundsTotal, 2);
    });

    test('a session nobody has played is not offered', () {
      CollabSessionStore.save(profileId: _profileId, session: _session());
      expect(CollabSessionStore.read(_profileId), isNull,
          reason: 'there is nothing to come back to');
    });

    test('a finished session is not offered', () {
      var s = _session(rounds: [_round('tree')]);
      s = s.applyTurn('clue').applyTurn('tree');
      expect(s.isComplete, isTrue);

      CollabSessionStore.save(profileId: _profileId, session: s);
      expect(CollabSessionStore.read(_profileId), isNull);
    });

    test('saving a finished session clears an earlier snapshot', () {
      final played = _session().applyTurn('clue');
      CollabSessionStore.save(profileId: _profileId, session: played);
      expect(CollabSessionStore.read(_profileId), isNotNull);

      var done = _session(rounds: [_round('tree')]);
      done = done.applyTurn('clue').applyTurn('tree');
      CollabSessionStore.save(profileId: _profileId, session: done);

      expect(CollabSessionStore.read(_profileId), isNull);
    });

    test('a profile-less learner is a no-op, not a crash', () {
      CollabSessionStore.save(profileId: null, session: _session());
      expect(CollabSessionStore.read(null), isNull);
      CollabSessionStore.clear(null);
    });

    test('two profiles never see each other\'s session', () {
      final played = _session().applyTurn('clue');
      CollabSessionStore.save(profileId: _profileId, session: played);

      expect(CollabSessionStore.read('someone-else'), isNull);
      expect(CollabSessionStore.read(_profileId), isNotNull);
      CollabSessionStore.clear('someone-else');
    });
  });

  group('what is dropped on read', () {
    test('a snapshot past its age is dropped', () {
      final played = _session().applyTurn('clue');
      final stale = CollabResumeSnapshot.of(played).toMap()
        ..['savedAt'] = DateTime.now()
            .subtract(CollabSessionStore.resumeMaxAge * 2)
            .millisecondsSinceEpoch;
      Hive.box('progress').put('collab_resume_$_profileId', stale);

      expect(CollabSessionStore.read(_profileId), isNull);
      expect(Hive.box('progress').containsKey('collab_resume_$_profileId'),
          isFalse, reason: 'and cleaned up, not left to be re-read');
    });

    test('a snapshot from an older build is dropped, not thrown', () {
      Hive.box('progress').put('collab_resume_$_profileId', {
        'activity': 'anActivityThisBuildDoesNotHave',
        'cardIds': ['card-tree'],
      });
      expect(CollabSessionStore.read(_profileId), isNull);
    });

    test('a snapshot with no rounds is dropped', () {
      Hive.box('progress').put('collab_resume_$_profileId', {
        'activity': CollabActivityType.wordRelay.name,
        'cardIds': <String>[],
      });
      expect(CollabSessionStore.read(_profileId), isNull);
    });

    test('anything that is not a map is ignored', () {
      Hive.box('progress').put('collab_resume_$_profileId', 'nonsense');
      expect(CollabSessionStore.read(_profileId), isNull);
    });
  });

  group('rebuilding the session', () {
    test('restores every field the pair had earned', () {
      var original = _session(type: CollabActivityType.wordRelay, rounds: [
        _round('go'),
        _round('up'),
      ]);
      original = original.applyTurn('g');
      CollabSessionStore.save(profileId: _profileId, session: original);

      final snapshot = CollabSessionStore.read(_profileId)!;
      // The screen re-draws choices from the live pool; the rounds handed back
      // here stand in for that.
      final restored = snapshot.toSession(
        id: 'new-id',
        rounds: [_round('go'), _round('up')],
      );

      expect(restored.activityType, original.activityType);
      expect(restored.roundIndex, original.roundIndex);
      expect(restored.currentPlayerIndex, original.currentPlayerIndex);
      expect(restored.revealed, original.revealed);
      expect(restored.wrongAttempts, original.wrongAttempts);
      expect(restored.clueGiven, original.clueGiven);
      expect(restored.teamScore, original.teamScore);
      expect(restored.turns, hasLength(original.turns.length));
      expect(restored.currentRound!.word, original.currentRound!.word);
    });

    test('a restored session carries on scoring where it left off', () {
      var original = _session(type: CollabActivityType.wordRelay, rounds: [
        _round('go'),
      ]);
      original = original.applyTurn('g');
      CollabSessionStore.save(profileId: _profileId, session: original);

      final restored = CollabSessionStore.read(_profileId)!
          .toSession(id: 'new-id', rounds: [_round('go')])
          .applyTurn('o');

      expect(restored.isComplete, isTrue);
      expect(restored.teamScore, 2, reason: 'both letters counted');
    });
  });
}
