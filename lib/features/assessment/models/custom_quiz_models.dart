import '../../../data/models/enums.dart';
import 'assessment_models.dart';

/// A lightweight custom quiz definition.
class CustomQuiz {
  final String id;
  final String title;
  final List<String> flashcardIds;
  final List<QuestionFormat> questionFormats;
  final GameDifficulty difficulty;
  final int? timeLimitMinutes;
  final String createdBy;
  final DateTime createdAt;

  const CustomQuiz({
    required this.id,
    required this.title,
    required this.flashcardIds,
    required this.questionFormats,
    this.difficulty = GameDifficulty.medium,
    this.timeLimitMinutes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'flashcardIds': flashcardIds,
    'questionFormats': questionFormats.map((f) => f.index).toList(),
    'difficulty': difficulty.index,
    'timeLimitMinutes': timeLimitMinutes,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CustomQuiz.fromJson(Map<String, dynamic> json) {
    final diffIndex = json['difficulty'] as int? ?? 1;
    return CustomQuiz(
      id: json['id'] as String,
      title: json['title'] as String,
      flashcardIds: List<String>.from(json['flashcardIds'] as List),
      questionFormats: (json['questionFormats'] as List? ?? [0])
          .map((f) => f as int)
          .where((f) => f >= 0 && f < QuestionFormat.values.length)
          .map((f) => QuestionFormat.values[f])
          .toList(),
      difficulty: (diffIndex >= 0 && diffIndex < GameDifficulty.values.length)
          ? GameDifficulty.values[diffIndex]
          : GameDifficulty.medium,
      timeLimitMinutes: json['timeLimitMinutes'] as int?,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
