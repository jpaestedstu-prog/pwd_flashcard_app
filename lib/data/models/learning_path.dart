import 'enums.dart';

/// A single step within a learning path (e.g. "learn flashcards", "play a game").
class LessonStep {
  final LessonStepType type;
  final String title;
  final String description;
  final FlashcardCategory category;

  /// Subset of flashcard indices within the category (null = use all 12).
  final List<int>? flashcardSubset;

  /// Which game to play (only for [LessonStepType.game]).
  final GameType? gameType;

  /// Game difficulty (only for [LessonStepType.game]).
  final GameDifficulty? gameDifficulty;

  /// Minimum score percentage (0.0–1.0) required to pass the step.
  final double minScoreThreshold;

  const LessonStep({
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    this.flashcardSubset,
    this.gameType,
    this.gameDifficulty,
    this.minScoreThreshold = 0.0,
  });

  /// [title] in the learner's language. Path content is seed data, like the
  /// category names, so the Filipino ships beside it. Game steps keep the
  /// game's own name, as the Games tab does.
  String titleOf({required bool filipino}) {
    if (!filipino) return title;
    return switch (type) {
      LessonStepType.flashcards => 'Aralin ang mga Salita',
      LessonStepType.story => 'Basahin ang Kwento',
      LessonStepType.quiz => 'Mabilis na Pagsusulit',
      LessonStepType.smartReview => 'Kabisaduhin Mo!',
      LessonStepType.game => title,
    };
  }

  /// [description] in the learner's language.
  String descriptionOf({required bool filipino}) {
    if (!filipino) return description;
    final pct = (minScoreThreshold * 100).round();
    final name = category.labelFilipino;
    return switch (type) {
      LessonStepType.flashcards =>
        'Pag-aralan ang lahat ng flashcard sa $name. Baligtarin ang bawat '
            'kard at pakinggan ang bigkas.',
      LessonStepType.game when gameType == GameType.spellingBee =>
        'Ayusin ang mga letra para mabuo ang bawat salita. Kumuha ng hindi '
            'bababa sa $pct% para pumasa!',
      LessonStepType.game =>
        'Itugma ang bawat salita sa larawan nito. Kumuha ng hindi bababa sa '
            '$pct% para magpatuloy!',
      LessonStepType.quiz =>
        'Sagutin ang mga tanong sa flashcard quiz para subukin ang iyong '
            'kaalaman. Layunin ang $pct%!',
      LessonStepType.smartReview =>
        'Tapusin ang isang smart review para tumatak ito sa iyong isip. '
            'Kumuha ng $pct% para ma-master ang landas na ito!',
      LessonStepType.story => description,
    };
  }
}

/// Type of activity in a lesson step.
enum LessonStepType {
  flashcards,
  game,
  story,
  quiz,
  smartReview,
}

/// A structured learning path for one category.
class LearningPath {
  final String id;
  final String title;
  final String description;
  final FlashcardCategory category;
  final String emoji;
  final List<LessonStep> steps;

  /// If true, this path is available from the start.
  /// If false, the prerequisite path must be completed first.
  final bool isInitiallyUnlocked;

  /// ID of the path that must be completed before this one unlocks.
  final String? prerequisitePathId;

  const LearningPath({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.emoji,
    required this.steps,
    this.isInitiallyUnlocked = false,
    this.prerequisitePathId,
  });

  int get totalSteps => steps.length;

  /// [title] in the learner's language (see [LessonStep.titleOf]).
  String titleOf({required bool filipino}) =>
      filipino ? (_pathTitleFilipino[id] ?? title) : title;

  /// [description] in the learner's language.
  String descriptionOf({required bool filipino}) => filipino
      ? 'Aralin nang hakbang-hakbang ang mga salita sa '
            '${category.labelFilipino}!'
      : description;
}

const _pathTitleFilipino = {
  'path_animals': 'Mga Kaibigang Hayop',
  'path_colors_shapes': 'Mga Kulay at Hugis',
  'path_numbers': 'Mundo ng mga Numero',
  'path_body_parts': 'Ang Aking Katawan',
  'path_food_drinks': 'Masarap na Pagkain',
  'path_family_greetings': 'Pamilya at Pagbati',
  'path_clothing': 'Pagbibihis',
  'path_weather': 'Bantay-Panahon',
  'path_classroom': 'Sa Paaralan',
  'path_transportation': 'Sa Daan',
  'path_emotions': 'Ang Nararamdaman Ko',
  'path_days_time': 'Araw at Oras',
};

/// Tracks the student's progress within a specific learning path.
class LearningPathProgress {
  final String pathId;
  final Set<int> completedStepIndices;
  final int currentStepIndex;
  final DateTime startedAt;
  final DateTime? completedAt;

  /// Best score per step index (0.0–1.0).
  final Map<int, double> bestScores;

  const LearningPathProgress({
    required this.pathId,
    this.completedStepIndices = const {},
    this.currentStepIndex = 0,
    required this.startedAt,
    this.completedAt,
    this.bestScores = const {},
  });

  bool get isCompleted => completedAt != null;

  double get progressPercent => progressPercentOf(5);

  /// Returns the fraction of steps completed out of [totalSteps].
  double progressPercentOf(int totalSteps) {
    if (completedStepIndices.isEmpty || totalSteps <= 0) return 0.0;
    return (completedStepIndices.length / totalSteps).clamp(0.0, 1.0);
  }

  LearningPathProgress copyWith({
    Set<int>? completedStepIndices,
    int? currentStepIndex,
    DateTime? completedAt,
    Map<int, double>? bestScores,
  }) {
    return LearningPathProgress(
      pathId: pathId,
      completedStepIndices: completedStepIndices ?? this.completedStepIndices,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      bestScores: bestScores ?? this.bestScores,
    );
  }

  Map<String, dynamic> toJson() => {
        'pathId': pathId,
        'completedStepIndices': completedStepIndices.toList(),
        'currentStepIndex': currentStepIndex,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'bestScores': bestScores.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory LearningPathProgress.fromJson(Map<String, dynamic> json) {
    return LearningPathProgress(
      pathId: json['pathId'] as String,
      completedStepIndices: Set<int>.from(
        (json['completedStepIndices'] as List).cast<int>(),
      ),
      currentStepIndex: json['currentStepIndex'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      // `as Map`, not `as Map<String, dynamic>`.
      //
      // Hive hands back nested maps as `Map<dynamic, dynamic>`, and
      // `HiveService.getAllLearningPathProgress` only converts the *top* level.
      // So this cast held for a freshly-built progress object and threw for one
      // read back from disk: a learner who scored on a path step and then
      // restarted the app crashed on the learning-path provider, taking every
      // screen that watches it down with it.
      bestScores: (json['bestScores'] as Map?)?.map(
            (k, v) => MapEntry(int.parse('$k'), (v as num).toDouble()),
          ) ??
          {},
    );
  }
}

extension LessonStepTypeX on LessonStepType {
  String get label => switch (this) {
        LessonStepType.flashcards => 'Learn Flashcards',
        LessonStepType.game => 'Play a Game',
        LessonStepType.story => 'Read a Story',
        LessonStepType.quiz => 'Take a Quiz',
        LessonStepType.smartReview => 'Smart Review',
      };

  String get emoji => switch (this) {
        LessonStepType.flashcards => '📚',
        LessonStepType.game => '🎮',
        LessonStepType.story => '📖',
        LessonStepType.quiz => '❓',
        LessonStepType.smartReview => '🧠',
      };
}
