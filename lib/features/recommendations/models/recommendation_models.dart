import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';

/// Priority level for a recommendation
enum RecommendationPriority { high, medium, low }

/// Type of recommendation action
enum RecommendationType {
  reviewWeakCategory,
  spacedRepetitionDue,
  trySuggestedGame,
  continueLearningPath,
  dailyChallengeReminder,
  exploreNewCategory,
  practiceWeakWords,
  increaseStreak,
}

/// A single actionable recommendation for the student
class Recommendation {
  final String id;
  final RecommendationType type;
  final RecommendationPriority priority;
  final String title;
  final String titleFilipino;
  final String description;
  final String descriptionFilipino;
  final String emoji;
  final String? route; // GoRouter path to navigate to
  final Map<String, String>? queryParams;
  final FlashcardCategory? category;
  final GameType? gameType;
  final double? relevanceScore; // 0.0 – 1.0, higher = more relevant

  const Recommendation({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.titleFilipino,
    required this.description,
    required this.descriptionFilipino,
    required this.emoji,
    this.route,
    this.queryParams,
    this.category,
    this.gameType,
    this.relevanceScore,
  });

  /// Priority-to-color mapping for UI
  Color get priorityColor => switch (priority) {
    RecommendationPriority.high => AppColors.error,
    RecommendationPriority.medium => AppColors.warningDark,
    RecommendationPriority.low => AppColors.success,
  };

  String get priorityLabel => switch (priority) {
    RecommendationPriority.high => 'Recommended',
    RecommendationPriority.medium => 'Suggested',
    RecommendationPriority.low => 'Optional',
  };

  String get priorityLabelFilipino => switch (priority) {
    RecommendationPriority.high => 'Inirerekomenda',
    RecommendationPriority.medium => 'Iminumungkahi',
    RecommendationPriority.low => 'Opsyonal',
  };

  IconData get typeIcon => switch (type) {
    RecommendationType.reviewWeakCategory => Icons.refresh_rounded,
    RecommendationType.spacedRepetitionDue => Icons.schedule_rounded,
    RecommendationType.trySuggestedGame => Icons.sports_esports_rounded,
    RecommendationType.continueLearningPath => Icons.route_rounded,
    RecommendationType.dailyChallengeReminder => Icons.today_rounded,
    RecommendationType.exploreNewCategory => Icons.explore_rounded,
    RecommendationType.practiceWeakWords => Icons.spellcheck_rounded,
    RecommendationType.increaseStreak => Icons.local_fire_department_rounded,
  };
}

/// Summary snapshot sent to the recommendations screen
class RecommendationSnapshot {
  final List<Recommendation> recommendations;
  final int wordsNeedingReview;
  final int categoriesExplored;
  final int totalCategories;
  final double overallAccuracy;
  final String? weakestCategoryLabel;
  final String? strongestCategoryLabel;
  final DateTime generatedAt;

  const RecommendationSnapshot({
    required this.recommendations,
    required this.wordsNeedingReview,
    required this.categoriesExplored,
    required this.totalCategories,
    required this.overallAccuracy,
    this.weakestCategoryLabel,
    this.strongestCategoryLabel,
    required this.generatedAt,
  });

  /// True when the user has no activity data yet (brand new)
  bool get isNewUser => categoriesExplored == 0 && overallAccuracy == 0;
}
