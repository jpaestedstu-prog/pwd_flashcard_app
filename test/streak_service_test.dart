import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/streak_service.dart';

void main() {
  group('StreakService.nextStreak', () {
    test('first-ever activity starts the streak at 1', () {
      final now = DateTime(2026, 5, 30, 9);
      expect(
        StreakService.nextStreak(
          prevStreak: 0,
          lastActivity: now, // value irrelevant when prevStreak <= 0
          now: now,
        ),
        1,
      );
    });

    test('migrated/zero streak heals to 1 even with a stale lastActivity', () {
      expect(
        StreakService.nextStreak(
          prevStreak: 0,
          lastActivity: DateTime(2026, 1, 15),
          now: DateTime(2026, 5, 30),
        ),
        1,
      );
    });

    test('same calendar day leaves the streak unchanged', () {
      expect(
        StreakService.nextStreak(
          prevStreak: 5,
          lastActivity: DateTime(2026, 5, 30, 8),
          now: DateTime(2026, 5, 30, 22),
        ),
        5,
      );
    });

    test('late-night then early-morning still counts as the same day', () {
      // The classic inDays bug: 23:00 -> 01:00 is < 24h but a new calendar day.
      // Here it is the SAME calendar day, so the streak must not advance twice.
      expect(
        StreakService.nextStreak(
          prevStreak: 3,
          lastActivity: DateTime(2026, 5, 30, 23, 10),
          now: DateTime(2026, 5, 30, 23, 30),
        ),
        3,
      );
    });

    test('consecutive day increments the streak', () {
      expect(
        StreakService.nextStreak(
          prevStreak: 3,
          lastActivity: DateTime(2026, 5, 29, 23),
          now: DateTime(2026, 5, 30, 1),
        ),
        4,
      );
    });

    test('a gap of more than one day resets to 1', () {
      expect(
        StreakService.nextStreak(
          prevStreak: 9,
          lastActivity: DateTime(2026, 5, 28),
          now: DateTime(2026, 5, 30),
        ),
        1,
      );
    });

    test('clock moving backwards resets to 1 rather than going negative', () {
      expect(
        StreakService.nextStreak(
          prevStreak: 4,
          lastActivity: DateTime(2026, 5, 30),
          now: DateTime(2026, 5, 28),
        ),
        1,
      );
    });
  });

  group('StreakService.isActiveToday', () {
    test('true for any time on the same calendar day', () {
      expect(
        StreakService.isActiveToday(
          DateTime(2026, 5, 30, 0, 1),
          now: DateTime(2026, 5, 30, 23, 59),
        ),
        isTrue,
      );
    });

    test('false across a midnight boundary even within 24 hours', () {
      expect(
        StreakService.isActiveToday(
          DateTime(2026, 5, 29, 23, 10),
          now: DateTime(2026, 5, 30, 1, 10),
        ),
        isFalse,
      );
    });
  });

  group('StreakService.dayDelta', () {
    test('counts calendar days, ignoring time-of-day', () {
      expect(
        StreakService.dayDelta(
          DateTime(2026, 5, 29, 23, 59),
          DateTime(2026, 5, 30, 0, 1),
        ),
        1,
      );
    });
  });
}
