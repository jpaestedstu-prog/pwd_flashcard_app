import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/educator_roster_service.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/home_group.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/deleted_learner_cleanup.dart';

/// The pieces of 1.4.1's privacy rules that live in the app.
///
/// The rules let a device read a learner's records only as the learner's own
/// device, one of their educators, or a classmate; a query may name 30
/// learners but a request may make only 10 lookups, so an educator's device
/// keeps a roster (`educator_rosters/{uid}`) the rules read once. These pin
/// how that roster follows a class, and the two numbers the rules engine
/// imposes on the app's queries. The rules themselves are tested against the
/// emulator (tool/privacy_rules_emulator_test.py).
void main() {
  group('roster plan for one group', () {
    test('adds members it does not have, and a member on a new device', () {
      final plan = EducatorRosterService.planGroup(
        roster: {'a': 'uA', 'b': 'old-tablet'},
        via: {'a': 'c1', 'b': 'c1'},
        groupId: 'c1',
        memberIds: {'a', 'b', 'c'},
        learnerUids: {'a': 'uA', 'b': 'new-tablet', 'c': 'uC'},
      );
      expect(plan.add, {'b': 'new-tablet', 'c': 'uC'});
      expect(plan.remove, isEmpty);
    });

    test('takes off whoever left this group', () {
      final plan = EducatorRosterService.planGroup(
        roster: {'a': 'uA', 'gone': 'uG'},
        via: {'a': 'c1', 'gone': 'c1'},
        groupId: 'c1',
        memberIds: {'a'},
        learnerUids: {'a': 'uA'},
      );
      expect(plan.add, isEmpty);
      expect(plan.remove, {'gone'});
    });

    test('leaves learners from this device\'s other groups alone', () {
      final plan = EducatorRosterService.planGroup(
        roster: {'a': 'uA', 'kid': 'uK', 'tablet': 'me'},
        via: {'a': 'c1', 'kid': 'family-1', 'tablet': 'device'},
        groupId: 'c1',
        memberIds: {'a'},
        learnerUids: {'a': 'uA'},
      );
      expect(plan.remove, isEmpty);
    });

    test('never adds someone who is not a member, or has no device', () {
      // A profile read for another reason must not slip onto the roster.
      final plan = EducatorRosterService.planGroup(
        roster: const {},
        via: const {},
        groupId: 'c1',
        memberIds: {'a', 'b'},
        learnerUids: {'a': 'uA', 'b': '', 'stranger': 'uX'},
      );
      expect(plan.add, {'a': 'uA'});
    });

    test('an unreadable member is not taken off for being unreadable', () {
      // A member whose profile this device could not read has no uid here,
      // but is still in the class: they keep their place.
      final plan = EducatorRosterService.planGroup(
        roster: {'a': 'uA', 'b': 'uB'},
        via: {'a': 'c1', 'b': 'c1'},
        groupId: 'c1',
        memberIds: {'a', 'b'},
        learnerUids: {'a': 'uA'},
      );
      expect(plan.add, isEmpty);
      expect(plan.remove, isEmpty);
    });
  });

  group('whose roster a joining learner joins', () {
    final now = DateTime.utc(2026, 10, 13);

    test('a class names its teacher\'s device, and reads it back', () {
      final c = Classroom(
        id: 'c1',
        code: 'ABC123',
        name: 'Class',
        teacherId: 'pT',
        teacherUid: 'uT',
        createdAt: now,
        updatedAt: now,
      );
      expect(c.toJson()['teacher_uid'], 'uT');
      expect(Classroom.fromJson(c.toJson()).teacherUid, 'uT');
      expect(c.copyWith(name: 'Renamed').teacherUid, 'uT');
    });

    test('a class from before 1.4.1 names none, and writes none back', () {
      final c = Classroom(
        id: 'c1',
        code: 'ABC123',
        name: 'Class',
        teacherId: 'pT',
        createdAt: now,
        updatedAt: now,
      );
      expect(c.toJson().containsKey('teacher_uid'), isFalse,
          reason: 'a save must not blank a name another version wrote');
      expect(Classroom.fromJson(c.toJson()).teacherUid, isNull);
    });

    test('a family group names its parent\'s device', () {
      final g = HomeGroup(
        id: 'g1',
        code: 'FAM123',
        name: 'Family',
        ownerProfileId: 'pP',
        ownerUid: 'uP',
        createdAt: now,
        updatedAt: now,
      );
      expect(g.toJson()['owner_uid'], 'uP');
      expect(HomeGroup.fromJson(g.toJson()).ownerUid, 'uP');
      final old = HomeGroup.fromJson({...g.toJson()}..remove('owner_uid'));
      expect(old.ownerUid, isNull);
      expect(old.toJson().containsKey('owner_uid'), isFalse);
    });
  });

  group('queries the rules engine can take', () {
    test('documents asked for by id: ten names a query', () {
      // Each name counts as a document read and a request may make 20 in
      // all, lookups included: 30 names (until 1.4.1) were always refused.
      final ids = [for (var i = 0; i < 25; i++) 'id-$i'];
      final chunks = AssessmentCloudService.chunkDocIds(ids).toList();
      expect(chunks.map((c) => c.length), [10, 10, 5]);
      expect(chunks.expand((c) => c).toList(), ids);
      expect(DeletedLearnerCleanup.byIdChunk, 10);
    });

    test('learners by field still go 30 to a query (the roster proves them)',
        () {
      final ids = [for (var i = 0; i < 31; i++) 'id-$i'];
      expect(
        AssessmentCloudService.chunkIds(ids).map((c) => c.length),
        [30, 1],
      );
    });
  });
}
