import '../../data/local/hive_service.dart';

/// Daily login reward tier — 7-day cycle with escalating star rewards.
class DailyLoginReward {
  /// Star rewards for days 1–7 of the cycle.
  static const List<int> _rewards = [5, 5, 10, 10, 15, 15, 25];

  /// Returns the star reward for a given day in the streak (1-based).
  /// After day 7 the cycle repeats.
  static int rewardForDay(int day) {
    if (day <= 0) return _rewards[0];
    return _rewards[(day - 1) % _rewards.length];
  }

  /// Whether the user has already claimed today's reward.
  static bool hasClaimedToday(String profileId) {
    final lastClaim = HiveService.getLoginRewardDate(profileId);
    if (lastClaim == null) return false;
    final today = _todayKey();
    return lastClaim == today;
  }

  /// The current login reward streak (consecutive days claimed).
  static int getStreak(String profileId) {
    return HiveService.getLoginRewardStreak(profileId);
  }

  /// Claims today's reward. Returns the number of stars earned,
  /// or 0 if already claimed.
  static Future<int> claimReward(String profileId) async {
    if (hasClaimedToday(profileId)) return 0;

    final lastClaim = HiveService.getLoginRewardDate(profileId);
    final today = _todayKey();
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    int streak;
    if (lastClaim == yesterday) {
      // Consecutive day — increment streak
      streak = HiveService.getLoginRewardStreak(profileId) + 1;
    } else {
      // Gap or first time — reset to day 1
      streak = 1;
    }

    await HiveService.saveLoginRewardDate(profileId, today);
    await HiveService.saveLoginRewardStreak(profileId, streak);

    return rewardForDay(streak);
  }

  /// Date key for today.
  static String _todayKey() => _dateKey(DateTime.now());

  /// Format a DateTime as a YYYY-MM-DD string.
  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
