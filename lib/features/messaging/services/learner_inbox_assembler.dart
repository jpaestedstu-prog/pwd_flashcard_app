import 'dart:async';

import '../../../data/models/enums.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';

/// Turns a [UserRole] index into the lowercase slug [Conversation] carries.
///
/// Shared so the directory service and the assembler can never disagree about
/// what counts as a teacher — the role slug drives both the inbox sort order
/// and the row's avatar emoji.
String roleSlugFromIndex(int idx) {
  if (idx < 0 || idx >= UserRole.values.length) return 'student';
  switch (UserRole.values[idx]) {
    case UserRole.teacher:
      return 'teacher';
    case UserRole.parent:
      return 'parent';
    case UserRole.child:
      return 'child';
    case UserRole.player:
      return 'player';
    case UserRole.student:
      return 'student';
  }
}

/// Assembles a learner's inbox peer list from three independent sources:
/// their accepted friendships, the teacher of any classroom they've joined,
/// and the set of profiles they've blocked.
///
/// Extracted from `ConversationDirectoryService` so the merge — and in
/// particular its **stale-result guard** — can be driven directly in tests
/// with a controllable [lookup]. The service keeps the Firebase wiring; this
/// class owns the logic that actually broke.
///
/// **Why the guard exists.** Every source drives [_rebuild], which awaits a
/// directory lookup in the middle. Three listeners means three rebuilds can be
/// in flight at once, and they can finish in any order. The friends stream in
/// particular emits an empty list before its second underlying query lands, so
/// the *stale* result is usually the empty one — and without the guard it
/// would land last and blank the entire inbox. On device that looked like
/// peers vanishing a beat after the screen loaded, with the teacher
/// reappearing through the messages-based fallback under the wrong role.
class LearnerInboxAssembler {
  LearnerInboxAssembler({required this.lookup});

  /// Resolves profile ids to directory entries. Injected so tests can control
  /// completion order (production passes `ProfileDirectoryService.lookupMany`).
  final Future<Map<String, DirectoryEntry>> Function(Set<String>) lookup;

  final _controller = StreamController<List<Conversation>>.broadcast();

  List<String> _friendIds = const [];
  List<String> _teacherIds = const [];
  Set<String> _blockedIds = const {};

  /// Monotonic run counter. A rebuild whose number is no longer the newest
  /// drops its result instead of emitting it.
  var _generation = 0;

  Stream<List<Conversation>> get stream => _controller.stream;

  /// The generation guard's counter, for assertions in tests.
  int get generationForTesting => _generation;

  Future<void> setFriends(List<String> ids) {
    _friendIds = ids;
    return _rebuild();
  }

  Future<void> setTeachers(List<String> ids) {
    _teacherIds = ids;
    return _rebuild();
  }

  Future<void> setBlocked(Set<String> ids) {
    _blockedIds = ids;
    return _rebuild();
  }

  Future<void> _rebuild() async {
    final mine = ++_generation;

    // Blocked peers drop out of the inbox even if the friendship delete hasn't
    // propagated yet — the block is the learner's safeguarding switch, so it
    // must take effect on this device immediately.
    final allIds = <String>{..._friendIds, ..._teacherIds}
      ..removeWhere(_blockedIds.contains);

    final resolved = await lookup(allIds);
    if (mine != _generation) return;

    final teacherIds = _teacherIds;
    final convos = <Conversation>[];
    for (final id in allIds) {
      final entry = resolved[id];
      if (entry == null) {
        // Best-effort fallback: keep the peer visible with a generic label so
        // the user can still tap through and chat.
        convos.add(
          Conversation(
            otherProfileId: id,
            otherProfileName: 'User',
            otherProfileRole: teacherIds.contains(id) ? 'teacher' : 'student',
          ),
        );
      } else {
        convos.add(
          Conversation(
            otherProfileId: entry.profileId,
            otherProfileName: entry.name,
            otherProfileRole: roleSlugFromIndex(entry.roleIndex),
          ),
        );
      }
    }

    // Teachers first, then friends sorted alphabetically — stable order so the
    // inbox doesn't shuffle on every emission.
    convos.sort((a, b) {
      final aTeacher =
          a.otherProfileRole == 'teacher' || a.otherProfileRole == 'parent';
      final bTeacher =
          b.otherProfileRole == 'teacher' || b.otherProfileRole == 'parent';
      if (aTeacher != bTeacher) return aTeacher ? -1 : 1;
      return a.otherProfileName.toLowerCase().compareTo(
        b.otherProfileName.toLowerCase(),
      );
    });

    if (!_controller.isClosed) _controller.add(convos);
  }

  Future<void> dispose() => _controller.close();
}
