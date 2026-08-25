import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/tv_cast_provider.dart';

/// Who appears on the cast leaderboard.
///
/// It filtered `role == UserRole.student`, so a Parent casting their home
/// group — whose members are all `child` — put an empty board on the TV. That
/// is the same invariant every other educator roster consumer already follows:
/// classroom students *and* home-group children, guests excluded. See
/// `UserRoleX.isEnrollableLearner`.
///
/// These run against the extracted pure builder; the ranking and totals had no
/// test at all before, which is part of why the filter went unnoticed.
void main() {
  final now = DateTime(2026, 8, 22, 12);

  (UserProfile, LearningProgress) learner(
    String name,
    UserRole role, {
    int stars = 0,
    int words = 0,
    int streak = 0,
    bool guest = false,
    DateTime? lastActive,
  }) => (
    UserProfile(
      id: name,
      name: name,
      role: role,
      isGuestPlayer: guest,
      createdAt: DateTime(2026),
    ),
    LearningProgress(
      profileId: name,
      lastActivityDate: lastActive ?? DateTime(2020),
      totalStars: stars,
      wordsLearned: words,
      streakDays: streak,
    ),
  );

  test('home-group children appear on the board', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner('Anak', UserRole.child, stars: 30),
      learner('Student', UserRole.student, stars: 10),
    ], now: now);

    expect(
      views.ranked.map((r) => r.name),
      ['Anak', 'Student'],
      reason: 'a Parent casting their home group used to see nothing at all',
    );
    expect(views.summary.learnerCount, 2);
  });

  test('a parent with only children still gets a board', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner('Anak A', UserRole.child, stars: 5),
      learner('Anak B', UserRole.child, stars: 8),
    ], now: now);

    expect(views.ranked, hasLength(2));
    expect(views.ranked.first.name, 'Anak B');
  });

  test('guests and educators are left off', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner('Student', UserRole.student, stars: 1),
      learner('Guest', UserRole.player, stars: 99, guest: true),
      learner('Progress Player', UserRole.player, stars: 98),
      learner('Teacher', UserRole.teacher, stars: 97),
      learner('Parent', UserRole.parent, stars: 96),
    ], now: now);

    expect(views.ranked.map((r) => r.name), ['Student']);
    expect(views.summary.learnerCount, 1);
  });

  test('ranking is by stars, highest first', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner('Low', UserRole.student, stars: 1),
      learner('High', UserRole.child, stars: 50),
      learner('Mid', UserRole.student, stars: 20),
    ], now: now);

    expect(views.ranked.map((r) => r.name), ['High', 'Mid', 'Low']);
    expect(views.ranked.map((r) => r.rank), [1, 2, 3]);
  });

  test('the ranked board stops at ten so it fits on a TV', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      for (var i = 0; i < 15; i++)
        learner('L$i', UserRole.student, stars: i),
    ], now: now);

    expect(views.ranked, hasLength(10));
    expect(views.summary.learnerCount, 15, reason: 'the count is not capped');
  });

  test('the class list is A-Z, capped at twelve, and unranked', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      for (var i = 0; i < 15; i++)
        learner('Learner ${i.toString().padLeft(2, '0')}', UserRole.child),
    ], now: now);

    expect(views.summary.rows, hasLength(12));
    expect(views.summary.rows.first.name, 'Learner 00');
    expect(views.summary.rows.every((r) => r.rank == 0), isTrue);
  });

  test('totals cover everyone, not just the twelve shown', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      for (var i = 0; i < 15; i++)
        learner('L$i', UserRole.student, stars: 2, words: 3),
    ], now: now);

    expect(views.summary.starsTotal, 30);
    expect(views.summary.wordsTotal, 45);
  });

  test('active-today counts the last 24 hours from the given moment', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner(
        'Just now',
        UserRole.child,
        lastActive: now.subtract(const Duration(hours: 1)),
      ),
      learner(
        'Yesterday',
        UserRole.student,
        lastActive: now.subtract(const Duration(hours: 30)),
      ),
    ], now: now);

    expect(views.summary.activeToday, 1);
  });

  test('best streak is the highest across the whole roster', () {
    final views = TvCastSessionNotifier.buildProgressViews([
      learner('A', UserRole.student, streak: 3),
      learner('B', UserRole.child, streak: 11),
      learner('C', UserRole.student, streak: 7),
    ], now: now);

    expect(views.summary.bestStreak, 11);
  });

  test('an empty roster is an empty board, not a crash', () {
    final views = TvCastSessionNotifier.buildProgressViews(const [], now: now);

    expect(views.ranked, isEmpty);
    expect(views.summary.learnerCount, 0);
    expect(views.summary.bestStreak, 0);
  });
}
