import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/classroom_member.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/messaging_models.dart';
import 'educator_inbox_assembler.dart';
import 'friend_service.dart';
import 'learner_inbox_assembler.dart';
import 'profile_directory_service.dart';

/// Source-of-truth for the messaging inbox. Replaces the old
/// `HiveService.getAllProfiles()` approach (which only saw profiles
/// created on the same device) with role-aware queries against:
///
///   * Student/Child: accepted [Friendship]s plus the teacher of any
///     classroom they've joined.
///   * Teacher/Parent: every student enrolled in classrooms the
///     educator owns, sourced from `classroom_members`.
///
/// The returned [Conversation]s are skeletons — `messages` is empty.
/// The messaging screen attaches messages from its own Firestore stream.
class ConversationDirectoryService {
  ConversationDirectoryService._();

  static final ConversationDirectoryService instance =
      ConversationDirectoryService._();

  /// Watch the conversation peer list for [me]. Emits whenever the
  /// underlying friends list, classroom roster, or classroom membership
  /// changes.
  Stream<List<Conversation>> watch(UserProfile me) {
    // Friends-based inbox for learners with a cloud identity: Students,
    // Children, and "Player (With Progress)". Educators (Teacher/Parent) use
    // their classroom roster instead. A progress player simply has no
    // classroom, so the student path resolves to just their friends list.
    final usesFriends =
        me.role == UserRole.student ||
        me.role == UserRole.child ||
        (me.role == UserRole.player && !me.isGuestPlayer);
    return usesFriends ? _watchForLearner(me) : _watchForEducator(me);
  }

  // ─── Learner (Student / Child / Player-with-Progress) ─

  Stream<List<Conversation>> _watchForLearner(UserProfile me) {
    // The merge (and its stale-result guard) lives in [LearnerInboxAssembler];
    // this method is only the Firebase wiring that feeds it.
    final assembler = LearnerInboxAssembler(
      lookup: ProfileDirectoryService.instance.lookupMany,
    );

    final friendsSub = FriendService.instance.watchFriends(me.id).listen((
      list,
    ) {
      // ignore: discarded_futures
      assembler.setFriends(list.map((f) => f.otherProfileFor(me.id)).toList());
    });

    // Teacher of joined classroom — only when the student has joined one.
    StreamSubscription? teachersSub;
    if (FirebaseService.isConfigured && me.classroomId != null) {
      teachersSub = FirebaseService.db
          .collection('classrooms')
          .doc(me.classroomId)
          .snapshots()
          .listen(
            (snap) {
              final teacherId = snap.data()?['teacher_id'] as String?;
              // ignore: discarded_futures
              assembler.setTeachers(
                (teacherId != null && teacherId.isNotEmpty)
                    ? <String>[teacherId]
                    : const <String>[],
              );
            },
            onError: (e, st) {
              ErrorHandler.report(
                e,
                st,
                'ConversationDirectoryService.studentTeacher',
              );
            },
          );
    }

    final blockedSub = FriendService.instance.watchBlocked(me.id).listen((ids) {
      // ignore: discarded_futures
      assembler.setBlocked(ids);
    });

    // Forward the assembler's output through a controller we own, so
    // cancelling the returned stream also tears down the three source
    // subscriptions and closes the assembler.
    final out = StreamController<List<Conversation>>.broadcast();
    final innerSub = assembler.stream.listen(out.add, onError: out.addError);
    out.onCancel = () async {
      await innerSub.cancel();
      await friendsSub.cancel();
      await teachersSub?.cancel();
      await blockedSub.cancel();
      await assembler.dispose();
    };
    return out.stream;
  }

  // ─── Teacher / Parent ─────────────────────────────────

  Stream<List<Conversation>> _watchForEducator(UserProfile me) {
    // The merge (and its stale-result guard) lives in
    // [EducatorInboxAssembler]; this method is only the Firebase wiring.
    final assembler = EducatorInboxAssembler(
      myProfileId: me.id,
      lookup: ProfileDirectoryService.instance.lookupMany,
    );
    final memberSubs = <String, StreamSubscription>{};

    void subscribeToClassroom(String classroomId) {
      if (memberSubs.containsKey(classroomId)) return;
      // Seed from Hive so the inbox renders even before the first cloud
      // emission lands.
      // ignore: discarded_futures
      assembler.setMembers(classroomId, HiveService.getMembers(classroomId));

      if (!FirebaseService.isConfigured) return;
      memberSubs[classroomId] = FirebaseService.db
          .collection('classroom_members')
          .where('classroom_id', isEqualTo: classroomId)
          .snapshots()
          .listen(
            (snap) {
              // ignore: discarded_futures
              assembler.setMembers(
                classroomId,
                snap.docs
                    .map(
                      (d) => ClassroomMember.fromJson(
                        Map<String, dynamic>.from(d.data()),
                      ),
                    )
                    .toList(),
              );
            },
            onError: (e, st) {
              ErrorHandler.report(
                e,
                st,
                'ConversationDirectoryService.classroomMembers',
              );
            },
          );
    }

    void unsubscribeFromClassroom(String classroomId) {
      memberSubs.remove(classroomId)?.cancel();
      // ignore: discarded_futures
      assembler.removeClassroom(classroomId);
    }

    // Seed classrooms from Hive immediately (offline-friendly) then
    // attach the Firestore stream.
    final cachedClassrooms = HiveService.getClassroomsByTeacher(me.id);
    for (final c in cachedClassrooms) {
      subscribeToClassroom(c.id);
    }

    StreamSubscription? classroomsSub;
    if (FirebaseService.isConfigured) {
      classroomsSub = FirebaseService.db
          .collection('classrooms')
          .where('teacher_id', isEqualTo: me.id)
          .snapshots()
          .listen(
            (snap) {
              final ids = snap.docs.map((d) => d.id).toSet();
              // Add new classrooms.
              for (final id in ids) {
                subscribeToClassroom(id);
              }
              // Remove dropped ones. Driven off the assembler's own classroom set
              // rather than `memberSubs`, which is empty when Firebase isn't
              // configured — a Hive-seeded classroom would otherwise never leave
              // the roster after the educator stopped owning it.
              final stale = assembler.classroomIds
                  .where((k) => !ids.contains(k))
                  .toList();
              for (final id in stale) {
                unsubscribeFromClassroom(id);
              }
            },
            onError: (e, st) {
              ErrorHandler.report(
                e,
                st,
                'ConversationDirectoryService.educatorClassrooms',
              );
            },
          );
    }

    // Forward through a controller we own, so cancelling the returned stream
    // tears down every membership subscription and closes the assembler.
    final out = StreamController<List<Conversation>>.broadcast();
    final innerSub = assembler.stream.listen(out.add, onError: out.addError);
    out.onCancel = () async {
      await innerSub.cancel();
      for (final sub in memberSubs.values) {
        await sub.cancel();
      }
      memberSubs.clear();
      await classroomsSub?.cancel();
      await assembler.dispose();
    };
    return out.stream;
  }

  // ─── Helpers ──────────────────────────────────────────

  /// Single implementation lives with the assembler so the two paths can
  /// never disagree about what counts as a teacher.
  String _roleSlug(int idx) => roleSlugFromIndex(idx);

  /// Debug aid — used in tests / dev logging.
  @visibleForTesting
  static String roleSlugForTesting(int idx) => instance._roleSlug(idx);
}
