import '../../data/models/models.dart';

/// A named level with its XP threshold.
class PlayerLevel {
  final int level;
  final String title;
  final String emoji;
  final int xpRequired;

  const PlayerLevel({
    required this.level,
    required this.title,
    required this.emoji,
    required this.xpRequired,
  });
}

/// Computes XP and levels from a student's [LearningProgress].
///
/// XP formula:
///   - Each word learned   = 10 XP
///   - Each star earned    =  2 XP
///   - Each best-streak day = 15 XP
///   - Each game played    =  5 XP
///
/// **Every input is monotonic, so XP never falls and a learner can never be
/// demoted.** That is a deliberate design rule, not an accident of the current
/// numbers: this app's learners are exactly the ones a punishment mechanic
/// hurts most. Two of the inputs used to break it —
///
///   - `streakDays` resets to 1 the moment a day is missed, so a fortnight's
///     streak evaporating dropped 195 XP and could demote a learner a whole
///     level for being ill. Scored off [LearningProgress.effectiveBestStreak]
///     instead, which is a high-water mark.
///   - `recentScores` is trimmed to the last 20 entries, so game XP silently
///     capped at 100. Scored off [LearningProgress.effectiveGamesPlayed].
///
/// Anything added here must be monotonic too. Stars use `totalStars` (lifetime
/// earnings) rather than `starBalance`, so spending in the Shop costs no XP.
class XpService {
  XpService._();

  // ─── Level Table ──────────────────────────────────
  static const List<PlayerLevel> levels = [
    PlayerLevel(level: 1, title: 'Beginner', emoji: '🌱', xpRequired: 0),
    PlayerLevel(level: 2, title: 'Explorer', emoji: '🔍', xpRequired: 100),
    PlayerLevel(level: 3, title: 'Learner', emoji: '📖', xpRequired: 300),
    PlayerLevel(level: 4, title: 'Achiever', emoji: '🏅', xpRequired: 600),
    PlayerLevel(level: 5, title: 'Scholar', emoji: '🎓', xpRequired: 1000),
    PlayerLevel(level: 6, title: 'Expert', emoji: '🧠', xpRequired: 1500),
    PlayerLevel(level: 7, title: 'Champion', emoji: '🏆', xpRequired: 2200),
    PlayerLevel(level: 8, title: 'Master', emoji: '👑', xpRequired: 3000),
    PlayerLevel(level: 9, title: 'Legend', emoji: '⭐', xpRequired: 4000),
    PlayerLevel(level: 10, title: 'Grandmaster', emoji: '💎', xpRequired: 5500),
  ];

  /// Total XP earned from the given progress. Never decreases — see the class
  /// doc for why each input is the monotonic one.
  static int calculateXp(LearningProgress progress) {
    final wordXp = progress.wordsLearned * 10;
    final starXp = progress.totalStars * 2;
    final streakXp = progress.effectiveBestStreak * 15;
    final gameXp = progress.effectiveGamesPlayed * 5;
    // Distinct signs watched. Monotonic like the rest: the set only ever grows,
    // so a learner can never de-level. Worth less than a word learned (which
    // requires answering correctly) but more than a game played — watching a
    // new sign is the core act of the FSL side of the app, and until now it
    // earned nothing at all.
    final signXp = progress.signsLearned * 8;
    // Educator-confirmed production. Worth more than watching a sign (8) or
    // answering a recognition question (10): it took a learner claiming it and
    // a teacher watching them do it.
    //
    // Only *confirmed* signs score — a bare self-claim earns nothing. That is
    // deliberate: the claim is unverified self-report, and if it paid XP a
    // learner could tap through 142 words and level up without signing once,
    // which would also poison the calibration measure this feature exists to
    // produce. Scored off the monotonic ever-confirmed set, so an educator
    // downgrading a word never de-levels the learner.
    final confirmedSignXp = progress.signsConfirmed * 15;
    return wordXp + starXp + streakXp + gameXp + signXp + confirmedSignXp;
  }

  /// XP earned *inside* the current level band — the numerator that matches
  /// [progressToNextLevel]'s bar. At max level this is the full band.
  static int xpIntoLevel(LearningProgress progress) {
    final xp = calculateXp(progress);
    return xp - currentLevel(progress).xpRequired;
  }

  /// Total XP the current level band spans, i.e. the denominator that matches
  /// [progressToNextLevel]'s bar. Null at max level, where there is no band.
  static int? xpLevelSpan(LearningProgress progress) {
    final next = nextLevel(progress);
    if (next == null) return null;
    return next.xpRequired - currentLevel(progress).xpRequired;
  }

  /// XP still needed to reach the next level, or null at max level.
  static int? xpToNextLevel(LearningProgress progress) {
    final next = nextLevel(progress);
    if (next == null) return null;
    return (next.xpRequired - calculateXp(progress)).clamp(0, next.xpRequired);
  }

  /// The current [PlayerLevel] for the given progress.
  static PlayerLevel currentLevel(LearningProgress progress) {
    final xp = calculateXp(progress);
    return levelForXp(xp);
  }

  /// The [PlayerLevel] for a given XP amount.
  static PlayerLevel levelForXp(int xp) {
    var result = levels.first;
    for (final lvl in levels) {
      if (xp >= lvl.xpRequired) {
        result = lvl;
      } else {
        break;
      }
    }
    return result;
  }

  /// The next level after the current one, or null if at max level.
  static PlayerLevel? nextLevel(LearningProgress progress) {
    final current = currentLevel(progress);
    final idx = levels.indexWhere((l) => l.level == current.level);
    if (idx < 0 || idx >= levels.length - 1) return null;
    return levels[idx + 1];
  }

  /// Progress fraction (0.0–1.0) towards the next level.
  /// Returns 1.0 if at max level.
  static double progressToNextLevel(LearningProgress progress) {
    final xp = calculateXp(progress);
    final current = currentLevel(progress);
    final next = nextLevel(progress);
    if (next == null) return 1.0;

    final xpIntoLevel = xp - current.xpRequired;
    final xpNeeded = next.xpRequired - current.xpRequired;
    if (xpNeeded <= 0) return 1.0;
    return (xpIntoLevel / xpNeeded).clamp(0.0, 1.0);
  }
}
