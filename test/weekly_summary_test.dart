import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/session_tracker.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/features/progress/models/weekly_summary.dart';

/// "This Week" and the day ledger it reads.
///
/// The ledger exists because no other record could answer the question: game
/// scores are trimmed to the last 20, so a week summary built on them would
/// shrink when a learner played *more*.
///
/// Plain `test()`, not `testWidgets`: a Hive write inside the fake-async zone
/// leaves its Future pending and hangs `deleteFromDisk` at teardown.
void main() {
  const profileId = 'p_week';
  final now = DateTime(2026, 8, 15, 12);

  setUpAll(() async {
    const dir = './build/test_cache/weekly_summary';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const <String>['profiles', 'settings', 'progress',
        'sessions']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (total, deleted) => false);
      }
    }
  });

  tearDown(() async {
    await Hive.box('progress').clear();
    await Hive.box('sessions').clear();
  });
  tearDownAll(() async => Hive.deleteFromDisk());

  test('an untouched profile reports an empty week', () {
    final week = WeeklySummary.forProfile(profileId, now: now);
    expect(week.isEmpty, isTrue);
    expect(week.daysActive, 0);
  });

  test('totals add up across the days in the window', () async {
    for (var i = 0; i < 3; i++) {
      await HiveService.addDailyActivity(
        profileId,
        games: 2,
        stars: 5,
        words: 1,
        on: now.subtract(Duration(days: i)),
      );
    }

    final week = WeeklySummary.forProfile(profileId, now: now);
    expect(week.daysActive, 3);
    expect(week.games, 6);
    expect(week.stars, 15);
    expect(week.words, 3);
    expect(week.isEmpty, isFalse);
  });

  test('activity older than the window is not counted', () async {
    await HiveService.addDailyActivity(
      profileId,
      games: 9,
      stars: 9,
      on: now.subtract(const Duration(days: 30)),
    );
    await HiveService.addDailyActivity(
      profileId,
      games: 1,
      stars: 2,
      on: now,
    );

    final week = WeeklySummary.forProfile(profileId, now: now);
    expect(week.games, 1);
    expect(week.stars, 2);
    expect(week.daysActive, 1);
  });

  test('the window is seven calendar days, inclusive of today', () async {
    // Day 6 back is inside the window; day 7 back is not.
    await HiveService.addDailyActivity(
      profileId,
      games: 1,
      on: now.subtract(const Duration(days: 6)),
    );
    await HiveService.addDailyActivity(
      profileId,
      games: 1,
      on: now.subtract(const Duration(days: 7)),
    );

    expect(WeeklySummary.forProfile(profileId, now: now).games, 1);
  });

  test('a busy week is not capped by the 20-entry score window', () async {
    // 40 games in one week — twice what `recentScores` can hold.
    for (var i = 0; i < 40; i++) {
      await HiveService.addDailyActivity(profileId, games: 1, stars: 1, on: now);
    }

    final week = WeeklySummary.forProfile(profileId, now: now);
    expect(week.games, 40);
    expect(week.stars, 40);
  });

  test('a day with only reading still counts as active', () async {
    // No game finished, so nothing lands in the ledger — but a session was
    // logged, which is the learner having been here.
    await HiveService.addSessionLog(profileId, {
      'date': now.subtract(const Duration(days: 1)).toIso8601String(),
      'durationSeconds': 600,
      'gamesPlayed': 0,
      'cardsReviewed': 12,
    });

    final week = WeeklySummary.forProfile(profileId, now: now);
    expect(week.daysActive, 1);
    expect(week.minutes, 10);
    expect(week.games, 0);
    expect(week.isEmpty, isFalse);
  });

  test('short sessions accumulate instead of each rounding to zero', () async {
    // Twelve 45-second sittings is nine minutes of study. Rounding each session
    // on its own threw every remainder away and reported the week as zero —
    // worst for the learners who work in the shortest bursts.
    for (var i = 0; i < 12; i++) {
      await HiveService.addSessionLog(profileId, {
        'date': now.toIso8601String(),
        'durationSeconds': 45,
        'gamesPlayed': 0,
        'cardsReviewed': 1,
      });
    }

    expect(WeeklySummary.forProfile(profileId, now: now).minutes, 9);
  });

  test('minutes match what the educator dashboard reports', () async {
    // The two surfaces describe the same learner's week and used to disagree:
    // this one truncated per session, `SessionTracker` sums seconds first.
    for (final seconds in const [50, 100, 20, 200, 35]) {
      await HiveService.addSessionLog(profileId, {
        'date': now.toIso8601String(),
        'durationSeconds': seconds,
        'gamesPlayed': 0,
        'cardsReviewed': 1,
      });
    }

    // Both sides are asked about the *same* instant. They used to be compared
    // with only one of them pinned, so this passed until real-now drifted more
    // than a week past the fixture and the SessionTracker side quietly went to
    // zero — a failure that had nothing to do with the behaviour under test.
    expect(
      WeeklySummary.forProfile(profileId, now: now).minutes,
      SessionTracker.totalStudyMinutes(
        profileId,
        days: WeeklySummary.days,
        now: now,
      ),
    );
  });

  test('a day that both played and studied is counted once', () async {
    await HiveService.addDailyActivity(profileId, games: 1, on: now);
    await HiveService.addSessionLog(profileId, {
      'date': now.toIso8601String(),
      'durationSeconds': 300,
      'gamesPlayed': 0,
      'cardsReviewed': 0,
    });

    expect(WeeklySummary.forProfile(profileId, now: now).daysActive, 1);
  });

  test('the ledger prunes itself to 90 days', () async {
    await HiveService.addDailyActivity(
      profileId,
      games: 1,
      on: DateTime.now().subtract(const Duration(days: 200)),
    );
    await HiveService.addDailyActivity(profileId, games: 1);

    expect(HiveService.getDailyActivity(profileId).length, 1);
  });

  group('SessionTracker.totalGamesPlayed', () {
    test('reads the ledger, so it is no longer a permanent zero', () async {
      // `recordGamePlayed()` is never called anywhere in the app, so every
      // session log carries gamesPlayed: 0 — this used to sum to 0 forever.
      await HiveService.addSessionLog(profileId, {
        'date': DateTime.now().toIso8601String(),
        'durationSeconds': 600,
        'gamesPlayed': 0,
        'cardsReviewed': 0,
      });
      await HiveService.addDailyActivity(profileId, games: 4);

      expect(SessionTracker.totalGamesPlayed(profileId), 4);
    });
  });
}
