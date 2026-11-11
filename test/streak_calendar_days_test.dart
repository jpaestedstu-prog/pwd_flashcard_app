import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/progress/screens/streak_calendar_screen.dart';

/// Which days the Streak Calendar marks "studied".
///
/// Found on the tablet (30 Oct): the calendar marked four days in a row and
/// its best streak said 4, beside "0 Day Streak". The marks came from the
/// session log, which is written for any visit over five seconds; the streak
/// counts learning. The calendar now marks the days the streak counts.
void main() {
  final lastActivity = DateTime(2026, 10, 30, 0, 50);

  Set<String> days({
    Map<String, Map<String, int>> ledger = const {},
    List<String> challengeDays = const [],
    List<Map<String, dynamic>> sessions = const [],
    List<DateTime> scoreDates = const [],
    int streakDays = 0,
  }) =>
      learningDays(
        ledger: ledger,
        challengeDays: challengeDays,
        sessions: sessions,
        scoreDates: scoreDates,
        streakDays: streakDays,
        lastActivity: lastActivity,
      );

  test('a visit alone is not a day learned', () {
    expect(
      days(sessions: [
        for (final d in ['2026-10-27', '2026-10-28', '2026-10-29'])
          {'date': '${d}T09:00:00.000', 'gamesPlayed': 0, 'cardsReviewed': 0},
      ]),
      isEmpty,
    );
  });

  test('a session that played or reviewed is', () {
    expect(
      days(sessions: [
        {'date': '2026-10-27T09:00:00.000', 'gamesPlayed': 1},
        {'date': '2026-10-28T09:00:00.000', 'cardsReviewed': 4},
      ]),
      {'2026-10-27', '2026-10-28'},
    );
  });

  test('the ledger, the daily challenge and game scores mark their days', () {
    expect(
      days(
        ledger: {
          '2026-10-20': {'games': 2, 'stars': 3, 'words': 1},
          '2026-10-21': {'games': 0, 'stars': 0, 'words': 0, 'activities': 1},
          '2026-10-22': {'games': 0, 'stars': 0, 'words': 0},
        },
        challengeDays: ['2026-10-23'],
        scoreDates: [DateTime(2026, 10, 24, 18, 5)],
      ),
      {'2026-10-20', '2026-10-21', '2026-10-23', '2026-10-24'},
    );
  });

  test("the current streak's days are always marked", () {
    // Learning from before the ledger noted every activity: the streak
    // itself says which days it counted.
    expect(days(streakDays: 3), {'2026-10-28', '2026-10-29', '2026-10-30'});
  });

  test('a streak is counted back across the start of a month', () {
    expect(
      learningDays(
        ledger: const {},
        challengeDays: const [],
        sessions: const [],
        scoreDates: const [],
        streakDays: 3,
        lastActivity: DateTime(2026, 11, 1, 8),
      ),
      {'2026-10-30', '2026-10-31', '2026-11-01'},
    );
  });

  test('a profile with no streak and no learning marks nothing', () {
    // A new profile's last activity is the day it was made.
    expect(days(), isEmpty);
  });
}
