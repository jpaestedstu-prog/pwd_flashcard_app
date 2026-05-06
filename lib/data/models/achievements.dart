import 'package:flutter/material.dart';
import 'enums.dart';
import 'models.dart';

/// Defines an achievement badge that can be unlocked by the student.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(LearningProgress progress) checkUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.checkUnlocked,
  });
}

/// All achievements available in the app.
class Achievements {
  Achievements._();

  // ─── Word Milestones ──────────────────────────────────

  static final firstWord = Achievement(
    id: 'first_word',
    title: 'First Word',
    description: 'Learned your very first word!',
    icon: Icons.abc,
    color: const Color(0xFF42A5F5),
    checkUnlocked: (p) => p.wordsLearned >= 1,
  );

  static final tenWords = Achievement(
    id: 'ten_words',
    title: '10 Words',
    description: 'Amazing! You learned 10 words!',
    icon: Icons.emoji_events_rounded,
    color: const Color(0xFFFFB74D),
    checkUnlocked: (p) => p.wordsLearned >= 10,
  );

  static final halfWay = Achievement(
    id: 'half_way',
    title: 'Half Way',
    description: 'You\'re halfway through all vocabulary!',
    icon: Icons.flag_rounded,
    color: const Color(0xFF66BB6A),
    checkUnlocked: (p) => p.wordsLearned >= 72,
  );

  static final wordMaster = Achievement(
    id: 'word_master',
    title: 'Word Master',
    description: 'Incredible — you learned all 144 words!',
    icon: Icons.workspace_premium_rounded,
    color: const Color(0xFFFFD700),
    checkUnlocked: (p) => p.wordsLearned >= 144,
  );

  // ─── Category Mastery ─────────────────────────────────

  static final allAnimals = Achievement(
    id: 'all_animals',
    title: 'Animal Expert',
    description: 'Mastered all animal vocabulary!',
    icon: Icons.pets_rounded,
    color: const Color(0xFFE65100),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.animals.label] ?? 0) >= 0.9,
  );

  static final allColors = Achievement(
    id: 'all_colors',
    title: 'Color Wizard',
    description: 'Mastered all colors & shapes!',
    icon: Icons.palette_rounded,
    color: const Color(0xFFC62828),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.colorsAndShapes.label] ?? 0) >=
        0.9,
  );

  static final allNumbers = Achievement(
    id: 'all_numbers',
    title: 'Number Ninja',
    description: 'Mastered all number vocabulary!',
    icon: Icons.looks_one_rounded,
    color: const Color(0xFF1565C0),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.numbers.label] ?? 0) >= 0.9,
  );

  static final allBody = Achievement(
    id: 'all_body',
    title: 'Body Builder',
    description: 'Mastered all body part vocabulary!',
    icon: Icons.accessibility_new_rounded,
    color: const Color(0xFF2E7D32),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.bodyParts.label] ?? 0) >= 0.9,
  );

  static final allFood = Achievement(
    id: 'all_food',
    title: 'Foodie Star',
    description: 'Mastered all food & drinks vocabulary!',
    icon: Icons.restaurant_rounded,
    color: const Color(0xFFBF360C),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.foodAndDrinks.label] ?? 0) >=
        0.9,
  );

  static final allFamily = Achievement(
    id: 'all_family',
    title: 'Family Hero',
    description: 'Mastered family & greetings vocabulary!',
    icon: Icons.people_rounded,
    color: const Color(0xFF6A1B9A),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.familyAndGreetings.label] ?? 0) >=
        0.9,
  );

  static final allClothing = Achievement(
    id: 'all_clothing',
    title: 'Fashion Star',
    description: 'Mastered all clothing vocabulary!',
    icon: Icons.checkroom_rounded,
    color: const Color(0xFFAD1457),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.clothing.label] ?? 0) >= 0.9,
  );

  static final allWeather = Achievement(
    id: 'all_weather',
    title: 'Weather Watcher',
    description: 'Mastered all weather vocabulary!',
    icon: Icons.wb_sunny_rounded,
    color: const Color(0xFFF57F17),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.weather.label] ?? 0) >= 0.9,
  );

  static final allClassroom = Achievement(
    id: 'all_classroom',
    title: 'School Whiz',
    description: 'Mastered all classroom vocabulary!',
    icon: Icons.class_rounded,
    color: const Color(0xFF0277BD),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.classroom.label] ?? 0) >= 0.9,
  );

  static final allTransportation = Achievement(
    id: 'all_transportation',
    title: 'Road Runner',
    description: 'Mastered all transportation vocabulary!',
    icon: Icons.directions_bus_rounded,
    color: const Color(0xFF4527A0),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.transportation.label] ?? 0) >=
        0.9,
  );

  static final allEmotions = Achievement(
    id: 'all_emotions',
    title: 'Feelings Expert',
    description: 'Mastered all emotions vocabulary!',
    icon: Icons.emoji_emotions_rounded,
    color: const Color(0xFFB71C1C),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.emotions.label] ?? 0) >= 0.9,
  );

  static final allDaysAndTime = Achievement(
    id: 'all_days_time',
    title: 'Time Keeper',
    description: 'Mastered all days & time vocabulary!',
    icon: Icons.calendar_today_rounded,
    color: const Color(0xFF33691E),
    checkUnlocked: (p) =>
        (p.categoryProgress[FlashcardCategory.daysAndTime.label] ?? 0) >= 0.9,
  );

  static final categoryChampion = Achievement(
    id: 'category_champion',
    title: 'Category Champ',
    description: 'Mastered every single category — outstanding!',
    icon: Icons.military_tech_rounded,
    color: const Color(0xFFFF6F00),
    checkUnlocked: (p) {
      return FlashcardCategory.values.every(
        (cat) => (p.categoryProgress[cat.label] ?? 0) >= 0.9,
      );
    },
  );

  // ─── Streak Milestones ────────────────────────────────

  static final threeDayStreak = Achievement(
    id: 'three_day_streak',
    title: '3-Day Streak',
    description: 'Practiced 3 days in a row — great habit!',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFF44336),
    checkUnlocked: (p) => p.streakDays >= 3,
  );

  static final weekStreak = Achievement(
    id: 'week_streak',
    title: '7-Day Streak',
    description: 'A whole week of learning — unstoppable!',
    icon: Icons.whatshot_rounded,
    color: const Color(0xFFFF6D00),
    checkUnlocked: (p) => p.streakDays >= 7,
  );

  static final twoWeekStreak = Achievement(
    id: 'two_week_streak',
    title: '14-Day Streak',
    description: 'Two weeks of daily learning — incredible dedication!',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFD50000),
    checkUnlocked: (p) => p.streakDays >= 14,
  );

  static final monthStreak = Achievement(
    id: 'month_streak',
    title: '30-Day Streak',
    description: 'A whole month of learning — you are a legend!',
    icon: Icons.military_tech_rounded,
    color: const Color(0xFFFFD600),
    checkUnlocked: (p) => p.streakDays >= 30,
  );

  // ─── Star Milestones ──────────────────────────────────

  static final gameStar = Achievement(
    id: 'game_star',
    title: 'Game Star',
    description: 'Collected 5 stars from games!',
    icon: Icons.star_rounded,
    color: const Color(0xFFFFC107),
    checkUnlocked: (p) => p.totalStars >= 5,
  );

  static final starCollector = Achievement(
    id: 'star_collector',
    title: 'Star Collector',
    description: 'Earned 25 stars — you shine bright!',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFFFFAB00),
    checkUnlocked: (p) => p.totalStars >= 25,
  );

  static final superstar = Achievement(
    id: 'superstar',
    title: 'Superstar',
    description: 'Collected 50 stars — truly amazing!',
    icon: Icons.stars_rounded,
    color: const Color(0xFFFF6F00),
    checkUnlocked: (p) => p.totalStars >= 50,
  );

  // ─── Game-Specific ────────────────────────────────────

  static final perfectScore = Achievement(
    id: 'perfect_score',
    title: 'Perfect Score',
    description: 'Got 100% in any game — flawless!',
    icon: Icons.verified_rounded,
    color: const Color(0xFF00C853),
    checkUnlocked: (p) =>
        p.recentScores.any((s) => s.score == s.total && s.total > 0),
  );

  static final gameExplorer = Achievement(
    id: 'game_explorer',
    title: 'Game Explorer',
    description: 'Played every game type at least once!',
    icon: Icons.explore_rounded,
    color: const Color(0xFF00ACC1),
    checkUnlocked: (p) {
      final playedTypes = p.recentScores.map((s) => s.gameType).toSet();
      // fslPractice is a hub screen, not a scoreable game
      final scoreable = GameType.values.where((gt) => gt != GameType.fslPractice);
      return scoreable.every((gt) => playedTypes.contains(gt));
    },
  );

  // ─── Story Milestones ────────────────────────────────

  static final firstStory = Achievement(
    id: 'first_story',
    title: 'First Story',
    description: 'Completed your first reading quiz!',
    icon: Icons.auto_stories_rounded,
    color: const Color(0xFF9FA8DA),
    checkUnlocked: (p) =>
        p.recentScores.any((s) => s.gameType == GameType.storyQuiz),
  );

  static final storyPerfect = Achievement(
    id: 'story_perfect',
    title: 'Story Star',
    description: 'Got 3/3 on a story quiz — amazing reader!',
    icon: Icons.menu_book_rounded,
    color: const Color(0xFF7E57C2),
    checkUnlocked: (p) => p.recentScores.any(
      (s) => s.gameType == GameType.storyQuiz && s.score == s.total && s.total > 0,
    ),
  );

  /// All achievements in display order.
  static final List<Achievement> all = [
    // Word milestones
    firstWord,
    tenWords,
    halfWay,
    wordMaster,
    // Category mastery
    allAnimals,
    allColors,
    allNumbers,
    allBody,
    allFood,
    allFamily,
    allClothing,
    allWeather,
    allClassroom,
    allTransportation,
    allEmotions,
    allDaysAndTime,
    categoryChampion,
    // Streaks
    threeDayStreak,
    weekStreak,
    twoWeekStreak,
    monthStreak,
    // Stars
    gameStar,
    starCollector,
    superstar,
    // Game-specific
    perfectScore,
    gameExplorer,
    // Story milestones
    firstStory,
    storyPerfect,
  ];

  /// Returns a list of achievements that are newly unlocked
  /// (unlocked now but weren't in the previous set).
  static List<Achievement> findNewlyUnlocked({
    required LearningProgress progress,
    required Set<String> previouslyUnlockedIds,
  }) {
    return all.where((a) {
      final isUnlockedNow = a.checkUnlocked(progress);
      final wasUnlockedBefore = previouslyUnlockedIds.contains(a.id);
      return isUnlockedNow && !wasUnlockedBefore;
    }).toList();
  }

  /// Returns all currently unlocked achievement IDs for a progress state.
  static Set<String> unlockedIds(LearningProgress progress) {
    return all
        .where((a) => a.checkUnlocked(progress))
        .map((a) => a.id)
        .toSet();
  }
}
