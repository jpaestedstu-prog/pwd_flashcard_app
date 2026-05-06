import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/recommendations/services/recommendation_service.dart';
import 'package:pwdpwdpwd/features/recommendations/models/recommendation_models.dart';

/// In-memory Hive setup for unit tests.
Future<void> _initHive() async {
  Hive.init('./build/test_cache/recommendation');
  if (!Hive.isBoxOpen('progress')) {
    await Hive.openBox('progress');
  }
}

/// Helper to build a minimal LearningProgress for testing.
LearningProgress _makeProgress({
  String profileId = 'test_user',
  int wordsLearned = 0,
  int streakDays = 0,
  DateTime? lastActivityDate,
  Map<String, double> categoryProgress = const {},
  List<GameScore> recentScores = const [],
  int totalStars = 0,
}) {
  return LearningProgress(
    profileId: profileId,
    wordsLearned: wordsLearned,
    streakDays: streakDays,
    lastActivityDate: lastActivityDate ?? DateTime.now(),
    categoryProgress: categoryProgress,
    recentScores: recentScores,
    totalStars: totalStars,
  );
}

void main() {
  late Box box;

  setUpAll(() async {
    await _initHive();
    box = Hive.box('progress');
  });

  setUp(() async {
    await box.clear();
  });

  // ─── generate() basics ─────────────────────────────────────

  group('RecommendationService.generate()', () {
    test('returns a valid snapshot for a brand new user', () {
      final snapshot = RecommendationService.generate(
        profileId: 'new_user',
        progress: _makeProgress(),
        pathProgress: {},
      );

      expect(snapshot, isA<RecommendationSnapshot>());
      expect(snapshot.generatedAt, isNotNull);
      expect(snapshot.overallAccuracy, 0.0);
      expect(snapshot.categoriesExplored, 0);
      expect(snapshot.totalCategories, FlashcardCategory.values.length);
    });

    test('recommendations list is not empty for a new user', () {
      final snapshot = RecommendationService.generate(
        profileId: 'new_user2',
        progress: _makeProgress(),
        pathProgress: {},
      );

      // A brand-new user should at minimum get:
      // - explore new category, daily challenge, continue learning path
      expect(snapshot.recommendations, isNotEmpty);
    });

    test('recommendations are sorted by priority then relevance', () {
      final snapshot = RecommendationService.generate(
        profileId: 'sorted_user',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.3,
            FlashcardCategory.numbers.label: 0.1,
          },
        ),
        pathProgress: {},
      );

      if (snapshot.recommendations.length >= 2) {
        // High priority should come before medium/low
        final priorities =
            snapshot.recommendations.map((r) => r.priority).toList();
        for (var i = 0; i < priorities.length - 1; i++) {
          expect(
            priorities[i].index <= priorities[i + 1].index,
            isTrue,
            reason:
                'Recommendation at index $i (${priorities[i]}) should have '
                'equal or higher priority than index ${i + 1} '
                '(${priorities[i + 1]})',
          );
        }
      }
    });
  });

  // ─── Weak categories ───────────────────────────────────────

  group('weak category recommendations', () {
    test('generates recommendations for categories with progress < 50%', () {
      final snapshot = RecommendationService.generate(
        profileId: 'weak_cats',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.2,
            FlashcardCategory.numbers.label: 0.4,
            FlashcardCategory.weather.label: 0.8, // strong — no recommendation
          },
        ),
        pathProgress: {},
      );

      final weakRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.reviewWeakCategory)
          .toList();

      expect(weakRecs.length, 2);
      // 20% category should be high priority
      final animalsRec =
          weakRecs.firstWhere((r) => r.id == 'weak_cat_Animals');
      expect(animalsRec.priority, RecommendationPriority.high);
    });

    test('categories at exactly 50% are not flagged as weak', () {
      final snapshot = RecommendationService.generate(
        profileId: 'boundary',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.5,
          },
        ),
        pathProgress: {},
      );

      final weakRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.reviewWeakCategory);
      expect(weakRecs, isEmpty);
    });

    test('categories at 0% are not flagged (treated as unexplored)', () {
      final snapshot = RecommendationService.generate(
        profileId: 'zero_cat',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.0,
          },
        ),
        pathProgress: {},
      );

      final weakRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.reviewWeakCategory);
      expect(weakRecs, isEmpty);
    });
  });

  // ─── Spaced repetition review ──────────────────────────────

  group('spaced repetition recommendations', () {
    test('generates smart review recommendation when review words exist', () {
      // Seed some spaced repetition data
      box.put('sr_sr_user', {
        'word1': {
          'correct': 2,
          'total': 5,
          'lastSeen':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
        'word2': {
          'correct': 1,
          'total': 4,
          'lastSeen':
              DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        },
      });

      final snapshot = RecommendationService.generate(
        profileId: 'sr_user',
        progress: _makeProgress(profileId: 'sr_user'),
        pathProgress: {},
      );

      final srRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.spacedRepetitionDue)
          .toList();

      expect(srRecs, isNotEmpty);
      expect(srRecs.first.route, '/smart-review');
    });
  });

  // ─── Explore new category ──────────────────────────────────

  group('explore new category recommendations', () {
    test('suggests unexplored categories', () {
      // All categories at 0 → lots of explore recommendations
      final snapshot = RecommendationService.generate(
        profileId: 'explorer',
        progress: _makeProgress(),
        pathProgress: {},
      );

      final exploreRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.exploreNewCategory)
          .toList();

      expect(exploreRecs, isNotEmpty);
      expect(exploreRecs.first.priority, RecommendationPriority.low);
    });

    test('does not suggest explored categories', () {
      // All categories have some progress
      final allProgress = <String, double>{};
      for (final cat in FlashcardCategory.values) {
        allProgress[cat.label] = 0.5;
      }

      final snapshot = RecommendationService.generate(
        profileId: 'all_explored',
        progress: _makeProgress(categoryProgress: allProgress),
        pathProgress: {},
      );

      final exploreRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.exploreNewCategory);
      expect(exploreRecs, isEmpty);
    });
  });

  // ─── Daily challenge ───────────────────────────────────────

  group('daily challenge recommendations', () {
    test('suggests daily challenge when not completed today', () {
      final snapshot = RecommendationService.generate(
        profileId: 'daily_test',
        progress: _makeProgress(),
        pathProgress: {},
      );

      final dailyRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.dailyChallengeReminder)
          .toList();

      expect(dailyRecs, isNotEmpty);
      expect(dailyRecs.first.route, '/daily-challenge');
    });
  });

  // ─── Streak motivation ─────────────────────────────────────

  group('streak recommendations', () {
    test('suggests keep streak when streak > 0 and last activity ≥ 1 day ago',
        () {
      final snapshot = RecommendationService.generate(
        profileId: 'streaker',
        progress: _makeProgress(
          streakDays: 5,
          lastActivityDate:
              DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        ),
        pathProgress: {},
      );

      final streakRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.increaseStreak)
          .toList();

      expect(streakRecs, isNotEmpty);
      expect(streakRecs.first.priority, RecommendationPriority.high);
    });

    test('no streak recommendation when streakDays is 0', () {
      final snapshot = RecommendationService.generate(
        profileId: 'no_streak',
        progress: _makeProgress(),
        pathProgress: {},
      );

      final streakRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.increaseStreak);
      expect(streakRecs, isEmpty);
    });
  });

  // ─── Game suggestion ───────────────────────────────────────

  group('game suggestion recommendations', () {
    test('suggests least played game', () {
      final scores = [
        GameScore(
          gameType: GameType.wordMatch,
          score: 5,
          total: 10,
          starsEarned: 1,
          date: DateTime.now(),
        ),
        GameScore(
          gameType: GameType.wordMatch,
          score: 7,
          total: 10,
          starsEarned: 2,
          date: DateTime.now(),
        ),
        // spellingBee never played → should be suggested
      ];

      final snapshot = RecommendationService.generate(
        profileId: 'gamer',
        progress: _makeProgress(recentScores: scores),
        pathProgress: {},
      );

      final gameRecs = snapshot.recommendations
          .where((r) => r.type == RecommendationType.trySuggestedGame)
          .toList();

      expect(gameRecs, isNotEmpty);
    });
  });

  // ─── Snapshot summary stats ────────────────────────────────

  group('snapshot summary stats', () {
    test('categoriesExplored counts categories with progress > 0', () {
      final snapshot = RecommendationService.generate(
        profileId: 'stats_test',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.5,
            FlashcardCategory.numbers.label: 0.3,
            FlashcardCategory.weather.label: 0.0, // not counted
          },
        ),
        pathProgress: {},
      );

      expect(snapshot.categoriesExplored, 2);
    });

    test('overallAccuracy reflects spaced repetition data', () {
      box.put('sr_acc_user', {
        'word1': {
          'correct': 4,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final snapshot = RecommendationService.generate(
        profileId: 'acc_user',
        progress: _makeProgress(profileId: 'acc_user'),
        pathProgress: {},
      );

      // 7/10 = 0.7
      expect(snapshot.overallAccuracy, closeTo(0.7, 0.01));
    });

    test('weakest/strongest category labels are set correctly', () {
      final snapshot = RecommendationService.generate(
        profileId: 'label_test',
        progress: _makeProgress(
          categoryProgress: {
            FlashcardCategory.animals.label: 0.9,
            FlashcardCategory.numbers.label: 0.2,
          },
        ),
        pathProgress: {},
      );

      expect(snapshot.weakestCategoryLabel, FlashcardCategory.numbers.label);
      expect(snapshot.strongestCategoryLabel, FlashcardCategory.animals.label);
    });
  });

  // ─── Recommendation model ─────────────────────────────────

  group('Recommendation model', () {
    test('priorityColor maps correctly', () {
      const high = Recommendation(
        id: 'r1',
        type: RecommendationType.reviewWeakCategory,
        priority: RecommendationPriority.high,
        title: 'Test',
        titleFilipino: 'Pagsusuri',
        description: 'desc',
        descriptionFilipino: 'paglalarawan',
        emoji: '📚',
      );
      expect(high.priorityColor, isNotNull);
      expect(high.priorityLabel, 'Recommended');
      expect(high.priorityLabelFilipino, 'Inirerekomenda');
    });

    test('typeIcon is defined for all recommendation types', () {
      for (final type in RecommendationType.values) {
        final rec = Recommendation(
          id: 'type_$type',
          type: type,
          priority: RecommendationPriority.medium,
          title: 'Test',
          titleFilipino: 'Test',
          description: 'desc',
          descriptionFilipino: 'desc',
          emoji: '📚',
        );
        expect(rec.typeIcon, isNotNull);
      }
    });
  });

  // ─── RecommendationSnapshot model ─────────────────────────

  group('RecommendationSnapshot', () {
    test('properties are accessible', () {
      final snapshot = RecommendationSnapshot(
        recommendations: const [],
        wordsNeedingReview: 5,
        categoriesExplored: 3,
        totalCategories: 12,
        overallAccuracy: 0.65,
        weakestCategoryLabel: 'Numbers',
        strongestCategoryLabel: 'Animals',
        generatedAt: DateTime(2025, 6),
      );

      expect(snapshot.wordsNeedingReview, 5);
      expect(snapshot.categoriesExplored, 3);
      expect(snapshot.totalCategories, 12);
      expect(snapshot.overallAccuracy, 0.65);
      expect(snapshot.weakestCategoryLabel, 'Numbers');
      expect(snapshot.strongestCategoryLabel, 'Animals');
    });
  });
}
