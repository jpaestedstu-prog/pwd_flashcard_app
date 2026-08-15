import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';

/// What the learner did over the last seven days.
///
/// Every other figure on the Progress tab is a lifetime total, which answers
/// "how far have I come?" but never "did I do anything this week?" — the
/// question a learner, a parent and a teacher all actually ask. A lifetime
/// number also stops moving visibly once it is large, so the tab slowly stops
/// giving feedback to exactly the learners who have used it longest.
///
/// Sourced from the day ledger ([HiveService.getDailyActivity]) rather than
/// `recentScores`, which is trimmed to the last 20 entries — a week summary
/// built on it would shrink when a learner played *more*.
class WeeklySummary {
  /// Days in the window with any recorded activity at all.
  final int daysActive;

  /// Minutes studied, from the session logs.
  final int minutes;

  final int games;
  final int stars;

  /// Words learned for the first time this week.
  final int words;

  /// The window length, so the UI can say "7 days" without hardcoding it.
  static const int days = 7;

  const WeeklySummary({
    required this.daysActive,
    required this.minutes,
    required this.games,
    required this.stars,
    required this.words,
  });

  static const empty = WeeklySummary(
    daysActive: 0,
    minutes: 0,
    games: 0,
    stars: 0,
    words: 0,
  );

  /// Nothing recorded in the window. The section says so in words instead of
  /// showing four zeros, which reads as failure rather than as "not yet".
  bool get isEmpty =>
      daysActive == 0 && minutes == 0 && games == 0 && stars == 0 && words == 0;

  /// Builds the summary for [profileId] over the [days] ending at [now].
  ///
  /// The window is counted in **calendar days**, not 7×24 hours: a learner who
  /// played on Monday morning should still see Monday in Monday-to-Sunday
  /// terms on Sunday evening.
  factory WeeklySummary.forProfile(String profileId, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final windowStart = startOfToday.subtract(const Duration(days: days - 1));
    final keys = {
      for (var i = 0; i < days; i++)
        HiveService.dayKey(windowStart.add(Duration(days: i))),
    };

    final ledger = HiveService.getDailyActivity(profileId);
    var games = 0, stars = 0, words = 0;
    final active = <String>{};
    for (final key in keys) {
      final row = ledger[key];
      if (row == null) continue;
      games += row['games'] ?? 0;
      stars += row['stars'] ?? 0;
      words += row['words'] ?? 0;
      if ((row['games'] ?? 0) > 0 ||
          (row['stars'] ?? 0) > 0 ||
          (row['words'] ?? 0) > 0) {
        active.add(key);
      }
    }

    // A learner can be active without finishing a game — reading a story,
    // reviewing cards, doing the daily challenge. Fold in the other two
    // records of "was here today" so the day count is honest.
    active.addAll(
      HiveService.getDailyChallengeHistory(profileId).where(keys.contains),
    );
    // Accumulate seconds and convert once at the end.
    //
    // Rounding each session on its own threw away every remainder, so short
    // sessions vanished: twelve 45-second sittings are nine minutes of study
    // and reported as zero. That fell hardest on the learners who work in the
    // shortest bursts — exactly the ones whose week most needs to show
    // something — and it disagreed with the parent dashboard, which sums
    // seconds first via `SessionTracker.totalStudyMinutes`.
    var seconds = 0;
    for (final session in HiveService.getSessionLogs(profileId)) {
      final date = DateTime.tryParse(session['date'] as String? ?? '');
      if (date == null) continue;
      final key = HiveService.dayKey(date);
      if (!keys.contains(key)) continue;
      active.add(key);
      seconds += (session['durationSeconds'] as int?) ?? 0;
    }
    final minutes = (seconds / 60).round();

    return WeeklySummary(
      daysActive: active.length,
      minutes: minutes,
      games: games,
      stars: stars,
      words: words,
    );
  }
}

/// This week's activity for the active learner.
///
/// Watches [progressProvider] so finishing a game refreshes the section — the
/// ledger is written on the same call.
final weeklySummaryProvider = Provider<WeeklySummary>((ref) {
  final progress = ref.watch(progressProvider);
  if (progress.profileId.isEmpty) return WeeklySummary.empty;
  return WeeklySummary.forProfile(progress.profileId);
});
