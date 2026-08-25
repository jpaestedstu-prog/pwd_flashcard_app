import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

/// The record behind the Games hub's personal-best badge.
///
/// It follows the rule the XP economy already lives by — **nothing earned is
/// taken away** — which is why the best is a high-water mark rather than the
/// last result, and why every path that writes a progress row has to carry it.
///
/// Plain `test()` only, with the real Hive box: this file must never gain a
/// `testWidgets` case. One fire-and-forget `put` from a fake-async zone
/// poisons the box's write queue for every later case in the same file. The
/// play clock's widget test lives in `game_play_clock_test.dart` for exactly
/// that reason.

LearningProgress _progress({
  Map<String, int> gameBestStars = const {},
  List<GameScore> recentScores = const [],
}) => LearningProgress(
  profileId: 'learner',
  lastActivityDate: DateTime(2026, 8, 16),
  gameBestStars: gameBestStars,
  recentScores: recentScores,
);

GameScore _score(GameType type, {required int score, required int total}) =>
    GameScore(
      gameType: type,
      score: score,
      total: total,
      // Deliberately 0 — the currency awarded must not influence the rating.
      starsEarned: 0,
      date: DateTime(2026, 8, 16),
    );

void main() {
  // ─── The rating formula ───────────────────────────────

  group('GameScore.ratingFor', () {
    test('maps the share of correct answers to 0–3', () {
      expect(GameScore.ratingFor(10, 10), 3); // 100 %
      expect(GameScore.ratingFor(9, 10), 3); // 90 %
      expect(GameScore.ratingFor(7, 10), 2); // 70 %
      expect(GameScore.ratingFor(5, 10), 1); // 50 %
      expect(GameScore.ratingFor(4, 10), 0); // 40 %
      expect(GameScore.ratingFor(0, 10), 0);
    });

    test('a zero-length round rates 0 rather than dividing by zero', () {
      expect(GameScore.ratingFor(0, 0), 0);
    });

    test('the result screen and the hub badge share one definition', () {
      for (var total = 1; total <= 14; total++) {
        for (var score = 0; score <= total; score++) {
          expect(
            GameResultDialog.ratingForScore(score, total),
            GameScore.ratingFor(score, total),
            reason: 'diverged at $score/$total',
          );
        }
      }
    });

    test('rating is independent of the stars actually awarded', () {
      // A profile with the star economy switched off still earns a best.
      expect(_score(GameType.wordMatch, score: 10, total: 10).rating, 3);
    });
  });

  // ─── The high-water mark ──────────────────────────────

  group('effectiveGameBestStars', () {
    test('is empty for a learner who has played nothing', () {
      expect(_progress().effectiveGameBestStars, isEmpty);
      expect(_progress().bestStarsFor(GameType.wordMatch), isNull);
    });

    test('never played and played-badly are different answers', () {
      final p = _progress(gameBestStars: {GameType.yesOrNo.name: 0});
      // 0 means "tried it, scored under 50 %" — the badge shows three empty
      // stars. null means "not tried" — the badge shows NEW.
      expect(p.bestStarsFor(GameType.yesOrNo), 0);
      expect(p.bestStarsFor(GameType.oddOneOut), isNull);
    });

    test('heals a legacy row from whatever recentScores still holds', () {
      // Rows written before the field existed carry no map at all.
      final p = _progress(
        recentScores: [
          _score(GameType.spellingBee, score: 5, total: 10), // 1★
          _score(GameType.spellingBee, score: 10, total: 10), // 3★
          _score(GameType.tracing, score: 7, total: 10), // 2★
        ],
      );
      expect(p.bestStarsFor(GameType.spellingBee), 3);
      expect(p.bestStarsFor(GameType.tracing), 2);
      expect(p.bestStarsFor(GameType.jigsawPuzzle), isNull);
    });

    test('a stored best outranks a worse round still in the window', () {
      // The 3★ round has aged out of recentScores; the stored best is what
      // keeps the badge from falling back to the recent 1★.
      final p = _progress(
        gameBestStars: {GameType.memoryMatch.name: 3},
        recentScores: [_score(GameType.memoryMatch, score: 5, total: 10)],
      );
      expect(p.bestStarsFor(GameType.memoryMatch), 3);
    });

    test('a better round still in the window raises a stale stored best', () {
      final p = _progress(
        gameBestStars: {GameType.memoryMatch.name: 1},
        recentScores: [_score(GameType.memoryMatch, score: 10, total: 10)],
      );
      expect(p.bestStarsFor(GameType.memoryMatch), 3);
    });

    test('healing does not mutate the stored map', () {
      const stored = {'wordMatch': 1};
      final p = _progress(
        gameBestStars: stored,
        recentScores: [_score(GameType.wordMatch, score: 10, total: 10)],
      );
      expect(p.effectiveGameBestStars['wordMatch'], 3);
      expect(p.gameBestStars['wordMatch'], 1, reason: 'source was mutated');
    });

    test('is keyed by enum name, so reordering GameType cannot shift it', () {
      final p = _progress(gameBestStars: {GameType.firstLetter.name: 2});
      expect(p.gameBestStars.keys.single, 'firstLetter');
    });
  });

  // ─── Persistence ──────────────────────────────────────

  group('Hive round-trip', () {
    setUpAll(() async {
      // Self-healing store: a previous hung run can leave a flutter_tester
      // holding the .lock, which fails every later setUpAll.
      try {
        Directory('./build/test_cache/game_bests').deleteSync(recursive: true);
      } catch (_) {
        // Nothing to clean, or still locked — openBox reports the real error.
      }
      Hive.init('./build/test_cache/game_bests');
      if (!Hive.isBoxOpen('progress')) {
        // Compaction disabled: it renames the .hivec over the .hive mid-write,
        // which fails with "Access is denied" on Windows.
        await Hive.openBox(
          'progress',
          compactionStrategy: (total, deleted) => false,
        );
      }
    });

    setUp(() async {
      await Hive.box('progress').clear().timeout(const Duration(seconds: 5));
    });

    test('bests survive a save and reload', () async {
      await HiveService.saveProgress(
        _progress(gameBestStars: {GameType.dragAndDrop.name: 2}),
      );
      final reloaded = HiveService.getProgress('learner');
      expect(reloaded.bestStarsFor(GameType.dragAndDrop), 2);
    });

    test('a row written before the field existed still loads', () async {
      // Exactly the shape saveProgress used to write.
      await Hive.box('progress').put('legacy', {
        'wordsLearned': 0,
        'learnedWordIds': <String>[],
        'streakDays': 1,
        'lastActivityDate': DateTime(2026, 8, 16).toIso8601String(),
        'totalStars': 0,
        'spentStars': 0,
        'categoryProgress': <String, double>{},
        'recentScores': [
          {
            'gameType': GameType.pictureWord.index,
            'score': 9,
            'total': 10,
            'starsEarned': 3,
            'date': DateTime(2026, 8, 16).toIso8601String(),
            'durationSeconds': null,
          },
        ],
      });
      final reloaded = HiveService.getProgress('legacy');
      expect(reloaded.bestStarsFor(GameType.pictureWord), 3);
    });

    test('a key for a game that no longer exists is dropped', () async {
      await Hive.box('progress').put('stale', {
        'wordsLearned': 0,
        'learnedWordIds': <String>[],
        'streakDays': 1,
        'lastActivityDate': DateTime(2026, 8, 16).toIso8601String(),
        'totalStars': 0,
        'spentStars': 0,
        'categoryProgress': <String, double>{},
        'recentScores': <dynamic>[],
        'gameBestStars': {'gameThatWasRemoved': 3, GameType.tracing.name: 2},
      });
      final reloaded = HiveService.getProgress('stale');
      expect(reloaded.gameBestStars.containsKey('gameThatWasRemoved'), isFalse);
      expect(reloaded.bestStarsFor(GameType.tracing), 2);
    });
  });

}
