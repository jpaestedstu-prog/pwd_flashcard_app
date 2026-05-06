import '../../../data/models/models.dart';

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

  /// Build from a profile + progress pair
  factory StudentAnalytics.from(UserProfile profile, LearningProgress progress,
      {Duration studyTime = Duration.zero}) {
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
      gamesPlayed: progress.recentScores.length,
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

  /// Build from a list of student analytics
  factory ClassAnalytics.fromStudents(List<StudentAnalytics> students) {
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

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final active =
        students.where((s) => s.lastActive.isAfter(weekAgo)).length;

    final avgAccuracy = students.fold<double>(
            0, (s, a) => s + a.averageAccuracy) /
        students.length;
    final totalWords =
        students.fold<int>(0, (s, a) => s + a.wordsLearned);
    final totalStars =
        students.fold<int>(0, (s, a) => s + a.totalStars);
    final totalGames =
        students.fold<int>(0, (s, a) => s + a.gamesPlayed);

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

    String? strongest;
    String? weakest;
    double maxVal = -1;
    double minVal = 2;
    for (final entry in catAvgs.entries) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
        strongest = entry.key;
      }
      if (entry.value < minVal) {
        minVal = entry.value;
        weakest = entry.key;
      }
    }

    final needHelp = students.where((s) => s.averageAccuracy < 0.5).toList();

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
      students: students..sort((a, b) => b.wordsLearned.compareTo(a.wordsLearned)),
      studentsNeedingHelp: needHelp,
    );
  }
}
