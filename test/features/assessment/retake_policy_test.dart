import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/home_group.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// Whether a learner may sit a half of the instrument again.
///
/// The policy is a decision about how the *instrument* is being used, so it
/// lives on the class or home group rather than on the profile: an educator
/// makes it once for everyone they teach. It rides on the document the
/// learner's device already caches at join time, which is why it needs no new
/// collection and no rules deploy.
///
/// Plain `test()` against real Hive — no `testWidgets` in this file, so an
/// awaited `box.put` cannot poison the write queue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retake_policy_test');
    Hive.init(tempDir.path);
    for (final name in const [
      'profiles',
      'progress',
      'settings',
      'classrooms',
      'home_groups',
    ]) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Classroom classroom({required bool allowed}) => Classroom(
    id: 'class-1',
    code: 'ABC123',
    name: 'Grade 3 Hearing',
    teacherId: 'teacher-1',
    accessibility: DisabilityType.hearing,
    allowAssessmentRetakes: allowed,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  HomeGroup homeGroup({required bool allowed}) => HomeGroup(
    id: 'group-1',
    code: 'XYZ789',
    name: 'Home',
    ownerProfileId: 'parent-1',
    allowAssessmentRetakes: allowed,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  UserProfile learner({String? classroomId, String? homeGroupId}) =>
      UserProfile(
        id: 'learner-1',
        name: 'Learner',
        role: classroomId != null ? UserRole.student : UserRole.child,
        createdAt: DateTime(2026),
        classroomId: classroomId,
        homeGroupId: homeGroupId,
      );

  // ─── The stored flag ─────────────────────────────────────

  group('serialisation', () {
    test('a class round-trips its policy', () {
      final locked = classroom(allowed: false);
      final back = Classroom.fromJson(locked.toJson());
      expect(back.allowAssessmentRetakes, isFalse);
    });

    test('a home group round-trips its policy', () {
      final locked = homeGroup(allowed: false);
      final back = HomeGroup.fromJson(locked.toJson());
      expect(back.allowAssessmentRetakes, isFalse);
    });

    test('a document written before the field existed is locked', () {
      // Every group is a study group. One made before the setting existed
      // must not stay open just because nobody remembered to lock it.
      final legacy = Classroom.fromJson({
        'id': 'old-1',
        'code': 'OLD123',
        'name': 'Legacy',
        'teacher_id': 'teacher-1',
        'accessibility': DisabilityType.none.index,
        'created_at': DateTime(2026).toIso8601String(),
        'updated_at': DateTime(2026).toIso8601String(),
      });
      expect(legacy.allowAssessmentRetakes, isFalse);
    });

    test('a new class or home group starts locked', () {
      expect(
        Classroom(
          id: 'c',
          code: 'C',
          name: 'New',
          teacherId: 't',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ).allowAssessmentRetakes,
        isFalse,
      );
      expect(
        HomeGroup(
          id: 'g',
          code: 'G',
          name: 'New',
          ownerProfileId: 'p',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ).allowAssessmentRetakes,
        isFalse,
      );
    });

    test('copyWith carries it', () {
      final reopened = classroom(
        allowed: false,
      ).copyWith(allowAssessmentRetakes: true);
      expect(reopened.allowAssessmentRetakes, isTrue);
    });
  });

  // ─── What the learner's device makes of it ───────────────

  group('resolving the policy for a learner', () {
    test('a student reads it from their class', () async {
      await HiveService.cacheClassroom(classroom(allowed: false));
      expect(
        AssessmentService.retakesAllowed(learner(classroomId: 'class-1')),
        isFalse,
      );
    });

    test('a child reads it from their home group', () async {
      await HiveService.cacheHomeGroup(homeGroup(allowed: false));
      expect(
        AssessmentService.retakesAllowed(learner(homeGroupId: 'group-1')),
        isFalse,
      );
    });

    test('an open class allows them', () async {
      await HiveService.cacheClassroom(classroom(allowed: true));
      expect(
        AssessmentService.retakesAllowed(learner(classroomId: 'class-1')),
        isTrue,
      );
    });

    // Locked is the answer wherever there is no group saying otherwise. That
    // only ever closes a *second* self-started sitting: a first one comes
    // from an assignment, which this policy does not touch.
    test('an unlinked learner is locked', () {
      expect(AssessmentService.retakesAllowed(learner()), isFalse);
    });

    test('a class this device has never cached is locked', () {
      expect(
        AssessmentService.retakesAllowed(learner(classroomId: 'never-seen')),
        isFalse,
      );
    });

    test('no profile at all is locked', () {
      expect(AssessmentService.retakesAllowed(null), isFalse);
    });
  });

  // ─── Attempt history ─────────────────────────────────────

  group('attempts', () {
    AssessmentResult result(AssessmentType type, int score, DateTime at) =>
        AssessmentResult(
          id: '${type.name}-${at.millisecondsSinceEpoch}',
          assessmentId: 'a1',
          profileId: 'learner-1',
          type: type,
          score: score,
          totalQuestions: 10,
          answers: const [],
          completedAt: at,
          durationSeconds: 60,
        );

    test('newest first, so the one that counts is first', () async {
      // The learning gain reads the newest sitting. A list in arrival order
      // would put the counted attempt anywhere.
      for (final (score, day) in const [(3, 1), (9, 20), (6, 10)]) {
        await AssessmentService.saveResult(
          'learner-1',
          result(AssessmentType.preTest, score, DateTime(2026, 9, day)),
        );
      }

      final attempts = AssessmentService.getAttempts(
        'learner-1',
        AssessmentType.preTest,
      );
      expect(attempts.map((a) => a.score), [9, 6, 3]);
      expect(
        attempts.first.completedAt,
        AssessmentService.getLatestPreTest('learner-1')!.completedAt,
        reason: 'the first row must be the one the gain is measured from',
      );
    });

    test('the two halves are kept apart', () async {
      await AssessmentService.saveResult(
        'learner-1',
        result(AssessmentType.preTest, 4, DateTime(2026, 9, 2)),
      );
      await AssessmentService.saveResult(
        'learner-1',
        result(AssessmentType.postTest, 8, DateTime(2026, 9, 20)),
      );

      expect(
        AssessmentService.getAttempts('learner-1', AssessmentType.preTest),
        hasLength(1),
      );
      expect(
        AssessmentService.getAttempts('learner-1', AssessmentType.postTest),
        hasLength(1),
      );
    });

    test('a learner who has sat nothing has no attempts', () {
      expect(
        AssessmentService.getAttempts('nobody', AssessmentType.preTest),
        isEmpty,
      );
    });
  });
}
