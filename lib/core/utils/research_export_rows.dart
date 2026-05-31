import '../../features/assessment/models/assessment_models.dart';

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
}
