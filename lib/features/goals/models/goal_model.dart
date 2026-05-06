import '../../../data/models/enums.dart';

enum GoalType {
  wordsLearned,
  gamesCompleted,
  categoryMastery,
  streakDays,
  starsEarned,
}

extension GoalTypeX on GoalType {
  String get label => switch (this) {
    GoalType.wordsLearned => 'Words Learned',
    GoalType.gamesCompleted => 'Games Completed',
    GoalType.categoryMastery => 'Category Mastery',
    GoalType.streakDays => 'Streak Days',
    GoalType.starsEarned => 'Stars Earned',
  };

  String get emoji => switch (this) {
    GoalType.wordsLearned => '📚',
    GoalType.gamesCompleted => '🎮',
    GoalType.categoryMastery => '🏆',
    GoalType.streakDays => '🔥',
    GoalType.starsEarned => '⭐',
  };
}

enum GoalStatus {
  active,
  completed,
  expired,
}

class LearningGoal {
  final String id;
  final String title;
  final GoalType type;
  final int targetValue;
  final int currentValue;
  final DateTime createdAt;
  final DateTime? deadline;
  final GoalStatus status;
  final FlashcardCategory? category;
  final String createdBy;

  const LearningGoal({
    required this.id,
    required this.title,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.createdAt,
    this.deadline,
    this.status = GoalStatus.active,
    this.category,
    required this.createdBy,
  });

  double get progressPercent =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => currentValue >= targetValue;

  bool get isExpired =>
      deadline != null && DateTime.now().isAfter(deadline!) && !isCompleted;

  LearningGoal copyWith({
    String? id,
    String? title,
    GoalType? type,
    int? targetValue,
    int? currentValue,
    DateTime? createdAt,
    DateTime? deadline,
    GoalStatus? status,
    FlashcardCategory? category,
    String? createdBy,
  }) {
    return LearningGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.index,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'status': status.index,
    'category': category?.index,
    'createdBy': createdBy,
  };

  factory LearningGoal.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int;
    final statusIndex = json['status'] as int;
    final catIndex = json['category'] as int?;
    return LearningGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      type: (typeIndex >= 0 && typeIndex < GoalType.values.length)
          ? GoalType.values[typeIndex]
          : GoalType.wordsLearned,
      targetValue: json['targetValue'] as int,
      currentValue: json['currentValue'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      status: (statusIndex >= 0 && statusIndex < GoalStatus.values.length)
          ? GoalStatus.values[statusIndex]
          : GoalStatus.active,
      category: (catIndex != null &&
              catIndex >= 0 &&
              catIndex < FlashcardCategory.values.length)
          ? FlashcardCategory.values[catIndex]
          : null,
      createdBy: json['createdBy'] as String,
    );
  }
}
