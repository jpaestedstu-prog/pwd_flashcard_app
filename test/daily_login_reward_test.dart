import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';

/// The Daily Reward's claim rules, against the real Hive keys: once a day,
/// a day in a row carries the run on, a missed day starts it again, and each
/// profile keeps its own. The star table itself is pinned in
/// `engagement_rewards_test.dart`.

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> _initHive() async {
  Hive.init('./build/test_cache/daily_login_reward');
  if (!Hive.isBoxOpen('progress')) {
    await Hive.openBox('progress', compactionStrategy: (_, _) => false);
  }
}

void main() {
  setUpAll(_initHive);
  setUp(() async => Hive.box('progress').clear());

  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));

  test('the first claim is day 1, and pays 5 stars once', () async {
    expect(DailyLoginReward.hasClaimedToday('ana'), isFalse);
    expect(await DailyLoginReward.claimReward('ana'), 5);
    expect(DailyLoginReward.getStreak('ana'), 1);
    expect(DailyLoginReward.hasClaimedToday('ana'), isTrue);
    expect(await DailyLoginReward.claimReward('ana'), 0,
        reason: 'opening Home again the same day pays nothing');
  });

  test('a day in a row carries the run on: day 2 pays 5', () async {
    // What the tablet showed for Visual Impairment Student on 28 Oct, after
    // a claim on 27 Oct.
    await HiveService.saveLoginRewardDate('ana', _key(yesterday));
    await HiveService.saveLoginRewardStreak('ana', 1);
    expect(await DailyLoginReward.claimReward('ana'), 5);
    expect(DailyLoginReward.getStreak('ana'), 2);
  });

  test('day 3 pays 10, day 7 pays 25, day 8 starts the cycle again',
      () async {
    for (final (streakBefore, stars) in [(2, 10), (6, 25), (7, 5)]) {
      await HiveService.saveLoginRewardDate('ana', _key(yesterday));
      await HiveService.saveLoginRewardStreak('ana', streakBefore);
      expect(await DailyLoginReward.claimReward('ana'), stars,
          reason: 'day ${streakBefore + 1}');
    }
  });

  test('a missed day starts the run again at day 1', () async {
    await HiveService.saveLoginRewardDate('ana', _key(twoDaysAgo));
    await HiveService.saveLoginRewardStreak('ana', 5);
    expect(await DailyLoginReward.claimReward('ana'), 5);
    expect(DailyLoginReward.getStreak('ana'), 1);
  });

  test('each profile keeps its own day', () async {
    await HiveService.saveLoginRewardDate('ana', _key(yesterday));
    await HiveService.saveLoginRewardStreak('ana', 6);
    expect(await DailyLoginReward.claimReward('ben'), 5);
    expect(DailyLoginReward.getStreak('ben'), 1);
    expect(DailyLoginReward.hasClaimedToday('ana'), isFalse,
        reason: "Ben's claim is not Ana's");
    expect(await DailyLoginReward.claimReward('ana'), 25);
  });
}
