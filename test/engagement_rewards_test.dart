import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/core/services/xp_level_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // 1. Daily Login Rewards
  // ─────────────────────────────────────────────────────
  group('DailyLoginReward', () {
    test('reward cycle has 7 days', () {
      final rewards = List.generate(7, (i) => DailyLoginReward.rewardForDay(i + 1));
      expect(rewards, [5, 5, 10, 10, 15, 15, 25]);
    });

    test('day 1 gives 5 stars', () {
      expect(DailyLoginReward.rewardForDay(1), 5);
    });

    test('day 7 gives 25 stars (max in cycle)', () {
      expect(DailyLoginReward.rewardForDay(7), 25);
    });

    test('cycle repeats after day 7', () {
      expect(DailyLoginReward.rewardForDay(8), DailyLoginReward.rewardForDay(1));
      expect(DailyLoginReward.rewardForDay(14), DailyLoginReward.rewardForDay(7));
      expect(DailyLoginReward.rewardForDay(15), DailyLoginReward.rewardForDay(1));
    });

    test('day 0 or negative defaults to first reward', () {
      expect(DailyLoginReward.rewardForDay(0), 5);
      expect(DailyLoginReward.rewardForDay(-1), 5);
    });

    test('total weekly reward is 85 stars', () {
      int total = 0;
      for (int i = 1; i <= 7; i++) {
        total += DailyLoginReward.rewardForDay(i);
      }
      expect(total, 85);
    });

    test('rewards escalate within a cycle', () {
      for (int i = 1; i < 7; i++) {
        expect(
          DailyLoginReward.rewardForDay(i),
          lessThanOrEqualTo(DailyLoginReward.rewardForDay(i + 1)),
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────
  // 2. XP & Level System
  // ─────────────────────────────────────────────────────
  group('XpService', () {
    LearningProgress makeProgress({
      int wordsLearned = 0,
      int totalStars = 0,
      int streakDays = 0,
      int gameCount = 0,
    }) {
      return LearningProgress(
        profileId: 'test',
        wordsLearned: wordsLearned,
        totalStars: totalStars,
        streakDays: streakDays,
        lastActivityDate: DateTime.now(),
        recentScores: List.generate(
          gameCount,
          (i) => GameScore(
            gameType: GameType.wordMatch,
            score: 5,
            total: 5,
            starsEarned: 3,
            date: DateTime.now(),
          ),
        ),
      );
    }

    test('XP formula: words=10, stars=2, streak=15, games=5', () {
      final p = makeProgress(
        wordsLearned: 10,
        totalStars: 50,
        streakDays: 5,
        gameCount: 4,
      );
      // 10*10 + 50*2 + 5*15 + 4*5 = 100 + 100 + 75 + 20 = 295
      expect(XpService.calculateXp(p), 295);
    });

    test('zero progress gives 0 XP', () {
      final p = makeProgress();
      expect(XpService.calculateXp(p), 0);
    });

    test('level 1 for 0 XP', () {
      final p = makeProgress();
      final level = XpService.currentLevel(p);
      expect(level.level, 1);
      expect(level.title, 'Beginner');
    });

    test('level 2 at 100 XP', () {
      // Need 100 XP = 10 words (100 XP)
      final p = makeProgress(wordsLearned: 10);
      expect(XpService.calculateXp(p), 100);
      expect(XpService.currentLevel(p).level, 2);
      expect(XpService.currentLevel(p).title, 'Explorer');
    });

    test('level 5 at 1000 XP', () {
      // 1000 XP = 50 words (500) + 100 stars (200) + 10 streak (150) + 30 games (150)
      final p = makeProgress(
        wordsLearned: 50,
        totalStars: 100,
        streakDays: 10,
        gameCount: 30,
      );
      expect(XpService.calculateXp(p), 1000);
      expect(XpService.currentLevel(p).level, 5);
      expect(XpService.currentLevel(p).title, 'Scholar');
    });

    test('there are 10 levels', () {
      expect(XpService.levels.length, 10);
    });

    test('levels are sorted by XP requirement', () {
      for (int i = 1; i < XpService.levels.length; i++) {
        expect(
          XpService.levels[i].xpRequired,
          greaterThan(XpService.levels[i - 1].xpRequired),
        );
      }
    });

    test('nextLevel returns null at max level', () {
      // Need 5500+ XP for max level: 400*10 + 500*2 = 5000, +30*15=450, +20*5=100 = 5550
      final p = makeProgress(wordsLearned: 400, totalStars: 500, streakDays: 30, gameCount: 20);
      final xp = XpService.calculateXp(p);
      expect(xp, greaterThanOrEqualTo(5500));
      expect(XpService.nextLevel(p), isNull);
    });

    test('progressToNextLevel is 1.0 at max level', () {
      final p = makeProgress(wordsLearned: 400, totalStars: 500, streakDays: 30, gameCount: 20);
      expect(XpService.progressToNextLevel(p), 1.0);
    });

    test('progressToNextLevel is between 0 and 1 mid-level', () {
      // 50 XP — level 1 (0 XP), next is level 2 (100 XP), progress = 50/100
      final p = makeProgress(wordsLearned: 5); // 50 XP
      expect(XpService.calculateXp(p), 50);
      expect(XpService.progressToNextLevel(p), closeTo(0.5, 0.01));
    });

    test('levelForXp handles exact threshold values', () {
      expect(XpService.levelForXp(0).level, 1);
      expect(XpService.levelForXp(99).level, 1);
      expect(XpService.levelForXp(100).level, 2);
      expect(XpService.levelForXp(299).level, 2);
      expect(XpService.levelForXp(300).level, 3);
    });

    test('each level has a unique emoji', () {
      final emojis = XpService.levels.map((l) => l.emoji).toSet();
      expect(emojis.length, XpService.levels.length);
    });
  });

  // ─────────────────────────────────────────────────────
  // 3. Star Shop Enhancements
  // ─────────────────────────────────────────────────────
  group('ShopData enhancements', () {
    test('new item types exist in enum', () {
      expect(ShopItemType.values, contains(ShopItemType.title));
      expect(ShopItemType.values, contains(ShopItemType.soundPack));
      expect(ShopItemType.values, contains(ShopItemType.celebration));
    });

    test('title items are available', () {
      final titles = ShopData.byType(ShopItemType.title);
      expect(titles.length, greaterThanOrEqualTo(4));
      for (final item in titles) {
        expect(item.type, ShopItemType.title);
        expect(item.cost, greaterThan(0));
        expect(item.name, isNotEmpty);
      }
    });

    test('sound pack items are available', () {
      final sounds = ShopData.byType(ShopItemType.soundPack);
      expect(sounds.length, greaterThanOrEqualTo(3));
      for (final item in sounds) {
        expect(item.type, ShopItemType.soundPack);
        expect(item.cost, greaterThan(0));
      }
    });

    test('celebration items are available', () {
      final celebrations = ShopData.byType(ShopItemType.celebration);
      expect(celebrations.length, greaterThanOrEqualTo(3));
      for (final item in celebrations) {
        expect(item.type, ShopItemType.celebration);
        expect(item.cost, greaterThan(0));
      }
    });

    test('all item IDs are unique', () {
      final ids = ShopData.allItems.map((i) => i.id).toSet();
      expect(ids.length, ShopData.allItems.length);
    });

    test('byType covers all items', () {
      int total = 0;
      for (final type in ShopItemType.values) {
        total += ShopData.byType(type).length;
      }
      expect(total, ShopData.allItems.length);
    });

    test('findById works for new items', () {
      expect(ShopData.findById('title_star_student'), isNotNull);
      expect(ShopData.findById('sound_chiptune'), isNotNull);
      expect(ShopData.findById('celebration_fireworks'), isNotNull);
    });

    test('total item count is 25', () {
      expect(ShopData.allItems.length, 25);
    });

    test('new items have valid cost ranges', () {
      for (final item in ShopData.allItems) {
        expect(item.cost, greaterThan(0));
        expect(item.cost, lessThanOrEqualTo(50));
      }
    });

    test('new items have non-empty emoji and description', () {
      for (final type in [ShopItemType.title, ShopItemType.soundPack, ShopItemType.celebration]) {
        for (final item in ShopData.byType(type)) {
          expect(item.emoji, isNotEmpty);
          expect(item.description, isNotEmpty);
        }
      }
    });
  });
}
