import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/parent_teacher_notes/services/notes_cloud_service.dart';

/// The proof a teacher's or parent's device names when it files itself as a
/// reader of a learner's notes: one of its own classes or home groups that
/// the learner joined. The rule checks the same membership document, so the
/// app must name one that exists (tool/trust_rules_emulator_test.py).
void main() {
  Future<({String? classroomId, String? homeGroupId})?> find(
    Set<String> memberships, {
    List<String> classes = const [],
    List<String> groups = const [],
  }) {
    return findNoteReaderVia(
      studentId: 'pS',
      classroomIds: classes,
      homeGroupIds: groups,
      exists: (path) async => memberships.contains(path),
    );
  }

  test('names the class the learner joined', () async {
    final via = await find(
      {'classroom_members/c2_pS'},
      classes: ['c1', 'c2'],
    );
    expect(via, (classroomId: 'c2', homeGroupId: null));
  });

  test('names the home group when the learner is in no class of theirs',
      () async {
    final via = await find(
      {'home_group_members/g1_pS'},
      classes: ['c1'],
      groups: ['g1'],
    );
    expect(via, (classroomId: null, homeGroupId: 'g1'));
  });

  test('prefers a class when the learner is in both', () async {
    final via = await find(
      {'classroom_members/c1_pS', 'home_group_members/g1_pS'},
      classes: ['c1'],
      groups: ['g1'],
    );
    expect(via?.classroomId, 'c1');
  });

  test('names nothing for a learner who joined none of them', () async {
    final via = await find(
      {'classroom_members/c9_pS', 'home_group_members/g1_pOther'},
      classes: ['c1'],
      groups: ['g1'],
    );
    expect(via, isNull);
  });

  test('looks up exactly the membership ids the rules check', () async {
    final asked = <String>[];
    await findNoteReaderVia(
      studentId: 'pS',
      classroomIds: ['c1'],
      homeGroupIds: ['g1'],
      exists: (path) async {
        asked.add(path);
        return false;
      },
    );
    expect(asked, ['classroom_members/c1_pS', 'home_group_members/g1_pS']);
  });
}
