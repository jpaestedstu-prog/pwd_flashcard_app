import 'package:uuid/uuid.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../models/goal_model.dart';

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

  static List<LearningGoal> updateGoalProgress(
    String profileId,
    LearningProgress progress,
  ) {
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

      final currentValue = _computeCurrentValue(goal, progress);
      final newGoal = goal.copyWith(currentValue: currentValue);

      if (newGoal.isCompleted) {
        updated.add(newGoal.copyWith(status: GoalStatus.completed));
      } else {
        updated.add(newGoal);
      }
    }

    return updated;
  }

  static int _computeCurrentValue(
    LearningGoal goal,
    LearningProgress progress,
  ) {
    return switch (goal.type) {
      GoalType.wordsLearned => progress.wordsLearned,
      GoalType.gamesCompleted => progress.recentScores.length,
      GoalType.categoryMastery => goal.category != null
          ? ((progress.categoryProgress[goal.category!.label] ?? 0.0) * 100)
              .round()
          : 0,
      GoalType.streakDays => progress.streakDays,
      GoalType.starsEarned => progress.totalStars,
    };
  }

  static List<LearningGoal> activeGoals(String profileId) {
    return getGoals(profileId)
        .where((g) => g.status == GoalStatus.active)
        .toList();
  }

  static List<LearningGoal> completedGoals(String profileId) {
    return getGoals(profileId)
        .where((g) => g.status == GoalStatus.completed)
        .toList();
  }
}
