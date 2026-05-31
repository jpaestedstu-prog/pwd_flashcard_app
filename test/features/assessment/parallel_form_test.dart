import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// Signature of an assessment's item set: (question id + correct answer) pairs.
/// Two assessments with the same signature measure the exact same items.
Set<String> _itemSignature(Assessment a) =>
    a.questions.map((q) => '${q.id}|${q.correctAnswer}').toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('parallel_form_test');
    Hive.init(tempDir.path);
    await Hive.openBox('progress');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Saves a completed pre-test result so the post-test generator can resolve
  /// the student's pre-test template by assessment id.
  Future<void> completePreTest(String profileId, Assessment preTest) {
    return AssessmentService.saveResult(
      profileId,
      AssessmentResult(
        id: 'result-${preTest.id}',
        assessmentId: preTest.id,
        profileId: profileId,
        type: AssessmentType.preTest,
        score: 5,
        totalQuestions: preTest.questions.length,
        answers: const [],
        completedAt: DateTime(2026),
        durationSeconds: 120,
      ),
    );
  }

  group('Parallel-form post-test', () {
    test('post-test replays the exact same items as the completed pre-test',
        () async {
      const profileId = 'p1';

      final preTest = AssessmentService.generateStandardAssessment(
        profileId: profileId,
        type: AssessmentType.preTest,
      );
      expect(preTest.questions, isNotEmpty);

      // The pre-test is persisted on generation, keyed by its id.
      expect(AssessmentService.getPreTestTemplate(preTest.id), isNotNull);

      await completePreTest(profileId, preTest);

      final postTest = AssessmentService.generateStandardAssessment(
        profileId: profileId,
        type: AssessmentType.postTest,
      );

      // Same instrument: same number of items and an identical
      // (id, correctAnswer) set — but a fresh assessment id and post-test type.
      expect(postTest.type, AssessmentType.postTest);
      expect(postTest.id, isNot(preTest.id));
      expect(postTest.questions.length, preTest.questions.length);
      expect(_itemSignature(postTest), equals(_itemSignature(preTest)));

      // Per item: choices are preserved as a permutation (same set), and the
      // correct answer is still present among them.
      final preById = {for (final q in preTest.questions) q.id: q};
      for (final q in postTest.questions) {
        final pre = preById[q.id]!;
        expect(q.choices.toSet(), equals(pre.choices.toSet()));
        if (q.choices.isNotEmpty) {
          expect(q.choices, contains(q.correctAnswer));
        }
      }

      // Metadata mirrors the pre-test instrument.
      expect(postTest.categories, equals(preTest.categories));
      expect(postTest.difficulty, preTest.difficulty);
    });

    test('falls back to a fresh sample when no pre-test exists', () {
      // No pre-test taken: the generator must still return a usable post-test
      // rather than throwing or returning an empty assessment.
      final postTest = AssessmentService.generateStandardAssessment(
        profileId: 'no-pretest',
        type: AssessmentType.postTest,
      );
      expect(postTest.type, AssessmentType.postTest);
      expect(postTest.questions, isNotEmpty);
    });
  });
}
