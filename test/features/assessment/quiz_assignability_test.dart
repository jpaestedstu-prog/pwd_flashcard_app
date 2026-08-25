import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/custom_quiz_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// Making Quiz Builder quizzes assignable.
///
/// A [CustomQuiz] is a recipe — card ids plus permitted formats — that re-rolls
/// its questions on every play. Handing that out directly would give every
/// learner a different test and leave the educator's tracking with nothing
/// stable to match against, because `AssessmentResult.assessmentId` has to line
/// up with `AssessmentAssignment.assessmentId`.
///
/// So a quiz is *materialised* into an immutable [Assessment] at the moment it
/// is assigned, and that assessment goes through the ordinary pipeline: saved
/// under the educator, mirrored to the cloud, resolvable by id on the learner's
/// device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quiz_assign_test');
    Hive.init(tempDir.path);
    for (final name in const ['progress', 'profiles']) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  List<Flashcard> cards(int count) => [
    for (var i = 0; i < count; i++)
      Flashcard(
        id: 'c$i',
        wordEnglish: 'Word $i',
        wordFilipino: 'Salita $i',
        category: FlashcardCategory.animals,
      ),
  ];

  CustomQuiz quiz({
    List<String>? cardIds,
    List<QuestionFormat> formats = const [QuestionFormat.multipleChoice],
    int? timeLimitMinutes,
  }) => CustomQuiz(
    id: 'quiz-1',
    title: 'Farm Words',
    flashcardIds: cardIds ?? const ['c0', 'c1', 'c2'],
    questionFormats: formats,
    difficulty: GameDifficulty.hard,
    timeLimitMinutes: timeLimitMinutes,
    createdBy: 'teacher-1',
    createdAt: DateTime(2026, 8),
  );

  test('a quiz becomes a real assessment with one question per card', () {
    final assessment = AssessmentService.materialiseQuiz(quiz(), cards(5));

    expect(assessment.questions, hasLength(3));
    expect(assessment.title, 'Farm Words');
    expect(assessment.type, AssessmentType.custom);
    expect(assessment.difficulty, GameDifficulty.hard);
  });

  test('the time limit carries over, so a timed quiz stays timed', () {
    final assessment = AssessmentService.materialiseQuiz(
      quiz(timeLimitMinutes: 10),
      cards(3),
    );

    expect(assessment.timeLimitMinutes, 10);
  });

  test('every question is answerable — the right answer is on offer', () {
    // The distractor picker draws from other cards; a bug there could leave
    // the correct answer out of its own choice list.
    final assessment = AssessmentService.materialiseQuiz(
      quiz(
        formats: const [
          QuestionFormat.multipleChoice,
          QuestionFormat.trueFalse,
          QuestionFormat.matchPairs,
        ],
      ),
      cards(6),
    );

    for (final q in assessment.questions) {
      expect(
        q.choices,
        contains(q.correctAnswer),
        reason: '"${q.questionText}" cannot be answered correctly',
      );
    }
  });

  test('a fill-in-the-blank question offers no choices', () {
    final assessment = AssessmentService.materialiseQuiz(
      quiz(formats: const [QuestionFormat.fillInBlank]),
      cards(4),
    );

    for (final q in assessment.questions) {
      expect(q.format, QuestionFormat.fillInBlank);
      expect(q.choices, isEmpty);
      expect(q.correctAnswer, isNotEmpty);
    }
  });

  test('assigning twice mints two separate instruments', () {
    // Two sittings of the same quiz are two assessments, tracked separately.
    // Reusing one id would make the second assignment look already-completed
    // to anyone who sat the first.
    final first = AssessmentService.materialiseQuiz(quiz(), cards(5));
    final second = AssessmentService.materialiseQuiz(quiz(), cards(5));

    expect(first.id, isNot(second.id));
  });

  test('the play-now path keeps grouping under the quiz id', () {
    final assessment = AssessmentService.materialiseQuiz(
      quiz(),
      cards(5),
      id: 'quiz-1',
    );

    expect(assessment.id, 'quiz-1');
  });

  test('cards deleted since the quiz was built are skipped', () {
    // A quiz can outlive a flashcard. Better a shorter test than a crash.
    final assessment = AssessmentService.materialiseQuiz(
      quiz(cardIds: const ['c0', 'gone', 'c1']),
      cards(3),
    );

    expect(assessment.questions, hasLength(2));
  });

  test('a quiz whose cards are all gone yields nothing to assign', () {
    // The caller checks this and refuses rather than handing out a blank test.
    final assessment = AssessmentService.materialiseQuiz(
      quiz(cardIds: const ['gone-1', 'gone-2']),
      cards(3),
    );

    expect(assessment.questions, isEmpty);
  });

  test('a single-card quiz cannot ask an unanswerable true/false', () {
    // With no other card to borrow a wrong answer from, the only honest
    // statement is the true one — a false one would compare the word to
    // itself and mark a correct answer wrong.
    for (var seed = 0; seed < 20; seed++) {
      final assessment = AssessmentService.materialiseQuiz(
        quiz(cardIds: const ['c0'], formats: const [QuestionFormat.trueFalse]),
        cards(1),
        random: Random(seed),
      );

      final q = assessment.questions.single;
      expect(q.correctAnswer, 'True');
      expect(q.questionText, contains('Salita 0'));
    }
  });

  test('an empty format list still produces answerable questions', () {
    final assessment = AssessmentService.materialiseQuiz(
      quiz(formats: const []),
      cards(5),
    );

    expect(assessment.questions, hasLength(3));
    for (final q in assessment.questions) {
      expect(q.choices, contains(q.correctAnswer));
    }
  });

  test('a materialised quiz is resolvable by id once saved', () async {
    // The whole point: the learner's device finds it exactly like any other
    // assessment, so the existing take → result → tracking path just works.
    final assessment = AssessmentService.materialiseQuiz(quiz(), cards(5));
    await AssessmentService.saveAssessment('teacher-1', assessment);

    final found = AssessmentService.findAssessmentById(assessment.id);

    expect(found, isNotNull);
    expect(found!.questions, hasLength(3));
  });

  test('an assignment pointing at it becomes openable work', () async {
    final assessment = AssessmentService.materialiseQuiz(quiz(), cards(5));
    await AssessmentService.saveAssessment('teacher-1', assessment);
    await AssessmentService.saveAssignment(
      'teacher-1',
      AssessmentAssignment(
        id: 'as1',
        assessmentId: assessment.id,
        assessmentTitle: assessment.title,
        assignedBy: 'teacher-1',
        studentIds: const ['student-1'],
        assignedAt: DateTime(2026, 8),
      ),
    );

    final open = AssessmentService.getOpenableAssignments('student-1');

    expect(open, hasLength(1));
    expect(open.single.assessment.title, 'Farm Words');
    expect(open.single.assessment.questions, hasLength(3));
  });
}
