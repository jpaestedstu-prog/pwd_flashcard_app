import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../data/local/hive_service.dart';
import '../../data/local/seed_data.dart';
import '../../data/local/spaced_repetition_service.dart';
import '../../features/progress/models/category_mastery.dart';
import '../../features/assessment/services/assessment_service.dart';
import '../../features/survey/services/survey_service.dart';
import '../../features/survey/models/survey_models.dart';
import '../../features/survey/services/smileyometer_service.dart';
import '../../features/experiment/models/experiment_models.dart';
import '../../features/experiment/services/experiment_service.dart';
import '../services/adaptive_difficulty_service.dart';
import '../services/engagement_tracker.dart';
import 'research_export_rows.dart';

/// Generates anonymized, cross-student research data exports for thesis
/// analysis. Unlike [CsvExportService] (single-student), this aggregates
/// all student data into research-grade datasets.
///
/// Exported files:
/// 1. `students_overview.csv`  – one row per student (anonymized)
/// 2. `learning_curves.csv`    – game scores over time per student
/// 3. `session_patterns.csv`   – session logs across all students
/// 4. `category_mastery.csv`   – per-category coverage *and* accuracy per student
/// 5. `word_accuracy.csv`      – per-word spaced-repetition data
/// 6. `assessment_results.csv` – pre/post test, learning & normalized gains
/// 6b. `item_responses.csv`    – per-question correctness & response time
///     (item difficulty/discrimination, Cronbach's α)
/// 7. `mood_data.csv`          – mood entries correlated with activity
/// 8. `adaptive_difficulty.csv` – per-game difficulty adjustments over time
/// 9. `sus_survey_results.csv` – teacher-administered SUS (respondent + role)
/// 9b. `student_experience.csv` – learner Smileyometer (descriptive, 1–3)
/// 10. `fsl_engagement.csv`    – per-view sign-language log + distinct signs
/// 10b. `fsl_mastery.csv`     – self-claimed vs educator-verified production
///     (the calibration measure: does a learner know what they can sign?)
/// 10. `summary_stats.json`    – high-level aggregates for quick analysis
class ResearchExportService {
  const ResearchExportService._();

  /// Generate all research CSV files and share as a bundle.
  static Future<void> generateAndShare() async {
    final profiles = HiveService.getAllProfilesWithProgress();
    // Research data is intentionally scoped to the Student role only — the
    // study population for this thesis is PWD *students*. Child (family-group)
    // and Player profiles are deliberately excluded from the dataset, so the
    // engagement tracker is likewise only attached for Students (see
    // engagementTrackerProvider in navigation/app_router.dart). This is by
    // design, not an omission; widening the population is a methodology +
    // consent decision, not a code change.
    final students = profiles
        .where((p) => p.$1.role == UserRole.student)
        .toList();

    if (students.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toString().split(' ').first;
    final exportDir = Directory('${dir.path}/FlashLearn_Research_$dateStr');
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

    files.add(
      await _writeFile(
        exportDir,
        'students_overview.csv',
        _buildStudentsOverview(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'learning_curves.csv',
        _buildLearningCurves(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'session_patterns.csv',
        _buildSessionPatterns(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'category_mastery.csv',
        _buildCategoryMastery(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'word_accuracy.csv',
        _buildWordAccuracy(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'assessment_results.csv',
        _buildAssessmentResults(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'item_responses.csv',
        _buildItemResponses(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'mood_data.csv',
        _buildMoodData(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'adaptive_difficulty.csv',
        _buildAdaptiveDifficulty(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'sus_survey_results.csv',
        _buildSusSurveyResults(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'student_experience.csv',
        _buildStudentExperience(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'experiment_groups.csv',
        _buildExperimentGroups(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'engagement_metrics.csv',
        _buildEngagementMetrics(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'fsl_engagement.csv',
        _buildFslEngagement(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'fsl_mastery.csv',
        _buildFslMastery(students, idMap),
      ),
    );

    files.add(
      await _writeFile(
        exportDir,
        'summary_stats.json',
        _buildSummaryJson(students, idMap),
      ),
    );

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
      // Distinct FSL signs watched, out of the 142 that exist. Sign-language
      // engagement is the intervention this study is actually about, and it was
      // absent from every one of these files.
      'signs_watched,'
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
      final achievements = HiveService.getUnlockedAchievements(
        profile.id,
      ).length;
      final categoriesExplored = progress.categoryProgress.entries
          .where((e) => e.value > 0)
          .length;
      final srSummary = SpacedRepetitionService.getSummary(profile.id);
      final avgAcc = srSummary.totalAttempted > 0
          ? (srSummary.totalCorrect / srSummary.totalAttempted * 100).round()
          : 0;
      final accountAge = DateTime.now().difference(profile.createdAt).inDays;

      buf.writeln(
        '$sid,'
        '${profile.disabilityType.name},'
        '${profile.gradeLevel?.name ?? "unknown"},'
        '${profile.age ?? ""},'
        '${progress.wordsLearned},'
        '${progress.totalStars},'
        '${progress.streakDays},'
        // Lifetime total. `recentScores` is trimmed to the last 20 entries, so
        // reading its length silently censored every participant's game count
        // at 20 in the exported research data.
        '${progress.effectiveGamesPlayed},'
        '$avgAcc,'
        '$totalMinutes,'
        '$uniqueDays,'
        '$achievements,'
        '$categoriesExplored,'
        '${progress.signsLearned},'
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
        final pct = s.total > 0 ? (s.score / s.total * 100).round() : 0;
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
        final datePart = dateStr.contains(' ')
            ? dateStr.split(' ').first
            : dateStr;
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

  /// Two measures per category, because they answer different questions and
  /// the single column here used to conflate them.
  ///
  ///   * `<category>_coverage_pct` — share of the category's words the learner
  ///     has answered correctly at least once. The completion measure.
  ///   * `<category>_accuracy_pct` — the rolling accuracy average carried on
  ///     `LearningProgress.categoryProgress`. Empty when the learner has never
  ///     played the category, which is not the same as scoring zero.
  ///
  /// The old file exported accuracy alone under the category's bare name, so
  /// any analysis that read it as "percent of the category learned" — the
  /// reading its column header invited — overstated coverage for every learner
  /// who played a short game well. See [CategoryMastery].
  static String _buildCategoryMastery(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    const cats = FlashcardCategory.values;
    final cards = [...SeedData.allFlashcards, ...HiveService.getCustomCards()];

    buf.write('student_id,disability_type');
    for (final cat in cats) {
      buf.write(',${_esc('${cat.label}_coverage_pct')}');
      buf.write(',${_esc('${cat.label}_accuracy_pct')}');
    }
    buf.writeln();

    for (final (profile, progress) in students) {
      final sid = idMap[profile.id]!;
      final mastery = CategoryMastery.forProgress(progress, cards);
      buf.write('$sid,${profile.disabilityType.name}');
      for (final cat in cats) {
        final m = mastery[cat];
        final coverage = ((m?.coverage ?? 0.0) * 100).round();
        final accuracy = m?.accuracy;
        buf.write(',$coverage');
        buf.write(',${accuracy == null ? '' : (accuracy * 100).round()}');
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
        final daysSince = DateTime.now().difference(wa.lastSeen).inDays;
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
    // Denormalize the experiment group onto every row so a treatment-vs-
    // control test runs straight off this file, with no manual JOIN against
    // experiment_groups.csv by student_id. learning_gain is the raw post−pre
    // percentage-point change; normalized_gain is Hake's g (blank when the
    // pre-test is perfect). Row formatting lives in ResearchExportRows.
    final buf = StringBuffer()
      ..writeln(ResearchExportRows.assessmentResultsHeader);

    for (final (profile, _) in students) {
      final config = ExperimentService.getConfig(profile.id);
      final rows = ResearchExportRows.assessmentResultRows(
        studentId: idMap[profile.id]!,
        groupLabel: config.groupLabel,
        experimentEnabled: config.enabled,
        results: AssessmentService.getResults(profile.id),
        gain: AssessmentService.getLearningGainReport(profile.id),
      );
      for (final row in rows) {
        buf.writeln(row);
      }
    }
    return buf.toString();
  }

  // ─── File 6b: Item-Level Responses ──────────────────────

  /// One row per answered question across every assessment result, keyed by
  /// question_id. Because pre- and post-tests now share question ids (parallel
  /// forms), items can be matched 1:1 across tests. Enables item difficulty
  /// (proportion correct), discrimination, and internal-consistency
  /// reliability (Cronbach's α) — pivot to a student × item correctness matrix.
  static String _buildItemResponses(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer()..writeln(ResearchExportRows.itemResponsesHeader);

    for (final (profile, _) in students) {
      final rows = ResearchExportRows.itemResponseRows(
        studentId: idMap[profile.id]!,
        groupLabel: ExperimentService.getConfig(profile.id).groupLabel,
        results: AssessmentService.getResults(profile.id),
      );
      for (final row in rows) {
        buf.writeln(row);
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
    buf.writeln('student_id,timestamp,mood,activity_context,note_length');

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
    final buf = StringBuffer()..writeln(ResearchExportRows.susSurveyHeader);

    // The SUS is the validated usability instrument, completed by the
    // teacher/facilitator (not the student). Build a role + anonymized-id
    // lookup across all profiles: students reuse their S-id; everyone else
    // (teachers/parents) gets a T-id. respondent_role lets you filter.
    final roleById = <String, String>{};
    final anonById = <String, String>{...idMap};
    var t = 0;
    for (final (profile, _) in HiveService.getAllProfilesWithProgress()) {
      roleById[profile.id] = profile.role.name;
      anonById.putIfAbsent(profile.id, () {
        t += 1;
        return 'T${t.toString().padLeft(3, '0')}';
      });
    }

    // Group SUS submissions by respondent.
    final byRespondent = <String, List<SusSurveyResult>>{};
    for (final r in SurveyService.getAllResults()) {
      byRespondent.putIfAbsent(r.profileId, () => []).add(r);
    }

    for (final entry in byRespondent.entries) {
      final rows = ResearchExportRows.susSurveyRows(
        respondentId: anonById[entry.key] ?? entry.key,
        respondentRole: roleById[entry.key] ?? 'unknown',
        results: entry.value,
      );
      for (final row in rows) {
        buf.writeln(row);
      }
    }
    return buf.toString();
  }

  // ─── File 9b: Student Experience (Smileyometer) ─────────

  static String _buildStudentExperience(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer()..writeln(ResearchExportRows.smileyometerHeader);
    for (final (profile, _) in students) {
      final rows = ResearchExportRows.smileyometerRows(
        studentId: idMap[profile.id]!,
        groupLabel: ExperimentService.getConfig(profile.id).groupLabel,
        results: SmileyometerService.getResults(profile.id),
      );
      for (final row in rows) {
        buf.writeln(row);
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
      'student_id,experiment_enabled,group_label,assigned_at,'
      'disabled_count,${featureNames.join(",")}',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final config = ExperimentService.getConfig(profile.id);
      final featureStatuses = GamificationFeature.values.map(
        (f) => config.isFeatureEnabled(f) ? '1' : '0',
      );

      buf.writeln(
        '$sid,'
        '${config.enabled ? 1 : 0},'
        '${config.groupLabel},'
        '${config.assignedAt?.toIso8601String() ?? ''},'
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

  // ─── File 12: FSL Engagement ────────────────────────────

  /// One row per sign-language clip a learner opened, plus the distinct-signs
  /// tally alongside it.
  ///
  /// The other files describe an app that happens to teach vocabulary; this one
  /// describes the Filipino Sign Language intervention itself, which is the
  /// distinctive claim of the study and previously produced no exportable data
  /// at all. `repeat_view` separates a learner returning to a sign from meeting
  /// it for the first time — the difference between rehearsal and coverage.
  ///
  /// The per-view log is capped at the most recent 200 entries per learner (see
  /// `HiveService.recordFslVideoView`), so `signs_distinct_total` is the
  /// complete figure and the rows are a recent window. For a deployment longer
  /// than that window, read the total from `students_overview.csv`.
  static String _buildFslEngagement(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,disability_type,category,word,viewed_at,'
      'repeat_view,signs_distinct_total',
    );

    for (final (profile, progress) in students) {
      final sid = idMap[profile.id]!;
      final views = HiveService.getFslVideoViews(profile.id);
      // Words already met earlier in the log, so a repeat can be told from a
      // first encounter without post-processing the timestamps.
      final seen = <String>{};
      for (final view in views) {
        final category = '${view['category'] ?? ''}';
        final word = '${view['word'] ?? ''}';
        final repeat = !seen.add(HiveService.fslWordKey(category, word));
        buf.writeln(
          '$sid,'
          '${profile.disabilityType.name},'
          '${_esc(category)},'
          '${_esc(word)},'
          '${view['date'] ?? ''},'
          '${repeat ? 1 : 0},'
          '${progress.signsLearned}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 13: FSL Mastery / Calibration ─────────────────

  /// One row per word the learner has said something about, pairing their own
  /// claim with the educator's verdict.
  ///
  /// This is the calibration dataset. Sign production has no automatic grader
  /// in this app — there is no pose model — so the learner's self-report and a
  /// teacher's confirmation are two independent measurements of the same thing,
  /// and the interesting quantity is the *disagreement* between them:
  ///
  ///   claim=can_sign & verdict=confirmed      → accurate self-assessment
  ///   claim=can_sign & verdict=not_confirmed  → over-confidence
  ///   claim=learning & verdict=confirmed      → under-confidence
  ///   verdict=unreviewed                      → not yet measurable, exclude
  ///
  /// `verifier_role` separates a classroom check from a home one; they are not
  /// equivalent evidence and a reader should be able to filter on it.
  /// `watched` is included so a claim about a sign the learner never opened in
  /// this app can be spotted rather than silently trusted.
  static String _buildFslMastery(
    List<(UserProfile, LearningProgress)> students,
    Map<String, String> idMap,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'student_id,disability_type,category,word,'
      'self_claim,educator_verdict,verified_at,verifier_role,watched',
    );

    for (final (profile, _) in students) {
      final sid = idMap[profile.id]!;
      final claims = HiveService.fslMastery(profile.id);
      final rows = <String, Map<String, dynamic>>{
        for (final r in HiveService.fslVerificationRows(profile.id))
          '${r['key']}': r,
      };
      final watched = HiveService.fslWordsViewed(profile.id);

      for (final entry in claims.entries) {
        // Keys are `[Category label]__[word]`; split on the last separator so a
        // category containing an underscore cannot corrupt the word.
        final sep = entry.key.indexOf('_');
        final category = sep < 0 ? '' : entry.key.substring(0, sep);
        final word = sep < 0 ? entry.key : entry.key.substring(sep + 1);
        final row = rows[entry.key];
        final verdictIndex = (row?['state'] as num?)?.toInt();
        final verdict =
            verdictIndex != null &&
                verdictIndex >= 0 &&
                verdictIndex < SignVerification.values.length
            ? SignVerification.values[verdictIndex]
            : SignVerification.unreviewed;

        buf.writeln(
          '$sid,'
          '${profile.disabilityType.name},'
          '${_esc(category)},'
          '${_esc(word)},'
          '${entry.value.exportCode},'
          '${verdict.exportCode},'
          '${row?['at'] ?? ''},'
          '${row?['role'] ?? ''},'
          '${watched.contains(entry.key) ? 1 : 0}',
        );
      }
    }
    return buf.toString();
  }

  // ─── File 14: Summary Stats (JSON) ──────────────────────

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
      totalGames += progress.effectiveGamesPlayed;
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
          gameTypeScores[key]!.add((score.score / score.total * 100).round());
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
      'average_learning_gain_pct': avgGain != null
          ? (avgGain * 100).round()
          : null,
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

  static String _esc(String value) => ResearchExportRows.esc(value);
}
