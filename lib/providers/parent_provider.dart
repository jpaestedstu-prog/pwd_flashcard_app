import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../core/constants/avatar_data.dart';
import '../data/local/hive_service.dart';
import '../data/local/seed_data.dart';
import '../features/mood_tracker/models/mood_summary.dart';
import '../features/progress/models/category_mastery.dart';
import '../core/services/session_tracker.dart';
import '../core/services/streak_service.dart';
import '../features/object_scan/services/object_scan_discovery_service.dart';
import 'app_providers.dart';
import 'wall_clock_provider.dart';

// ─── Child Summary Model ───────────────────────────────

/// Aggregated progress snapshot for one child, designed for parent viewing.
class ChildSummary {
  final String profileId;
  final String name;
  final String avatarEmoji;
  final int avatarIndex;
  final DisabilityType disabilityType;

  // Core stats
  final int wordsLearned;
  final int totalStars;
  final int streakDays;
  final int gamesPlayed;
  final double averageAccuracy; // 0.0–1.0

  // Time-based
  final int studyMinutesThisWeek;
  final int studyMinutesLastWeek;
  final int totalSessions;
  final Map<String, int> dailyStudyMinutes; // last 7 days

  // Category breakdown — rolling accuracy average per category.
  final Map<String, double> categoryProgress;

  /// Share of each category's words the learner has actually answered
  /// correctly, 0.0–1.0.
  ///
  /// Separate from [categoryProgress], which despite its name is an accuracy
  /// average and can read 83% for a category the learner has barely opened.
  /// Anything phrased to an educator as "how far through" belongs here.
  final Map<String, double> categoryCoverage;

  // Word Hunt (camera finds) — its own log, not part of LearningProgress.
  final int wordHuntFinds;

  /// Distinct Filipino Sign Language clips this learner has watched, out of the
  /// 142 that exist. Sign-language engagement is the point of the FSL side of
  /// the app and, for a Deaf learner, the main thing an educator wants to see —
  /// but it reached no educator surface at all until now.
  final int signsWatched;
  final int wordHuntStreak;

  /// The learner's wellbeing over the last 7 days, as a pattern only.
  ///
  /// Mood lived exclusively in the learner's own screens and the research
  /// CSV, so the people best placed to respond to a run of hard days could
  /// not see one. Never carries the learner's written notes — see
  /// [MoodSummary].
  final MoodSummary moodSummary;

  // Recent activity
  final List<GameScore> recentScores;
  final DateTime lastActivityDate;

  const ChildSummary({
    required this.profileId,
    required this.name,
    required this.avatarEmoji,
    required this.avatarIndex,
    required this.disabilityType,
    required this.wordsLearned,
    required this.totalStars,
    required this.streakDays,
    required this.gamesPlayed,
    required this.averageAccuracy,
    required this.studyMinutesThisWeek,
    required this.studyMinutesLastWeek,
    required this.totalSessions,
    required this.dailyStudyMinutes,
    required this.categoryProgress,
    required this.categoryCoverage,
    required this.wordHuntFinds,
    required this.signsWatched,
    this.moodSummary = MoodSummary.empty,
    required this.wordHuntStreak,
    required this.recentScores,
    required this.lastActivityDate,
  });

  /// Percentage change in study time vs last week. Positive = improvement.
  double get weekOverWeekChange {
    if (studyMinutesLastWeek == 0) {
      return studyMinutesThisWeek > 0 ? 100.0 : 0.0;
    }
    return ((studyMinutesThisWeek - studyMinutesLastWeek) /
            studyMinutesLastWeek *
            100)
        .clamp(-100.0, 500.0);
  }

  /// Strongest category (highest progress).
  String? get strongestCategory {
    if (categoryProgress.isEmpty) return null;
    return categoryProgress.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Weakest category (lowest progress, but > 0 attempts).
  String? get weakestCategory {
    final attempted = categoryProgress.entries
        .where((e) => e.value > 0)
        .toList();
    if (attempted.isEmpty) return null;
    return attempted.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  /// Categories not yet started.
  List<String> get unexploredCategories {
    final allCats = FlashcardCategory.values.map((c) => c.label).toSet();
    final attempted = categoryProgress.keys
        .where((k) => (categoryProgress[k] ?? 0) > 0)
        .toSet();
    return allCats.difference(attempted).toList();
  }

  /// Whether the child has been active today (same calendar day), matching
  /// how streaks are counted. Avoids the 24-hour-window bug where activity
  /// at 11pm looked "inactive" by 1am the next calendar day.
  bool get isRecentlyActive => StreakService.isActiveToday(lastActivityDate);

  /// Number of categories the learner has covered at least 80% of.
  ///
  /// Counted from [categoryCoverage], not [categoryProgress]: the old reading
  /// counted categories where the learner had merely *answered accurately*, so
  /// five good three-question games registered as a mastered category.
  int get masteredCategories =>
      categoryCoverage.values.where((v) => v >= 0.8).length;
}

// ─── Parent Dashboard Snapshot ─────────────────────────

/// Full parent dashboard state with all children's summaries.
class ParentDashboardSnapshot {
  final DateTime timestamp;
  final List<ChildSummary> children;

  const ParentDashboardSnapshot({
    required this.timestamp,
    required this.children,
  });

  int get totalChildren => children.length;
  int get activeChildren => children.where((c) => c.isRecentlyActive).length;

  // Aggregate stats across all children
  int get totalWordsLearned =>
      children.fold(0, (sum, c) => sum + c.wordsLearned);
  int get totalStarsEarned => children.fold(0, (sum, c) => sum + c.totalStars);
  int get totalGamesPlayed => children.fold(0, (sum, c) => sum + c.gamesPlayed);
  int get totalStudyMinutes =>
      children.fold(0, (sum, c) => sum + c.studyMinutesThisWeek);

  double get overallAccuracy {
    if (children.isEmpty) return 0;
    return children.map((c) => c.averageAccuracy).reduce((a, b) => a + b) /
        children.length;
  }
}

// ─── Parent Dashboard Snapshot Provider ─────────────────
//
// Pure projection over [educatorRosterProvider] (the live, stream-backed
// roster of every child a teacher / parent owns) plus [wallClockTickerProvider]
// (so `isRecentlyActive` flips without a manual refresh as the 24h
// threshold passes).
//
// To force a re-fetch, callers invalidate `educatorRosterProvider(profile.id)`
// — this provider then rebuilds automatically.

ParentDashboardSnapshot _buildSnapshot(
  List<(UserProfile, LearningProgress)> profilesWithProgress,
) {
  // Resolved once for the whole roster rather than per child — the card list is
  // the same for everyone and reading custom cards hits Hive.
  final allCards = [...SeedData.allFlashcards, ...HiveService.getCustomCards()];
  final children = profilesWithProgress
      .where(
        (pair) => pair.$1.role.isEnrollableLearner && !pair.$1.isGuestPlayer,
      )
      .map((pair) {
        final profile = pair.$1;
        final progress = pair.$2;

        double avgAccuracy = 0;
        if (progress.recentScores.isNotEmpty) {
          avgAccuracy =
              progress.recentScores
                  .map((s) => s.total > 0 ? s.score / s.total : 0.0)
                  .reduce((a, b) => a + b) /
              progress.recentScores.length;
        }

        final studyThisWeek = SessionTracker.totalStudyMinutes(
          profile.id,
          days: 7,
        );
        final studyLastWeekRaw =
            SessionTracker.totalStudyMinutes(profile.id, days: 14) -
            studyThisWeek;
        final studyLastWeek = studyLastWeekRaw < 0 ? 0 : studyLastWeekRaw;
        final totalSessions = SessionTracker.totalSessions(profile.id);
        final dailyMinutes = SessionTracker.dailyStudyMinutes(profile.id);

        return ChildSummary(
          profileId: profile.id,
          name: profile.name,
          avatarEmoji: AvatarData.getAvatar(profile.avatarIndex).emoji,
          avatarIndex: profile.avatarIndex,
          disabilityType: profile.disabilityType,
          wordsLearned: progress.wordsLearned,
          totalStars: progress.totalStars,
          streakDays: progress.streakDays,
          gamesPlayed: progress.effectiveGamesPlayed,
          averageAccuracy: avgAccuracy,
          studyMinutesThisWeek: studyThisWeek,
          studyMinutesLastWeek: studyLastWeek,
          totalSessions: totalSessions,
          dailyStudyMinutes: dailyMinutes,
          categoryProgress: progress.categoryProgress,
          categoryCoverage: {
            for (final entry
                in CategoryMastery.forProgress(progress, allCards).entries)
              entry.key.label: entry.value.coverage,
          },
          // Word Hunt keeps its own per-profile discovery log, so an educator can
          // see real-world hunting alongside in-app play.
          wordHuntFinds: ObjectScanDiscoveryService.discoveryCount(profile.id),
          signsWatched: HiveService.fslUniqueWordsViewed(profile.id),
          moodSummary: MoodSummary.fromEntries(
            HiveService.getMoodEntries(profile.id),
          ),
          wordHuntStreak: ObjectScanDiscoveryService.safeHuntStreak(profile.id),
          recentScores: progress.recentScores,
          lastActivityDate: progress.lastActivityDate,
        );
      })
      .toList();

  children.sort((a, b) {
    if (a.isRecentlyActive != b.isRecentlyActive) {
      return a.isRecentlyActive ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  });

  return ParentDashboardSnapshot(timestamp: DateTime.now(), children: children);
}

final parentDashboardProvider = Provider<ParentDashboardSnapshot>((ref) {
  // Force re-evaluation on the 10 s wall-clock tick so `isRecentlyActive`
  // flips without waiting for the next Firestore push.
  ref.watch(wallClockTickerProvider);
  final active = ref.watch(profileProvider);
  if (active == null) {
    return ParentDashboardSnapshot(
      timestamp: DateTime.now(),
      children: const [],
    );
  }
  final rosterAsync = ref.watch(educatorRosterProvider(active.id));
  final profilesWithProgress = rosterAsync.valueOrNull ?? const [];
  return _buildSnapshot(profilesWithProgress);
});
