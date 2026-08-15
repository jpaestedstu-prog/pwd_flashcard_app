import 'package:flutter/material.dart';
import '../../features/object_scan/services/object_scan_discovery_service.dart';
import 'enums.dart';
import 'models.dart';

/// A Word Hunt badge rung: find this many words with the camera to unlock it.
///
/// Kept beside the achievements it drives and shared with the Word Hunt
/// collection screen, so the "next badge" nudge there can never promise a
/// milestone that does not exist.
class HuntMilestone {
  final int finds;
  final String title;
  final String emoji;
  const HuntMilestone({
    required this.finds,
    required this.title,
    required this.emoji,
  });
}

/// The camera-find ladder, in ascending order. Topped out well below the ~61
/// huntable words so it stays reachable for a learner who hunts occasionally.
const List<HuntMilestone> huntFindMilestones = [
  HuntMilestone(finds: 1, title: 'First Find', emoji: '🔍'),
  HuntMilestone(finds: 10, title: 'Word Spotter', emoji: '🔎'),
  HuntMilestone(finds: 25, title: 'Word Collector', emoji: '🎒'),
];

/// Consecutive hunting days that unlock the "Daily Hunter" badge.
const int kHuntStreakMilestone = 3;

/// The next rung above [finds], or null once every rung is earned.
HuntMilestone? nextHuntMilestone(int finds) {
  for (final milestone in huntFindMilestones) {
    if (finds < milestone.finds) return milestone;
  }
  return null;
}

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
    description: 'You learned $_halfWayWords words — halfway there!',
    icon: Icons.flag_rounded,
    color: const Color(0xFF66BB6A),
    checkUnlocked: (p) => p.wordsLearned >= _halfWayWords,
  );

  /// Word-count rungs, stated as counts rather than as a share of "all
  /// vocabulary". The seed deck has grown (72/144 was half and all of a
  /// 144-word deck; it now holds 177 words, and a learner may add custom cards
  /// on top), so a badge that promises "all the words" at 144 names a finish
  /// line that moved. The thresholds are kept — learners have already earned
  /// them — and only the wording is made true again.
  static const int _halfWayWords = 72;
  static const int _wordMasterWords = 144;

  static final wordMaster = Achievement(
    id: 'word_master',
    title: 'Word Master',
    description: 'Incredible — you learned $_wordMasterWords words!',
    icon: Icons.workspace_premium_rounded,
    color: const Color(0xFFFFD700),
    checkUnlocked: (p) => p.wordsLearned >= _wordMasterWords,
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
        (p.categoryProgress[FlashcardCategory.foodAndDrinks.label] ?? 0) >= 0.9,
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
  //
  // Scored off [LearningProgress.effectiveBestStreak], the high-water mark,
  // not the current run. `streakDays` resets to 1 the moment a day is missed,
  // so checking it meant a learner who was ill for a weekend watched four
  // badges disappear from their Progress tab — and, because
  // `checkAchievements()` re-persists the current set, lost them from storage
  // for good. Being ill costs the flame, never the badge. Same rule the XP
  // economy runs on; see [XpService.calculateXp].

  static final threeDayStreak = Achievement(
    id: 'three_day_streak',
    title: '3-Day Streak',
    description: 'Practiced 3 days in a row — great habit!',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFF44336),
    checkUnlocked: (p) => p.effectiveBestStreak >= 3,
  );

  static final weekStreak = Achievement(
    id: 'week_streak',
    title: '7-Day Streak',
    description: 'A whole week of learning — unstoppable!',
    icon: Icons.whatshot_rounded,
    color: const Color(0xFFFF6D00),
    checkUnlocked: (p) => p.effectiveBestStreak >= 7,
  );

  static final twoWeekStreak = Achievement(
    id: 'two_week_streak',
    title: '14-Day Streak',
    description: 'Two weeks of daily learning — incredible dedication!',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFD50000),
    checkUnlocked: (p) => p.effectiveBestStreak >= 14,
  );

  static final monthStreak = Achievement(
    id: 'month_streak',
    title: '30-Day Streak',
    description: 'A whole month of learning — you are a legend!',
    icon: Icons.military_tech_rounded,
    color: const Color(0xFFFFD600),
    checkUnlocked: (p) => p.effectiveBestStreak >= 30,
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

  /// Distinct game types that earn [gameExplorer].
  ///
  /// Deliberately **not** "every scoreable type". [GameCatalog] gives each
  /// accessibility category a curated roster of ten, so no Student or Child
  /// profile can reach all fourteen scoreable types — a Motor-Impairment
  /// learner can reach ten, a Deaf learner ten, and so on. The old check asked
  /// for all fourteen, which made this the one badge permanently greyed out
  /// for *every* accessibility category in an app built for them.
  ///
  /// Eight clears the smallest roster (nine scoreable games plus Story Quiz
  /// from the Stories tab) with room to spare, so it stays earnable by every
  /// category while still meaning "you have really explored".
  static const int gameExplorerTypes = 8;

  static final gameExplorer = Achievement(
    id: 'game_explorer',
    title: 'Game Explorer',
    description: 'Played $gameExplorerTypes different games!',
    icon: Icons.explore_rounded,
    color: const Color(0xFF00ACC1),
    // Reads the lifetime set, not `recentScores`: twenty rounds of one
    // favourite used to push every other type out of the 20-entry window and
    // silently revoke this badge.
    checkUnlocked: (p) =>
        p.effectivePlayedGameTypes
            .where((gt) => gt != GameType.fslPractice)
            .length >=
        gameExplorerTypes,
  );

  // ─── Story Milestones ────────────────────────────────
  //
  // Read the permanent story record ([LearningProgress.completedStoryIds] and
  // [LearningProgress.storyBestStars]) first and fall back to the score
  // window. Reading only `recentScores` meant a reader's badges expired twenty
  // games after the story — the story itself still shows its ✓ and ★ on the
  // Stories tab, so the two surfaces disagreed about the same event.

  static final firstStory = Achievement(
    id: 'first_story',
    title: 'First Story',
    description: 'Completed your first reading quiz!',
    icon: Icons.auto_stories_rounded,
    color: const Color(0xFF9FA8DA),
    checkUnlocked: (p) =>
        p.completedStoryIds.isNotEmpty ||
        p.storyBestStars.isNotEmpty ||
        p.recentScores.any((s) => s.gameType == GameType.storyQuiz),
  );

  static final storyPerfect = Achievement(
    id: 'story_perfect',
    title: 'Story Star',
    description: 'Got 3/3 on a story quiz — amazing reader!',
    icon: Icons.menu_book_rounded,
    color: const Color(0xFF7E57C2),
    checkUnlocked: (p) =>
        p.storyBestStars.values.any((stars) => stars >= 3) ||
        p.recentScores.any(
          (s) =>
              s.gameType == GameType.storyQuiz &&
              s.score == s.total &&
              s.total > 0,
        ),
  );

  // ─── Word Hunt (camera finds) ─────────────────────────
  //
  // These read the Word Hunt collection rather than [LearningProgress], because
  // a camera discovery is not a game score — it is its own log, keyed by
  // profile. [ObjectScanDiscoveryService]'s guarded accessors mean a closed
  // Hive box reads as "nothing found yet" instead of throwing here.

  static final huntFirstFind = Achievement(
    id: 'hunt_first_find',
    title: huntFindMilestones[0].title,
    description: 'Found your first word with the camera!',
    icon: Icons.photo_camera_rounded,
    color: const Color(0xFFFF7043),
    checkUnlocked: (p) =>
        ObjectScanDiscoveryService.discoveryCount(p.profileId) >=
        huntFindMilestones[0].finds,
  );

  static final huntSpotter = Achievement(
    id: 'hunt_spotter',
    title: huntFindMilestones[1].title,
    description: 'Spotted 10 words out in the real world!',
    icon: Icons.search_rounded,
    color: const Color(0xFFF4511E),
    checkUnlocked: (p) =>
        ObjectScanDiscoveryService.discoveryCount(p.profileId) >=
        huntFindMilestones[1].finds,
  );

  static final huntCollector = Achievement(
    id: 'hunt_collector',
    title: huntFindMilestones[2].title,
    description: 'Collected 25 words with your camera — incredible!',
    icon: Icons.backpack_rounded,
    color: const Color(0xFFD84315),
    checkUnlocked: (p) =>
        ObjectScanDiscoveryService.discoveryCount(p.profileId) >=
        huntFindMilestones[2].finds,
  );

  static final huntDailyStreak = Achievement(
    id: 'hunt_daily_streak',
    title: 'Daily Hunter',
    description: 'Found a new word $kHuntStreakMilestone days in a row!',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFBF360C),
    checkUnlocked: (p) =>
        ObjectScanDiscoveryService.safeHuntStreak(p.profileId) >=
        kHuntStreakMilestone,
  );

  // ─── Filipino Sign Language ───────────────────────────
  // Watching signs is the core act of the FSL side of the app and, for a Deaf
  // learner, the whole point of it — but it unlocked nothing until now. The
  // rungs are sized against the 142 signs that actually exist, not the 177 seed
  // words: 35 have no clip recorded, so a target of 177 could never be reached.

  static final firstSign = Achievement(
    id: 'first_sign',
    title: 'First Sign',
    description: 'Watched your very first sign in Filipino Sign Language!',
    icon: Icons.sign_language_rounded,
    color: const Color(0xFF26A69A),
    checkUnlocked: (p) => p.signsLearned >= 1,
  );

  static final signExplorer = Achievement(
    id: 'sign_explorer',
    title: 'Sign Explorer',
    description: 'Watched 25 different signs — your hands are learning!',
    icon: Icons.waving_hand_rounded,
    color: const Color(0xFF00897B),
    checkUnlocked: (p) => p.signsLearned >= 25,
  );

  static final signFluent = Achievement(
    id: 'sign_fluent',
    title: 'Sign Fluent',
    description: 'Watched 100 different signs. That is real fluency!',
    icon: Icons.back_hand_rounded,
    color: const Color(0xFF00695C),
    checkUnlocked: (p) => p.signsLearned >= 100,
  );

  static final firstVerifiedSign = Achievement(
    id: 'first_verified_sign',
    title: 'Signed It!',
    description: 'A teacher confirmed your very first sign!',
    icon: Icons.verified_rounded,
    color: const Color(0xFF00838F),
    checkUnlocked: (p) => p.signsConfirmed >= 1,
  );

  static final verifiedSigner = Achievement(
    id: 'verified_signer',
    title: 'Verified Signer',
    description: '10 of your signs have been confirmed by a teacher.',
    icon: Icons.workspace_premium_rounded,
    color: const Color(0xFF006064),
    checkUnlocked: (p) => p.signsConfirmed >= 10,
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
    // Word Hunt
    huntFirstFind,
    huntSpotter,
    huntCollector,
    huntDailyStreak,
    // Filipino Sign Language
    firstSign,
    signExplorer,
    signFluent,
    firstVerifiedSign,
    verifiedSigner,
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
  ///
  /// This is a *live* evaluation. Prefer [durableUnlockedIds] anywhere a
  /// learner is shown their badges — see the note there.
  static Set<String> unlockedIds(LearningProgress progress) {
    return all.where((a) => a.checkUnlocked(progress)).map((a) => a.id).toSet();
  }

  /// Every badge the learner holds: what they have *ever* unlocked, union what
  /// the live check reports now.
  ///
  /// A badge is a record of something that happened, so it cannot be taken
  /// back by later events. The individual checks above are all monotonic now,
  /// but the union is still the honest answer for two reasons:
  ///
  ///   * `perfect_score` can only be seen in the moment — it is true while the
  ///     100% game sits in the 20-entry `recentScores` window and unknowable
  ///     afterwards. The stored id is the only lasting evidence.
  ///   * The live side still matters: an educator confirming a sign unlocks
  ///     `first_verified_sign` on *their* device, so the learner's stored set
  ///     has not caught up yet.
  ///
  /// [previouslyUnlockedIds] is filtered against [all] so a badge retired in a
  /// later build doesn't linger as an id nothing can render.
  static Set<String> durableUnlockedIds({
    required LearningProgress progress,
    required Set<String> previouslyUnlockedIds,
  }) {
    final known = {for (final a in all) a.id};
    return {
      ...previouslyUnlockedIds.where(known.contains),
      ...unlockedIds(progress),
    };
  }
}
