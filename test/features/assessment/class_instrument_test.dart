import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/post_test_readiness.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// The study procedure, end to end.
///
/// Chapter V has the teacher or parent *assign* the pre-test, the learners use
/// the app for a set period, and then the educator assigns the post-test. The
/// app could not do the first step: the assign screen only offered custom
/// assessments, which are typed `custom` and so never counted as a pre-test —
/// not in the learning gain, the Class Report, or the research export. A
/// teacher following the written procedure would have collected no gain data.
///
/// Plain `test()` against real Hive, no `testWidgets`: this file writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const educator = 'educator-1';
  const learner = 'learner-1';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('class_instrument_test');
    Hive.init(tempDir.path);
    for (final name in const ['progress', 'profiles', 'sessions']) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// A learner sitting [assessment] and getting [correct] of it right.
  AssessmentResult sit(
    Assessment assessment,
    int correct,
    DateTime at, {
    String who = learner,
  }) {
    final answers = [
      for (var i = 0; i < assessment.questions.length; i++)
        QuestionAnswer(
          questionId: assessment.questions[i].id,
          givenAnswer: i < correct ? assessment.questions[i].correctAnswer : 'x',
          isCorrect: i < correct,
          responseTimeMs: 1500,
        ),
    ];
    return AssessmentResult(
      id: '${assessment.id}-$who',
      assessmentId: assessment.id,
      profileId: who,
      type: assessment.type,
      score: correct,
      totalQuestions: assessment.questions.length,
      answers: answers,
      completedAt: at,
      durationSeconds: 300,
    );
  }

  AssessmentAssignment assign(Assessment a) => AssessmentAssignment(
    id: 'assign-${a.id}',
    assessmentId: a.id,
    assessmentTitle: a.title,
    assignedBy: educator,
    studentIds: const [learner],
    assignedAt: DateTime(2026, 9, 3),
  );

  // ─── Minting ─────────────────────────────────────────────

  group('the class pre-test', () {
    test('is a real pre-test, owned by the educator', () {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      expect(pre.type, AssessmentType.preTest);
      expect(pre.createdBy, educator);
      expect(pre.questions, hasLength(15));
    });

    test('the latest one is what the post-test mirrors', () async {
      final older = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, older);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final newer = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, newer);

      expect(AssessmentService.latestClassPreTest(educator)?.id, newer.id);
    });

    test('a custom assessment is never mistaken for one', () async {
      await AssessmentService.saveAssessment(
        educator,
        Assessment(
          id: 'custom-1',
          title: 'Animals Check',
          type: AssessmentType.custom,
          questions: const [],
          createdBy: educator,
          createdAt: DateTime(2026, 9, 20),
        ),
      );
      expect(AssessmentService.latestClassPreTest(educator), isNull);
    });
  });

  group('the class post-test', () {
    test('mirrors the pre-test item for item', () {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      final post = AssessmentService.createClassPostTest(pre);

      expect(post.type, AssessmentType.postTest);
      expect(post.createdBy, educator);
      expect(post.id, isNot(pre.id));
      expect(
        post.questions.map((q) => q.id).toSet(),
        pre.questions.map((q) => q.id).toSet(),
        reason: 'the gain has to compare the same questions',
      );
    });
  });

  // ─── Sign items for a group ──────────────────────────────

  group('sign items in a common instrument', () {
    const clips = [
      Flashcard(
        id: 'c1',
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
        category: FlashcardCategory.animals,
      ),
    ];

    test('everyone signs → the clips are used', () {
      expect(
        AssessmentService.signCardsForGroup<bool>(
          const [true, true],
          (signs) => signs,
          clips,
        ),
        clips,
      );
    });

    test('one learner who does not sign → none, for everyone', () {
      // One test, one set of items. A sign item is only fair when everyone
      // sitting it signs.
      expect(
        AssessmentService.signCardsForGroup<bool>(
          const [true, false],
          (signs) => signs,
          clips,
        ),
        isEmpty,
      );
    });

    test('nobody selected → none', () {
      expect(
        AssessmentService.signCardsForGroup<bool>(
          const [],
          (signs) => signs,
          clips,
        ),
        isEmpty,
      );
    });
  });

  // ─── The procedure, as Chapter V writes it ───────────────

  group('the study procedure', () {
    test('an assigned pre-test counts as the learner\'s pre-test', () async {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, pre);

      await AssessmentService.saveResult(
        learner,
        sit(pre, 6, DateTime(2026, 9, 2)),
      );

      expect(AssessmentService.hasCompletedPreTest(learner), isTrue);
      expect(AssessmentService.getLatestPreTest(learner)?.assessmentId, pre.id);
    });

    test('an assigned post-test ends the readiness wait', () async {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, pre);
      await AssessmentService.saveResult(
        learner,
        sit(pre, 6, DateTime.now()),
      );

      // The pre-test was a moment ago, so on its own the learner waits.
      expect(
        AssessmentService.getPostTestReadiness(learner).gate,
        PostTestGate.waiting,
      );

      final post = AssessmentService.createClassPostTest(pre);
      await AssessmentService.saveAssessment(educator, post);
      await AssessmentService.saveAssignment(educator, assign(post));

      expect(
        AssessmentService.getPostTestReadiness(learner).gate,
        PostTestGate.assigned,
        reason: 'the educator deciding the study period is over is the '
            'override, and it was unreachable until the post-test could be '
            'assigned at all',
      );
    });

    test('the pair produces a learning gain', () async {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, pre);
      await AssessmentService.saveResult(
        learner,
        sit(pre, 6, DateTime(2026, 9, 2)),
      );

      final post = AssessmentService.createClassPostTest(pre);
      await AssessmentService.saveAssessment(educator, post);
      await AssessmentService.saveResult(
        learner,
        sit(post, 12, DateTime(2026, 9, 20)),
      );

      final gain = AssessmentService.getLearningGainReport(learner);
      expect(gain, isNotNull, reason: 'this was empty under the old flow');
      expect(gain!.preTestPercentage, closeTo(0.4, 0.001));
      expect(gain.postTestPercentage, closeTo(0.8, 0.001));
    });

    test('a self-serve post-test after an assigned pre-test mirrors it', () async {
      // The learner's own post-test used to look up only the dedicated
      // template key, so after an *assigned* pre-test it fell back to a fresh
      // random sample — a different test, and a meaningless gain.
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, pre);
      // Simulate the learner's device: the template arrives under the
      // educator's key, never under the dedicated pre-test template key.
      await Hive.box('progress').delete('pretest_template_${pre.id}');
      await AssessmentService.saveResult(
        learner,
        sit(pre, 6, DateTime(2026, 9, 2)),
      );

      final selfServe = AssessmentService.generateStandardAssessment(
        profileId: learner,
        type: AssessmentType.postTest,
      );
      expect(
        selfServe.questions.map((q) => q.id).toSet(),
        pre.questions.map((q) => q.id).toSet(),
      );
    });
  });

  // ─── The Class Report's wording ──────────────────────────

  group('item wording for the Class Report', () {
    test('a sign item names the word it signs', () async {
      // Every sign item is asked "Watch the sign. Which word is it?", so the
      // Class Report on the Honor listed four identical rows and the teacher
      // could not tell which sign the class found hard.
      final signCards = [
        for (final (id, en, fil) in const [
          ('s1', 'Dog', 'Aso'),
          ('s2', 'Cat', 'Pusa'),
          ('s3', 'Bird', 'Ibon'),
          ('s4', 'Fish', 'Isda'),
          ('s5', 'Cow', 'Baka'),
          ('s6', 'Pig', 'Baboy'),
        ])
          Flashcard(
            id: id,
            wordEnglish: en,
            wordFilipino: fil,
            category: FlashcardCategory.animals,
          ),
      ];
      final pre = AssessmentService.createClassPreTest(
        educatorId: educator,
        signCards: signCards,
      );
      await AssessmentService.saveAssessment(educator, pre);

      final signItems = pre.questions
          .where((q) => q.format == QuestionFormat.signVideo)
          .toList();
      expect(signItems, isNotEmpty, reason: 'the fixture must make sign items');

      final prompts = AssessmentService.questionPrompts();
      for (final q in signItems) {
        expect(prompts[q.id], contains('“${q.correctAnswer}”'));
      }
      // Two sign items never read the same.
      expect(
        {for (final q in signItems) prompts[q.id]},
        hasLength(signItems.length),
      );
    });

    test('every other item keeps its wording as asked', () async {
      final pre = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, pre);
      final prompts = AssessmentService.questionPrompts();
      for (final q in pre.questions) {
        expect(prompts[q.id], q.questionText);
      }
    });
  });

  // ─── Two classes, one teacher ────────────────────────────

  group("each learner's post-test mirrors the pre-test they sat", () {
    // The post-test used to mirror the teacher's *newest* class pre-test for
    // everyone. A teacher with two classes mints two pre-tests, so the first
    // class got a post-test built from the second class's items — different
    // words, and a gain that measures nothing.
    const morning = 'learner-am';
    const afternoon = 'learner-pm';

    Future<(Assessment, Assessment)> twoClasses() async {
      final first = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, first);
      await AssessmentService.saveResult(
        morning,
        sit(first, 5, DateTime(2026, 9, 2), who: morning),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = AssessmentService.createClassPreTest(educatorId: educator);
      await AssessmentService.saveAssessment(educator, second);
      await AssessmentService.saveResult(
        afternoon,
        sit(second, 7, DateTime(2026, 9, 3), who: afternoon),
      );
      return (first, second);
    }

    test('two classes get two post-tests, each against its own pre-test',
        () async {
      final (first, second) = await twoClasses();
      // The pre-tests really are different samples, or this proves nothing.
      expect(
        first.questions.map((q) => q.id).toSet(),
        isNot(second.questions.map((q) => q.id).toSet()),
      );

      final plan = AssessmentService.classPostTestPlan(
        educator,
        const [morning, afternoon],
      );

      expect(plan, hasLength(2));
      final byPre = {for (final g in plan) g.pre.id: g.learners};
      expect(byPre[first.id], [morning], reason: 'not the newest pre-test');
      expect(byPre[second.id], [afternoon]);

      for (final group in plan) {
        final post = AssessmentService.createClassPostTest(group.pre);
        expect(
          post.questions.map((q) => q.id).toSet(),
          group.pre.questions.map((q) => q.id).toSet(),
        );
      }
    });

    test('learners who sat the same pre-test share one post-test', () async {
      final (first, _) = await twoClasses();
      await AssessmentService.saveResult(
        'learner-am-2',
        sit(first, 9, DateTime(2026, 9, 2), who: 'learner-am-2'),
      );

      final plan = AssessmentService.classPostTestPlan(
        educator,
        const [morning, 'learner-am-2'],
      );
      expect(plan, hasLength(1));
      expect(plan.single.pre.id, first.id);
      expect(plan.single.learners, [morning, 'learner-am-2']);
    });

    test('a learner who sat no class pre-test gets the newest', () async {
      final (_, second) = await twoClasses();
      final plan = AssessmentService.classPostTestPlan(
        educator,
        const ['joined-late'],
      );
      expect(plan.single.pre.id, second.id);
      expect(plan.single.learners, ['joined-late']);
    });

    test("another teacher's pre-test never decides the pairing", () async {
      final (_, second) = await twoClasses();
      final theirs = AssessmentService.createClassPreTest(educatorId: 'other');
      await AssessmentService.saveAssessment('other', theirs);
      await AssessmentService.saveResult(
        'shared',
        sit(theirs, 4, DateTime(2026, 9, 4), who: 'shared'),
      );

      final plan = AssessmentService.classPostTestPlan(
        educator,
        const ['shared'],
      );
      expect(plan.single.pre.id, second.id);
    });

    test('no class pre-test at all places nobody', () {
      expect(
        AssessmentService.classPostTestPlan(educator, const [learner]),
        isEmpty,
      );
    });
  });
}
