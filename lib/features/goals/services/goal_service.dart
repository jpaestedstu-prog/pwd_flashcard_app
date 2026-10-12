import 'package:uuid/uuid.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../models/goal_model.dart';
import 'package:flutter/foundation.dart';

class GoalService {
  GoalService._();

  static const _uuid = Uuid();

  static LearningGoal createGoal({
    required String title,
    required GoalType type,
    required int targetValue,
    required String createdBy,
    DateTime? deadline,
    FlashcardCategory? category,
  }) {
    return LearningGoal(
      id: _uuid.v4(),
      title: title,
      type: type,
      targetValue: targetValue,
      createdAt: DateTime.now(),
      deadline: deadline,
      category: category,
      createdBy: createdBy,
    );
  }

  static List<LearningGoal> getGoals(String profileId) {
    return HiveService.getGoals(profileId);
  }

  static Future<void> saveGoal(String profileId, LearningGoal goal) async {
    final goals = getGoals(profileId);
    goals.removeWhere((g) => g.id == goal.id);
    goals.add(goal);
    await HiveService.saveGoals(profileId, goals);
  }

  static Future<void> removeGoal(String profileId, String goalId) async {
    final goals = getGoals(profileId);
    goals.removeWhere((g) => g.id == goalId);
    await HiveService.saveGoals(profileId, goals);
  }

  /// [coverage] is each category's share of words the learner has actually
  /// learned (CategoryMastery.coverage), what a category-mastery goal counts.
  static List<LearningGoal> updateGoalProgress(
    String profileId,
    LearningProgress progress, {
    Map<FlashcardCategory, double> coverage = const {},
  }) {
    final goals = getGoals(profileId);
    final updated = <LearningGoal>[];

    for (final goal in goals) {
      if (goal.status == GoalStatus.completed) {
        updated.add(goal);
        continue;
      }

      // Check if expired
      if (goal.isExpired) {
        updated.add(goal.copyWith(status: GoalStatus.expired));
        continue;
      }

      final currentValue = computeCurrentValue(goal, progress, coverage);
      final newGoal = goal.copyWith(currentValue: currentValue);

      if (newGoal.isCompleted) {
        updated.add(newGoal.copyWith(status: GoalStatus.completed));
      } else {
        updated.add(newGoal);
      }
    }

    return updated;
  }

  @visibleForTesting
  static int computeCurrentValue(
    LearningGoal goal,
    LearningProgress progress,
    Map<FlashcardCategory, double> coverage,
  ) {
    return switch (goal.type) {
      GoalType.wordsLearned => progress.wordsLearned,
      // Lifetime count. `recentScores` is trimmed to the last 20, so any goal
      // with a target above 20 could never be completed.
      GoalType.gamesCompleted => progress.effectiveGamesPlayed,
      // The share of the category's words actually learned. This used to be
      // `categoryProgress`, a rolling accuracy average: five perfect
      // three-question games "mastered" a category of twenty words.
      GoalType.categoryMastery =>
        goal.category != null
            ? ((coverage[goal.category!] ?? 0.0) * 100).round()
            : 0,
      GoalType.streakDays => progress.liveStreakDays,
      GoalType.starsEarned => progress.totalStars,
    };
  }

  static List<LearningGoal> activeGoals(String profileId) {
    return getGoals(
      profileId,
    ).where((g) => g.status == GoalStatus.active).toList();
  }

  static List<LearningGoal> completedGoals(String profileId) {
    return getGoals(
      profileId,
    ).where((g) => g.status == GoalStatus.completed).toList();
  }
}
