import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/research_export_rows.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/survey/models/survey_models.dart';
import 'package:pwdpwdpwd/features/survey/models/smileyometer_models.dart';

AssessmentResult _res(
  AssessmentType type, {
  int score = 0,
  int total = 10,
  List<QuestionAnswer> answers = const [],
  String assessmentId = 'a1',
}) =>
    AssessmentResult(
      id: 'r-${type.name}',
      assessmentId: assessmentId,
      profileId: 'p1',
      type: type,
      score: score,
      totalQuestions: total,
      answers: answers,
      completedAt: DateTime(2026),
      durationSeconds: 90,
    );

QuestionAnswer _ans(String qid, bool correct, {int ms = 1000, String given = 'x'}) =>
    QuestionAnswer(
      questionId: qid,
      givenAnswer: given,
      isCorrect: correct,
      responseTimeMs: ms,
    );

void main() {
  group('ResearchExportRows.esc', () {
    test('passes through values with no special characters', () {
      expect(ResearchExportRows.esc('treatment'), 'treatment');
    });

    test('quotes and doubles embedded commas, quotes, and newlines', () {
      expect(ResearchExportRows.esc('a,b'), '"a,b"');
      expect(ResearchExportRows.esc('say "hi"'), '"say ""hi"""');
      expect(ResearchExportRows.esc('line1\nline2'), '"line1\nline2"');
    });
  });

  group('ResearchExportRows.assessmentResultRows', () {
    test('header has 11 columns', () {
      expect(ResearchExportRows.assessmentResultsHeader.split(',').length, 11);
    });

    test('attaches gain metrics only to the post-test row', () {
      final pre = _res(AssessmentType.preTest, score: 4); // 40%
      final post = _res(AssessmentType.postTest, score: 7); // 70%
      final rows = ResearchExportRows.assessmentResultRows(
        studentId: 'S001',
        groupLabel: 'treatment',
        experimentEnabled: true,
        results: [pre, post],
        gain: LearningGainReport(preTest: pre, postTest: post),
      );

      expect(rows.length, 2);
      final preCells = rows[0].split(',');
      final postCells = rows[1].split(',');

      // Every row: 11 columns, shared id/group/enabled prefix.
      expect(preCells.length, 11);
      expect(postCells.length, 11);
      expect(preCells[0], 'S001');
      expect(preCells[1], 'treatment');
      expect(preCells[2], '1'); // experiment_enabled

      // percentage column (index 6).
      expect(preCells[6], '40');
      expect(postCells[6], '70');

      // learning_gain (9) + normalized_gain (10): blank on pre, set on post.
      expect(preCells[9], '');
      expect(preCells[10], '');
      expect(postCells[9], '30'); // raw 0.30 -> 30 pts
      expect(postCells[10], '0.500'); // Hake's g = 0.3 / (1-0.4)
    });

    test('leaves gain cells blank when no gain report is supplied', () {
      final post = _res(AssessmentType.postTest, score: 9);
      final rows = ResearchExportRows.assessmentResultRows(
        studentId: 'S001',
        groupLabel: 'control',
        experimentEnabled: false,
        results: [post],
      );
      final cells = rows.single.split(',');
      expect(cells[2], '0'); // experiment_enabled false
      expect(cells[9], '');
      expect(cells[10], '');
    });

    test('escapes a group label containing a comma', () {
      final rows = ResearchExportRows.assessmentResultRows(
        studentId: 'S001',
        groupLabel: 'group,A',
        experimentEnabled: true,
        results: [_res(AssessmentType.preTest, score: 5)],
      );
      expect(rows.single, contains('"group,A"'));
    });
  });

  group('ResearchExportRows.itemResponseRows', () {
    test('header has 9 columns', () {
      expect(ResearchExportRows.itemResponsesHeader.split(',').length, 9);
    });

    test('emits one row per answer with 0/1 correctness and timing', () {
      final result = _res(
        AssessmentType.postTest,
        answers: [
          _ans('q1', true, ms: 3500),
          _ans('q2', false, ms: 1200),
        ],
      );
      final rows = ResearchExportRows.itemResponseRows(
        studentId: 'S001',
        groupLabel: 'treatment',
        results: [result],
      );

      expect(rows.length, 2);
      final r1 = rows[0].split(',');
      expect(r1.length, 9);
      expect(r1[5], 'q1'); // question_id
      expect(r1[6], '1'); // is_correct
      expect(r1[7], '3500'); // response_time_ms
      expect(rows[1].split(',')[6], '0'); // q2 incorrect
    });

    test('escapes a given answer containing a comma', () {
      final result = _res(
        AssessmentType.postTest,
        answers: [_ans('q1', true, given: 'yes, maybe')],
      );
      final rows = ResearchExportRows.itemResponseRows(
        studentId: 'S001',
        groupLabel: 'treatment',
        results: [result],
      );
      expect(rows.single, contains('"yes, maybe"'));
    });
  });

  group('ResearchExportRows.susSurveyRows', () {
    test('header has 16 columns', () {
      expect(ResearchExportRows.susSurveyHeader.split(',').length, 16);
    });

    test('formats a teacher SUS row with respondent role and score', () {
      final sus = SusSurveyResult(
        id: 's1',
        profileId: 't1',
        completedAt: DateTime(2026),
        responses: const [5, 1, 5, 1, 5, 1, 5, 1, 5, 1], // perfect → SUS 100
        feedback: 'great',
      );
      final rows = ResearchExportRows.susSurveyRows(
        respondentId: 'T001',
        respondentRole: 'teacher',
        results: [sus],
      );
      expect(rows.length, 1);
      final cells = rows.single.split(',');
      expect(cells.length, 16);
      expect(cells[0], 'T001');
      expect(cells[1], 'teacher');
      expect(cells.sublist(3, 13),
          ['5', '1', '5', '1', '5', '1', '5', '1', '5', '1']);
      expect(cells[13], '100.0'); // sus_score
      expect(cells[15], '5'); // feedback_length ("great")
    });
  });

  group('ResearchExportRows.smileyometerRows', () {
    test('header has 7 columns', () {
      expect(ResearchExportRows.smileyometerHeader.split(',').length, 7);
    });

    test('formats face ratings and mean (no-comma row is 7 columns)', () {
      final s = SmileyometerResult(
        id: '1',
        profileId: 'p',
        completedAt: DateTime(2026),
        ratings: const [1, 2, 3],
      );
      final rows = ResearchExportRows.smileyometerRows(
        studentId: 'S001',
        groupLabel: 'treatment',
        results: [s],
      );
      final cells = rows.single.split(',');
      expect(cells.length, 7);
      expect(cells.sublist(3, 6), ['1', '2', '3']); // q1..q3
      expect(cells[6], '2.00'); // mean_rating
    });

    test('escapes a group label containing a comma', () {
      final s = SmileyometerResult(
        id: '1',
        profileId: 'p',
        completedAt: DateTime(2026),
        ratings: const [3, 3, 3],
      );
      final rows = ResearchExportRows.smileyometerRows(
        studentId: 'S001',
        groupLabel: 'group,A',
        results: [s],
      );
      expect(rows.single, contains('"group,A"'));
      expect(rows.single.endsWith('3.00'), isTrue);
    });
  });
}
