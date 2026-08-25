import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// The multi-device half of the assignment loop.
///
/// Everything the module stores is per-profile in one Hive box, which closed
/// the loop on a shared tablet and nowhere else: a teacher assigning from
/// their own laptop reached nobody. [AssessmentCloudService] mirrors the three
/// record types to Firestore and hydrates them back.
///
/// These are the parts that can be tested without a network: the merge rules
/// that decide what a pull is allowed to overwrite, the query chunking, and —
/// most important — that the whole cloud layer degrades to a plain local write
/// when Firebase is unconfigured, which is the case offline, in tests, and in
/// any build shipped without a Firebase project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('assessment_sync_test');
    Hive.init(tempDir.path);
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
    List<String> studentIds = const ['student-1'],
    String title = 'Animals Quiz',
  }) => AssessmentAssignment(
    id: id,
    assessmentId: assessmentId,
    assessmentTitle: title,
    assignedBy: 'teacher-1',
    studentIds: studentIds,
    assignedAt: DateTime(2026, 8),
  );

  AssessmentResult result(
    String id, {
    required String assessmentId,
    String profileId = 'student-1',
    DateTime? completedAt,
    int score = 1,
  }) => AssessmentResult(
    id: id,
    assessmentId: assessmentId,
    profileId: profileId,
    type: AssessmentType.custom,
    score: score,
    totalQuestions: 1,
    answers: const [],
    completedAt: completedAt ?? DateTime(2026, 8, 2),
    durationSeconds: 30,
  );

  // ─── Degrading to local ─────────────────────────────────

  group('with Firebase unconfigured', () {
    const cloud = AssessmentCloudService();

    test('every write still lands in Hive', () async {
      // The property the offline build, the test suite, and any deployment
      // without a Firebase project all rest on: the cloud layer is a mirror,
      // never a gate.
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      await cloud.saveResult('student-1', result('r1', assessmentId: 'a1'));

      expect(AssessmentService.getAssessments('teacher-1'), hasLength(1));
      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
      expect(AssessmentService.getResults('student-1'), hasLength(1));
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        isEmpty,
        reason: 'the one assignment was already completed by result r1',
      );
    });

    test('assigning reports localOnly rather than claiming success', () async {
      // The failure this guards: rules not yet deployed, or a tablet with no
      // signal. The row is safe, but the class does not have it — and a plain
      // "Assigned!" would tell the teacher otherwise.
      final outcome = await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );

      expect(outcome, CloudSyncOutcome.localOnly);
      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
    });

    test('deletes still land in Hive', () async {
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );

      await cloud.deleteAssignment('teacher-1', 'as1');
      await cloud.deleteAssessment('teacher-1', 'a1');

      expect(AssessmentService.getAssignments('teacher-1'), isEmpty);
      expect(AssessmentService.getAssessments('teacher-1'), isEmpty);
    });

    test('hydrating is a no-op that cannot throw or lose local work', () async {
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );

      await cloud.hydrateEducator('teacher-1');
      await cloud.hydrateLearner('student-1');

      expect(AssessmentService.getAssessments('teacher-1'), hasLength(1));
      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        hasLength(1),
      );
    });

    test('a learner with no assignments still syncs their results', () async {
      // hydrateLearner used to bail out early when the arrayContains query
      // came back empty, which skipped the result sync entirely — including
      // the push that is the only way an offline completion ever reaches the
      // educator. The local data must survive that path either way.
      await cloud.saveResult('student-1', result('r1', assessmentId: 'a1'));

      await cloud.hydrateLearner('student-1');

      expect(AssessmentService.getResults('student-1'), hasLength(1));
    });

    test('hydrating an empty profile id does nothing', () async {
      await cloud.hydrateEducator('');
      await cloud.hydrateLearner('');
      expect(AssessmentService.getAssessments(''), isEmpty);
    });
  });

  // ─── Offline deletes ────────────────────────────────────

  group('offline deletes', () {
    const cloud = AssessmentCloudService();

    test('a delete that cannot reach the cloud leaves a tombstone', () async {
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );

      final assessmentOutcome = await cloud.deleteAssessment(
        'teacher-1',
        'a1',
      );
      final assignmentOutcome = await cloud.deleteAssignment(
        'teacher-1',
        'as1',
      );

      expect(assessmentOutcome, CloudSyncOutcome.localOnly);
      expect(assignmentOutcome, CloudSyncOutcome.localOnly);
      expect(AssessmentService.getPendingDeletions('assessments_teacher-1'), {
        'a1',
      });
      expect(AssessmentService.getPendingDeletions('assignments_teacher-1'), {
        'as1',
      });
    });

    test('a later pull does not resurrect a deleted assessment', () async {
      // The exact bug: the row left Hive, the remote delete failed, and the
      // next hydrate handed the still-present cloud copy straight back.
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.deleteAssessment('teacher-1', 'a1');

      // What a pull would deliver — the cloud has not caught up yet.
      await AssessmentService.mergeAssessments('teacher-1', [template('a1')]);

      expect(
        AssessmentService.getAssessments('teacher-1'),
        isEmpty,
        reason: 'the educator deleted this; it must not come back',
      );
    });

    test('a later pull does not resurrect a deleted assignment', () async {
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      await cloud.deleteAssignment('teacher-1', 'as1');

      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('as1', assessmentId: 'a1'),
      ]);

      expect(AssessmentService.getAssignments('teacher-1'), isEmpty);
    });

    test('a full hydrate cycle leaves the deletion standing', () async {
      // Closest a unit test gets to "reconnect and sync": delete, then run the
      // same hydrate the screens run on open.
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      await cloud.deleteAssignment('teacher-1', 'as1');

      await cloud.hydrateEducator('teacher-1');
      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('as1', assessmentId: 'a1'),
      ]);

      expect(AssessmentService.getAssignments('teacher-1'), isEmpty);
      expect(
        AssessmentService.getAssessments('teacher-1'),
        hasLength(1),
        reason: 'deleting the assignment must not touch the template',
      );
    });

    test('a learner is not handed back work their educator deleted', () async {
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        hasLength(1),
      );

      await cloud.deleteAssignment('teacher-1', 'as1');
      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('as1', assessmentId: 'a1'),
      ]);

      expect(AssessmentService.getOpenableAssignments('student-1'), isEmpty);
    });

    test('clearing a confirmed deletion restores normal merging', () async {
      // A tombstone is a pending-delete marker, not a permanent ban: once the
      // cloud confirms, it is dropped so the bucket behaves normally again.
      await cloud.saveAssessment('teacher-1', template('a1'));
      await cloud.deleteAssessment('teacher-1', 'a1');
      await AssessmentService.clearDeletion('assessments_teacher-1', 'a1');

      expect(
        AssessmentService.getPendingDeletions('assessments_teacher-1'),
        isEmpty,
      );

      await AssessmentService.mergeAssessments('teacher-1', [template('a1')]);
      expect(AssessmentService.getAssessments('teacher-1'), hasLength(1));
    });

    test('tombstones are scoped to one educator', () async {
      // Two educators can hold assignments with the same id; one deleting
      // theirs must not suppress anything in the other's bucket.
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      await cloud.deleteAssignment('teacher-1', 'as1');

      await AssessmentService.mergeAssignments('parent-9', [
        AssessmentAssignment(
          id: 'as1',
          assessmentId: 'a2',
          assessmentTitle: 'Home Words',
          assignedBy: 'parent-9',
          studentIds: const ['student-1'],
          assignedAt: DateTime(2026, 8),
        ),
      ]);

      expect(AssessmentService.getAssignments('teacher-1'), isEmpty);
      expect(
        AssessmentService.getAssignments('parent-9'),
        hasLength(1),
        reason: 'one tombstone must not reach another educator bucket',
      );
    });

    test('an assessment tombstone does not block an assignment', () async {
      // The two buckets are keyed separately; ids are uuids but nothing stops
      // them colliding across record types.
      await cloud.saveAssessment('teacher-1', template('shared-id'));
      await cloud.deleteAssessment('teacher-1', 'shared-id');

      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('shared-id', assessmentId: 'a1'),
      ]);

      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
      expect(AssessmentService.getAssessments('teacher-1'), isEmpty);
    });

    test('deleting the same row twice keeps one tombstone', () async {
      await cloud.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      await cloud.deleteAssignment('teacher-1', 'as1');
      await cloud.deleteAssignment('teacher-1', 'as1');

      expect(AssessmentService.getPendingDeletions('assignments_teacher-1'), {
        'as1',
      });
    });
  });

  // ─── The synced-id ledger ───────────────────────────────

  group('synced-id ledger', () {
    test('records and forgets ids per bucket', () async {
      await AssessmentService.markSynced('assessments_teacher-1', ['a1', 'a2']);
      expect(AssessmentService.getSyncedIds('assessments_teacher-1'), {
        'a1',
        'a2',
      });

      await AssessmentService.unmarkSynced('assessments_teacher-1', ['a1']);
      expect(AssessmentService.getSyncedIds('assessments_teacher-1'), {'a2'});

      await AssessmentService.unmarkSynced('assessments_teacher-1', ['a2']);
      expect(
        AssessmentService.getSyncedIds('assessments_teacher-1'),
        isEmpty,
        reason: 'an empty ledger should not leave a stray key behind',
      );
    });

    test('is scoped per bucket', () async {
      await AssessmentService.markSynced('assessments_teacher-1', ['x']);
      expect(AssessmentService.getSyncedIds('assignments_teacher-1'), isEmpty);
      expect(AssessmentService.getSyncedIds('assessments_parent-9'), isEmpty);
    });

    test('a never-synced id is not in the ledger', () async {
      // This is the distinction the reconciler rests on: a row absent from
      // the cloud AND absent from the ledger was created offline and must be
      // pushed, never deleted.
      const cloud = AssessmentCloudService();
      await cloud.saveAssessment('teacher-1', template('offline-made'));

      expect(
        AssessmentService.getSyncedIds('assessments_teacher-1'),
        isEmpty,
        reason: 'Firebase is unconfigured here, so nothing reached the cloud',
      );
    });

    test('deleting a row forgets its ledger entry', () async {
      await AssessmentService.markSynced('assignments_teacher-1', ['as1']);
      await AssessmentService.unmarkSynced('assignments_teacher-1', ['as1']);

      expect(AssessmentService.getSyncedIds('assignments_teacher-1'), isEmpty);
    });

    test('marking the same id twice is idempotent', () async {
      await AssessmentService.markSynced('assessments_teacher-1', ['a1']);
      await AssessmentService.markSynced('assessments_teacher-1', ['a1']);

      expect(AssessmentService.getSyncedIds('assessments_teacher-1'), {'a1'});
    });
  });

  // ─── Reconciling local rows against the cloud ───────────

  group('classifyLocalRows', () {
    ({Set<String> toDelete, Set<String> toPush}) classify({
      required Set<String> local,
      required Set<String> cloud,
      Set<String> synced = const {},
      required bool authoritative,
    }) => AssessmentCloudService.classifyLocalRows(
      localIds: local,
      cloudIds: cloud,
      syncedIds: synced,
      cloudIsAuthoritative: authoritative,
    );

    test('a row the cloud still has is left alone', () {
      final plan = classify(
        local: {'a1'},
        cloud: {'a1'},
        synced: {'a1'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('a never-synced row is pushed, never deleted', () {
      // Created during an offline window. This is the case that must survive.
      final plan = classify(
        local: {'offline-made'},
        cloud: const {},
        authoritative: true,
      );

      expect(plan.toPush, {'offline-made'});
      expect(plan.toDelete, isEmpty);
    });

    test('a synced row the cloud dropped is deleted locally', () {
      // Deleted on the teacher's laptop; the tablet has to follow.
      final plan = classify(
        local: {'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: true,
      );

      expect(plan.toDelete, {'a1'});
      expect(plan.toPush, isEmpty);
    });

    // ─ The guard the whole hardening exists for ─

    test('a cached empty answer deletes nothing', () {
      // `get()` falls back to Firestore's offline cache when the server is
      // unreachable and returns whatever is cached — possibly nothing — with
      // no error raised. Acting on that would wipe a teacher's whole question
      // bank because the wifi dropped.
      final plan = classify(
        local: {'a1', 'a2', 'a3'},
        cloud: const {},
        synced: {'a1', 'a2', 'a3'},
        authoritative: false,
      );

      expect(
        plan.toDelete,
        isEmpty,
        reason: 'an unauthoritative empty response is not evidence of deletion',
      );
    });

    test('a cached answer does not re-push synced rows either', () {
      // We cannot tell whether the cloud still has them, so the only safe move
      // is to leave them completely alone — pushing could resurrect a row that
      // really was deleted elsewhere.
      final plan = classify(
        local: {'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: false,
      );

      expect(plan.toPush, isEmpty);
      expect(plan.toDelete, isEmpty);
    });

    test('offline work is still pushed from a cached answer', () {
      // Unsynced rows are this device's own; uploading them is safe whatever
      // the cloud snapshot was, and it is how an offline window recovers.
      final plan = classify(
        local: {'offline-made', 'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: false,
      );

      expect(plan.toPush, {'offline-made'});
      expect(plan.toDelete, isEmpty);
    });

    test('an authoritative empty answer does clear a synced bucket', () {
      // The legitimate mirror of the guard: a teacher really did delete
      // everything from another device, and this must converge rather than
      // hold stale rows forever.
      final plan = classify(
        local: {'a1', 'a2'},
        cloud: const {},
        synced: {'a1', 'a2'},
        authoritative: true,
      );

      expect(plan.toDelete, {'a1', 'a2'});
    });

    test('a mixed bucket is split correctly', () {
      final plan = classify(
        local: {'kept', 'deleted-elsewhere', 'made-offline'},
        cloud: {'kept'},
        synced: {'kept', 'deleted-elsewhere'},
        authoritative: true,
      );

      expect(plan.toDelete, {'deleted-elsewhere'});
      expect(plan.toPush, {'made-offline'});
    });

    test('a cloud row this device never had is not our problem', () {
      // The merge adds it; classification only ever looks at local rows.
      final plan = classify(
        local: const {},
        cloud: {'from-laptop'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('an empty device with an empty cloud does nothing', () {
      final plan = classify(local: const {}, cloud: const {}, authoritative: true);

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('a stale ledger entry cannot delete a row the cloud returned', () {
      // Belt and braces: presence in the cloud always wins over the ledger.
      final plan = classify(
        local: {'a1'},
        cloud: {'a1'},
        synced: {'a1', 'ghost'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
    });
  });

  // ─── Work withdrawn on the educator's device ────────────

  group('withdrawLearnerFromAssignmentsExcept', () {
    /// Saves an assignment *and* records it as synced — the state a row is in
    /// once it has been through the cloud, which is the only state withdrawal
    /// is allowed to act on.
    Future<void> saveSynced(
      String educatorId,
      AssessmentAssignment task,
    ) async {
      await AssessmentService.saveAssignment(educatorId, task);
      await AssessmentService.markSynced('assignments_$educatorId', [task.id]);
    }

    test('stops showing work the educator deleted elsewhere', () async {
      // Verified broken on two real devices before this existed: the teacher
      // deleted the assignment, the cloud dropped it, and the pupil's tablet
      // still said "1 pending assessment" on every launch.
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await saveSynced('teacher-1', assignment('as1', assessmentId: 'a1'));
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        hasLength(1),
      );

      // The cloud came back without it.
      final changed = await AssessmentService
          .withdrawLearnerFromAssignmentsExcept('student-1', const {});

      expect(changed, isTrue);
      expect(AssessmentService.getOpenableAssignments('student-1'), isEmpty);
    });

    test('work still assigned is left alone', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await saveSynced('teacher-1', assignment('as1', assessmentId: 'a1'));

      final changed = await AssessmentService
          .withdrawLearnerFromAssignmentsExcept('student-1', {'as1'});

      expect(changed, isFalse);
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        hasLength(1),
      );
    });

    test('an educator\'s unsynced work is never destroyed', () async {
      // The shared-tablet data-loss path. The teacher creates an assignment
      // while offline; the learner signs in on the same device and their cloud
      // query legitimately does not return it. Withdrawing would empty the row
      // and delete work that never had its chance to upload — and the
      // educator's own reconcile could not push what no longer existed.
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('made-offline', assessmentId: 'a1'),
      );

      final changed = await AssessmentService
          .withdrawLearnerFromAssignmentsExcept('student-1', const {});

      expect(changed, isFalse);
      expect(
        AssessmentService.getAssignments('teacher-1'),
        hasLength(1),
        reason: 'missing from the cloud only means deleted if it was ever there',
      );
    });

    test('a classmate on the same tablet keeps their copy', () async {
      // The reason this trims the row instead of deleting it: a shared device
      // holds one assignment naming several learners.
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await saveSynced(
        'teacher-1',
        assignment(
          'as1',
          assessmentId: 'a1',
          studentIds: ['student-1', 'student-2'],
        ),
      );

      await AssessmentService.withdrawLearnerFromAssignmentsExcept(
        'student-1',
        const {},
      );

      expect(AssessmentService.getOpenableAssignments('student-1'), isEmpty);
      expect(
        AssessmentService.getOpenableAssignments('student-2'),
        hasLength(1),
        reason: 'withdrawing one pupil must not cancel another pupil\'s work',
      );
    });

    test('a row left naming nobody is dropped', () async {
      await saveSynced('teacher-1', assignment('as1', assessmentId: 'a1'));

      await AssessmentService.withdrawLearnerFromAssignmentsExcept(
        'student-1',
        const {},
      );

      expect(AssessmentService.getAssignments('teacher-1'), isEmpty);
    });

    test('withdrawal spans every educator who set work', () async {
      await saveSynced('teacher-1', assignment('as1', assessmentId: 'a1'));
      await saveSynced(
        'parent-9',
        AssessmentAssignment(
          id: 'as2',
          assessmentId: 'a2',
          assessmentTitle: 'Home Words',
          assignedBy: 'parent-9',
          studentIds: const ['student-1'],
          assignedAt: DateTime(2026, 8),
        ),
      );

      await AssessmentService.withdrawLearnerFromAssignmentsExcept(
        'student-1',
        {'as1'},
      );

      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
      expect(AssessmentService.getAssignments('parent-9'), isEmpty);
    });

    test('another learner is never touched', () async {
      await saveSynced(
        'teacher-1',
        assignment('as1', assessmentId: 'a1', studentIds: ['student-2']),
      );

      final changed = await AssessmentService
          .withdrawLearnerFromAssignmentsExcept('student-1', const {});

      expect(changed, isFalse);
      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
    });

    test('an empty learner id changes nothing', () async {
      await saveSynced('teacher-1', assignment('as1', assessmentId: 'a1'));

      final changed = await AssessmentService
          .withdrawLearnerFromAssignmentsExcept('', const {});

      expect(changed, isFalse);
      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
    });
  });

  // ─── Reconciling local rows against the cloud ───────────

  group('classifyLocalRows', () {
    ({Set<String> toDelete, Set<String> toPush}) classify({
      required Set<String> local,
      required Set<String> cloud,
      Set<String> synced = const {},
      required bool authoritative,
    }) => AssessmentCloudService.classifyLocalRows(
      localIds: local,
      cloudIds: cloud,
      syncedIds: synced,
      cloudIsAuthoritative: authoritative,
    );

    test('a row the cloud still has is left alone', () {
      final plan = classify(
        local: {'a1'},
        cloud: {'a1'},
        synced: {'a1'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('a never-synced row is pushed, never deleted', () {
      // Created during an offline window. This is the case that must survive.
      final plan = classify(
        local: {'offline-made'},
        cloud: const {},
        authoritative: true,
      );

      expect(plan.toPush, {'offline-made'});
      expect(plan.toDelete, isEmpty);
    });

    test('a synced row the cloud dropped is deleted locally', () {
      // Deleted on the teacher's laptop; the tablet has to follow.
      final plan = classify(
        local: {'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: true,
      );

      expect(plan.toDelete, {'a1'});
      expect(plan.toPush, isEmpty);
    });

    // ─ The guard the whole hardening exists for ─

    test('a cached empty answer deletes nothing', () {
      // `get()` falls back to Firestore's offline cache when the server is
      // unreachable and returns whatever is cached — possibly nothing — with
      // no error raised. Acting on that would wipe a teacher's whole question
      // bank because the wifi dropped.
      final plan = classify(
        local: {'a1', 'a2', 'a3'},
        cloud: const {},
        synced: {'a1', 'a2', 'a3'},
        authoritative: false,
      );

      expect(
        plan.toDelete,
        isEmpty,
        reason: 'an unauthoritative empty response is not evidence of deletion',
      );
    });

    test('a cached answer does not re-push synced rows either', () {
      // We cannot tell whether the cloud still has them, so the only safe move
      // is to leave them completely alone — pushing could resurrect a row that
      // really was deleted elsewhere.
      final plan = classify(
        local: {'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: false,
      );

      expect(plan.toPush, isEmpty);
      expect(plan.toDelete, isEmpty);
    });

    test('offline work is still pushed from a cached answer', () {
      // Unsynced rows are this device's own; uploading them is safe whatever
      // the cloud snapshot was, and it is how an offline window recovers.
      final plan = classify(
        local: {'offline-made', 'a1'},
        cloud: const {},
        synced: {'a1'},
        authoritative: false,
      );

      expect(plan.toPush, {'offline-made'});
      expect(plan.toDelete, isEmpty);
    });

    test('an authoritative empty answer does clear a synced bucket', () {
      // The legitimate mirror of the guard: a teacher really did delete
      // everything from another device, and this must converge rather than
      // hold stale rows forever.
      final plan = classify(
        local: {'a1', 'a2'},
        cloud: const {},
        synced: {'a1', 'a2'},
        authoritative: true,
      );

      expect(plan.toDelete, {'a1', 'a2'});
    });

    test('a mixed bucket is split correctly', () {
      final plan = classify(
        local: {'kept', 'deleted-elsewhere', 'made-offline'},
        cloud: {'kept'},
        synced: {'kept', 'deleted-elsewhere'},
        authoritative: true,
      );

      expect(plan.toDelete, {'deleted-elsewhere'});
      expect(plan.toPush, {'made-offline'});
    });

    test('a cloud row this device never had is not our problem', () {
      // The merge adds it; classification only ever looks at local rows.
      final plan = classify(
        local: const {},
        cloud: {'from-laptop'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('an empty device with an empty cloud does nothing', () {
      final plan = classify(local: const {}, cloud: const {}, authoritative: true);

      expect(plan.toDelete, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('a stale ledger entry cannot delete a row the cloud returned', () {
      // Belt and braces: presence in the cloud always wins over the ledger.
      final plan = classify(
        local: {'a1'},
        cloud: {'a1'},
        synced: {'a1', 'ghost'},
        authoritative: true,
      );

      expect(plan.toDelete, isEmpty);
    });
  });

  // ─── Work withdrawn on the educator's device ────────────

  // ─── Merge rules ────────────────────────────────────────

  group('mergeAssessments', () {
    test('keeps local work a pull did not know about', () async {
      // The offline case: a teacher builds on the tablet with no signal, then
      // opens Assign Tasks once back on wifi. The pull must not erase them.
      await AssessmentService.saveAssessment('teacher-1', template('local'));

      await AssessmentService.mergeAssessments('teacher-1', [
        template('cloud', title: 'From The Laptop'),
      ]);

      final ids = AssessmentService.getAssessments(
        'teacher-1',
      ).map((a) => a.id).toSet();
      expect(ids, {'local', 'cloud'});
    });

    test('the incoming copy wins a same-id collision', () async {
      await AssessmentService.saveAssessment(
        'teacher-1',
        template('a1', title: 'Old Title'),
      );

      await AssessmentService.mergeAssessments('teacher-1', [
        template('a1', title: 'Renamed On The Laptop'),
      ]);

      final stored = AssessmentService.getAssessments('teacher-1');
      expect(stored, hasLength(1));
      expect(stored.single.title, 'Renamed On The Laptop');
    });

    test('an empty pull changes nothing', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.mergeAssessments('teacher-1', const []);
      expect(AssessmentService.getAssessments('teacher-1'), hasLength(1));
    });
  });

  group('mergeAssignments', () {
    test('unions by id and keeps local rows', () async {
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('local', assessmentId: 'a1'),
      );

      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('cloud', assessmentId: 'a2'),
      ]);

      expect(
        AssessmentService.getAssignments('teacher-1').map((a) => a.id).toSet(),
        {'local', 'cloud'},
      );
    });

    test('a re-pull of the same assignment does not duplicate it', () async {
      final task = assignment('as1', assessmentId: 'a1');
      await AssessmentService.mergeAssignments('teacher-1', [task]);
      await AssessmentService.mergeAssignments('teacher-1', [task]);

      expect(AssessmentService.getAssignments('teacher-1'), hasLength(1));
    });

    test('a learner reached from two educators keeps both', () async {
      // What `hydrateLearner` does: the same pull is split by `assignedBy` and
      // filed under each educator, because that is where
      // `getAssignmentsForStudent` scans for it.
      await AssessmentService.mergeAssignments('teacher-1', [
        assignment('as1', assessmentId: 'a1'),
      ]);
      await AssessmentService.mergeAssignments('parent-9', [
        AssessmentAssignment(
          id: 'as2',
          assessmentId: 'a2',
          assessmentTitle: 'Home Words',
          assignedBy: 'parent-9',
          studentIds: const ['student-1'],
          assignedAt: DateTime(2026, 8),
        ),
      ]);

      expect(
        AssessmentService.getAssignmentsForStudent(
          'student-1',
        ).map((a) => a.id).toSet(),
        {'as1', 'as2'},
      );
    });
  });

  group('mergeResults', () {
    test('unions by id rather than appending duplicates', () async {
      await AssessmentService.saveResult('student-1', result('r1', assessmentId: 'a1'));

      // The same result pulled back down from the cloud.
      await AssessmentService.mergeResults('student-1', [result('r1', assessmentId: 'a1')]);

      expect(AssessmentService.getResults('student-1'), hasLength(1));
    });

    test('a result submitted on another device completes the work', () async {
      await AssessmentService.saveAssessment('teacher-1', template('a1'));
      await AssessmentService.saveAssignment(
        'teacher-1',
        assignment('as1', assessmentId: 'a1'),
      );
      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        hasLength(1),
      );

      await AssessmentService.mergeResults('student-1', [
        result('r-from-school-tablet', assessmentId: 'a1'),
      ]);

      expect(
        AssessmentService.getOpenableAssignments('student-1'),
        isEmpty,
        reason: 'an assessment already sat elsewhere must stop nagging here',
      );
    });

    test('the hundred-result cap keeps the newest, not the last merged', () async {
      // Merge order is arrival order, which for a cloud pull is arbitrary.
      // Trimming has to go by completion time or a learner loses their most
      // recent scores to whatever Firestore happened to return first.
      final older = [
        for (var i = 0; i < 100; i++)
          result(
            'old-$i',
            assessmentId: 'a1',
            completedAt: DateTime(2026).add(Duration(days: i)),
          ),
      ];
      final newest = result(
        'newest',
        assessmentId: 'a1',
        completedAt: DateTime(2026, 12, 31),
      );

      await AssessmentService.mergeResults('student-1', [newest, ...older]);

      final stored = AssessmentService.getResults('student-1');
      expect(stored, hasLength(100));
      expect(
        stored.map((r) => r.id),
        contains('newest'),
        reason: 'the most recent result must survive the trim',
      );
      expect(stored.map((r) => r.id), isNot(contains('old-0')));
    });
  });

  // ─── Not hanging the UI ─────────────────────────────────

  test('every remote call is time-boxed', () {
    // A Firestore write future does not complete while offline — it resolves
    // only on server ack. Without a bound, "Assign" hangs on "Assigning…"
    // forever with no network, which is the case this whole feature most
    // needs to handle gracefully. If this constant ever disappears, that bug
    // comes straight back.
    expect(AssessmentCloudService.remoteTimeout, greaterThan(Duration.zero));
    expect(
      AssessmentCloudService.remoteTimeout,
      lessThanOrEqualTo(const Duration(seconds: 10)),
      reason: 'a learner should not stare at a spinner for longer than this',
    );
  });

  // ─── Query chunking ─────────────────────────────────────

  group('chunkIds', () {
    test('splits at Firestore\'s thirty-value whereIn limit', () {
      final ids = [for (var i = 0; i < 31; i++) 'id-$i'];

      final chunks = AssessmentCloudService.chunkIds(ids).toList();

      expect(chunks, hasLength(2));
      expect(chunks.first, hasLength(30));
      expect(chunks.last, hasLength(1));
      expect(
        chunks.expand((c) => c).toSet(),
        ids.toSet(),
        reason: 'a class of thirty-one must not silently lose a learner',
      );
    });

    test('an exact multiple produces no empty trailing chunk', () {
      final ids = [for (var i = 0; i < 60; i++) 'id-$i'];
      final chunks = AssessmentCloudService.chunkIds(ids).toList();
      expect(chunks, hasLength(2));
      expect(chunks.every((c) => c.isNotEmpty), isTrue);
    });

    test('an empty list produces no chunks', () {
      expect(AssessmentCloudService.chunkIds(const []), isEmpty);
    });
  });
}
