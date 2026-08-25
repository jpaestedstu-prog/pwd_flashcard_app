import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// The educator → learner assignment loop.
///
/// A teacher could build an assessment, assign it, and watch a tracking screen
/// that would never move: the learner's side of the loop was missing its
/// middle. Assessment templates are stored per creator under
/// `assessments_<profileId>`, so a learner had no key to look one up under,
/// every route that only accepted a pre-built object via go_router's `extra`
/// dead-ended back on the hub, and the learner's own home banner ("you have 2
/// assessments to complete") pointed at a screen that never named one.
///
/// These are plain `test()` cases against real Hive — deliberately not
/// `testWidgets`, which must never share a file with awaited `box.put`s here
/// (a fire-and-forget write from a fake-async zone poisons the box's write
/// queue for the rest of the file).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('assignment_loop_test');
    Hive.init(tempDir.path);
    // Compaction renames the box file mid-write on Windows and fails the run
    // with errno 5; these suites are short-lived so they never need it.
    // `progress` holds the assessments/assignments/results; `profiles` is what
    // getAssignmentStatuses reads learner names out of.
    for (final name in const ['progress', 'profiles']) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Assessment template(String id, {String title = 'Animals Quiz'}) => Assessment(
    id: id,
    title: title,
    type: AssessmentType.custom,
    questions: [
      AssessmentQuestion(
        id: '$id-q1',
        questionText: 'What is the Filipino word for "dog"?',
        correctAnswer: 'Aso',
        choices: const ['Aso', 'Pusa', 'Ibon', 'Isda'],
        category: FlashcardCategory.animals,
      ),
    ],
    categories: const [FlashcardCategory.animals],
    createdBy: 'teacher-1',
    createdAt: DateTime(2026, 8),
  );

  AssessmentAssignment assignment(
    String id, {
    required String assessmentId,
    required List<String> studentIds,
    DateTime? deadline,
    String title = 'Animals Quiz',
  }) => AssessmentAssignment(
    id: id,
    assessmentId: assessmentId,
    assessmentTitle: title,
    assignedBy: 'teacher-1',
    studentIds: studentIds,
    assignedAt: DateTime(2026, 8),
    deadline: deadline,
  );

  Future<void> completeAssessment(String profileId, String assessmentId) {
    return AssessmentService.saveResult(
      profileId,
      AssessmentResult(
        id: 'result-$assessmentId-$profileId',
        assessmentId: assessmentId,
        profileId: profileId,
        type: AssessmentType.custom,
        score: 1,
        totalQuestions: 1,
        answers: const [],
        completedAt: DateTime(2026, 8, 2),
        durationSeconds: 30,
      ),
    );
  }

  // ─── findAssessmentById ─────────────────────────────────

  group('findAssessmentById', () {
    test('finds a template stored under another profile\'s key', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));

      // The learner is the caller here, and 'student-1' has no assessments of
      // their own — this is exactly the lookup that used to be impossible.
      final found = AssessmentService.findAssessmentById('a1');

      expect(found, isNotNull);
      expect(found!.title, 'Animals Quiz');
      expect(found.questions.single.correctAnswer, 'Aso');
      expect(
        AssessmentService.getAssessments('student-1'),
        isEmpty,
        reason: 'the template is not, and should not be, copied to the learner',
      );
    });

    test('searches every creator, not just the first', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssessment(
        'parent-9',
        template('a2', title: 'Home Words'),
      );

      expect(AssessmentService.findAssessmentById('a2')?.title, 'Home Words');
    });

    test('returns null for an id nothing on the device holds', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));

      expect(AssessmentService.findAssessmentById('nope'), isNull);
      expect(AssessmentService.findAssessmentById(''), isNull);
    });

    test('skips a corrupt record instead of failing the whole lookup', () async {
      // One unreadable entry ahead of the wanted one: a learner must not be
      // locked out of their assigned work by another educator's bad row.
      await Hive.box('progress').put('assessments_broken', [
        {'id': 'a-broken'},
      ]);
      await AssessmentService.saveAssessment('teacher-1', template('a1'));

      expect(AssessmentService.findAssessmentById('a1')?.title, 'Animals Quiz');
      expect(AssessmentService.findAssessmentById('a-broken'), isNull);
    });

    test('ignores keys that are not assessment lists', () async {
      await Hive.box('progress').put('assessment_results_x', 'not-a-list');
      await AssessmentService.saveAssessment('teacher-1', template('a1'));

      expect(AssessmentService.findAssessmentById('a1'), isNotNull);
    });

    test('falls back to a stored pre-test template', () async {
      // Pre-tests are generated, never saved to an `assessments_*` list — they
      // are persisted separately so the post-test can mirror them. Resuming
      // one by id has to reach that store too.
      final preTest = AssessmentService.generateStandardAssessment(
        profileId: 'student-1',
        type: AssessmentType.preTest,
        questionCount: 5,
      );
      // The generator persists the template fire-and-forget; let it land.
      await Future<void>.delayed(Duration.zero);

      final found = AssessmentService.findAssessmentById(preTest.id);
      expect(found, isNotNull);
      expect(found!.type, AssessmentType.preTest);
      expect(found.questions.length, preTest.questions.length);
    });
  });

  // ─── getOpenableAssignments ─────────────────────────────

  group('getOpenableAssignments', () {
    test('pairs a pending assignment with the template it points at', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['student-1']),
      );

      final open = AssessmentService.getOpenableAssignments('student-1');

      expect(open, hasLength(1));
      expect(open.single.assignment.id, 'as1');
      expect(
        open.single.assessment.id,
        'a1',
        reason:
            'the learner must sit the educator\'s own template, so the result '
            'matches the assignment back in tracking',
      );
    });

    test('drops an assignment once the learner has completed it', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['student-1']),
      );
      await completeAssessment('student-1', 'a1');

      expect(AssessmentService.getOpenableAssignments('student-1'), isEmpty);
    });

    test('drops an assignment whose template was deleted', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['student-1']),
      );
      await AssessmentService.deleteAssessment('teacher-1', 'a1');

      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        isEmpty,
        reason: 'better absent than a tile that cannot open anything',
      );
      expect(
        AssessmentService.getPendingAssignments('student-1'),
        hasLength(1),
        reason: 'the assignment itself still exists for the educator',
      );
    });

    test('only returns work assigned to this learner', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['student-2']),
      );

      expect(AssessmentService.getOpenableAssignments('student-1'), isEmpty);
      expect(
        AssessmentService.getOpenableAssignments('student-2'),
        hasLength(1),
      );
    });

    test('spans educators — a child gets class work and home work', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssessment(
        'parent-9',
        template('a2', title: 'Home Words'),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['child-1']),
      );
      await AssessmentService.saveAssignment(
        'parent-9',
        assignment(
          'as2',
          assessmentId: 'a2',
          studentIds: ['child-1'],
          title: 'Home Words',
        ),
      );

      final titles = AssessmentService.getOpenableAssignments(
        'child-1',
      ).map((w) => w.assessment.title).toSet();

      expect(titles, {'Animals Quiz', 'Home Words'});
    });

    test('sorts soonest deadline first, undated last', () async {
      for (final id in ['a1', 'a2', 'a3']) {
        await AssessmentService.saveAssessment(
          'teacher-1',
          template(id, title: 'Quiz $id'),
        );
      }
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment(
          'late',
          assessmentId: 'a1',
          studentIds: ['student-1'],
          deadline: DateTime(2099, 12, 31),
        ),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('undated', assessmentId: 'a2', studentIds: ['student-1']),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment(
          'soon',
          assessmentId: 'a3',
          studentIds: ['student-1'],
          deadline: DateTime(2099),
        ),
      );

      final order = AssessmentService.getOpenableAssignments(
        'student-1',
      ).map((w) => w.assignment.id).toList();

      expect(order, ['soon', 'late', 'undated']);
    });
  });

  // ─── Tracking side of the same loop ─────────────────────

  group('getAssignmentStatuses', () {
    test('flips to completed once the learner sits the assignment', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      final task = assignment(
        'as1',
        assessmentId: 'a1',
        studentIds: ['student-1', 'student-2'],
      );
      await AssessmentService.saveAssignment('teacher-1', task);

      expect(
        AssessmentService.getAssignmentStatuses(
          task,
        ).map((s) => s.status).toSet(),
        {AssignmentStatus.pending},
      );

      await completeAssessment('student-1', 'a1');

      final after = AssessmentService.getAssignmentStatuses(task);
      expect(
        after.firstWhere((s) => s.studentId == 'student-1').status,
        AssignmentStatus.completed,
      );
      expect(
        after.firstWhere((s) => s.studentId == 'student-2').status,
        AssignmentStatus.pending,
      );
    });

    test('an unfinished assignment past its deadline reads overdue', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      final task = assignment(
        'as1',
        assessmentId: 'a1',
        studentIds: ['student-1'],
        deadline: DateTime(2020),
      );
      await AssessmentService.saveAssignment('teacher-1', task);

      expect(
        AssessmentService.getAssignmentStatuses(task).single.status,
        AssignmentStatus.overdue,
      );
    });
  });
}
