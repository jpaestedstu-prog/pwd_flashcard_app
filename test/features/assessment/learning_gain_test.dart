import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';

AssessmentResult _result(AssessmentType type, int score, int total) =>
    AssessmentResult(
      id: 'r-${type.name}',
      assessmentId: 'a1',
      profileId: 'p1',
      type: type,
      score: score,
      totalQuestions: total,
      answers: const [],
      completedAt: DateTime(2026),
      durationSeconds: 60,
    );

LearningGainReport _report(int preScore, int postScore, {int total = 10}) =>
    LearningGainReport(
      preTest: _result(AssessmentType.preTest, preScore, total),
      postTest: _result(AssessmentType.postTest, postScore, total),
    );

void main() {
  group("LearningGainReport.normalizedGain (Hake's g)", () {
    test('computes (post - pre) / (1 - pre)', () {
      // pre 40%, post 70% → (0.7 - 0.4) / (1 - 0.4) = 0.3 / 0.6 = 0.5
      expect(_report(4, 7).normalizedGain, closeTo(0.5, 1e-9));
    });

    test('credits gains under a ceiling more than the raw difference', () {
      // High starter: pre 80%, post 90% → raw 0.10 but g = 0.1 / 0.2 = 0.5
      final r = _report(8, 9);
      expect(r.improvement, closeTo(0.10, 1e-9));
      expect(r.normalizedGain, closeTo(0.5, 1e-9));
    });

    test('equals the raw improvement when starting from zero', () {
      // pre 0%, post 60% → (0.6 - 0) / (1 - 0) = 0.6 == improvement
      final r = _report(0, 6);
      expect(r.normalizedGain, closeTo(0.6, 1e-9));
      expect(r.normalizedGain, closeTo(r.improvement, 1e-9));
    });

    test('is negative when the score drops', () {
      // pre 50%, post 30% → (0.3 - 0.5) / (1 - 0.5) = -0.2 / 0.5 = -0.4
      expect(_report(5, 3).normalizedGain, closeTo(-0.4, 1e-9));
    });

    test('is null when the pre-test is already perfect (undefined)', () {
      expect(_report(10, 10).normalizedGain, isNull);
    });
  });
}
