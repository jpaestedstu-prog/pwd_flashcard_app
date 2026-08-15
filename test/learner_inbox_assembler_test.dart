import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/services/learner_inbox_assembler.dart';

/// The learner inbox merge, and specifically its stale-result guard.
///
/// Three independent sources (friends, classroom teacher, blocks) each kick
/// off a rebuild that awaits a directory lookup, so rebuilds overlap and can
/// finish out of order. Before the guard, a stale rebuild landing last wiped
/// the inbox — on device the teacher and friends vanished a beat after the
/// screen loaded, and the teacher reappeared through the messages fallback
/// under the wrong role.

const _teacher = 'teacher-id';
const _friend = 'friend-id';

DirectoryEntry _entry(String id, String name, UserRole role) => DirectoryEntry(
      username: '$name-0001',
      profileId: id,
      name: name,
      roleIndex: role.index,
      ownerUid: 'uid',
      updatedAt: DateTime(2026, 8, 10),
    );

final _directory = <String, DirectoryEntry>{
  _teacher: _entry(_teacher, 'Sir Kevin', UserRole.teacher),
  _friend: _entry(_friend, 'Player Friendly', UserRole.player),
};

/// A lookup whose every call can be released individually, so a test can make
/// an *earlier* call finish *later* — the exact interleaving that broke.
class _ControllableLookup {
  final List<Completer<Map<String, DirectoryEntry>>> pending = [];
  final List<Set<String>> requested = [];

  Future<Map<String, DirectoryEntry>> call(Set<String> ids) {
    requested.add(ids);
    final completer = Completer<Map<String, DirectoryEntry>>();
    pending.add(completer);
    return completer.future;
  }

  /// Release the call at [index] with the entries that actually resolve.
  void release(int index) {
    final ids = requested[index];
    pending[index].complete({
      for (final id in ids)
        if (_directory[id] != null) id: _directory[id]!,
    });
  }
}

/// Resolves immediately — for the tests that only care about merge output.
Future<Map<String, DirectoryEntry>> _immediateLookup(Set<String> ids) async => {
      for (final id in ids)
        if (_directory[id] != null) id: _directory[id]!,
    };

void main() {
  group('stale rebuild guard', () {
    test('a slow early rebuild cannot overwrite a newer one', () async {
      final lookup = _ControllableLookup();
      final assembler = LearnerInboxAssembler(lookup: lookup.call);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      // Rebuild #1: the friends stream's first emission is empty (its second
      // underlying query hasn't landed yet), so this run resolves to nobody.
      unawaited(assembler.setFriends(const []));
      // Rebuild #2: the real friend list arrives.
      unawaited(assembler.setFriends(const [_friend]));

      expect(lookup.requested, [<String>{}, {_friend}]);

      // Finish the NEWER one first...
      lookup.release(1);
      await pumpEventQueue();
      expect(emissions, hasLength(1));
      expect(emissions.single.map((c) => c.otherProfileId), [_friend]);

      // ...then let the stale, empty one finish. It must be dropped.
      lookup.release(0);
      await pumpEventQueue();
      expect(
        emissions,
        hasLength(1),
        reason: 'the superseded rebuild must not emit',
      );
      expect(emissions.single.map((c) => c.otherProfileId), [_friend]);
    });

    test('three interleaved sources settle on the newest state', () async {
      // The production shape: friends, teacher, and blocks all fire, and the
      // lookups come back in an order unrelated to how they were started.
      final lookup = _ControllableLookup();
      final assembler = LearnerInboxAssembler(lookup: lookup.call);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      unawaited(assembler.setFriends(const []));
      unawaited(assembler.setTeachers(const [_teacher]));
      unawaited(assembler.setFriends(const [_friend]));
      unawaited(assembler.setBlocked(const {}));

      expect(lookup.requested, hasLength(4));

      // Release in a deliberately scrambled order, newest (3) not last.
      lookup.release(3);
      await pumpEventQueue();
      lookup.release(0);
      lookup.release(2);
      lookup.release(1);
      await pumpEventQueue();

      expect(
        emissions,
        hasLength(1),
        reason: 'only the newest rebuild may emit',
      );
      expect(
        emissions.single.map((c) => c.otherProfileId).toSet(),
        {_teacher, _friend},
      );
    });

    test('the guard does not suppress genuinely newer results', () async {
      // The mirror risk: a guard that is too aggressive would freeze the
      // inbox. Sequential rebuilds must each emit.
      final assembler = LearnerInboxAssembler(lookup: _immediateLookup);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setFriends(const [_friend]);
      await assembler.setTeachers(const [_teacher]);
      await pumpEventQueue();

      expect(emissions, hasLength(2));
      expect(emissions.first.map((c) => c.otherProfileId), [_friend]);
      expect(
        emissions.last.map((c) => c.otherProfileId).toSet(),
        {_teacher, _friend},
      );
    });
  });

  group('merge output', () {
    test('teachers sort above friends', () async {
      final assembler = LearnerInboxAssembler(lookup: _immediateLookup);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setFriends(const [_friend]);
      await assembler.setTeachers(const [_teacher]);
      await pumpEventQueue();

      final latest = emissions.last;
      expect(latest.first.otherProfileId, _teacher);
      expect(latest.first.otherProfileRole, 'teacher');
      expect(latest.last.otherProfileId, _friend);
    });

    test('a blocked peer is removed from the inbox', () async {
      final assembler = LearnerInboxAssembler(lookup: _immediateLookup);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setFriends(const [_friend]);
      await assembler.setTeachers(const [_teacher]);
      await assembler.setBlocked(const {_friend});
      await pumpEventQueue();

      expect(
        emissions.last.map((c) => c.otherProfileId),
        [_teacher],
        reason: 'blocking must take effect locally, at once',
      );
    });

    test('unblocking brings the peer back', () async {
      final assembler = LearnerInboxAssembler(lookup: _immediateLookup);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setFriends(const [_friend]);
      await assembler.setBlocked(const {_friend});
      await assembler.setBlocked(const {});
      await pumpEventQueue();

      expect(emissions.last.map((c) => c.otherProfileId), [_friend]);
    });

    test('an unresolvable peer stays visible, with the right role', () async {
      // A peer whose directory entry hasn't propagated must not disappear —
      // and a teacher must not be mislabelled a student, because the role
      // drives both the sort order and the row's avatar.
      final assembler = LearnerInboxAssembler(
        lookup: (_) async => const <String, DirectoryEntry>{},
      );
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setTeachers(const [_teacher]);
      await assembler.setFriends(const ['ghost']);
      await pumpEventQueue();

      final latest = emissions.last;
      expect(latest, hasLength(2));
      expect(
        latest.firstWhere((c) => c.otherProfileId == _teacher)
            .otherProfileRole,
        'teacher',
      );
      expect(
        latest.firstWhere((c) => c.otherProfileId == 'ghost')
            .otherProfileRole,
        'student',
      );
    });

    test('a peer who is both friend and teacher appears once', () async {
      final assembler = LearnerInboxAssembler(lookup: _immediateLookup);
      addTearDown(assembler.dispose);

      final emissions = <List<Conversation>>[];
      assembler.stream.listen(emissions.add);

      await assembler.setFriends(const [_teacher]);
      await assembler.setTeachers(const [_teacher]);
      await pumpEventQueue();

      expect(emissions.last, hasLength(1));
    });
  });

  group('role slugs', () {
    test('map every role, and fall back for out-of-range indexes', () {
      expect(roleSlugFromIndex(UserRole.teacher.index), 'teacher');
      expect(roleSlugFromIndex(UserRole.parent.index), 'parent');
      expect(roleSlugFromIndex(UserRole.child.index), 'child');
      expect(roleSlugFromIndex(UserRole.player.index), 'player');
      expect(roleSlugFromIndex(UserRole.student.index), 'student');
      // Forward-compat: a role index this build doesn't know must not throw.
      expect(roleSlugFromIndex(-1), 'student');
      expect(roleSlugFromIndex(999), 'student');
    });
  });
}
