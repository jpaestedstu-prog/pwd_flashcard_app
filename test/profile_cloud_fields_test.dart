import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/security/pin_credential_helper.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/remote/profile_cloud_fields.dart';

/// A learner's cloud profile is readable by any signed-in user who knows its
/// id. Until 1.4.1 the class and family-group joins copied the PIN hash, the
/// birth date and the grade level there. These pin what a join, and every
/// profile sync, may send now.

UserProfile _learner() => PinCredentialHelper.applyPin(
  UserProfile(
    id: 'kid',
    name: 'Kid',
    role: UserRole.child,
    createdAt: DateTime(2026, 1, 2),
    birthDate: DateTime(2017, 5, 6),
    gradeLevel: GradeLevel.values.first,
    classroomId: 'class-1',
    homeGroupId: 'family-1',
    learningLevel: LearningLevel.beginner,
    ownerUid: 'uid-kid',
  ),
  '1234',
).profile;

void main() {
  group('a join sends nothing private', () {
    for (final family in [false, true]) {
      test(family ? 'family group' : 'class', () {
        final learner = _learner();
        expect(learner.pinHash, isNotNull, reason: 'the device has a PIN');
        final doc = ProfileCloudFields.forJoin(learner, family: family);
        for (final field in ProfileCloudFields.private) {
          expect(doc[field], isA<FieldValue>(),
              reason: '$field may only ever be removed');
        }
        final values = doc.values.whereType<String>().toList();
        expect(values, isNot(contains(learner.pinHash)));
        expect(values, isNot(contains(learner.pinSalt)));
        expect(values.where((v) => v.startsWith('2017-05-06')), isEmpty,
            reason: 'nor the birth date under another name');
      });
    }
  });

  test('a class join names the class, a family join the group', () {
    final learner = _learner();
    final classDoc = ProfileCloudFields.forJoin(learner, family: false);
    expect(classDoc['classroom_id'], 'class-1');
    expect(classDoc.containsKey('home_group_id'), isFalse,
        reason: 'written with merge, so the family group stays as it is');
    final familyDoc = ProfileCloudFields.forJoin(learner, family: true);
    expect(familyDoc['home_group_id'], 'family-1',
        reason: "the rules find a child's parent through it");
    expect(familyDoc.containsKey('classroom_id'), isFalse);
    expect(familyDoc['owner_uid'], 'uid-kid');
  });

  test('the removals cover exactly the private fields', () {
    final removals = ProfileCloudFields.removals();
    expect(removals.keys.toSet(), ProfileCloudFields.private.toSet());
    expect(removals.values, everyElement(isA<FieldValue>()));
  });

  test('no other code writes the private fields to the cloud', () {
    final key = RegExp(
      r"""['"](pin_hash|pin_salt|pin_hash_algorithm|birth_date|grade_level)['"]\s*:""",
    );
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('profile_cloud_fields.dart') &&
            key.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
