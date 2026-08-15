import '../../../data/models/models.dart';

/// How a learner is doing, as an educator would triage them.
///
/// Replaces a bare `accuracy < 50%` test, which silently swept in every
/// learner who had simply never played (their accuracy defaults to 0) — a
/// teacher opening Analytics saw most of the class in a red alert.
enum StudentStanding {
  /// No graded activity yet — nothing to judge, so never "needs help".
  notStarted,

  /// Has activity, but none in the last 7 days.
  inactive,

  /// Enough evidence ([minGradedGames]+ games) and still below 50%.
  struggling,

  /// Has recent activity and acceptable accuracy.
  onTrack;

  /// Games needed before low accuracy is treated as a real signal rather
  /// than a small-sample artifact.
  static const int minGradedGames = 3;

  bool get needsHelp => this == StudentStanding.struggling;
}

/// Aggregated analytics for a single student
class StudentAnalytics {
  final String profileId;
  final String name;
  final int avatarIndex;
  final int wordsLearned;
  final int totalStars;
  final int streakDays;
  final int gamesPlayed;
  final double averageAccuracy;
  final Map<String, double> categoryProgress;
  final String? strongestCategory;
  final String? weakestCategory;
  final Duration totalStudyTime;
  final DateTime lastActive;

  const StudentAnalytics({
    required this.profileId,
    required this.name,
    required this.avatarIndex,
    required this.wordsLearned,
    required this.totalStars,
    required this.streakDays,
    required this.gamesPlayed,
    required this.averageAccuracy,
    required this.categoryProgress,
    this.strongestCategory,
    this.weakestCategory,
    required this.totalStudyTime,
    required this.lastActive,
  });

  /// True once the learner has any graded game — i.e. [averageAccuracy]
  /// means something. Without this, "0% accuracy" is indistinguishable
  /// between "got everything wrong" and "never played".
  bool get hasGradedActivity => gamesPlayed > 0;

  /// Triage bucket for this learner. [now] is injectable for tests.
  StudentStanding standing({DateTime? now}) {
    if (!hasGradedActivity) return StudentStanding.notStarted;
    final reference = now ?? DateTime.now();
    if (lastActive.isBefore(reference.subtract(const Duration(days: 7)))) {
      return StudentStanding.inactive;
    }
    if (gamesPlayed >= StudentStanding.minGradedGames &&
        averageAccuracy < 0.5) {
      return StudentStanding.struggling;
    }
    return StudentStanding.onTrack;
  }

  /// Build from a profile + progress pair
  factory StudentAnalytics.from(
    UserProfile profile,
    LearningProgress progress, {
    Duration studyTime = Duration.zero,
  }) {
    // Calculate average accuracy from recent scores
    double avgAccuracy = 0.0;
    if (progress.recentScores.isNotEmpty) {
      final sum = progress.recentScores.fold<double>(
        0,
        (s, score) => s + (score.total > 0 ? score.score / score.total : 0),
      );
      avgAccuracy = sum / progress.recentScores.length;
    }

    // Find strongest and weakest categories
    String? strongest;
    String? weakest;
    double maxProgress = -1;
    double minProgress = 2;
    for (final entry in progress.categoryProgress.entries) {
      if (entry.value > maxProgress) {
        maxProgress = entry.value;
        strongest = entry.key;
      }
      if (entry.value < minProgress) {
        minProgress = entry.value;
        weakest = entry.key;
      }
    }

    return StudentAnalytics(
      profileId: profile.id,
      name: profile.name,
      avatarIndex: profile.avatarIndex,
      wordsLearned: progress.wordsLearned,
      totalStars: progress.totalStars,
      streakDays: progress.streakDays,
      gamesPlayed: progress.effectiveGamesPlayed,
      averageAccuracy: avgAccuracy,
      categoryProgress: progress.categoryProgress,
      strongestCategory: strongest,
      weakestCategory: weakest,
      totalStudyTime: studyTime,
      lastActive: progress.lastActivityDate,
    );
  }
}

/// Aggregated class-level analytics
class ClassAnalytics {
  final int totalStudents;
  final int activeStudents; // active in last 7 days
  final double classAverageAccuracy;
  final int classWordsLearned;
  final int classTotalStars;
  final int classGamesPlayed;
  final Map<String, double> categoryAverages;
  final String? classStrongestCategory;
  final String? classWeakestCategory;
  final List<StudentAnalytics> students;
  final List<StudentAnalytics> studentsNeedingHelp; // accuracy < 50%

  const ClassAnalytics({
    required this.totalStudents,
    required this.activeStudents,
    required this.classAverageAccuracy,
    required this.classWordsLearned,
    required this.classTotalStars,
    required this.classGamesPlayed,
    required this.categoryAverages,
    this.classStrongestCategory,
    this.classWeakestCategory,
    required this.students,
    required this.studentsNeedingHelp,
  });

  /// Build from a list of student analytics.
  ///
  /// [now] is injectable so the "active in the last 7 days" and "needs help"
  /// windows can be evaluated against a fixed clock in tests — otherwise a
  /// test's hard-coded `lastActive` dates silently age past the window and the
  /// suite starts failing on a calendar date rather than a code change.
  factory ClassAnalytics.fromStudents(
    List<StudentAnalytics> students, {
    DateTime? now,
  }) {
    if (students.isEmpty) {
      return const ClassAnalytics(
        totalStudents: 0,
        activeStudents: 0,
        classAverageAccuracy: 0,
        classWordsLearned: 0,
        classTotalStars: 0,
        classGamesPlayed: 0,
        categoryAverages: {},
        students: [],
        studentsNeedingHelp: [],
      );
    }

    final asOf = now ?? DateTime.now();
    final weekAgo = asOf.subtract(const Duration(days: 7));
    final active = students.where((s) => s.lastActive.isAfter(weekAgo)).length;

    // Average over learners who actually have graded games. Including
    // never-played learners (accuracy 0.0) dragged the class average toward
    // zero and made an active class look like it was failing.
    final graded = students.where((s) => s.hasGradedActivity).toList();
    final avgAccuracy = graded.isEmpty
        ? 0.0
        : graded.fold<double>(0, (s, a) => s + a.averageAccuracy) /
              graded.length;
    final totalWords = students.fold<int>(0, (s, a) => s + a.wordsLearned);
    final totalStars = students.fold<int>(0, (s, a) => s + a.totalStars);
    final totalGames = students.fold<int>(0, (s, a) => s + a.gamesPlayed);

    // Aggregate category averages
    final catSums = <String, double>{};
    final catCounts = <String, int>{};
    for (final s in students) {
      for (final entry in s.categoryProgress.entries) {
        catSums[entry.key] = (catSums[entry.key] ?? 0) + entry.value;
        catCounts[entry.key] = (catCounts[entry.key] ?? 0) + 1;
      }
    }
    final catAvgs = catSums.map(
      (key, value) => MapEntry(key, value / (catCounts[key] ?? 1)),
    );

    // Strongest / weakest only mean something when the categories actually
    // differ. With every category tied (e.g. a class that hasn't started,
    // all at 0%) the old first-wins scan still crowned an arbitrary winner
    // and red-flagged an arbitrary loser. Ties now resolve by name so the
    // pick is at least deterministic, and a flat spread reports neither.
    String? strongest;
    String? weakest;
    if (catAvgs.isNotEmpty) {
      final ordered = catAvgs.entries.toList()
        ..sort((a, b) {
          final byValue = b.value.compareTo(a.value);
          return byValue != 0 ? byValue : a.key.compareTo(b.key);
        });
      if (ordered.first.value > ordered.last.value) {
        strongest = ordered.first.key;
        weakest = ordered.last.key;
      }
    }

    final needHelp = students
        .where((s) => s.standing(now: asOf).needsHelp)
        .toList();

    // Rank by demonstrated learning, then break ties so the order is stable
    // and meaningful: words → accuracy → stars → games → name. Sorting on
    // words alone put learners with identical (often zero) word counts in
    // arbitrary order, which handed the top medals to inactive learners
    // while a 100%-accuracy learner ranked near the bottom.
    final ranked = [...students]
      ..sort((a, b) {
        final byWords = b.wordsLearned.compareTo(a.wordsLearned);
        if (byWords != 0) return byWords;
        final byAccuracy = b.averageAccuracy.compareTo(a.averageAccuracy);
        if (byAccuracy != 0) return byAccuracy;
        final byStars = b.totalStars.compareTo(a.totalStars);
        if (byStars != 0) return byStars;
        final byGames = b.gamesPlayed.compareTo(a.gamesPlayed);
        if (byGames != 0) return byGames;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ClassAnalytics(
      totalStudents: students.length,
      activeStudents: active,
      classAverageAccuracy: avgAccuracy,
      classWordsLearned: totalWords,
      classTotalStars: totalStars,
      classGamesPlayed: totalGames,
      categoryAverages: catAvgs,
      classStrongestCategory: strongest,
      classWeakestCategory: weakest,
      students: ranked,
      studentsNeedingHelp: needHelp,
    );
  }
}
