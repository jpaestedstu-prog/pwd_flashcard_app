import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/class_analysis.dart';

/// Reading a class rather than one learner.
///
/// Every answer and response time has been recorded since assessments
/// existed, and nothing ever read it back: an educator could see *who*
/// struggled but never *which words*. And the study compares accessibility
/// categories, which no screen showed at all.
///
/// Pure arithmetic — no Hive, no widgets.
void main() {
  /// One sitting: [correct] is the per-question verdict, keyed by question id.
  AssessmentResult sitting(
    String learner,
    Map<String, bool> correct, {
    Map<String, String> given = const {},
    Map<String, int> ms = const {},
    AssessmentType type = AssessmentType.preTest,
  }) {
    final answers = [
      for (final entry in correct.entries)
        QuestionAnswer(
          questionId: entry.key,
          givenAnswer: entry.value
              ? 'right'
              : (given[entry.key] ?? 'wrong'),
          isCorrect: entry.value,
          responseTimeMs: ms[entry.key] ?? 1000,
        ),
    ];
    final score = correct.values.where((v) => v).length;
    return AssessmentResult(
      id: '$learner-${type.name}',
      assessmentId: 'a1',
      profileId: learner,
      type: type,
      score: score,
      totalQuestions: correct.length,
      answers: answers,
      completedAt: DateTime(2026, 9, 10),
      durationSeconds: 120,
    );
  }

  LearningGainReport gain(double pre, double post) {
    AssessmentResult half(AssessmentType type, double pct) => AssessmentResult(
      id: '${type.name}-$pct',
      assessmentId: 'a1',
      profileId: 'p',
      type: type,
      score: (pct * 100).round(),
      totalQuestions: 100,
      answers: const [],
      completedAt: DateTime(2026, 9, 10),
      durationSeconds: 60,
    );
    return LearningGainReport(
      preTest: half(AssessmentType.preTest, pre),
      postTest: half(AssessmentType.postTest, post),
    );
  }

  // ─── Item analysis ───────────────────────────────────────

  group('item statistics', () {
    test('nothing in, nothing out', () {
      expect(ClassAnalysis.itemStats(const []), isEmpty);
    });

    test('difficulty is the share who got it right', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': true, 'q2': false}),
        sitting('b', {'q1': true, 'q2': false}),
        sitting('c', {'q1': false, 'q2': false}),
        sitting('d', {'q1': true, 'q2': true}),
      ]);
      final q1 = stats.firstWhere((s) => s.questionId == 'q1');
      expect(q1.attempts, 4);
      expect(q1.correct, 3);
      expect(q1.difficulty, closeTo(0.75, 0.001));
    });

    test('the hardest item comes first', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'easy': true, 'hard': false}),
        sitting('b', {'easy': true, 'hard': false}),
      ]);
      expect(stats.first.questionId, 'hard');
      expect(stats.last.questionId, 'easy');
    });

    test('an item everybody failed is named plainly', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': false}),
        sitting('b', {'q1': false}),
      ]);
      expect(stats.single.difficulty, 0);
      expect(stats.single.difficultyLabel, 'Almost nobody');
    });

    test('the wording is carried through when a template still has it', () {
      final stats = ClassAnalysis.itemStats(
        [sitting('a', {'q1': true})],
        prompts: {'q1': 'What is the Filipino word for “dog”?'},
      );
      expect(stats.single.prompt, 'What is the Filipino word for “dog”?');
    });

    test('an id with no stored wording falls back to the id', () {
      // Dropping the row would hide a hard item just because the assessment
      // that asked it is no longer on this device.
      final stats = ClassAnalysis.itemStats([sitting('a', {'q_dog': false})]);
      expect(stats.single.prompt, 'q_dog');
    });

    test('the median response time ignores one learner who wandered off', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': true}, ms: {'q1': 2000}),
        sitting('b', {'q1': true}, ms: {'q1': 3000}),
        sitting('c', {'q1': true}, ms: {'q1': 900000}),
      ]);
      expect(stats.single.medianResponseMs, 3000);
    });

    test('the distractor doing the damage is reported', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': false}, given: {'q1': 'Pusa'}),
        sitting('b', {'q1': false}, given: {'q1': 'Pusa'}),
        sitting('c', {'q1': false}, given: {'q1': 'Ibon'}),
        sitting('d', {'q1': true}),
      ]);
      expect(stats.single.commonWrongAnswer, 'Pusa');
      expect(stats.single.commonWrongCount, 2);
    });

    test('a right answer is never counted as a distractor', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': true}),
        sitting('b', {'q1': true}),
      ]);
      expect(stats.single.commonWrongAnswer, isNull);
      expect(stats.single.commonWrongCount, 0);
    });
  });

  group('discrimination', () {
    test('too few learners means no number rather than a bad one', () {
      final stats = ClassAnalysis.itemStats([
        sitting('a', {'q1': true}),
        sitting('b', {'q1': false}),
      ]);
      expect(stats.single.discrimination, isNull);
      expect(stats.single.needsReview, isFalse);
    });

    test('an item the strong get right and the weak get wrong scores high', () {
      // Four sittings: two strong, two weak. q1 tracks overall ability.
      final stats = ClassAnalysis.itemStats([
        sitting('strong1', {'q1': true, 'q2': true, 'q3': true}),
        sitting('strong2', {'q1': true, 'q2': true, 'q3': true}),
        sitting('weak1', {'q1': false, 'q2': false, 'q3': false}),
        sitting('weak2', {'q1': false, 'q2': false, 'q3': false}),
      ]);
      final q1 = stats.firstWhere((s) => s.questionId == 'q1');
      expect(q1.discrimination, 1.0);
      expect(q1.needsReview, isFalse);
    });

    test('an item the strongest learners get wrong is flagged for review', () {
      // q3 runs backwards: the two learners who scored best overall failed it.
      // That is the signature of confusing wording, not of a hard word.
      final stats = ClassAnalysis.itemStats([
        sitting('strong1', {'q1': true, 'q2': true, 'q3': false}),
        sitting('strong2', {'q1': true, 'q2': true, 'q3': false}),
        sitting('weak1', {'q1': false, 'q2': false, 'q3': true}),
        sitting('weak2', {'q1': false, 'q2': false, 'q3': true}),
      ]);
      final q3 = stats.firstWhere((s) => s.questionId == 'q3');
      expect(q3.discrimination, lessThan(0));
      expect(q3.needsReview, isTrue);
    });

    test('an item everybody gets right separates nobody', () {
      final stats = ClassAnalysis.itemStats([
        for (final name in const ['a', 'b', 'c', 'd'])
          sitting(name, {'gimme': true, 'real': name.compareTo('c') < 0}),
      ]);
      final gimme = stats.firstWhere((s) => s.questionId == 'gimme');
      expect(gimme.discrimination, 0);
      expect(gimme.needsReview, isTrue);
    });
  });

  // ─── Gains by accessibility ──────────────────────────────

  group('gains by accessibility category', () {
    test('categories nobody is enrolled in are left out', () {
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.hearing, report: gain(0.4, 0.8)),
      ]);
      expect(gains.map((g) => g.type), [DisabilityType.hearing]);
    });

    test('the mean is over the learners who finished both halves', () {
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.hearing, report: gain(0.4, 0.8)),
        (type: DisabilityType.hearing, report: gain(0.2, 0.6)),
      ]);
      final g = gains.single;
      expect(g.learners, 2);
      expect(g.pending, 0);
      expect(g.meanPre, closeTo(0.3, 0.001));
      expect(g.meanPost, closeTo(0.7, 0.001));
      expect(g.meanGain, closeTo(0.4, 0.001));
      expect(g.hasImproved, isTrue);
    });

    test('a learner missing one half is counted, not silently dropped', () {
      // A mean over two learners must never be mistaken for a mean over
      // twelve, so the coverage travels with the figure.
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.visual, report: gain(0.5, 0.9)),
        (type: DisabilityType.visual, report: null),
        (type: DisabilityType.visual, report: null),
      ]);
      expect(gains.single.learners, 1);
      expect(gains.single.pending, 2);
    });

    test('a category where nobody has finished reports zero measured', () {
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.motor, report: null),
      ]);
      expect(gains.single.learners, 0);
      expect(gains.single.pending, 1);
      expect(gains.single.meanNormalizedGain, isNull);
    });

    test('a perfect pre-test is skipped by the normalized mean, not by the raw', () {
      // Hake's gain is undefined at a ceiling. Dropping that learner from the
      // *raw* mean as well would quietly change what the raw mean is over.
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.none, report: gain(1.0, 1.0)),
        (type: DisabilityType.none, report: gain(0.5, 0.75)),
      ]);
      final g = gains.single;
      expect(g.learners, 2);
      expect(g.meanGain, closeTo(0.125, 0.001));
      expect(g.meanNormalizedGain, closeTo(0.5, 0.001));
    });

    test('a category that went backwards is not called an improvement', () {
      final gains = ClassAnalysis.gainsByAccessibility([
        (type: DisabilityType.cognitive, report: gain(0.6, 0.4)),
      ]);
      expect(gains.single.hasImproved, isFalse);
      expect(gains.single.meanGain, lessThan(0));
    });
  });
}
