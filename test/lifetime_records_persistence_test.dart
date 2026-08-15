import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// The lifetime records — `bestStreakDays`, `gamesPlayed`, `playedGameTypes` —
/// have to survive every trip through storage. Each one is a high-water mark
/// that cannot be rebuilt from the rest of the row: `streakDays` resets on a
/// missed day and `recentScores` is trimmed to the last 20 entries. Miss one
/// writer and a reload silently rolls the learner back, costing them XP, a
/// level, and badges.
///
/// Plain `test()`, not `testWidgets`: a Hive write inside the fake-async zone
/// leaves its Future pending and hangs `deleteFromDisk` at teardown.
void main() {
  const profileId = 'p_lifetime';

  setUpAll(() async {
    const dir = './build/test_cache/lifetime_records';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const <String>['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (total, deleted) => false);
      }
    }
  });

  tearDown(() async => Hive.box('progress').clear());
  tearDownAll(() async => Hive.deleteFromDisk());

  GameScore score(GameType type) => GameScore(
    gameType: type,
    score: 5,
    total: 5,
    starsEarned: 3,
    date: DateTime.now(),
  );

  test('playedGameTypes round-trips through Hive', () async {
    const played = {
      GameType.wordMatch,
      GameType.yesOrNo,
      GameType.tracing,
      GameType.storyQuiz,
    };
    await HiveService.saveProgress(
      LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
        playedGameTypes: played,
      ),
    );

    final reloaded = HiveService.getProgress(profileId);
    expect(reloaded.playedGameTypes, played);
  });

  test('a favourite game cannot push the others out of the record', () async {
    // The learner has tried eight games...
    const tried = {
      GameType.wordMatch,
      GameType.spellingBee,
      GameType.memoryMatch,
      GameType.pronunciation,
      GameType.sentenceBuilder,
      GameType.tracing,
      GameType.yesOrNo,
      GameType.oddOneOut,
    };
    // ...and then plays twenty rounds of one of them, which is exactly enough
    // to refill the 20-entry `recentScores` window with a single type.
    await HiveService.saveProgress(
      LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
        playedGameTypes: tried,
        gamesPlayed: 28,
        recentScores: List.generate(20, (_) => score(GameType.wordMatch)),
      ),
    );

    final reloaded = HiveService.getProgress(profileId);
    expect(reloaded.playedGameTypes, tried);
    expect(reloaded.effectiveGamesPlayed, 28);
    expect(
      Achievements.unlockedIds(reloaded).contains('game_explorer'),
      isTrue,
      reason: 'the badge is earned by what was played, not what is still shown',
    );
  });

  test('a legacy row heals from whatever scores it still holds', () async {
    // Written before the field existed: no `playedGameTypes` key at all.
    await Hive.box('progress').put(profileId, {
      'wordsLearned': 10,
      'streakDays': 4,
      'lastActivityDate': DateTime.now().toIso8601String(),
      'totalStars': 12,
      'recentScores': [
        {
          'gameType': GameType.memoryMatch.index,
          'score': 4,
          'total': 5,
          'starsEarned': 2,
          'date': DateTime.now().toIso8601String(),
        },
      ],
    });
    HiveService.invalidateProgressCache(profileId);

    final reloaded = HiveService.getProgress(profileId);
    expect(reloaded.playedGameTypes, isEmpty);
    expect(
      reloaded.effectivePlayedGameTypes,
      {GameType.memoryMatch},
      reason: 'the healed view folds in the types still on hand',
    );
  });

  test('re-saving a legacy row upgrades it in place', () async {
    await HiveService.saveProgress(
      LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
        recentScores: [score(GameType.jigsawPuzzle)],
      ),
    );

    final raw = Map<String, dynamic>.from(
      Hive.box('progress').get(profileId) as Map,
    );
    expect(
      raw['playedGameTypes'],
      contains(GameType.jigsawPuzzle.name),
      reason: 'saveProgress persists the healed value, like bestStreakDays',
    );
  });

  test('names, not indices, are what is stored', () async {
    await HiveService.saveProgress(
      LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
        playedGameTypes: const {GameType.firstLetter},
      ),
    );

    final raw = Map<String, dynamic>.from(
      Hive.box('progress').get(profileId) as Map,
    );
    expect(raw['playedGameTypes'], ['firstLetter']);
  });

  test('an unknown game name is dropped rather than throwing', () {
    expect(
      gameTypesFromNames(['wordMatch', 'a_game_we_removed', 'tracing']),
      {GameType.wordMatch, GameType.tracing},
    );
    expect(gameTypesFromNames(null), isEmpty);
    expect(gameTypesFromNames('not a list'), isEmpty);
  });

  test('the streak high-water mark still survives a reload', () async {
    await HiveService.saveProgress(
      LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
        streakDays: 1,
        bestStreakDays: 30,
      ),
    );

    final reloaded = HiveService.getProgress(profileId);
    expect(reloaded.effectiveBestStreak, 30);
    expect(
      Achievements.unlockedIds(reloaded),
      containsAll({'week_streak', 'month_streak'}),
    );
  });
}
