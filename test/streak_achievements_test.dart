import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

void main() {
  group('New streak achievements', () {
    LearningProgress progress({int streakDays = 0}) => LearningProgress(
          profileId: 'test',
          streakDays: streakDays,
          lastActivityDate: DateTime.now(),
        );

    test('twoWeekStreak does NOT unlock at 13 days', () {
      final ids = Achievements.unlockedIds(progress(streakDays: 13));
      expect(ids.contains('two_week_streak'), false);
    });

    test('twoWeekStreak unlocks at 14 days', () {
      final ids = Achievements.unlockedIds(progress(streakDays: 14));
      expect(ids.contains('two_week_streak'), true);
    });

    test('monthStreak does NOT unlock at 29 days', () {
      final ids = Achievements.unlockedIds(progress(streakDays: 29));
      expect(ids.contains('month_streak'), false);
    });

    test('monthStreak unlocks at 30 days', () {
      final ids = Achievements.unlockedIds(progress(streakDays: 30));
      expect(ids.contains('month_streak'), true);
    });

    test('30-day streak unlocks all streak achievements', () {
      final ids = Achievements.unlockedIds(progress(streakDays: 30));
      expect(ids.contains('three_day_streak'), true);
      expect(ids.contains('week_streak'), true);
      expect(ids.contains('two_week_streak'), true);
      expect(ids.contains('month_streak'), true);
    });
  });

  group('Achievement uniqueness (including new ones)', () {
    test('all achievements still have unique IDs', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(ids.length, Achievements.all.length);
    });

    test('twoWeekStreak and monthStreak are in all list', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(ids.contains('two_week_streak'), true);
      expect(ids.contains('month_streak'), true);
    });
  });
}
