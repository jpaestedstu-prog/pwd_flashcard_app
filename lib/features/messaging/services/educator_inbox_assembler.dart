import 'dart:async';

import '../../../data/models/classroom_member.dart';
import '../../../data/models/home_group_member.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import 'learner_inbox_assembler.dart' show roleSlugFromIndex;

/// Assembles an educator's inbox from the membership rows of every classroom
/// and home group they own.
///
/// The counterpart to [LearnerInboxAssembler], extracted for the same reason:
/// every group has its own membership listener, and each one drives a
/// rebuild that awaits a directory lookup, so rebuilds overlap and can finish
/// out of order. A stale result landing last would show a roster that no
/// longer exists — students from a classroom the educator just left, or an
/// empty inbox for a teacher who has 30 learners.
///
/// Membership is held per group so one group's emission can update its own
/// slice without resetting the others. Classrooms (a teacher's) and home
/// groups (a parent's) are kept apart: they live in different collections,
/// and a parent's inbox used to read only the classroom side — so it was
/// always empty, however many children had joined the family group.
class EducatorInboxAssembler {
  EducatorInboxAssembler({required this.myProfileId, required this.lookup});

  /// The educator's own profile id, excluded from their own roster.
  final String myProfileId;

  /// Resolves profile ids to directory entries. Injected so tests can control
  /// completion order (production passes `ProfileDirectoryService.lookupMany`).
  final Future<Map<String, DirectoryEntry>> Function(Set<String>) lookup;

  final _controller = StreamController<List<Conversation>>.broadcast();
  final _byClassroom = <String, List<_Member>>{};
  final _byHomeGroup = <String, List<_Member>>{};
  final _groupNames = <String, String>{};

  /// Monotonic run counter. A rebuild whose number is no longer the newest
  /// drops its result instead of emitting it.
  var _generation = 0;

  Stream<List<Conversation>> get stream => _controller.stream;

  /// Replace the membership rows for one classroom.
  Future<void> setMembers(String classroomId, List<ClassroomMember> members) {
    _byClassroom[classroomId] = [
      for (final m in members)
        _Member(profileId: m.profileId, displayName: m.displayName),
    ];
    return _rebuild();
  }

  /// Replace the membership rows for one home group.
  Future<void> setHomeGroupMembers(
    String homeGroupId,
    List<HomeGroupMember> members,
  ) {
    _byHomeGroup[homeGroupId] = [
      for (final m in members)
        _Member(profileId: m.profileId, displayName: m.displayName),
    ];
    return _rebuild();
  }

  /// Name the classes / home groups, for the inbox's group filter. Rebuilds
  /// only when a name actually changed, so a repeated snapshot is free.
  Future<void> setGroupNames(Map<String, String> names) {
    var changed = false;
    for (final entry in names.entries) {
      if (_groupNames[entry.key] != entry.value) {
        _groupNames[entry.key] = entry.value;
        changed = true;
      }
    }
    return changed ? _rebuild() : Future.value();
  }

  /// Drop a classroom the educator no longer owns. No-ops (without emitting)
  /// when the classroom wasn't tracked, so a redundant cloud snapshot doesn't
  /// churn the inbox.
  Future<void> removeClassroom(String classroomId) {
    if (_byClassroom.remove(classroomId) == null) return Future.value();
    return _rebuild();
  }

  /// Drop a home group the educator no longer owns. Same no-op rule as
  /// [removeClassroom].
  Future<void> removeHomeGroup(String homeGroupId) {
    if (_byHomeGroup.remove(homeGroupId) == null) return Future.value();
    return _rebuild();
  }

  /// The classrooms currently contributing to the roster.
  Set<String> get classroomIds => _byClassroom.keys.toSet();

  /// The home groups currently contributing to the roster.
  Set<String> get homeGroupIds => _byHomeGroup.keys.toSet();

  Future<void> _rebuild() async {
    final mine = ++_generation;

    // Dedupe by profile id — a learner enrolled in two of this educator's
    // groups belongs in the inbox once, tagged with both.
    final order = <String>[];
    final fallbackName = <String, String>{};
    final groupsOf = <String, List<InboxGroup>>{};

    void collect(Map<String, List<_Member>> source, bool isHomeGroup) {
      for (final entry in source.entries) {
        final group = InboxGroup(
          id: entry.key,
          name: _groupNames[entry.key] ?? '',
          isHomeGroup: isHomeGroup,
        );
        for (final m in entry.value) {
          if (m.profileId == myProfileId || m.profileId.isEmpty) continue;
          if (!groupsOf.containsKey(m.profileId)) {
            order.add(m.profileId);
            fallbackName[m.profileId] = m.displayName;
            groupsOf[m.profileId] = [];
          }
          groupsOf[m.profileId]!.add(group);
        }
      }
    }

    collect(_byClassroom, false);
    collect(_byHomeGroup, true);

    // `displayName` on a membership row is frozen at join time, so a learner
    // who was later renamed showed up under their old name (a "Deaf Student"
    // listed as "Hearing Student"). The directory carries the live name; the
    // membership row is only the fallback for a learner who has no directory
    // entry yet.
    final resolved = await lookup(order.toSet());
    if (mine != _generation) return;

    final convos = <Conversation>[];
    for (final id in order) {
      final entry = resolved[id];
      final name = (entry != null && entry.name.isNotEmpty)
          ? entry.name
          : fallbackName[id] ?? '';
      convos.add(
        Conversation(
          otherProfileId: id,
          otherProfileName: name,
          otherProfileRole: entry != null
              ? roleSlugFromIndex(entry.roleIndex)
              : (groupsOf[id]!.every((g) => g.isHomeGroup)
                    ? 'child'
                    : 'student'),
          otherDisabilityIndex: entry?.disabilityIndex,
          groups: List.unmodifiable(groupsOf[id]!),
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

/// One membership row, whichever collection it came from.
class _Member {
  final String profileId;
  final String displayName;
  const _Member({required this.profileId, required this.displayName});
}
