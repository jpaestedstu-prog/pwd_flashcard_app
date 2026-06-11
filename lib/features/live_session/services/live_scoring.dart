import '../models/live_session_models.dart';

/// Pure star-scoring logic for live sessions.
///
/// This is the single source of truth for "award stars based on the rules the
/// educator configured". It runs identically on every learner device (the
/// learner self-awards into its own progress doc, since Firestore rules only
/// let a profile write its own progress) and is fully unit-tested with no I/O.
class LiveScoring {
  const LiveScoring._();

  /// Stars to award for a single response.
  ///
  /// Returns 0 for an incorrect answer. For a correct answer it sums:
  ///   • [LiveScoringRules.baseStars] (or the activity's `points` override),
  ///   • a speed bonus that decays linearly from [LiveScoringRules.speedBonusMax]
  ///     (answered instantly) to 0 (answered at/after `speedWindowSec`), and
  ///   • [LiveScoringRules.firstCorrectBonus] when [isFirstCorrect] is true,
  /// then clamps the total so the learner's running session earnings never
  /// exceed [LiveScoringRules.sessionCap] (0 = uncapped).
  ///
  /// [alreadyEarnedThisSession] is the learner's running total of stars earned
  /// in *this* session before this response, used only for the cap.
  static int computeStars({
    required LiveScoringRules rules,
    required bool isCorrect,
    int elapsedMs = 0,
    bool isFirstCorrect = false,
    int alreadyEarnedThisSession = 0,
    int? activityPoints,
  }) {
    if (!isCorrect) return 0;

    final base = (activityPoints ?? rules.baseStars);
    var total = base < 0 ? 0 : base;

    total += _speedBonus(rules, elapsedMs);

    if (isFirstCorrect && rules.firstCorrectEnabled) {
      total += rules.firstCorrectBonus;
    }

    if (total < 0) total = 0;

    // Apply the per-session cap last so bonuses can't push a learner over it.
    if (rules.hasCap) {
      final remaining = rules.sessionCap - alreadyEarnedThisSession;
      if (remaining <= 0) return 0;
      if (total > remaining) return remaining;
    }

    return total;
  }

  /// Linear-decay speed bonus, rounded to the nearest whole star and clamped
  /// to `[0, speedBonusMax]`. A response at `t = 0` earns the full bonus; at
  /// `t >= speedWindowSec` it earns none.
  static int _speedBonus(LiveScoringRules rules, int elapsedMs) {
    if (!rules.speedBonusEnabled) return 0;
    if (elapsedMs <= 0) return rules.speedBonusMax;

    final windowMs = rules.speedWindowSec * 1000;
    if (elapsedMs >= windowMs) return 0;

    final fraction = 1.0 - (elapsedMs / windowMs);
    final bonus = (rules.speedBonusMax * fraction).round();
    if (bonus < 0) return 0;
    if (bonus > rules.speedBonusMax) return rules.speedBonusMax;
    return bonus;
  }
}
