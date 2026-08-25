import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Guards the rule that a cloud pull can never take away what a learner has
/// already earned, and that the two legs of progress sync stay gated on the
/// same condition.
///
/// Both were broken. Found by pulling `progress.hive` off the tablet after a
/// game and decoding the append-only log: the game's category value was
/// written correctly (0.1190 → 0.2333) and then a later write put 0.1190
/// back. The cause was a background listener subscribed to a document this
/// device never writes, applying a stale snapshot on top of fresh progress.

LearningProgress _progress({
  String profileId = 'p1',
  int wordsLearned = 0,
  Set<String> learnedWordIds = const {},
  int totalStars = 0,
  int spentStars = 0,
  int streakDays = 0,
  int bestStreakDays = 0,
  int gamesPlayed = 0,
  Set<GameType> playedGameTypes = const {},
  Map<String, double> categoryProgress = const {},
  Set<String> completedStoryIds = const {},
  Map<String, int> storyBestStars = const {},
  Map<String, int> gameBestStars = const {},
  Set<String> signedWordKeys = const {},
  DateTime? lastActivityDate,
}) {
  return LearningProgress(
    profileId: profileId,
    wordsLearned: wordsLearned,
    learnedWordIds: learnedWordIds,
    totalStars: totalStars,
    spentStars: spentStars,
    streakDays: streakDays,
    bestStreakDays: bestStreakDays,
    gamesPlayed: gamesPlayed,
    playedGameTypes: playedGameTypes,
    categoryProgress: categoryProgress,
    completedStoryIds: completedStoryIds,
    storyBestStars: storyBestStars,
    gameBestStars: gameBestStars,
    signedWordKeys: signedWordKeys,
    lastActivityDate: lastActivityDate ?? DateTime(2026, 8, 25),
  );
}

UserProfile _profile({
  required UserRole role,
  bool isGuestPlayer = false,
  String? classroomId,
}) {
  return UserProfile(
    id: 'p1',
    name: 'Test',
    role: role,
    isGuestPlayer: isGuestPlayer,
    classroomId: classroomId,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('UserProfile.syncsProgressToCloud', () {
    test('a classroom-linked student syncs', () {
      expect(
        _profile(role: UserRole.student, classroomId: 'class-1')
            .syncsProgressToCloud,
        isTrue,
      );
    });

    test('an unlinked student does not', () {
      expect(
        _profile(role: UserRole.student).syncsProgressToCloud,
        isFalse,
        reason: 'nothing pushes for them, so nothing may pull either',
      );
    });

    test('Player With Progress does not, despite not being a guest', () {
      // The exact profile whose progress was rolled back on the tablet: a
      // Player role with isGuestPlayer == false, which the old listener gate
      // (`!isGuestPlayer`) waved straight through.
      final player = _profile(role: UserRole.player);
      expect(player.isGuestPlayer, isFalse);
      expect(player.isPlayerMode, isTrue);
      expect(player.syncsProgressToCloud, isFalse);
    });

    test('a guest player does not', () {
      expect(
        _profile(role: UserRole.player, isGuestPlayer: true)
            .syncsProgressToCloud,
        isFalse,
      );
    });
  });

  group('LearningProgress.mergeWith', () {
    test('a stale pull cannot roll back category progress', () {
      // The measured regression, as a unit test.
      final local = _progress(
        categoryProgress: {'Body Parts': 0.2333, 'Food & Drinks': 0.2503},
      );
      final staleCloud = _progress(
        categoryProgress: {'Body Parts': 0.1190, 'Food & Drinks': 0.1432},
      );

      final merged = local.mergeWith(staleCloud);

      expect(merged.categoryProgress['Body Parts'], closeTo(0.2333, 1e-9));
      expect(merged.categoryProgress['Food & Drinks'], closeTo(0.2503, 1e-9));
    });

    test('a genuinely newer pull is still applied', () {
      final local = _progress(categoryProgress: {'Numbers': 0.10});
      final fresher = _progress(categoryProgress: {'Numbers': 0.80});
      expect(
        local.mergeWith(fresher).categoryProgress['Numbers'],
        closeTo(0.80, 1e-9),
      );
    });

    test('counters take the max in both directions', () {
      final a = _progress(totalStars: 100, gamesPlayed: 40, bestStreakDays: 9);
      final b = _progress(totalStars: 60, gamesPlayed: 55, bestStreakDays: 3);

      final ab = a.mergeWith(b);
      final ba = b.mergeWith(a);

      for (final m in [ab, ba]) {
        expect(m.totalStars, 100);
        expect(m.gamesPlayed, 55);
        expect(m.effectiveBestStreak, 9);
      }
    });

    test('spent stars take the max, so a sync never refunds', () {
      // Picking the lower figure would hand back stars the other device
      // already spent, and the shop would let them be spent twice.
      final local = _progress(totalStars: 100, spentStars: 10);
      final cloud = _progress(totalStars: 100, spentStars: 60);
      expect(local.mergeWith(cloud).spentStars, 60);
      expect(cloud.mergeWith(local).spentStars, 60);
      expect(local.mergeWith(cloud).starBalance, 40);
    });

    test('sets union rather than replace', () {
      final a = _progress(
        learnedWordIds: {'w1', 'w2'},
        playedGameTypes: {GameType.wordMatch},
        completedStoryIds: {'s1'},
        signedWordKeys: {'sign-a'},
      );
      final b = _progress(
        learnedWordIds: {'w2', 'w3'},
        playedGameTypes: {GameType.memoryMatch},
        completedStoryIds: {'s2'},
        signedWordKeys: {'sign-b'},
      );

      final m = a.mergeWith(b);
      expect(m.learnedWordIds, {'w1', 'w2', 'w3'});
      expect(m.playedGameTypes, contains(GameType.wordMatch));
      expect(m.playedGameTypes, contains(GameType.memoryMatch));
      expect(m.completedStoryIds, {'s1', 's2'});
      expect(m.signedWordKeys, {'sign-a', 'sign-b'});
    });

    test('wordsLearned follows the union, never a stale counter', () {
      final a = _progress(learnedWordIds: {'w1', 'w2'}, wordsLearned: 2);
      final b = _progress(learnedWordIds: {'w3'}, wordsLearned: 1);
      expect(a.mergeWith(b).wordsLearned, 3);
    });

    test('per-key bests take the max per key', () {
      final a = _progress(
        storyBestStars: {'story-1': 3, 'story-2': 1},
        gameBestStars: {'wordMatch': 3},
      );
      final b = _progress(
        storyBestStars: {'story-2': 2, 'story-3': 1},
        gameBestStars: {'wordMatch': 1, 'memoryMatch': 2},
      );

      final m = a.mergeWith(b);
      expect(m.storyBestStars, {'story-1': 3, 'story-2': 2, 'story-3': 1});
      expect(m.gameBestStars['wordMatch'], 3);
      expect(m.gameBestStars['memoryMatch'], 2);
    });

    test('the streak follows the more recent row', () {
      final older = _progress(
        streakDays: 9,
        lastActivityDate: DateTime(2026, 8, 20),
      );
      final newer = _progress(
        streakDays: 2,
        lastActivityDate: DateTime(2026, 8, 25),
      );

      final m = older.mergeWith(newer);
      expect(m.streakDays, 2, reason: 'the current run is a calendar fact');
      expect(m.lastActivityDate, DateTime(2026, 8, 25));
      expect(m.effectiveBestStreak, 9, reason: 'but the record still stands');
    });

    test('merging is idempotent', () {
      final a = _progress(
        totalStars: 40,
        learnedWordIds: {'w1'},
        categoryProgress: {'Numbers': 0.4},
      );
      final once = a.mergeWith(a);
      final twice = once.mergeWith(a);
      expect(twice.totalStars, once.totalStars);
      expect(twice.learnedWordIds, once.learnedWordIds);
      expect(twice.categoryProgress, once.categoryProgress);
    });

    test('merging an empty cloud row leaves local progress intact', () {
      // A profile whose document was never written: the case that produced
      // the rollback in the first place.
      final local = _progress(
        totalStars: 51,
        wordsLearned: 31,
        learnedWordIds: {for (var i = 0; i < 31; i++) 'w$i'},
        gamesPlayed: 12,
        categoryProgress: {'Body Parts': 0.2333},
      );
      final empty = _progress();

      final m = local.mergeWith(empty);
      expect(m.totalStars, 51);
      expect(m.wordsLearned, 31);
      expect(m.gamesPlayed, 12);
      expect(m.categoryProgress['Body Parts'], closeTo(0.2333, 1e-9));
    });
  });
}
