import '../../features/ai_tutor/models/tutor_brain_models.dart';
import '../../features/assessment/models/assessment_models.dart';
import '../../features/sign_interpreter/models/sign_interpreter_models.dart';
import '../../features/survey/models/survey_models.dart';
import '../../features/survey/models/smileyometer_models.dart';
import '../services/knowledge_tracing_service.dart';

/// Pure CSV header/row builders for [ResearchExportService].
///
/// Split out from the service so the formatting logic — column order, metric
/// formatting, and escaping — is unit-testable without Hive or platform
/// plugins. The service fetches each student's data (from Hive/services) and
/// delegates the string formatting to the methods here.
class ResearchExportRows {
  const ResearchExportRows._();

  /// CSV-escapes a value if it contains a comma, quote, or newline.
  static String esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ─── assessment_results.csv ─────────────────────────────

  static const String assessmentResultsHeader =
      'student_id,group_label,experiment_enabled,'
      'assessment_type,score,total_questions,'
      'percentage,duration_seconds,completed_at,'
      'learning_gain,normalized_gain';

  /// Rows for one student's assessment results.
  ///
  /// [gain] is that student's pre/post learning-gain report (null unless both
  /// tests were taken); its raw and normalized metrics attach only to the
  /// post-test row(s).
  static List<String> assessmentResultRows({
    required String studentId,
    required String groupLabel,
    required bool experimentEnabled,
    required List<AssessmentResult> results,
    LearningGainReport? gain,
  }) {
    final gainValue =
        gain != null ? (gain.improvement * 100).round().toString() : '';
    final normGain = gain?.normalizedGain;
    final normGainValue = normGain != null ? normGain.toStringAsFixed(3) : '';
    final groupCell = esc(groupLabel);
    final expCell = experimentEnabled ? 1 : 0;

    final rows = <String>[];
    for (final r in results) {
      final pct = r.totalQuestions > 0
          ? (r.score / r.totalQuestions * 100).round()
          : 0;
      final isPost = r.type == AssessmentType.postTest;
      rows.add(
        '$studentId,'
        '$groupCell,'
        '$expCell,'
        '${r.type.name},'
        '${r.score},'
        '${r.totalQuestions},'
        '$pct,'
        '${r.durationSeconds},'
        '${r.completedAt.toIso8601String()},'
        '${isPost ? gainValue : ''},'
        '${isPost ? normGainValue : ''}',
      );
    }
    return rows;
  }

  // ─── item_responses.csv ─────────────────────────────────

  static const String itemResponsesHeader =
      'student_id,group_label,assessment_type,assessment_id,'
      'completed_at,question_id,is_correct,response_time_ms,given_answer';

  /// One row per answered question across one student's assessment results.
  static List<String> itemResponseRows({
    required String studentId,
    required String groupLabel,
    required List<AssessmentResult> results,
  }) {
    final groupCell = esc(groupLabel);
    final rows = <String>[];
    for (final r in results) {
      final completedAt = r.completedAt.toIso8601String();
      final assessmentType = r.type.name;
      for (final a in r.answers) {
        rows.add(
          '$studentId,'
          '$groupCell,'
          '$assessmentType,'
          '${r.assessmentId},'
          '$completedAt,'
          '${a.questionId},'
          '${a.isCorrect ? 1 : 0},'
          '${a.responseTimeMs},'
          '${esc(a.givenAnswer)}',
        );
      }
    }
    return rows;
  }

  // ─── speech_to_sign_usage.csv ───────────────────────────

  static const String speechToSignUsageHeader =
      'student_id,timestamp,locale,source,'
      'token_count,matched_count,unmatched_words,duration_ms';

  /// One row per Speech→Sign session for one student. The unmatched-word
  /// column is semicolon-joined so the CSV stays one-row-per-session; it
  /// doubles as the priority list for which signs to record next.
  static List<String> speechToSignUsageRows({
    required String studentId,
    required List<SignUsageEvent> events,
  }) {
    return [
      for (final e in events)
        '$studentId,'
            '${e.timestamp.toIso8601String()},'
            '${e.locale},'
            '${e.source},'
            '${e.tokenCount},'
            '${e.matchedCount},'
            '${esc(e.unmatchedWords.join(';'))},'
            '${e.durationMs}',
    ];
  }

  // ─── tutor_interactions.csv ─────────────────────────────

  static const String tutorInteractionsHeader =
      'student_id,timestamp,trigger,brain,latency_ms,'
      'fallback_reason,action_type';

  /// One row per tutor-brain turn (rule AND llm) for one student — the
  /// rule-vs-LLM engagement comparison joins on `brain`.
  static List<String> tutorInteractionRows({
    required String studentId,
    required List<TutorInteractionEvent> events,
  }) {
    return [
      for (final e in events)
        '$studentId,'
            '${e.timestamp.toIso8601String()},'
            '${e.trigger.name},'
            '${e.brain},'
            '${e.latencyMs},'
            '${e.fallbackReason ?? ''},'
            '${e.actionType}',
    ];
  }

  // ─── knowledge_state.csv ────────────────────────────────

  static const String knowledgeStateHeader =
      'student_id,word_id,category,theta_global,theta_category,'
      'beta,p_correct,attempts,trend_slope,last_seen';

  /// One row per Elo-tracked word for one student. `theta_category` is blank
  /// for words outside the seed vocabulary (custom flashcards), which only
  /// update the global ability estimate.
  static List<String> knowledgeStateRows({
    required String studentId,
    required double thetaGlobal,
    required Map<String, double> thetaByCategory,
    required List<EloWordReport> reports,
  }) {
    final thetaGlobalCell = thetaGlobal.toStringAsFixed(3);
    return [
      for (final r in reports)
        '$studentId,'
            '${esc(r.wordId)},'
            '${esc(r.category)},'
            '$thetaGlobalCell,'
            '${thetaByCategory[r.category]?.toStringAsFixed(3) ?? ''},'
            '${r.beta.toStringAsFixed(3)},'
            '${r.pCorrect.toStringAsFixed(3)},'
            '${r.attempts},'
            '${r.trendSlope.toStringAsFixed(3)},'
            '${r.lastSeen.toIso8601String()}',
    ];
  }

  // ─── sus_survey_results.csv (teacher-administered) ──────

  static const String susSurveyHeader =
      'respondent_id,respondent_role,survey_date,'
      'q1,q2,q3,q4,q5,q6,q7,q8,q9,q10,'
      'sus_score,grade_label,feedback_length';

  /// Rows for one respondent's SUS submissions. The SUS is the validated
  /// usability instrument, completed by the teacher/facilitator — hence
  /// [respondentId]/[respondentRole] rather than a student id.
  static List<String> susSurveyRows({
    required String respondentId,
    required String respondentRole,
    required List<SusSurveyResult> results,
  }) {
    final roleCell = esc(respondentRole);
    final rows = <String>[];
    for (final r in results) {
      final resp = r.responses;
      final answers = resp.length >= 10
          ? resp.sublist(0, 10).join(',')
          : List.filled(10, '').join(',');
      rows.add(
        '$respondentId,'
        '$roleCell,'
        '${r.completedAt.toIso8601String()},'
        '$answers,'
        '${r.susScore.toStringAsFixed(1)},'
        '${esc(r.gradeLabel)},'
        '${r.feedback?.length ?? 0}',
      );
    }
    return rows;
  }

  // ─── student_experience.csv (learner Smileyometer) ──────

  static const String smileyometerHeader =
      'student_id,group_label,completed_at,q1,q2,q3,mean_rating';

  /// Rows for one learner's Smileyometer submissions (3 face ratings, 1–3),
  /// reported descriptively — not a usability score.
  static List<String> smileyometerRows({
    required String studentId,
    required String groupLabel,
    required List<SmileyometerResult> results,
  }) {
    final groupCell = esc(groupLabel);
    final rows = <String>[];
    for (final r in results) {
      final ratings = [
        for (var i = 0; i < 3; i++)
          i < r.ratings.length ? r.ratings[i].toString() : '',
      ].join(',');
      rows.add(
        '$studentId,'
        '$groupCell,'
        '${r.completedAt.toIso8601String()},'
        '$ratings,'
        '${r.meanRating.toStringAsFixed(2)}',
      );
    }
    return rows;
  }
}
