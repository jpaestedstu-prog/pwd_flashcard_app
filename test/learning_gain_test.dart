import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('LearningGainReport', () {
    final preTest = AssessmentResult(
      id: 'pre-1',
      assessmentId: 'a-1',
      profileId: 'p-1',
      type: AssessmentType.preTest,
      score: 6,
      totalQuestions: 10,
      answers: [],
      completedAt: DateTime(2025),
      durationSeconds: 120,
      categories: [FlashcardCategory.animals, FlashcardCategory.foodAndDrinks],
      categoryScores: {'Animals': 0.5, 'Food & Drinks': 0.7},
    );

    final postTest = AssessmentResult(
      id: 'post-1',
      assessmentId: 'a-1',
      profileId: 'p-1',
      type: AssessmentType.postTest,
      score: 9,
      totalQuestions: 10,
      answers: [],
      completedAt: DateTime(2025, 2),
      durationSeconds: 90,
      categories: [FlashcardCategory.animals, FlashcardCategory.foodAndDrinks],
      categoryScores: {'Animals': 0.8, 'Food & Drinks': 0.95},
    );

    test('preTestPercentage is computed correctly', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      expect(report.preTestPercentage, closeTo(0.6, 0.001));
    });

    test('postTestPercentage is computed correctly', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      expect(report.postTestPercentage, closeTo(0.9, 0.001));
    });

    test('hasImproved is true when post > pre', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      expect(report.hasImproved, true);
    });

    test('hasImproved is false when post < pre', () {
      final report = LearningGainReport(preTest: postTest, postTest: preTest);
      expect(report.hasImproved, false);
    });

    test('improvement and improvementPercent computed correctly', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      expect(report.improvement, closeTo(0.3, 0.001));
      expect(report.improvementPercent, closeTo(0.5, 0.01));
    });

    test('categoryGains merge both tests', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      final gains = report.categoryGains;
      expect(gains.containsKey('Animals'), true);
      expect(gains.containsKey('Food & Drinks'), true);
      expect(gains['Animals']!.pre, closeTo(0.5, 0.001));
      expect(gains['Animals']!.post, closeTo(0.8, 0.001));
      expect(gains['Animals']!.gain, closeTo(0.3, 0.001));
      expect(gains['Food & Drinks']!.pre, closeTo(0.7, 0.001));
      expect(gains['Food & Drinks']!.post, closeTo(0.95, 0.001));
      expect(gains['Food & Drinks']!.gain, closeTo(0.25, 0.001));
    });

    test('summary text contains improvement info', () {
      final report = LearningGainReport(preTest: preTest, postTest: postTest);
      expect(report.summary, contains('improved'));
    });
  });

  group('AssessmentResult', () {
    test('percentage is score / totalQuestions', () {
      final result = AssessmentResult(
        id: 'r-1',
        assessmentId: 'a-1',
        profileId: 'p-1',
        type: AssessmentType.preTest,
        score: 7,
        totalQuestions: 10,
        answers: [],
        completedAt: DateTime(2025),
        durationSeconds: 60,
        categories: [],
        categoryScores: {},
      );
      expect(result.percentage, closeTo(0.7, 0.001));
    });

    test('gradeEmoji returns appropriate emoji', () {
      final excellent = AssessmentResult(
        id: 'r-2',
        assessmentId: 'a-1',
        profileId: 'p-1',
        type: AssessmentType.postTest,
        score: 10,
        totalQuestions: 10,
        answers: [],
        completedAt: DateTime(2025),
        durationSeconds: 60,
        categories: [],
        categoryScores: {},
      );
      expect(excellent.gradeEmoji, isNotEmpty);
    });

    test('grade returns letter grade', () {
      final result = AssessmentResult(
        id: 'r-3',
        assessmentId: 'a-1',
        profileId: 'p-1',
        type: AssessmentType.preTest,
        score: 8,
        totalQuestions: 10,
        answers: [],
        completedAt: DateTime(2025),
        durationSeconds: 60,
        categories: [],
        categoryScores: {},
      );
      expect(result.grade, isNotEmpty);
    });
  });

  group('AssessmentType', () {
    test('all types have labels', () {
      for (final t in AssessmentType.values) {
        expect(t.label.isNotEmpty, true, reason: '${t.name} label');
      }
    });

    test('all types have emojis', () {
      for (final t in AssessmentType.values) {
        expect(t.emoji.isNotEmpty, true, reason: '${t.name} emoji');
      }
    });

    test('has expected values', () {
      expect(AssessmentType.values, containsAll([
        AssessmentType.preTest,
        AssessmentType.postTest,
        AssessmentType.categoryMastery,
        AssessmentType.custom,
      ]));
    });
  });
}
