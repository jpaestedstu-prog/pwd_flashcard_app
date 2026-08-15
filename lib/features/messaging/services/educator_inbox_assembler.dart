import 'dart:async';

import '../../../data/models/classroom_member.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import 'learner_inbox_assembler.dart' show roleSlugFromIndex;

/// Assembles an educator's inbox from the membership rows of every classroom
/// (or home group) they own.
///
/// The counterpart to [LearnerInboxAssembler], extracted for the same reason:
/// every classroom has its own membership listener, and each one drives a
/// rebuild that awaits a directory lookup, so rebuilds overlap and can finish
/// out of order. A stale result landing last would show a roster that no
/// longer exists — students from a classroom the educator just left, or an
/// empty inbox for a teacher who has 30 learners.
///
/// Membership is held per classroom so one classroom's emission can update its
/// own slice without resetting the others.
class EducatorInboxAssembler {
  EducatorInboxAssembler({required this.myProfileId, required this.lookup});

  /// The educator's own profile id, excluded from their own roster.
  final String myProfileId;

  /// Resolves profile ids to directory entries. Injected so tests can control
  /// completion order (production passes `ProfileDirectoryService.lookupMany`).
  final Future<Map<String, DirectoryEntry>> Function(Set<String>) lookup;

  final _controller = StreamController<List<Conversation>>.broadcast();
  final _byClassroom = <String, List<ClassroomMember>>{};

  /// Monotonic run counter. A rebuild whose number is no longer the newest
  /// drops its result instead of emitting it.
  var _generation = 0;

  Stream<List<Conversation>> get stream => _controller.stream;

  /// Replace the membership rows for one classroom.
  Future<void> setMembers(String classroomId, List<ClassroomMember> members) {
    _byClassroom[classroomId] = members;
    return _rebuild();
  }

  /// Drop a classroom the educator no longer owns. No-ops (without emitting)
  /// when the classroom wasn't tracked, so a redundant cloud snapshot doesn't
  /// churn the inbox.
  Future<void> removeClassroom(String classroomId) {
    if (_byClassroom.remove(classroomId) == null) return Future.value();
    return _rebuild();
  }

  /// The classrooms currently contributing to the roster.
  Set<String> get classroomIds => _byClassroom.keys.toSet();

  Future<void> _rebuild() async {
    final mine = ++_generation;

    // Dedupe by profile_id — a learner enrolled in two of this educator's
    // classrooms belongs in the inbox once.
    final seen = <String>{};
    final members = <ClassroomMember>[];
    for (final roster in _byClassroom.values) {
      for (final m in roster) {
        if (m.profileId == myProfileId) continue;
        if (!seen.add(m.profileId)) continue;
        members.add(m);
      }
    }

    // `ClassroomMember.displayName` is frozen at join time, so a learner who
    // was later renamed showed up under their old name (a "Deaf Student"
    // listed as "Hearing Student"). The directory carries the live name; the
    // membership row is only the fallback for a learner who has no directory
    // entry yet.
    final resolved = await lookup(members.map((m) => m.profileId).toSet());
    if (mine != _generation) return;

    final convos = <Conversation>[];
    for (final m in members) {
      final entry = resolved[m.profileId];
      final name = (entry != null && entry.name.isNotEmpty)
          ? entry.name
          : m.displayName;
      convos.add(
        Conversation(
          otherProfileId: m.profileId,
          otherProfileName: name,
          otherProfileRole: entry != null
              ? roleSlugFromIndex(entry.roleIndex)
              : 'student',
        ),
      );
    }
    convos.sort(
      (a, b) => a.otherProfileName.toLowerCase().compareTo(
        b.otherProfileName.toLowerCase(),
      ),
    );

    if (!_controller.isClosed) _controller.add(convos);
  }

  Future<void> dispose() => _controller.close();
}
