import 'package:flutter/material.dart';

/// User role in the app.
///
/// Order matters: `child` and `player` are appended at the end so existing
/// stored profiles (serialized by enum index) continue to deserialize.
enum UserRole { student, teacher, parent, child, player }

/// Adaptive learning level. Auto-assigned from age at onboarding, then
/// adjusted by the system over time (or overridden by a teacher / parent).
enum LearningLevel { beginner, elementary, intermediate, advanced }

/// Disability type for accessibility auto-profiling
enum DisabilityType { visual, hearing, motor, cognitive, multiple, none }

/// Vocabulary category
enum FlashcardCategory {
  animals,
  colorsAndShapes,
  numbers,
  bodyParts,
  foodAndDrinks,
  familyAndGreetings,
  // ─── New categories (appended to preserve Hive int index) ───
  clothing,
  weather,
  classroom,
  transportation,
  emotions,
  daysAndTime,
  // Action words / verbs. Appended last to preserve every existing Hive int
  // index (categories are persisted by `index`). Real-world "Show Me" clips
  // and photographs attach to these cards via the media manifests.
  actions,
}

/// Game difficulty
enum GameDifficulty { easy, medium, hard }

/// Game type
enum GameType {
  wordMatch,
  spellingBee,
  memoryMatch,
  dragAndDrop,
  flashcardQuiz,
  pronunciation,
  sentenceBuilder,
  storyQuiz,
  tracing,
  fslPractice,
  // ─── New games (appended to preserve Hive int index) ───
  jigsawPuzzle,
  pictureWord,
}

/// Grade/year level for student profiles
enum GradeLevel {
  kinder,
  grade1,
  grade2,
  grade3,
  grade4,
  grade5,
  grade6,
  highSchool,
  college,
}

/// Sort fields for the student list
enum StudentSortField {
  name,
  gradeLevel,
  wordsLearned,
  streakDays,
  stars,
  lastActive,
  averageAccuracy,
  createdAt,
}

/// Activity status filter for students
enum ActivityStatus {
  all,
  activeToday,
  activeThisWeek,
  inactive7Days,
}

// ─── Extension helpers ─────────────────────────────────

extension DisabilityTypeX on DisabilityType {
  String get label => switch (this) {
    DisabilityType.visual => 'Visual Impairment',
    DisabilityType.hearing => 'Hearing Impairment',
    DisabilityType.motor => 'Motor Impairment',
    DisabilityType.cognitive => 'Cognitive/Learning',
    DisabilityType.multiple => 'Multiple Disabilities',
    DisabilityType.none => 'No Accessibility Needs',
  };

  /// Fuller wording used when this category is shown as part of a learner's
  /// "profile type" (e.g. "Student - Cognitive/Learning Disability" in the
  /// profile switcher). Mirrors [label] except the cognitive entry spells out
  /// "Disability" so the combined phrase reads naturally.
  String get profileTypeLabel => switch (this) {
    DisabilityType.cognitive => 'Cognitive/Learning Disability',
    _ => label,
  };

  String get description => switch (this) {
    DisabilityType.visual => 'Difficulty seeing, low vision, or color blindness',
    DisabilityType.hearing => 'Difficulty hearing or deaf',
    DisabilityType.motor => 'Difficulty with fine motor skills or touch',
    DisabilityType.cognitive => 'Dyslexia, ADHD, or learning difficulties',
    DisabilityType.multiple => 'Combination of accessibility needs',
    DisabilityType.none => 'Standard settings, no special adjustments',
  };

  IconData get icon => switch (this) {
    DisabilityType.visual => Icons.visibility_rounded,
    DisabilityType.hearing => Icons.hearing_rounded,
    DisabilityType.motor => Icons.touch_app_rounded,
    DisabilityType.cognitive => Icons.psychology_rounded,
    DisabilityType.multiple => Icons.accessibility_new_rounded,
    DisabilityType.none => Icons.check_circle_outline_rounded,
  };

  String get emoji => switch (this) {
    DisabilityType.visual => '👁️',
    DisabilityType.hearing => '👂',
    DisabilityType.motor => '🖐️',
    DisabilityType.cognitive => '🧠',
    DisabilityType.multiple => '♿',
    DisabilityType.none => '✅',
  };

  Color get color => switch (this) {
    DisabilityType.visual => const Color(0xFF5C6BC0),
    DisabilityType.hearing => const Color(0xFF26A69A),
    DisabilityType.motor => const Color(0xFFEF5350),
    DisabilityType.cognitive => const Color(0xFFFFA726),
    DisabilityType.multiple => const Color(0xFF7E57C2),
    DisabilityType.none => const Color(0xFF66BB6A),
  };
}

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.teacher => 'Teacher',
    UserRole.parent => 'Parent',
    UserRole.child => 'Child',
    UserRole.player => 'Player',
  };

  IconData get icon => switch (this) {
    UserRole.student => Icons.school_rounded,
    UserRole.teacher => Icons.menu_book_rounded,
    UserRole.parent => Icons.family_restroom_rounded,
    UserRole.child => Icons.child_care_rounded,
    UserRole.player => Icons.sports_esports_rounded,
  };

  String get emoji => switch (this) {
    UserRole.student => '🎒',
    UserRole.teacher => '📚',
    UserRole.parent => '👨‍👩‍👧',
    UserRole.child => '🧒',
    UserRole.player => '🎮',
  };

  /// Roles that learn (consume content) vs. roles that manage (create/oversee).
  bool get isLearner =>
      this == UserRole.student ||
      this == UserRole.child ||
      this == UserRole.player;

  bool get isEducator =>
      this == UserRole.teacher || this == UserRole.parent;
}

extension LearningLevelX on LearningLevel {
  String get label => switch (this) {
    LearningLevel.beginner => 'Beginner',
    LearningLevel.elementary => 'Elementary',
    LearningLevel.intermediate => 'Intermediate',
    LearningLevel.advanced => 'Advanced',
  };

  String get description => switch (this) {
    LearningLevel.beginner => 'Just starting out — simple words and short sessions.',
    LearningLevel.elementary => 'Building vocabulary — slightly longer lessons.',
    LearningLevel.intermediate => 'Comfortable with most lessons — full-length games.',
    LearningLevel.advanced => 'Ready for harder challenges and complex stories.',
  };

  Color get color => switch (this) {
    LearningLevel.beginner => const Color(0xFF66BB6A),
    LearningLevel.elementary => const Color(0xFF42A5F5),
    LearningLevel.intermediate => const Color(0xFFAB47BC),
    LearningLevel.advanced => const Color(0xFFEF5350),
  };

  /// Maps to the existing GameDifficulty so we can keep the per-game tuning
  /// already implemented in AdaptiveDifficultyService without a parallel
  /// scale.
  GameDifficulty get suggestedDifficulty => switch (this) {
    LearningLevel.beginner => GameDifficulty.easy,
    LearningLevel.elementary => GameDifficulty.easy,
    LearningLevel.intermediate => GameDifficulty.medium,
    LearningLevel.advanced => GameDifficulty.hard,
  };
}

extension FlashcardCategoryX on FlashcardCategory {
  String get label => switch (this) {
    FlashcardCategory.animals => 'Animals',
    FlashcardCategory.colorsAndShapes => 'Colors & Shapes',
    FlashcardCategory.numbers => 'Numbers',
    FlashcardCategory.bodyParts => 'Body Parts',
    FlashcardCategory.foodAndDrinks => 'Food & Drinks',
    FlashcardCategory.familyAndGreetings => 'Family & Greetings',
    FlashcardCategory.clothing => 'Clothing',
    FlashcardCategory.weather => 'Weather',
    FlashcardCategory.classroom => 'Classroom',
    FlashcardCategory.transportation => 'Transportation',
    FlashcardCategory.emotions => 'Emotions',
    FlashcardCategory.daysAndTime => 'Days & Time',
    FlashcardCategory.actions => 'Actions',
  };

  String get labelFilipino => switch (this) {
    FlashcardCategory.animals => 'Mga Hayop',
    FlashcardCategory.colorsAndShapes => 'Mga Kulay at Hugis',
    FlashcardCategory.numbers => 'Mga Numero',
    FlashcardCategory.bodyParts => 'Mga Bahagi ng Katawan',
    FlashcardCategory.foodAndDrinks => 'Pagkain at Inumin',
    FlashcardCategory.familyAndGreetings => 'Pamilya at Pagbati',
    FlashcardCategory.clothing => 'Mga Damit',
    FlashcardCategory.weather => 'Panahon',
    FlashcardCategory.classroom => 'Silid-aralan',
    FlashcardCategory.transportation => 'Sasakyan',
    FlashcardCategory.emotions => 'Damdamin',
    FlashcardCategory.daysAndTime => 'Araw at Oras',
    FlashcardCategory.actions => 'Mga Kilos',
  };

  String get emoji => switch (this) {
    FlashcardCategory.animals => '🐶',
    FlashcardCategory.colorsAndShapes => '🎨',
    FlashcardCategory.numbers => '🔢',
    FlashcardCategory.bodyParts => '🖐️',
    FlashcardCategory.foodAndDrinks => '🍎',
    FlashcardCategory.familyAndGreetings => '👋',
    FlashcardCategory.clothing => '👕',
    FlashcardCategory.weather => '☀️',
    FlashcardCategory.classroom => '🏫',
    FlashcardCategory.transportation => '🚌',
    FlashcardCategory.emotions => '😊',
    FlashcardCategory.daysAndTime => '🕒',
    FlashcardCategory.actions => '🏃',
  };

  IconData get icon => switch (this) {
    FlashcardCategory.animals => Icons.pets_rounded,
    FlashcardCategory.colorsAndShapes => Icons.palette_rounded,
    FlashcardCategory.numbers => Icons.looks_one_rounded,
    FlashcardCategory.bodyParts => Icons.accessibility_new_rounded,
    FlashcardCategory.foodAndDrinks => Icons.restaurant_rounded,
    FlashcardCategory.familyAndGreetings => Icons.people_rounded,
    FlashcardCategory.clothing => Icons.checkroom_rounded,
    FlashcardCategory.weather => Icons.wb_sunny_rounded,
    FlashcardCategory.classroom => Icons.class_rounded,
    FlashcardCategory.transportation => Icons.directions_bus_rounded,
    FlashcardCategory.emotions => Icons.emoji_emotions_rounded,
    FlashcardCategory.daysAndTime => Icons.calendar_today_rounded,
    FlashcardCategory.actions => Icons.directions_run_rounded,
  };

  Color get color => switch (this) {
    FlashcardCategory.animals => const Color(0xFFFFCC80),
    FlashcardCategory.colorsAndShapes => const Color(0xFFEF9A9A),
    FlashcardCategory.numbers => const Color(0xFF90CAF9),
    FlashcardCategory.bodyParts => const Color(0xFFA5D6A7),
    FlashcardCategory.foodAndDrinks => const Color(0xFFFFAB91),
    FlashcardCategory.familyAndGreetings => const Color(0xFFCE93D8),
    FlashcardCategory.clothing => const Color(0xFFF8BBD0),
    FlashcardCategory.weather => const Color(0xFFFFF9C4),
    FlashcardCategory.classroom => const Color(0xFFB3E5FC),
    FlashcardCategory.transportation => const Color(0xFFD1C4E9),
    FlashcardCategory.emotions => const Color(0xFFFFCDD2),
    FlashcardCategory.daysAndTime => const Color(0xFFDCEDC8),
    FlashcardCategory.actions => const Color(0xFF80DEEA),
  };

  Color get darkColor => switch (this) {
    FlashcardCategory.animals => const Color(0xFFE65100),
    FlashcardCategory.colorsAndShapes => const Color(0xFFC62828),
    FlashcardCategory.numbers => const Color(0xFF1565C0),
    FlashcardCategory.bodyParts => const Color(0xFF2E7D32),
    FlashcardCategory.foodAndDrinks => const Color(0xFFBF360C),
    FlashcardCategory.familyAndGreetings => const Color(0xFF6A1B9A),
    FlashcardCategory.clothing => const Color(0xFFAD1457),
    FlashcardCategory.weather => const Color(0xFFF57F17),
    FlashcardCategory.classroom => const Color(0xFF0277BD),
    FlashcardCategory.transportation => const Color(0xFF4527A0),
    FlashcardCategory.emotions => const Color(0xFFB71C1C),
    FlashcardCategory.daysAndTime => const Color(0xFF33691E),
    FlashcardCategory.actions => const Color(0xFF00838F),
  };
}

extension GameDifficultyX on GameDifficulty {
  String get label => switch (this) {
    GameDifficulty.easy => 'Easy',
    GameDifficulty.medium => 'Medium',
    GameDifficulty.hard => 'Hard',
  };

  String get labelFilipino => switch (this) {
    GameDifficulty.easy => 'Madali',
    GameDifficulty.medium => 'Katamtaman',
    GameDifficulty.hard => 'Mahirap',
  };

  String get description => switch (this) {
    GameDifficulty.easy => 'Fewer questions, more hints — great for beginners!',
    GameDifficulty.medium => 'Balanced challenge — the standard experience',
    GameDifficulty.hard => 'More questions, fewer hints — test your skills!',
  };

  IconData get icon => switch (this) {
    GameDifficulty.easy => Icons.sentiment_satisfied_rounded,
    GameDifficulty.medium => Icons.sentiment_neutral_rounded,
    GameDifficulty.hard => Icons.local_fire_department_rounded,
  };

  Color get color => switch (this) {
    GameDifficulty.easy => const Color(0xFF4CAF50),
    GameDifficulty.medium => const Color(0xFFFF9800),
    GameDifficulty.hard => const Color(0xFFF44336),
  };

  String get emoji => switch (this) {
    GameDifficulty.easy => '😊',
    GameDifficulty.medium => '💪',
    GameDifficulty.hard => '🔥',
  };
}

extension GameTypeX on GameType {
  String get label => switch (this) {
    GameType.wordMatch => 'Word Match',
    GameType.spellingBee => 'Spelling Bee',
    GameType.memoryMatch => 'Memory Match',
    GameType.dragAndDrop => 'Drag & Drop',
    GameType.flashcardQuiz => 'Flashcard Quiz',
    GameType.pronunciation => 'Pronunciation Practice',
    GameType.sentenceBuilder => 'Sentence Builder',
    GameType.storyQuiz => 'Story Quiz',
    GameType.tracing => 'Tracing',
    GameType.fslPractice => 'FSL Practice',
    GameType.jigsawPuzzle => 'Jigsaw Puzzle',
    GameType.pictureWord => 'Picture-Word',
  };

  String get description => switch (this) {
    GameType.wordMatch => 'Match the picture to the correct word!',
    GameType.spellingBee => 'Unscramble the letters to spell the word!',
    GameType.memoryMatch => 'Find matching pairs of cards!',
    GameType.dragAndDrop => 'Drag each word to its matching picture!',
    GameType.flashcardQuiz => 'Swipe right if you know it, left to learn!',
    GameType.pronunciation => 'Listen and pick the correct word!',
    GameType.sentenceBuilder => 'Fill in the missing word in the sentence!',
    GameType.storyQuiz => 'Read a story and answer questions!',
    GameType.tracing => 'Trace the letters of each word!',
    GameType.fslPractice => 'Learn Filipino Sign Language!',
    GameType.jigsawPuzzle => 'Assemble the picture puzzle!',
    GameType.pictureWord => 'Match pictures to words by listening!',
  };

  IconData get icon => switch (this) {
    GameType.wordMatch => Icons.touch_app_rounded,
    GameType.spellingBee => Icons.spellcheck_rounded,
    GameType.memoryMatch => Icons.grid_view_rounded,
    GameType.dragAndDrop => Icons.drag_indicator_rounded,
    GameType.flashcardQuiz => Icons.swipe_rounded,
    GameType.pronunciation => Icons.hearing_rounded,
    GameType.sentenceBuilder => Icons.short_text_rounded,
    GameType.storyQuiz => Icons.auto_stories_rounded,
    GameType.tracing => Icons.draw_rounded,
    GameType.fslPractice => Icons.sign_language_rounded,
    GameType.jigsawPuzzle => Icons.extension_rounded,
    GameType.pictureWord => Icons.image_search_rounded,
  };

  Color get color => switch (this) {
    GameType.wordMatch => const Color(0xFF80DEEA),
    GameType.spellingBee => const Color(0xFFF48FB1),
    GameType.memoryMatch => const Color(0xFFA5D6A7),
    GameType.dragAndDrop => const Color(0xFFFFCC80),
    GameType.flashcardQuiz => const Color(0xFFB39DDB),
    GameType.pronunciation => const Color(0xFF81D4FA),
    GameType.sentenceBuilder => const Color(0xFFFFAB91),
    GameType.storyQuiz => const Color(0xFF9FA8DA),
    GameType.tracing => const Color(0xFF80CBC4),
    GameType.fslPractice => const Color(0xFFB388FF),
    GameType.jigsawPuzzle => const Color(0xFFFFE082),
    GameType.pictureWord => const Color(0xFFC5E1A5),
  };
}

extension GradeLevelX on GradeLevel {
  String get label => switch (this) {
    GradeLevel.kinder => 'Kinder',
    GradeLevel.grade1 => 'Grade 1',
    GradeLevel.grade2 => 'Grade 2',
    GradeLevel.grade3 => 'Grade 3',
    GradeLevel.grade4 => 'Grade 4',
    GradeLevel.grade5 => 'Grade 5',
    GradeLevel.grade6 => 'Grade 6',
    GradeLevel.highSchool => 'High School',
    GradeLevel.college => 'College',
  };

  int get sortOrder => index;
}

extension StudentSortFieldX on StudentSortField {
  String get label => switch (this) {
    StudentSortField.name => 'Name',
    StudentSortField.gradeLevel => 'Grade Level',
    StudentSortField.wordsLearned => 'Words Learned',
    StudentSortField.streakDays => 'Streak',
    StudentSortField.stars => 'Stars',
    StudentSortField.lastActive => 'Last Active',
    StudentSortField.averageAccuracy => 'Accuracy',
    StudentSortField.createdAt => 'Date Joined',
  };

  IconData get icon => switch (this) {
    StudentSortField.name => Icons.sort_by_alpha_rounded,
    StudentSortField.gradeLevel => Icons.school_rounded,
    StudentSortField.wordsLearned => Icons.auto_stories_rounded,
    StudentSortField.streakDays => Icons.local_fire_department_rounded,
    StudentSortField.stars => Icons.star_rounded,
    StudentSortField.lastActive => Icons.schedule_rounded,
    StudentSortField.averageAccuracy => Icons.trending_up_rounded,
    StudentSortField.createdAt => Icons.calendar_today_rounded,
  };
}

extension ActivityStatusX on ActivityStatus {
  String get label => switch (this) {
    ActivityStatus.all => 'All',
    ActivityStatus.activeToday => 'Active Today',
    ActivityStatus.activeThisWeek => 'Active This Week',
    ActivityStatus.inactive7Days => 'Inactive 7+ Days',
  };
}
