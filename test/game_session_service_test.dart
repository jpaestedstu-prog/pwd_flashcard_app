import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/game_session_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// The two convenience records behind "Last played" and "Continue where you
/// left off".
///
/// Plain `test()` only, with the real Hive box — never add a `testWidgets`
/// case here, or one fire-and-forget `put` from a fake-async zone poisons the
/// box's write queue for every later case in the file.

GameResumeSnapshot _snapshot({
  String profileId = 'learner',
  GameType gameType = GameType.wordMatch,
  int roundIndex = 3,
  int score = 2,
  int deckSize = 10,
  DateTime? savedAt,
}) => GameResumeSnapshot(
  profileId: profileId,
  gameType: gameType,
  difficulty: GameDifficulty.hard,
  categories: const [FlashcardCategory.animals],
  timedMode: true,
  cardIds: [for (var i = 0; i < deckSize; i++) 'card_$i'],
  roundIndex: roundIndex,
  score: score,
  cardResults: const {'card_0': true, 'card_1': false, 'card_2': true},
  savedAt: savedAt ?? DateTime.now(),
);

void main() {
  setUpAll(() async {
    try {
      Directory('./build/test_cache/game_session').deleteSync(recursive: true);
    } catch (_) {
      // Nothing to clean, or still locked — openBox reports the real error.
    }
    Hive.init('./build/test_cache/game_session');
    if (!Hive.isBoxOpen('progress')) {
      await Hive.openBox(
        'progress',
        compactionStrategy: (total, deleted) => false,
      );
    }
  });

  setUp(() async {
    await Hive.box('progress').clear().timeout(const Duration(seconds: 5));
  });

  // ─── Last setup ───────────────────────────────────────

  group('lastSetup', () {
    test('is null before the learner has ever started this game', () {
      expect(
        GameSessionService.lastSetup(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('round-trips difficulty, categories and timed mode', () {
      GameSessionService.saveSetup(
        profileId: 'learner',
        gameType: GameType.spellingBee,
        difficulty: GameDifficulty.hard,
        categories: const [
          FlashcardCategory.animals,
          FlashcardCategory.colorsAndShapes,
        ],
        timedMode: true,
      );
      final setup = GameSessionService.lastSetup(
        profileId: 'learner',
        gameType: GameType.spellingBee,
      )!;
      expect(setup.difficulty, GameDifficulty.hard);
      expect(setup.categories, [
        FlashcardCategory.animals,
        FlashcardCategory.colorsAndShapes,
      ]);
      expect(setup.timedMode, isTrue);
    });

    test('is per game, not one setting for the whole hub', () {
      GameSessionService.saveSetup(
        profileId: 'learner',
        gameType: GameType.wordMatch,
        difficulty: GameDifficulty.easy,
        categories: const [],
        timedMode: false,
      );
      expect(
        GameSessionService.lastSetup(
          profileId: 'learner',
          gameType: GameType.memoryMatch,
        ),
        isNull,
      );
    });

    test('is per profile, so a shared tablet keeps learners apart', () {
      GameSessionService.saveSetup(
        profileId: 'ana',
        gameType: GameType.wordMatch,
        difficulty: GameDifficulty.hard,
        categories: const [],
        timedMode: false,
      );
      expect(
        GameSessionService.lastSetup(
          profileId: 'ben',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('a guest with no profile id is a no-op, not a crash', () {
      GameSessionService.saveSetup(
        profileId: null,
        gameType: GameType.wordMatch,
        difficulty: GameDifficulty.hard,
        categories: const [],
        timedMode: false,
      );
      expect(
        GameSessionService.lastSetup(
          profileId: null,
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });
  });

  // ─── Resume snapshot ──────────────────────────────────

  group('resume snapshot', () {
    test('round-trips the deck and the position in it', () {
      GameSessionService.saveResume(_snapshot());
      final saved = GameSessionService.resumeFor(
        profileId: 'learner',
        gameType: GameType.wordMatch,
      )!;
      expect(saved.roundIndex, 3);
      expect(saved.score, 2);
      expect(saved.cardIds.length, 10);
      expect(saved.roundsLeft, 7);
      expect(saved.difficulty, GameDifficulty.hard);
      expect(saved.categories, [FlashcardCategory.animals]);
      expect(saved.timedMode, isTrue);
      expect(saved.cardResults['card_1'], isFalse);
    });

    test('a run with nothing answered yet is not worth offering', () {
      GameSessionService.saveResume(_snapshot(roundIndex: 0));
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('a run already at its last round is not worth offering', () {
      GameSessionService.saveResume(
        _snapshot(roundIndex: 10),
      );
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('saving an unofferable run clears an earlier one', () {
      GameSessionService.saveResume(_snapshot(roundIndex: 4));
      GameSessionService.saveResume(_snapshot(roundIndex: 0));
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('a run older than a day is dropped rather than offered', () {
      GameSessionService.saveResume(
        _snapshot(
          savedAt: DateTime.now().subtract(const Duration(hours: 25)),
        ),
      );
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('a run from this morning is still offered', () {
      GameSessionService.saveResume(
        _snapshot(savedAt: DateTime.now().subtract(const Duration(hours: 6))),
      );
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNotNull,
      );
    });

    test('only the most recent unfinished run per game is kept', () {
      GameSessionService.saveResume(_snapshot(roundIndex: 2));
      GameSessionService.saveResume(_snapshot(roundIndex: 7));
      expect(
        GameSessionService
            .resumeFor(
              profileId: 'learner',
              gameType: GameType.wordMatch,
            )!
            .roundIndex,
        7,
      );
    });

    test('clearing forgets it', () {
      GameSessionService.saveResume(_snapshot());
      GameSessionService.clearResume(
        profileId: 'learner',
        gameType: GameType.wordMatch,
      );
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
    });

    test('allResumes lists every game with an offerable run', () {
      GameSessionService.saveResume(_snapshot());
      GameSessionService.saveResume(_snapshot(gameType: GameType.yesOrNo));
      // Not offerable — nothing answered.
      GameSessionService.saveResume(
        _snapshot(gameType: GameType.oddOneOut, roundIndex: 0),
      );
      final all = GameSessionService.allResumes('learner');
      expect(all.keys, containsAll([GameType.wordMatch, GameType.yesOrNo]));
      expect(all.containsKey(GameType.oddOneOut), isFalse);
    });

    test('allResumes is empty for a guest with no profile id', () {
      expect(GameSessionService.allResumes(null), isEmpty);
    });

    test('a snapshot written by an older build is dropped, not thrown', () {
      // Shape a previous version might have written: no savedAt at all.
      Hive.box('progress').put('game_resume_learner', {
        GameType.wordMatch.name: {'roundIndex': 3, 'score': 1},
      });
      expect(
        GameSessionService.resumeFor(
          profileId: 'learner',
          gameType: GameType.wordMatch,
        ),
        isNull,
      );
      // …and the bad entry is gone, so it cannot re-throw on every hub build.
      expect(GameSessionService.allResumes('learner'), isEmpty);
    });
  });
}
