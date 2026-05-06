import '../models/enums.dart';
import '../models/learning_path.dart';

/// Seed data for the 12 structured learning paths (one per category).
///
/// Each path has 5 steps:
///   1. Learn flashcards (view cards)
///   2. Word Match game (easy)
///   3. Spelling Bee game (medium)
///   4. Story quiz (where available) or Flashcard Quiz
///   5. Smart Review (spaced repetition)
///
/// Paths unlock sequentially: Animals → Colors & Shapes → Numbers → ...
class LearningPathData {
  const LearningPathData._();

  static List<LearningPath> get allPaths => [
        _buildPath(
          id: 'path_animals',
          title: 'Animal Friends',
          emoji: '🐾',
          category: FlashcardCategory.animals,
          isInitiallyUnlocked: true,
        ),
        _buildPath(
          id: 'path_colors_shapes',
          title: 'Colors & Shapes',
          emoji: '🎨',
          category: FlashcardCategory.colorsAndShapes,
          prerequisitePathId: 'path_animals',
        ),
        _buildPath(
          id: 'path_numbers',
          title: 'Number World',
          emoji: '🔢',
          category: FlashcardCategory.numbers,
          prerequisitePathId: 'path_colors_shapes',
        ),
        _buildPath(
          id: 'path_body_parts',
          title: 'My Body',
          emoji: '🧍',
          category: FlashcardCategory.bodyParts,
          prerequisitePathId: 'path_numbers',
        ),
        _buildPath(
          id: 'path_food_drinks',
          title: 'Yummy Food',
          emoji: '🍎',
          category: FlashcardCategory.foodAndDrinks,
          prerequisitePathId: 'path_body_parts',
        ),
        _buildPath(
          id: 'path_family_greetings',
          title: 'Family & Hello',
          emoji: '👨‍👩‍👧',
          category: FlashcardCategory.familyAndGreetings,
          prerequisitePathId: 'path_food_drinks',
        ),
        _buildPath(
          id: 'path_clothing',
          title: 'Getting Dressed',
          emoji: '👕',
          category: FlashcardCategory.clothing,
          prerequisitePathId: 'path_family_greetings',
        ),
        _buildPath(
          id: 'path_weather',
          title: 'Weather Watch',
          emoji: '🌤️',
          category: FlashcardCategory.weather,
          prerequisitePathId: 'path_clothing',
        ),
        _buildPath(
          id: 'path_classroom',
          title: 'At School',
          emoji: '🏫',
          category: FlashcardCategory.classroom,
          prerequisitePathId: 'path_weather',
        ),
        _buildPath(
          id: 'path_transportation',
          title: 'On the Go',
          emoji: '🚌',
          category: FlashcardCategory.transportation,
          prerequisitePathId: 'path_classroom',
        ),
        _buildPath(
          id: 'path_emotions',
          title: 'How I Feel',
          emoji: '😊',
          category: FlashcardCategory.emotions,
          prerequisitePathId: 'path_transportation',
        ),
        _buildPath(
          id: 'path_days_time',
          title: 'Days & Time',
          emoji: '📅',
          category: FlashcardCategory.daysAndTime,
          prerequisitePathId: 'path_emotions',
        ),
      ];

  static LearningPath _buildPath({
    required String id,
    required String title,
    required String emoji,
    required FlashcardCategory category,
    bool isInitiallyUnlocked = false,
    String? prerequisitePathId,
  }) {
    return LearningPath(
      id: id,
      title: title,
      description: 'Master ${category.label} vocabulary step by step!',
      category: category,
      emoji: emoji,
      isInitiallyUnlocked: isInitiallyUnlocked,
      prerequisitePathId: prerequisitePathId,
      steps: [
        LessonStep(
          type: LessonStepType.flashcards,
          title: 'Learn the Words',
          description:
              'Study all 12 ${category.label} flashcards. Flip each card and listen to the pronunciation.',
          category: category,
        ),
        LessonStep(
          type: LessonStepType.game,
          title: 'Word Match',
          description:
              'Match each word to its picture. Score at least 70% to continue!',
          category: category,
          gameType: GameType.wordMatch,
          gameDifficulty: GameDifficulty.easy,
          minScoreThreshold: 0.7,
        ),
        LessonStep(
          type: LessonStepType.game,
          title: 'Spelling Bee',
          description:
              'Unscramble the letters to spell each word. Score at least 60% to pass!',
          category: category,
          gameType: GameType.spellingBee,
          gameDifficulty: GameDifficulty.medium,
          minScoreThreshold: 0.6,
        ),
        LessonStep(
          type: LessonStepType.quiz,
          title: 'Quick Quiz',
          description:
              'Answer flashcard quiz questions to test your knowledge. Aim for 70%!',
          category: category,
          gameType: GameType.flashcardQuiz,
          gameDifficulty: GameDifficulty.medium,
          minScoreThreshold: 0.7,
        ),
        LessonStep(
          type: LessonStepType.smartReview,
          title: 'Master It!',
          description:
              'Complete a smart review session to lock in your memory. Score 80% to master this path!',
          category: category,
          minScoreThreshold: 0.8,
        ),
      ],
    );
  }
}
