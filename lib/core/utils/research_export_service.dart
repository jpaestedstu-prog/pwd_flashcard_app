import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../data/local/hive_service.dart';
import '../../data/local/spaced_repetition_service.dart';
import '../../features/assessment/services/assessment_service.dart';
import '../../features/assessment/models/assessment_models.dart';
import '../../features/survey/services/survey_service.dart';
import '../../features/experiment/models/experiment_models.dart';
import '../../features/experiment/services/experiment_service.dart';
import '../services/adaptive_difficulty_service.dart';
import '../services/engagement_tracker.dart';

/// Generates anonymized, cross-student research data exports for thesis
/// analysis. Unlike [CsvExportService] (single-student), this aggregates
/// all student data into research-grade datasets.
///
/// Exported files:
/// 1. `students_overview.csv`  – one row per student (anonymized)
/// 2. `learning_curves.csv`    – game scores over time per student
/// 3. `session_patterns.csv`   – session logs across all students
/// 4. `category_mastery.csv`   – per-category progress per student
/// 5. `word_accuracy.csv`      – per-word spaced-repetition data
/// 6. `assessment_results.csv` – pre/post test & learning gains
/// 7. `mood_data.csv`          – mood entries correlated with activity
/// 8. `adaptive_difficulty.csv` – per-game difficulty adjustments over time
/// 9. `summary_stats.json`     – high-level aggregates for quick analysis
class ResearchExportService {
  const ResearchExportService._();

  /// Generate all research CSV files and share as a bundle.
  static Future<void> generateAndShare() async {
    final profiles = HiveService.getAllProfilesWithProgress();
    final students = profiles
        .where((p) => p.$1.role == UserRole.student)
        .toList();

    if (students.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toString().split(' ').first;
    final exportDir =
        Directory('${dir.path}/FlashLearn_Research_$dateStr');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create(recursive: true);

    // Build anonymized ID mapping: profileId → "S001", "S002", ...
    final idMap = <String, String>{};
    for (var i = 0; i < students.length; i++) {
      idMap[students[i].$1.id] = 'S${(i + 1).toString().padLeft(3, '0')}';
    }

    // Generate all CSV files in parallel
    final files = <XFile>[];

    files.add(await _writeFile(
      exportDir,
      'students_overview.csv',
      _buildStudentsOverview(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'learning_curves.csv',
      _buildLearningCurves(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'session_patterns.csv',
      _buildSessionPatterns(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'category_mastery.csv',
      _buildCategoryMastery(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'word_accuracy.csv',
      _buildWordAccuracy(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'assessment_results.csv',
      _buildAssessmentResults(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'mood_data.csv',
      _buildMoodData(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'adaptive_difficulty.csv',
      _buildAdaptiveDifficulty(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'sus_survey_results.csv',
      _buildSusSurveyResults(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'experiment_groups.csv',
      _buildExperimentGroups(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'engagement_metrics.csv',
      _buildEngagementMetrics(students, idMap),
    ));

    files.add(await _writeFile(
      exportDir,
      'summary_stats.json',
      _buildSummaryJson(students, idMap),
    ));

    await Share.shareXFiles(
      files,
      subject: 'FlashLearn PWD – Research Data Export ($dateStr)',
    );
  }

  // ─── File 1: Students Overview ──────────────────────────

  static String _buildStudentsOverview(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,disability_type,grade_level,age,'
      'words_learned,total_stars,streak_days,games_played,'
      'avg_accuracy,study_minutes_total,days_active,'
      'achievements_unlocked,categories_explored,'
      'account_age_days',
    );

    for (final (profile, progress) in students) {
      final sid = idMap[profile.id]!;
      final sessions = HiveService.getSessionLogs(profile.id);
      final totalMinutes = sessions.fold<int>(
        0,
        (sum, s) => sum + (((s['durationSeconds'] as int?) ?? 0) ~/ 60),
      );
      final uniqueDays = sessions
          .map((s) => (s['date'] as String? ?? '').split(' ').first)
          .toSet()
          .length;
      final achievements =
          HiveService.getUnlockedAchievements(profile.id).length;
      final categoriesExplored = progress.categoryProgress.entries
          .where((e) => e.value > 0)
          .length;
      final srSummary = SpacedRepetitionService.getSummary(profile.id);
      final avgAcc = srSummary.totalAttempted > 0
          ? (srSummary.totalCorrect / srSummary.totalAttempted * 100).round()
          : 0;
      final accountAge =
          DateTime.now().difference(profile.createdAt).inDays;

      buf.writeln(
        '$sid,'
        '${profile.disabilityType.name},'
        '${profile.gradeLevel?.name ?? "unknown"},'
        '${profile.age ?? ""},'
        '${progress.wordsLearned},'
        '${progress.totalStars},'
        '${progress.streakDays},'
        '${progress.recentScores.length},'
        '$avgAcc,'
        '$totalMinutes,'
        '$uniqueDays,'
        '$achievements,'
        '$categoriesExplored,'
        '$accountAge',
      );
    }
    return buf.toString();
  }

  // ─── File 2: Learning Curves ────────────────────────────

  static String _buildLearningCurves(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,date,game_type,score,total,percentage,'
      'stars_earned,duration_seconds,game_index',
    );

    for (final (profile, progress) in students) {
      final sid = idMap[profile.id]!;
      // Sort scores chronologically
      final scores = [...progress.recentScores]
        ..sort((a, b) => a.date.compareTo(b.date));

      for (var i = 0; i < scores.length; i++) {
        final s = scores[i];
        final pct =
            s.total > 0 ? (s.score / s.total * 100).round() : 0;
        buf.writeln(
          '$sid,'
          '${s.date.toIso8601String()},'
          '${s.gameType.name},'
          '${s.score},'
          '${s.total},'
          '$pct,'
          '${s.starsEarned},'
          '${s.durationSeconds ?? ""},'
          '${i + 1}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 3: Session Patterns ───────────────────────────

  static String _buildSessionPatterns(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,date,duration_minutes,games_played,'
      'cards_reviewed,day_of_week',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final sessions = HiveService.getSessionLogs(profile.id);

      for (final s in sessions) {
        final dateStr = s['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        final datePart = dateStr.contains(' ') ? dateStr.split(' ').first : dateStr;
        final durMin = ((s['durationSeconds'] as int?) ?? 0) ~/ 60;
        final dayOfWeek = date != null ? date.weekday : '';

        buf.writeln(
          '$sid,'
          '$datePart,'
          '$durMin,'
          '${s['gamesPlayed'] ?? 0},'
          '${s['cardsReviewed'] ?? 0},'
          '$dayOfWeek',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 4: Category Mastery ───────────────────────────

  static String _buildCategoryMastery(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    // Header: student_id + one column per category
    const cats = FlashcardCategory.values;
    buf.write('student_id,disability_type');
    for (final cat in cats) {
      buf.write(',${_esc(cat.label)}');
    }
    buf.writeln();

    for (final (profile, progress) in students) {
      final sid = idMap[profile.id]!;
      buf.write('$sid,${profile.disabilityType.name}');
      for (final cat in cats) {
        final pct =
            ((progress.categoryProgress[cat.label] ?? 0.0) * 100).round();
        buf.write(',$pct');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ─── File 5: Word Accuracy ──────────────────────────────

  static String _buildWordAccuracy(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,word_id,correct,total,accuracy_pct,'
      'last_seen,days_since_seen',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final accs = SpacedRepetitionService.getWordAccuracies(profile.id);

      for (final entry in accs.entries) {
        final wa = entry.value;
        final accPct = (wa.accuracy * 100).round();
        final daysSince =
            DateTime.now().difference(wa.lastSeen).inDays;
        buf.writeln(
          '$sid,'
          '${entry.key},'
          '${wa.correct},'
          '${wa.total},'
          '$accPct,'
          '${wa.lastSeen.toIso8601String()},'
          '$daysSince',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 6: Assessment Results ─────────────────────────

  static String _buildAssessmentResults(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,group_label,experiment_enabled,'
      'assessment_type,score,total_questions,'
      'percentage,duration_seconds,completed_at,'
      'learning_gain,normalized_gain',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final results = AssessmentService.getResults(profile.id);

      // Denormalize the experiment group onto every row so a treatment-vs-
      // control test runs straight off this file, with no manual JOIN against
      // experiment_groups.csv by student_id.
      final config = ExperimentService.getConfig(profile.id);
      final groupLabel = _esc(config.groupLabel);
      final expEnabled = config.enabled ? 1 : 0;

      // Get learning gain if both pre and post exist. learning_gain is the raw
      // post−pre percentage-point change; normalized_gain is Hake's g, a
      // ceiling-corrected decimal in (−∞, 1] (blank when pre-test is perfect).
      final gainReport = AssessmentService.getLearningGainReport(profile.id);
      final gainValue = gainReport != null
          ? (gainReport.improvement * 100).round().toString()
          : '';
      final normGain = gainReport?.normalizedGain;
      final normGainValue =
          normGain != null ? normGain.toStringAsFixed(3) : '';

      for (final r in results) {
        final pct =
            r.totalQuestions > 0
                ? (r.score / r.totalQuestions * 100).round()
                : 0;
        // Only attach learning-gain metrics to the post-test row.
        final isPost = r.type == AssessmentType.postTest;
        final gain = isPost ? gainValue : '';
        final ng = isPost ? normGainValue : '';

        buf.writeln(
          '$sid,'
          '$groupLabel,'
          '$expEnabled,'
          '${r.type.name},'
          '${r.score},'
          '${r.totalQuestions},'
          '$pct,'
          '${r.durationSeconds},'
          '${r.completedAt.toIso8601String()},'
          '$gain,'
          '$ng',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 7: Mood Data ──────────────────────────────────

  static String _buildMoodData(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,timestamp,mood,activity_context,note_length',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final moods = HiveService.getMoodEntries(profile.id);

      for (final m in moods) {
        buf.writeln(
          '$sid,'
          '${m.timestamp.toIso8601String()},'
          '${m.mood.name},'
          '${m.activityContext ?? ""},'
          '${m.note?.length ?? 0}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 8: Adaptive Difficulty History ────────────────

  static String _buildAdaptiveDifficulty(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,timestamp,game_type,category,'
      'difficulty,accuracy_pct,duration_seconds',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final history = AdaptiveDifficultyService.getHistory(profile.id);

      for (final entry in history) {
        buf.writeln(
          '$sid,'
          '${entry.timestamp.toIso8601String()},'
          '${entry.gameType},'
          '${entry.category ?? ""},'
          '${entry.difficulty},'
          '${(entry.accuracy * 100).round()},'
          '${entry.durationSeconds ?? ""}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 9: SUS Survey Results ─────────────────────────

  static String _buildSusSurveyResults(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,survey_date,q1,q2,q3,q4,q5,'
      'q6,q7,q8,q9,q10,sus_score,grade_label,feedback_length',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final results = SurveyService.getSurveyResults(profile.id);

      for (final r in results) {
        final resp = r.responses;
        buf.writeln(
          '$sid,'
          '${r.completedAt.toIso8601String()},'
          '${resp.length >= 10 ? resp.sublist(0, 10).join(",") : List.filled(10, "").join(",")},'
          '${r.susScore.toStringAsFixed(1)},'
          '${r.gradeLabel},'
          '${r.feedback?.length ?? 0}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 10: Experiment Groups ────────────────────────

  static String _buildExperimentGroups(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    final featureNames = GamificationFeature.values.map((f) => f.name);
    buf.writeln(
      'student_id,experiment_enabled,group_label,'
      'disabled_count,${featureNames.join(",")}',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final config = ExperimentService.getConfig(profile.id);
      final featureStatuses = GamificationFeature.values
          .map((f) => config.isFeatureEnabled(f) ? '1' : '0');

      buf.writeln(
        '$sid,'
        '${config.enabled ? 1 : 0},'
        '${config.groupLabel},'
        '${config.disabledFeatures.length},'
        '${featureStatuses.join(",")}',
      );
    }
    return buf.toString();
  }

  // ─── File 11: Engagement Metrics ──────────────────────

  static String _buildEngagementMetrics(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,active_days_30d,return_freq_days,'
      'top_screen,top_screen_visits,'
      'total_screen_time_sec,feature_usage_count,'
      'total_sessions,total_session_minutes,avg_session_minutes',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final days = EngagementTracker.activeDays(profile.id);
      final freq = EngagementTracker.returnFrequency(profile.id);
      final top = EngagementTracker.topScreens(profile.id, limit: 1);
      final durations = EngagementTracker.screenDurations(profile.id);
      final features = EngagementTracker.featureUsageSummary(profile.id);

      final topScreen = top.isNotEmpty ? top.keys.first : '';
      final topVisits = top.isNotEmpty ? top.values.first : 0;
      final totalTime = durations.values.fold<int>(0, (a, b) => a + b);
      final totalFeatures = features.values.fold<int>(0, (a, b) => a + b);

      // Aggregated session stats from SessionTracker / HiveService
      final sessions = HiveService.getSessionLogs(profile.id);
      final totalSessions = sessions.length;
      final totalSessionMin = sessions.fold<int>(
        0,
        (sum, s) => sum + (((s['durationSeconds'] as int?) ?? 0) ~/ 60),
      );
      final avgSessionMin = totalSessions > 0
          ? (totalSessionMin / totalSessions).toStringAsFixed(1)
          : '0.0';

      buf.writeln(
        '$sid,'
        '$days,'
        '${freq.toStringAsFixed(1)},'
        '${_esc(topScreen)},'
        '$topVisits,'
        '$totalTime,'
        '$totalFeatures,'
        '$totalSessions,'
        '$totalSessionMin,'
        '$avgSessionMin',
      );
    }
    return buf.toString();
  }

  // ─── File 12: Summary Stats (JSON) ──────────────────────

  static String _buildSummaryJson(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final now = DateTime.now();
    int totalGames = 0;
    int totalWords = 0;
    int totalStars = 0;
    int totalSessions = 0;
    int totalStudyMinutes = 0;
    final disabilityDist = <String, int>{};
    final gradeDist = <String, int>{};
    double accuracySum = 0;
    int accuracyCount = 0;

    // Per-game-type stats
    final gameTypeScores = <String, List<int>>{};

    // Pre/post test gains
    final learningGains = <double>[];
    final normalizedGains = <double>[];

    for (final (profile, progress) in students) {
      totalGames += progress.recentScores.length;
      totalWords += progress.wordsLearned;
      totalStars += progress.totalStars;

      final sessions = HiveService.getSessionLogs(profile.id);
      totalSessions += sessions.length;
      totalStudyMinutes += sessions.fold<int>(
        0,
        (sum, s) => sum + (((s['durationSeconds'] as int?) ?? 0) ~/ 60),
      );

      // Disability distribution
      final dt = profile.disabilityType.name;
      disabilityDist[dt] = (disabilityDist[dt] ?? 0) + 1;

      // Grade distribution
      final gl = profile.gradeLevel?.name ?? 'unknown';
      gradeDist[gl] = (gradeDist[gl] ?? 0) + 1;

      // Accuracy
      final sr = SpacedRepetitionService.getSummary(profile.id);
      if (sr.totalAttempted > 0) {
        accuracySum += sr.totalCorrect / sr.totalAttempted;
        accuracyCount++;
      }

      // Game type breakdown
      for (final score in progress.recentScores) {
        final key = score.gameType.name;
        gameTypeScores.putIfAbsent(key, () => []);
        if (score.total > 0) {
          gameTypeScores[key]!
              .add((score.score / score.total * 100).round());
        }
      }

      // Learning gains
      final gain = AssessmentService.getLearningGainReport(profile.id);
      if (gain != null) {
        learningGains.add(gain.improvement);
        final ng = gain.normalizedGain;
        if (ng != null) normalizedGains.add(ng);
      }
    }

    // Compute game type averages
    final gameTypeAvg = <String, double>{};
    for (final entry in gameTypeScores.entries) {
      if (entry.value.isNotEmpty) {
        gameTypeAvg[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    final avgGain = learningGains.isNotEmpty
        ? learningGains.reduce((a, b) => a + b) / learningGains.length
        : null;
    final avgNormGain = normalizedGains.isNotEmpty
        ? normalizedGains.reduce((a, b) => a + b) / normalizedGains.length
        : null;

    final summary = {
      'export_date': now.toIso8601String(),
      'total_students': students.length,
      'disability_distribution': disabilityDist,
      'grade_distribution': gradeDist,
      'total_games_played': totalGames,
      'total_words_learned': totalWords,
      'total_stars_earned': totalStars,
      'total_sessions': totalSessions,
      'total_study_minutes': totalStudyMinutes,
      'average_accuracy_pct': accuracyCount > 0
          ? (accuracySum / accuracyCount * 100).round()
          : null,
      'game_type_avg_scores': gameTypeAvg,
      'students_with_learning_gain': learningGains.length,
      'average_learning_gain_pct':
          avgGain != null ? (avgGain * 100).round() : null,
      'students_with_normalized_gain': normalizedGains.length,
      'average_normalized_gain': avgNormGain != null
          ? double.parse(avgNormGain.toStringAsFixed(3))
          : null,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(summary);
  }

  // ─── Helpers ────────────────────────────────────────────

  static Future<XFile> _writeFile(
    Directory dir,
    String fileName,
    String content,
  ) async {
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    return XFile(file.path);
  }

  static String _esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
