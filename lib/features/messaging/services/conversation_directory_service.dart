import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/classroom_member.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/messaging_models.dart';
import 'friend_service.dart';
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
    final isStudent =
        me.role == UserRole.student || me.role == UserRole.child;
    return isStudent ? _watchForStudent(me) : _watchForEducator(me);
  }

  // ─── Student / Child ──────────────────────────────────

  Stream<List<Conversation>> _watchForStudent(UserProfile me) {
    final controller = StreamController<List<Conversation>>.broadcast();

    List<String> friendIds = const [];
    List<String> teacherIds = const [];

    Future<void> rebuild() async {
      final allIds = <String>{...friendIds, ...teacherIds};
      final resolved = await ProfileDirectoryService.instance
          .lookupMany(allIds);
      final convos = <Conversation>[];
      for (final id in allIds) {
        final entry = resolved[id];
        if (entry == null) {
          // Best-effort fallback: keep the peer visible with a generic
          // label so the user can still tap through and chat.
          convos.add(Conversation(
            otherProfileId: id,
            otherProfileName: 'User',
            otherProfileRole: teacherIds.contains(id) ? 'teacher' : 'student',
          ));
        } else {
          convos.add(Conversation(
            otherProfileId: entry.profileId,
            otherProfileName: entry.name,
            otherProfileRole: _roleSlug(entry.roleIndex),
          ));
        }
      }
      // Teachers first, then friends sorted alphabetically — stable order
      // so the inbox doesn't shuffle on every emission.
      convos.sort((a, b) {
        final aTeacher = a.otherProfileRole == 'teacher' ||
            a.otherProfileRole == 'parent';
        final bTeacher = b.otherProfileRole == 'teacher' ||
            b.otherProfileRole == 'parent';
        if (aTeacher != bTeacher) return aTeacher ? -1 : 1;
        return a.otherProfileName
            .toLowerCase()
            .compareTo(b.otherProfileName.toLowerCase());
      });
      if (!controller.isClosed) controller.add(convos);
    }

    final friendsSub =
        FriendService.instance.watchFriends(me.id).listen((list) {
      friendIds = list.map((f) => f.otherProfileFor(me.id)).toList();
      // ignore: discarded_futures
      rebuild();
    });

    // Teacher of joined classroom — only when the student has joined one.
    StreamSubscription? teachersSub;
    if (FirebaseService.isConfigured && me.classroomId != null) {
      teachersSub = FirebaseService.db
          .collection('classrooms')
          .doc(me.classroomId)
          .snapshots()
          .listen((snap) {
        final teacherId = snap.data()?['teacher_id'] as String?;
        teacherIds = (teacherId != null && teacherId.isNotEmpty)
            ? <String>[teacherId]
            : const <String>[];
        // ignore: discarded_futures
        rebuild();
      }, onError: (e, st) {
        ErrorHandler.report(
            e, st, 'ConversationDirectoryService.studentTeacher');
      });
    }

    controller.onCancel = () async {
      await friendsSub.cancel();
      await teachersSub?.cancel();
    };
    return controller.stream;
  }

  // ─── Teacher / Parent ─────────────────────────────────

  Stream<List<Conversation>> _watchForEducator(UserProfile me) {
    final controller = StreamController<List<Conversation>>.broadcast();

    // Map<classroomId, members[]> — kept here so a single membership
    // emission can update its slice without resetting the others.
    final byClassroom = <String, List<ClassroomMember>>{};
    final memberSubs = <String, StreamSubscription>{};

    void rebuild() {
      final all = <ClassroomMember>[];
      for (final v in byClassroom.values) {
        all.addAll(v);
      }
      // Dedupe by profile_id — a student in two classrooms shows up once.
      final seen = <String>{};
      final convos = <Conversation>[];
      for (final m in all) {
        if (m.profileId == me.id) continue;
        if (!seen.add(m.profileId)) continue;
        convos.add(Conversation(
          otherProfileId: m.profileId,
          otherProfileName: m.displayName,
          otherProfileRole: 'student',
        ));
      }
      convos.sort((a, b) => a.otherProfileName
          .toLowerCase()
          .compareTo(b.otherProfileName.toLowerCase()));
      if (!controller.isClosed) controller.add(convos);
    }

    void subscribeToClassroom(String classroomId) {
      if (memberSubs.containsKey(classroomId)) return;
      // Seed from Hive so the inbox renders even before the first cloud
      // emission lands.
      byClassroom[classroomId] = HiveService.getMembers(classroomId);
      rebuild();

      if (!FirebaseService.isConfigured) return;
      memberSubs[classroomId] = FirebaseService.db
          .collection('classroom_members')
          .where('classroom_id', isEqualTo: classroomId)
          .snapshots()
          .listen((snap) {
        byClassroom[classroomId] = snap.docs
            .map((d) =>
                ClassroomMember.fromJson(Map<String, dynamic>.from(d.data())))
            .toList();
        rebuild();
      }, onError: (e, st) {
        ErrorHandler.report(
            e, st, 'ConversationDirectoryService.classroomMembers');
      });
    }

    void unsubscribeFromClassroom(String classroomId) {
      memberSubs.remove(classroomId)?.cancel();
      byClassroom.remove(classroomId);
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
          .listen((snap) {
        final ids = snap.docs.map((d) => d.id).toSet();
        // Add new classrooms.
        for (final id in ids) {
          subscribeToClassroom(id);
        }
        // Remove dropped classrooms.
        final stale = memberSubs.keys.where((k) => !ids.contains(k)).toList();
        for (final id in stale) {
          unsubscribeFromClassroom(id);
        }
        rebuild();
      }, onError: (e, st) {
        ErrorHandler.report(
            e, st, 'ConversationDirectoryService.educatorClassrooms');
      });
    }

    controller.onCancel = () async {
      for (final sub in memberSubs.values) {
        await sub.cancel();
      }
      memberSubs.clear();
      await classroomsSub?.cancel();
    };
    return controller.stream;
  }

  // ─── Helpers ──────────────────────────────────────────

  String _roleSlug(int idx) {
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

  /// Debug aid — used in tests / dev logging.
  @visibleForTesting
  static String roleSlugForTesting(int idx) =>
      instance._roleSlug(idx);
}
