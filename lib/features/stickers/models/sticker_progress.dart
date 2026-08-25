import '../../../data/models/models.dart';

/// How close a learner is to a locked sticker.
///
/// The album used to say only "Learn 50 words" behind every lock — true, but
/// it never said whether the learner was at 3 words or at 49. A locked shelf
/// with no sense of nearness reads as a wall; the same shelf with "38 / 50"
/// on it reads as a goal.
class StickerProgress {
  /// How much the learner has done, in the unit the goal is counted in.
  final int current;

  /// How much the goal needs. Zero for conditions that are not a count
  /// (for example "get a perfect score"), which have no meaningful bar.
  final int target;

  const StickerProgress({required this.current, required this.target});

  /// A condition with no countable progress — either/or, not nearer/further.
  static const StickerProgress none = StickerProgress(current: 0, target: 0);

  bool get isCountable => target > 0;

  bool get isComplete => isCountable && current >= target;

  /// 0..1, clamped. Meaningless when [isCountable] is false.
  double get fraction =>
      isCountable ? (current / target).clamp(0.0, 1.0) : 0.0;

  /// "38 / 50", for the tile and the detail sheet.
  String get label => '$current / $target';

  /// Progress toward [conditionId] for [progress].
  ///
  /// The thresholds here mirror `StickerUnlockChecker.isUnlocked` exactly —
  /// same fields, same numbers. Anything the checker treats as a non-count
  /// (perfect scores, a first story) returns [none] rather than a made-up
  /// bar, so the album never implies a learner is "halfway" to something
  /// that only happens all at once.
  static StickerProgress forCondition(
    String conditionId,
    LearningProgress progress, {
    int completedPaths = 0,
    int dailyChallenges = 0,
    int ownedStickers = 0,
  }) {
    StickerProgress of(int current, int target) =>
        StickerProgress(current: current, target: target);

    final masteredCategories =
        progress.categoryProgress.values.where((v) => v >= 0.8).length;

    return switch (conditionId) {
      'words_5' => of(progress.wordsLearned, 5),
      'words_10' => of(progress.wordsLearned, 10),
      'words_25' => of(progress.wordsLearned, 25),
      'words_50' => of(progress.wordsLearned, 50),
      'words_100' => of(progress.wordsLearned, 100),
      'stars_10' => of(progress.totalStars, 10),
      'stars_50' => of(progress.totalStars, 50),
      'stars_100' => of(progress.totalStars, 100),
      'stars_500' => of(progress.totalStars, 500),
      'games_1' => of(progress.effectiveGamesPlayed, 1),
      'games_10' => of(progress.effectiveGamesPlayed, 10),
      'perfect_5' => of(
          progress.recentScores
              .where((s) => s.score == s.total && s.total > 0)
              .length,
          5,
        ),
      'path_complete_1' => of(completedPaths, 1),
      'categories_3' => of(masteredCategories, 3),
      'categories_12' => of(masteredCategories, 12),
      'streak_3' => of(progress.streakDays, 3),
      'streak_7' => of(progress.streakDays, 7),
      'streak_14' => of(progress.streakDays, 14),
      'streak_30' => of(progress.streakDays, 30),
      'daily_5' => of(dailyChallenges, 5),
      'daily_20' => of(dailyChallenges, 20),
      'stickers_20' => of(ownedStickers, 20),
      // 'perfect_score' and 'stories_1' are one-shot events, not counts.
      _ => none,
    };
  }
}

/// The unit a sticker goal is counted in, for a plain-language "3 more words
/// to go" line. Derived from the condition id so it cannot drift from
/// [StickerProgress.forCondition].
enum StickerGoalUnit { words, stars, games, days, challenges, stickers, other }

extension StickerGoalUnitX on StickerGoalUnit {
  String get label => switch (this) {
        StickerGoalUnit.words => 'words',
        StickerGoalUnit.stars => 'stars',
        StickerGoalUnit.games => 'games',
        StickerGoalUnit.days => 'days',
        StickerGoalUnit.challenges => 'challenges',
        StickerGoalUnit.stickers => 'stickers',
        StickerGoalUnit.other => 'to go',
      };

  String get labelFilipino => switch (this) {
        StickerGoalUnit.words => 'salita',
        StickerGoalUnit.stars => 'bituin',
        StickerGoalUnit.games => 'laro',
        StickerGoalUnit.days => 'araw',
        StickerGoalUnit.challenges => 'hamon',
        StickerGoalUnit.stickers => 'sticker',
        StickerGoalUnit.other => 'na lang',
      };

  static StickerGoalUnit forCondition(String conditionId) {
    if (conditionId.startsWith('words_')) return StickerGoalUnit.words;
    if (conditionId.startsWith('stars_')) return StickerGoalUnit.stars;
    if (conditionId.startsWith('games_')) return StickerGoalUnit.games;
    if (conditionId.startsWith('streak_')) return StickerGoalUnit.days;
    if (conditionId.startsWith('daily_')) return StickerGoalUnit.challenges;
    if (conditionId.startsWith('stickers_')) return StickerGoalUnit.stickers;
    return StickerGoalUnit.other;
  }
}

