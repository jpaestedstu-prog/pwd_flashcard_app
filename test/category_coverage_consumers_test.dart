import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/models/teacher_analytics_models.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// `categoryProgress` is a rolling average of game accuracy. Shown to a
/// teacher or a parent as "progress" or "% mastery" it reads high for a
/// category barely opened: on the Honor (13 October 2026) a learner who knew
/// 1 animal word of 12 and no colour word was "doing great" at Colors &
/// Shapes, 36%. These pin the summaries those screens print to what the
/// learner has actually learned; accuracy keeps its own figure.

/// The averages a few games leave behind, disagreeing with what was learned.
const _accuracy = {'Animals': 0.28, 'Colors & Shapes': 0.36};

LearningProgress _progress() {
  final animal = SeedData.allFlashcards.firstWhere((c) => c.category == FlashcardCategory.animals);
  return LearningProgress(
    profileId: 'kid',
    lastActivityDate: DateTime(2026, 10, 12),
    wordsLearned: 1,
    learnedWordIds: {animal.id},
    categoryProgress: _accuracy,
    recentScores: [
      GameScore(gameType: GameType.wordMatch, score: 3, total: 5, starsEarned: 1, date: DateTime(2026, 10, 12)),
    ],
  );
}

ChildSummary _child(Map<String, double> coverage) => ChildSummary(
  profileId: 'kid',
  name: 'Kid',
  avatarEmoji: '🐼',
  avatarIndex: 0,
  disabilityType: DisabilityType.none,
  wordsLearned: 1,
  totalStars: 10,
  streakDays: 0,
  gamesPlayed: 2,
  averageAccuracy: 0.6,
  studyMinutesThisWeek: 10,
  studyMinutesLastWeek: 0,
  totalSessions: 2,
  dailyStudyMinutes: const {},
  categoryProgress: _accuracy,
  categoryCoverage: coverage,
  wordHuntFinds: 0,
  signsWatched: 0,
  wordHuntStreak: 0,
  recentScores: const [],
  lastActivityDate: DateTime(2026, 10, 12),
);

void main() {
  group('the teacher analytics', () {
    test('compare categories by words learned', () {
      final a = StudentAnalytics.from(
        UserProfile(id: 'kid', name: 'Kid', role: UserRole.student, createdAt: DateTime(2026)),
        _progress(),
      );
      expect(a.categoryProgress['Animals'], closeTo(1 / 12, 1e-9));
      expect(a.categoryProgress['Colors & Shapes'], 0.0,
          reason: 'played, but no word of it learned');
      expect(a.strongestCategory, 'Animals', reason: 'not Colors & Shapes at a 36% average');
      expect(a.weakestCategory, 'Colors & Shapes');
      expect(a.averageAccuracy, closeTo(0.6, 1e-9), reason: 'accuracy keeps its own figure');
    });
  });

  group("a child's summary (detail sheet, weekly report)", () {
    final child = _child({'Animals': 1 / 12, 'Colors & Shapes': 0.0, 'Food & Drinks': 2 / 17});

    test('strongest and weakest are by words learned', () {
      expect(child.strongestCategory, 'Food & Drinks');
      expect(child.weakestCategory, 'Animals',
          reason: 'the least learned of the categories begun');
    });

    test('a category is explored once played or once a word of it is learned', () {
      expect(child.unexploredCategories, isNot(contains('Colors & Shapes')),
          reason: 'played, though no word of it learned');
      expect(child.unexploredCategories, isNot(contains('Food & Drinks')),
          reason: 'not played, but words of it learned');
      expect(child.unexploredCategories, contains('Numbers'));
    });

    test('nothing learned yet: no strongest, no weakest', () {
      final none = _child(const {});
      expect(none.strongestCategory, isNull);
      expect(none.weakestCategory, isNull);
      expect(none.unexploredCategories, hasLength(FlashcardCategory.values.length - 2),
          reason: 'Animals and Colors & Shapes were played');
    });
  });
}
