import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/models/teacher_analytics_models.dart';

/// Regression tests for the Class Analytics aggregation.
///
/// These pin the three defects found during the 2026-07-29 tablet review:
/// never-played learners were flagged as "needing help", the class average
/// was dragged toward zero by them, and the medal ranking was arbitrary
/// because it sorted on `wordsLearned` alone (which was itself always 0).
void main() {
  final now = DateTime(2026, 7, 29, 12);

  StudentAnalytics learner({
    required String name,
    int wordsLearned = 0,
    int totalStars = 0,
    int gamesPlayed = 0,
    double accuracy = 0.0,
    Duration since = Duration.zero,
    Map<String, double> categories = const {},
  }) {
    return StudentAnalytics(
      profileId: name,
      name: name,
      avatarIndex: 0,
      wordsLearned: wordsLearned,
      totalStars: totalStars,
      streakDays: 0,
      gamesPlayed: gamesPlayed,
      averageAccuracy: accuracy,
      categoryProgress: categories,
      totalStudyTime: Duration.zero,
      lastActive: now.subtract(since),
    );
  }

  group('StudentStanding', () {
    test('a learner with no graded games is notStarted, never needsHelp', () {
      final s = learner(name: 'Fresh');
      expect(s.hasGradedActivity, isFalse);
      expect(s.standing(now: now), StudentStanding.notStarted);
      expect(s.standing(now: now).needsHelp, isFalse);
    });

    test('low accuracy on too few games is not yet struggling', () {
      final s = learner(name: 'Unlucky', gamesPlayed: 2, accuracy: 0.1);
      expect(s.standing(now: now), StudentStanding.onTrack);
    });

    test('low accuracy over enough games is struggling', () {
      final s = learner(
        name: 'Struggler',
        gamesPlayed: StudentStanding.minGradedGames,
        accuracy: 0.2,
      );
      expect(s.standing(now: now), StudentStanding.struggling);
      expect(s.standing(now: now).needsHelp, isTrue);
    });

    test('active learner past 7 days is inactive, not struggling', () {
      final s = learner(
        name: 'Away',
        gamesPlayed: 10,
        accuracy: 0.2,
        since: const Duration(days: 9),
      );
      expect(s.standing(now: now), StudentStanding.inactive);
      expect(s.standing(now: now).needsHelp, isFalse);
    });
  });

  group('ClassAnalytics.fromStudents', () {
    test('needs-help excludes learners who never played', () {
      final analytics = ClassAnalytics.fromStudents([
        learner(name: 'NeverPlayed'),
        learner(name: 'AlsoNever'),
        learner(name: 'Struggling', gamesPlayed: 5, accuracy: 0.3),
      ]);

      expect(
        analytics.studentsNeedingHelp.map((s) => s.name),
        ['Struggling'],
      );
    });

    test('class average ignores learners with no graded games', () {
      // One learner at 100%, five who never played. The old mean over all
      // six reported 17%; the class average should reflect actual work.
      final analytics = ClassAnalytics.fromStudents([
        learner(name: 'Ace', gamesPlayed: 3, accuracy: 1.0),
        for (var i = 0; i < 5; i++) learner(name: 'Idle$i'),
      ]);

      expect(analytics.classAverageAccuracy, 1.0);
    });

    test('class average is 0 when nobody has played', () {
      final analytics = ClassAnalytics.fromStudents([
        learner(name: 'A'),
        learner(name: 'B'),
      ]);
      expect(analytics.classAverageAccuracy, 0.0);
    });

    test('ranking breaks word-count ties by accuracy, not insertion order',
        () {
      // The exact on-device shape: everyone at 0 words, but one learner has
      // 100% accuracy and stars. They must rank first, not fifth.
      final analytics = ClassAnalytics.fromStudents([
        learner(name: 'Normal'),
        learner(name: 'Multiple'),
        learner(name: 'Cognitive', totalStars: 10, gamesPlayed: 1),
        learner(name: 'Motor', totalStars: 10, gamesPlayed: 1),
        learner(
          name: 'Deaf',
          totalStars: 15,
          gamesPlayed: 1,
          accuracy: 1.0,
        ),
        learner(name: 'Visual', totalStars: 10, gamesPlayed: 1),
      ]);

      expect(analytics.students.first.name, 'Deaf');
    });

    test('word count still outranks accuracy', () {
      final analytics = ClassAnalytics.fromStudents([
        learner(name: 'Accurate', gamesPlayed: 3, accuracy: 1.0),
        learner(
          name: 'Prolific',
          wordsLearned: 40,
          gamesPlayed: 3,
          accuracy: 0.6,
        ),
      ]);

      expect(analytics.students.first.name, 'Prolific');
    });

    test('ranking is deterministic for wholly tied learners', () {
      List<String> order() => ClassAnalytics.fromStudents([
            learner(name: 'charlie'),
            learner(name: 'alice'),
            learner(name: 'bob'),
          ]).students.map((s) => s.name).toList();

      expect(order(), ['alice', 'bob', 'charlie']);
      expect(order(), order());
    });

    test('a flat category spread reports no strongest or weakest', () {
      // Every category at 0% — the old first-wins scan still crowned one
      // category and red-flagged another.
      final analytics = ClassAnalytics.fromStudents([
        learner(
          name: 'Idle',
          categories: const {'Animals': 0.0, 'Food & Drinks': 0.0},
        ),
      ]);

      expect(analytics.classStrongestCategory, isNull);
      expect(analytics.classWeakestCategory, isNull);
    });

    test('a real category spread reports both ends', () {
      final analytics = ClassAnalytics.fromStudents([
        learner(
          name: 'Mixed',
          categories: const {'Animals': 0.8, 'Food & Drinks': 0.1},
        ),
      ]);

      expect(analytics.classStrongestCategory, 'Animals');
      expect(analytics.classWeakestCategory, 'Food & Drinks');
    });
  });

  group('StudentAnalytics.from', () {
    test('derives accuracy and games from recent scores', () {
      final progress = LearningProgress(
        profileId: 'p1',
        wordsLearned: 4,
        lastActivityDate: now,
        recentScores: [
          GameScore(
            gameType: GameType.wordMatch,
            score: 8,
            total: 10,
            starsEarned: 3,
            date: now,
          ),
          GameScore(
            gameType: GameType.wordMatch,
            score: 6,
            total: 10,
            starsEarned: 2,
            date: now,
          ),
        ],
      );
      final profile = UserProfile(
        id: 'p1',
        name: 'Learner',
        role: UserRole.student,
        createdAt: now,
      );

      final s = StudentAnalytics.from(profile, progress);

      expect(s.gamesPlayed, 2);
      expect(s.averageAccuracy, closeTo(0.7, 1e-9));
      expect(s.hasGradedActivity, isTrue);
      expect(s.standing(now: now), StudentStanding.onTrack);
    });
  });
}
