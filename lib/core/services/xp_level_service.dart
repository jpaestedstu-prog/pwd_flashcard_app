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
///   - Each word learned  = 10 XP
///   - Each star earned    =  2 XP
///   - Each streak day     = 15 XP
///   - Each game played    =  5 XP
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

  /// Total XP earned from the given progress.
  static int calculateXp(LearningProgress progress) {
    final wordXp = progress.wordsLearned * 10;
    final starXp = progress.totalStars * 2;
    final streakXp = progress.streakDays * 15;
    final gameXp = progress.recentScores.length * 5;
    return wordXp + starXp + streakXp + gameXp;
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
