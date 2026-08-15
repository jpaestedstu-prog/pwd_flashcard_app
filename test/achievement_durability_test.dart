import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/game_catalog.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Guards the rule the XP economy already lives by, applied to badges:
/// **nothing a learner has earned is ever taken away.**
///
/// `LearningProgress.streakDays` resets to 1 on a missed day and
/// `recentScores` is trimmed to the last 20 entries, so any achievement that
/// reads either of them is revocable — the badge simply disappears from the
/// Progress tab. Worse, `checkAchievements()` re-persists the *currently*
/// unlocked set, so the vanished badge is deleted from Hive (and pushed to
/// Firestore) too.
///
/// See [[xp-level-economy]] for the same fix applied to XP.
void main() {
  LearningProgress base({
    int streakDays = 0,
    int bestStreakDays = 0,
    List<GameScore> recentScores = const [],
    Set<String> completedStoryIds = const {},
    Map<String, int> storyBestStars = const {},
    Set<GameType> playedGameTypes = const {},
  }) {
    return LearningProgress(
      profileId: 'test',
      lastActivityDate: DateTime.now(),
      streakDays: streakDays,
      bestStreakDays: bestStreakDays,
      recentScores: recentScores,
      completedStoryIds: completedStoryIds,
      storyBestStars: storyBestStars,
      playedGameTypes: playedGameTypes,
    );
  }

  GameScore score(GameType type, {int s = 5, int total = 5}) => GameScore(
    gameType: type,
    score: s,
    total: total,
    starsEarned: 3,
    date: DateTime.now(),
  );

  group('streak badges survive a broken streak', () {
    test('30-day badge stays unlocked after the streak resets to 1', () {
      final onStreak = base(streakDays: 30, bestStreakDays: 30);
      expect(
        Achievements.unlockedIds(onStreak),
        containsAll({
          'three_day_streak',
          'week_streak',
          'two_week_streak',
          'month_streak',
        }),
      );

      // Learner is ill for a weekend: StreakService.nextStreak resets the
      // current run to 1 while the high-water mark stands.
      final afterGap = base(streakDays: 1, bestStreakDays: 30);
      expect(
        Achievements.unlockedIds(afterGap),
        containsAll({
          'three_day_streak',
          'week_streak',
          'two_week_streak',
          'month_streak',
        }),
        reason: 'a broken streak must not un-earn streak badges',
      );
    });

    test('a streak never reached still does not unlock', () {
      final never = base(streakDays: 2, bestStreakDays: 2);
      final ids = Achievements.unlockedIds(never);
      expect(ids.contains('three_day_streak'), isFalse);
      expect(ids.contains('week_streak'), isFalse);
    });
  });

  group('story badges read the durable story record', () {
    test('first_story survives the quiz aging out of recentScores', () {
      final justFinished = base(
        recentScores: [score(GameType.storyQuiz, s: 3, total: 3)],
        completedStoryIds: {'story-1'},
        storyBestStars: {'story-1': 3},
      );
      expect(
        Achievements.unlockedIds(justFinished),
        containsAll({'first_story', 'story_perfect'}),
      );

      // 20 games later the story quiz has fallen out of the window, but the
      // story record itself is permanent.
      final later = base(
        recentScores: List.generate(20, (_) => score(GameType.wordMatch)),
        completedStoryIds: {'story-1'},
        storyBestStars: {'story-1': 3},
      );
      expect(
        Achievements.unlockedIds(later),
        containsAll({'first_story', 'story_perfect'}),
        reason: 'story badges must not depend on the 20-entry score window',
      );
    });

    test('story_perfect needs a 3-star quiz, not merely a finished story', () {
      final read = base(
        completedStoryIds: {'story-1'},
        storyBestStars: {'story-1': 2},
      );
      final ids = Achievements.unlockedIds(read);
      expect(ids.contains('first_story'), isTrue);
      expect(ids.contains('story_perfect'), isFalse);
    });
  });

  group('game_explorer is reachable and durable', () {
    test('is earnable by every accessibility category roster', () {
      for (final type in DisabilityType.values) {
        // Every game the learner can actually reach: their curated hub roster
        // plus Story Quiz, which lives on the Stories tab. FSL Practice is a
        // hub screen, not a scoreable game, so it can never be recorded.
        final reachable = {
          ...GameCatalog.forCategory(type),
          GameType.storyQuiz,
        }..remove(GameType.fslPractice);

        final progress = base(playedGameTypes: reachable);
        expect(
          Achievements.unlockedIds(progress).contains('game_explorer'),
          isTrue,
          reason:
              'Game Explorer must be reachable for ${type.label} learners — '
              'their roster only offers ${reachable.length} scoreable games',
        );
      }
    });

    test('survives games aging out of the 20-entry window', () {
      final played = {
        GameType.wordMatch,
        GameType.spellingBee,
        GameType.memoryMatch,
        GameType.pronunciation,
        GameType.sentenceBuilder,
        GameType.tracing,
        GameType.yesOrNo,
        GameType.oddOneOut,
      };
      final progress = base(
        playedGameTypes: played,
        // Nothing but Word Match still on hand.
        recentScores: List.generate(20, (_) => score(GameType.wordMatch)),
      );
      expect(
        Achievements.unlockedIds(progress).contains('game_explorer'),
        isTrue,
      );
    });

    test('does not unlock for a learner who has tried only a few games', () {
      final progress = base(
        playedGameTypes: {GameType.wordMatch, GameType.memoryMatch},
      );
      expect(
        Achievements.unlockedIds(progress).contains('game_explorer'),
        isFalse,
      );
    });
  });

  group('durableUnlockedIds never shrinks', () {
    test('keeps a badge that the live check no longer reports', () {
      final afterGap = base(streakDays: 1);
      final union = Achievements.durableUnlockedIds(
        progress: afterGap,
        previouslyUnlockedIds: {'perfect_score', 'month_streak'},
      );
      expect(union, containsAll({'perfect_score', 'month_streak'}));
    });

    test('still adds newly earned badges', () {
      final perfect = base(recentScores: [score(GameType.wordMatch)]);
      final union = Achievements.durableUnlockedIds(
        progress: perfect,
        previouslyUnlockedIds: {'first_word'},
      );
      expect(union, containsAll({'first_word', 'perfect_score'}));
    });

    test('drops ids that no longer name a real achievement', () {
      final union = Achievements.durableUnlockedIds(
        progress: base(),
        previouslyUnlockedIds: {'a_badge_we_removed'},
      );
      expect(union.contains('a_badge_we_removed'), isFalse);
    });
  });

  group('word badges describe a target that exists', () {
    // The deck used to hold 144 words, so "half way" (72) and "all 144 words"
    // were literally true. It holds 177 now — and a learner may add custom
    // cards on top — so any badge that promises the *whole* vocabulary at a
    // fixed count is naming a finish line that has moved.
    test('word_master does not promise the whole deck', () {
      final desc = Achievements.wordMaster.description.toLowerCase();
      final deckSize = SeedData.allFlashcards.length;
      expect(
        desc.contains('all '),
        isFalse,
        reason:
            'word_master unlocks well short of the $deckSize-word deck, so it '
            'must not claim "all the words": "$desc"',
      );
    });

    test('half_way does not promise a share of the deck', () {
      final desc = Achievements.halfWay.description.toLowerCase();
      expect(
        desc.contains('all vocabulary'),
        isFalse,
        reason: 'its 72-word threshold is not half of the deck any more',
      );
    });
  });
}
