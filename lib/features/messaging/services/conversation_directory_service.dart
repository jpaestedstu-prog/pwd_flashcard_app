import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/classroom_member.dart';
import '../../../data/models/home_group_member.dart';
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
///     classroom they've joined and the parent of any home group they've
///     joined.
///   * Teacher/Parent: every learner enrolled in the classrooms and home
///     groups the educator owns, sourced from `classroom_members` and
///     `home_group_members`.
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

    // Seed the grown-ups from Hive so an offline inbox still lists them; the
    // live documents below replace these as soon as they land.
    final cachedTeacher = _cached(
      () => HiveService.getCachedClassroom(me.classroomId!)?.teacherId,
      when: me.classroomId != null,
    );
    if (cachedTeacher != null) {
      // ignore: discarded_futures
      assembler.setTeachers([cachedTeacher]);
    }
    final cachedOwner = _cached(
      () => HiveService.getCachedHomeGroup(me.homeGroupId!)?.ownerProfileId,
      when: me.homeGroupId != null,
    );
    if (cachedOwner != null) {
      // ignore: discarded_futures
      assembler.setGroupOwners([cachedOwner]);
    }

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

    // Parent of the joined home group. Without this leg a Child's inbox never
    // listed the parent who enrolled them.
    StreamSubscription? ownersSub;
    if (FirebaseService.isConfigured && me.homeGroupId != null) {
      ownersSub = FirebaseService.db
          .collection('home_groups')
          .doc(me.homeGroupId)
          .snapshots()
          .listen(
            (snap) {
              final ownerId = snap.data()?['owner_profile_id'] as String?;
              // ignore: discarded_futures
              assembler.setGroupOwners(
                (ownerId != null && ownerId.isNotEmpty)
                    ? <String>[ownerId]
                    : const <String>[],
              );
            },
            onError: (e, st) {
              ErrorHandler.report(
                e,
                st,
                'ConversationDirectoryService.childParent',
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
      await ownersSub?.cancel();
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
    final groupMemberSubs = <String, StreamSubscription>{};

    void subscribeToClassroom(String classroomId) {
      if (memberSubs.containsKey(classroomId)) return;
      // Seed from Hive so the inbox renders even before the first cloud
      // emission lands.
      // ignore: discarded_futures
      assembler.setMembers(
        classroomId,
        _cached(() => HiveService.getMembers(classroomId)) ?? const [],
      );

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

    // A parent's home groups — the family side, which the inbox used to skip
    // entirely, so a parent's Messages was always empty.
    void subscribeToHomeGroup(String groupId) {
      if (groupMemberSubs.containsKey(groupId)) return;
      // ignore: discarded_futures
      assembler.setHomeGroupMembers(
        groupId,
        _cached(() => HiveService.getHomeGroupMembers(groupId)) ?? const [],
      );

      if (!FirebaseService.isConfigured) return;
      groupMemberSubs[groupId] = FirebaseService.db
          .collection('home_group_members')
          .where('home_group_id', isEqualTo: groupId)
          .snapshots()
          .listen(
            (snap) {
              // ignore: discarded_futures
              assembler.setHomeGroupMembers(
                groupId,
                snap.docs
                    .map(
                      (d) => HomeGroupMember.fromJson(
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
                'ConversationDirectoryService.homeGroupMembers',
              );
            },
          );
    }

    void unsubscribeFromHomeGroup(String groupId) {
      groupMemberSubs.remove(groupId)?.cancel();
      // ignore: discarded_futures
      assembler.removeHomeGroup(groupId);
    }

    // Seed classrooms and home groups from Hive immediately (offline-friendly)
    // then attach the Firestore streams.
    final cachedClassrooms =
        _cached(() => HiveService.getClassroomsByTeacher(me.id)) ?? const [];
    // ignore: discarded_futures
    assembler.setGroupNames({for (final c in cachedClassrooms) c.id: c.name});
    for (final c in cachedClassrooms) {
      subscribeToClassroom(c.id);
    }
    final cachedGroups =
        _cached(() => HiveService.getHomeGroupsByOwner(me.id)) ?? const [];
    // ignore: discarded_futures
    assembler.setGroupNames({for (final g in cachedGroups) g.id: g.name});
    for (final g in cachedGroups) {
      subscribeToHomeGroup(g.id);
    }

    StreamSubscription? classroomsSub;
    StreamSubscription? homeGroupsSub;
    if (FirebaseService.isConfigured) {
      classroomsSub = FirebaseService.db
          .collection('classrooms')
          .where('teacher_id', isEqualTo: me.id)
          .snapshots()
          .listen(
            (snap) {
              final ids = snap.docs.map((d) => d.id).toSet();
              // ignore: discarded_futures
              assembler.setGroupNames({
                for (final d in snap.docs)
                  d.id: (d.data()['name'] as String?) ?? '',
              });
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
      homeGroupsSub = FirebaseService.db
          .collection('home_groups')
          .where('owner_profile_id', isEqualTo: me.id)
          .snapshots()
          .listen(
            (snap) {
              final ids = snap.docs.map((d) => d.id).toSet();
              // ignore: discarded_futures
              assembler.setGroupNames({
                for (final d in snap.docs)
                  d.id: (d.data()['name'] as String?) ?? '',
              });
              for (final id in ids) {
                subscribeToHomeGroup(id);
              }
              final stale = assembler.homeGroupIds
                  .where((k) => !ids.contains(k))
                  .toList();
              for (final id in stale) {
                unsubscribeFromHomeGroup(id);
              }
            },
            onError: (e, st) {
              ErrorHandler.report(
                e,
                st,
                'ConversationDirectoryService.educatorHomeGroups',
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
      for (final sub in [...memberSubs.values, ...groupMemberSubs.values]) {
        await sub.cancel();
      }
      memberSubs.clear();
      groupMemberSubs.clear();
      await classroomsSub?.cancel();
      await homeGroupsSub?.cancel();
      await assembler.dispose();
    };
    return out.stream;
  }

  // ─── Helpers ──────────────────────────────────────────

  /// A Hive read that must never take the inbox down: a closed box (tests,
  /// very early startup) reads as "nothing cached".
  static T? _cached<T>(T? Function() read, {bool when = true}) {
    if (!when) return null;
    try {
      return read();
    } catch (_) {
      return null;
    }
  }

  /// Single implementation lives with the assembler so the two paths can
  /// never disagree about what counts as a teacher.
  String _roleSlug(int idx) => roleSlugFromIndex(idx);

  /// Debug aid — used in tests / dev logging.
  @visibleForTesting
  static String roleSlugForTesting(int idx) => instance._roleSlug(idx);
}
