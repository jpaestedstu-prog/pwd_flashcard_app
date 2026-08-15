import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/classroom_member.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/services/educator_inbox_assembler.dart';

/// The educator roster merge, and its stale-result guard.
///
/// Every classroom the educator owns has its own membership listener, and each
/// drives a rebuild that awaits a directory lookup — so rebuilds overlap and
/// can finish out of order. A stale result landing last would show a roster
/// that no longer exists: students from a class the teacher just left, or an
/// empty inbox for a teacher who has a full class.

const _me = 'teacher-id';

ClassroomMember _member(
  String classroomId,
  String profileId, {
  String? displayName,
}) =>
    ClassroomMember(
      classroomId: classroomId,
      profileId: profileId,
      displayName: displayName ?? profileId,
      joinedAt: DateTime(2026, 8, 10),
    );

DirectoryEntry _entry(String id, String name, UserRole role) => DirectoryEntry(
      username: '$id-0001',
      profileId: id,
      name: name,
      roleIndex: role.index,
      ownerUid: 'uid',
      updatedAt: DateTime(2026, 8, 10),
    );

final _directory = <String, DirectoryEntry>{
  'deaf': _entry('deaf', 'Deaf Student', UserRole.student),
  'motor': _entry('motor', 'Motor Student', UserRole.student),
  'anak': _entry('anak', 'Visual Anak', UserRole.child),
};

/// A lookup whose every call can be released individually, so a test can make
/// an *earlier* call finish *later* — the exact interleaving that breaks.
class _ControllableLookup {
  final List<Completer<Map<String, DirectoryEntry>>> pending = [];
  final List<Set<String>> requested = [];

  Future<Map<String, DirectoryEntry>> call(Set<String> ids) {
    requested.add(ids);
    final completer = Completer<Map<String, DirectoryEntry>>();
    pending.add(completer);
    return completer.future;
  }

  void release(int index) {
    final ids = requested[index];
    pending[index].complete({
      for (final id in ids)
        if (_directory[id] != null) id: _directory[id]!,
    });
  }
}

Future<Map<String, DirectoryEntry>> _immediateLookup(Set<String> ids) async => {
      for (final id in ids)
        if (_directory[id] != null) id: _directory[id]!,
    };

EducatorInboxAssembler _assembler({
  Future<Map<String, DirectoryEntry>> Function(Set<String>)? lookup,
}) =>
    EducatorInboxAssembler(
      myProfileId: _me,
      lookup: lookup ?? _immediateLookup,
    );

void main() {
  group('stale rebuild guard', () {
    test('a slow early rebuild cannot overwrite a newer one', () async {
      final lookup = _ControllableLookup();
      final assembler = _assembler(lookup: lookup.call);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      // The membership listener's first snapshot is empty (the query hasn't
      // resolved yet), then the real roster lands.
      unawaited(assembler.setMembers('class-a', const []));
      unawaited(assembler.setMembers('class-a', [_member('class-a', 'deaf')]));

      expect(lookup.requested, [<String>{}, {'deaf'}]);

      // Finish the NEWER one first...
      lookup.release(1);
      await pumpEventQueue();
      expect(emissions, hasLength(1));
      expect(emissions.single.map((c) => c.otherProfileId), ['deaf']);

      // ...then let the stale, empty one finish. It must be dropped, or the
      // teacher's roster blanks out a beat after loading.
      lookup.release(0);
      await pumpEventQueue();
      expect(
        emissions,
        hasLength(1),
        reason: 'the superseded rebuild must not emit',
      );
      expect(emissions.single.map((c) => c.otherProfileId), ['deaf']);
    });

    test('several classrooms racing settle on the newest roster', () async {
      // The production shape: a teacher with three classrooms, each listener
      // firing independently and resolving in an unrelated order.
      final lookup = _ControllableLookup();
      final assembler = _assembler(lookup: lookup.call);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      unawaited(assembler.setMembers('class-a', [_member('class-a', 'deaf')]));
      unawaited(assembler.setMembers('class-b', const []));
      unawaited(assembler.setMembers('class-b', [_member('class-b', 'motor')]));
      unawaited(assembler.setMembers('class-c', [_member('class-c', 'anak')]));

      expect(lookup.requested, hasLength(4));

      // Scrambled release order, newest (3) not last.
      lookup.release(3);
      await pumpEventQueue();
      lookup.release(1);
      lookup.release(0);
      lookup.release(2);
      await pumpEventQueue();

      expect(
        emissions,
        hasLength(1),
        reason: 'only the newest rebuild may emit',
      );
      expect(
        emissions.single.map((c) => c.otherProfileId).toSet(),
        {'deaf', 'motor', 'anak'},
      );
    });

    test('a rebuild in flight cannot resurrect a removed classroom', () async {
      // Leaving a classroom must stick. If the in-flight rebuild that was
      // started *before* the removal is allowed to emit, the teacher sees
      // students from a class they no longer own.
      final lookup = _ControllableLookup();
      final assembler = _assembler(lookup: lookup.call);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      unawaited(assembler.setMembers('class-a', [_member('class-a', 'deaf')]));
      unawaited(assembler.setMembers('class-b', [_member('class-b', 'motor')]));
      unawaited(assembler.removeClassroom('class-b'));

      lookup.release(2); // the post-removal rebuild
      await pumpEventQueue();
      lookup.release(0);
      lookup.release(1); // both pre-removal, both stale
      await pumpEventQueue();

      expect(emissions, hasLength(1));
      expect(
        emissions.single.map((c) => c.otherProfileId),
        ['deaf'],
        reason: 'a removed classroom must not come back',
      );
    });

    test('the guard does not suppress genuinely newer results', () async {
      // The mirror risk: a guard that is too aggressive freezes the roster.
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [_member('class-a', 'deaf')]);
      await assembler.setMembers('class-b', [_member('class-b', 'motor')]);
      await pumpEventQueue();

      expect(emissions, hasLength(2));
      expect(emissions.first.map((c) => c.otherProfileId), ['deaf']);
      expect(
        emissions.last.map((c) => c.otherProfileId).toSet(),
        {'deaf', 'motor'},
      );
    });
  });

  group('roster merge', () {
    test('the educator is never in their own roster', () async {
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [
        _member('class-a', _me, displayName: 'Sir Kevin'),
        _member('class-a', 'deaf'),
      ]);
      await pumpEventQueue();

      expect(emissions.last.map((c) => c.otherProfileId), ['deaf']);
    });

    test('a learner in two classrooms appears once', () async {
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [_member('class-a', 'deaf')]);
      await assembler.setMembers('class-b', [_member('class-b', 'deaf')]);
      await pumpEventQueue();

      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.otherProfileId, 'deaf');
    });

    test('the live directory name wins over the frozen membership row',
        () async {
      // The regression this exists for: `ClassroomMember.displayName` is
      // captured at join time, so a renamed learner showed up in the
      // educator's inbox under their old name.
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [
        _member('class-a', 'deaf', displayName: 'Hearing Student'),
      ]);
      await pumpEventQueue();

      expect(emissions.last.single.otherProfileName, 'Deaf Student');
    });

    test('an unresolved learner keeps their membership name and stays visible',
        () async {
      final assembler = _assembler(
        lookup: (_) async => const <String, DirectoryEntry>{},
      );
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [
        _member('class-a', 'ghost', displayName: 'New Learner'),
      ]);
      await pumpEventQueue();

      expect(emissions.last.single.otherProfileName, 'New Learner');
      expect(emissions.last.single.otherProfileRole, 'student');
    });

    test('a child learner keeps their own role, not a hardcoded student',
        () async {
      // Parents run this path too, and their roster is Children — the role
      // drives the row's avatar emoji.
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('group-a', [_member('group-a', 'anak')]);
      await pumpEventQueue();

      expect(emissions.last.single.otherProfileRole, 'child');
    });

    test('the roster is sorted by display name', () async {
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [
        _member('class-a', 'motor'),
        _member('class-a', 'anak'),
        _member('class-a', 'deaf'),
      ]);
      await pumpEventQueue();

      expect(
        emissions.last.map((c) => c.otherProfileName),
        ['Deaf Student', 'Motor Student', 'Visual Anak'],
      );
    });

    test('removing an untracked classroom does not churn the inbox', () async {
      // A redundant cloud snapshot must not re-emit — the messaging screen
      // rebuilds its conversation list on every emission.
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [_member('class-a', 'deaf')]);
      await assembler.removeClassroom('never-owned');
      await pumpEventQueue();

      expect(emissions, hasLength(1));
    });

    test('classroomIds tracks what is contributing to the roster', () async {
      // The service drives its "which classrooms went stale?" diff off this.
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      await assembler.setMembers('class-a', const []);
      await assembler.setMembers('class-b', const []);
      expect(assembler.classroomIds, {'class-a', 'class-b'});

      await assembler.removeClassroom('class-a');
      expect(assembler.classroomIds, {'class-b'});
    });

    test('emptying every classroom empties the roster', () async {
      final assembler = _assembler();
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setMembers('class-a', [_member('class-a', 'deaf')]);
      await assembler.setMembers('class-a', const []);
      await pumpEventQueue();

      expect(emissions.last, isEmpty);
    });
  });
}
