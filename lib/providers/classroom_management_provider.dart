import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/firebase_service.dart';
import '../core/services/join_code_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/classroom.dart';
import '../data/models/classroom_member.dart';
import '../data/remote/firestore_repository.dart';

/// Teacher-facing state for the "Manage Classes" screen.
///
/// All operations write **directly** to Firestore so the data is
/// immediately visible in the Firebase Console — no queue, no replay
/// delay. Hive is used only as a read-side cache for offline display.
class ClassroomManagementNotifier
    extends FamilyAsyncNotifier<List<Classroom>, String> {
  static const _uuid = Uuid();

  @override
  Future<List<Classroom>> build(String teacherId) async {
    if (teacherId.isEmpty) return const [];
    if (!FirebaseService.isConfigured) return const [];

    final snap = await FirebaseService.db
        .collection('classrooms')
        .where('teacher_id', isEqualTo: teacherId)
        .get();
    final classrooms = snap.docs
        .map((d) => Classroom.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Refresh local cache.
    for (final c in classrooms) {
      await HiveService.cacheClassroom(c);
    }
    return classrooms;
  }

  /// Create a new classroom with a unique join code.
  Future<Classroom> createClass(String name) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final teacherId = arg;

    // Pre-flight: the new strict rule for `classrooms/{id}` create
    // requires `ownsProfile(teacher_id)` — i.e. the teacher profile
    // must already exist in Firestore with `owner_uid` matching this
    // device's auth uid. Push the teacher profile first (idempotent
    // merge) so the rule check passes even if the original
    // background sync never landed. Without this, a freshly-created
    // teacher would hit `permission-denied` on their first class.
    final teacher = HiveService.getProfileById(teacherId);
    if (teacher != null) {
      try {
        await const FirestoreRepository().saveProfile(teacher);
      } catch (e) {
        throw Exception(
            'Could not sync teacher profile to cloud before creating class: $e');
      }
    }

    final code = await JoinCodeService.generateUniqueCode();
    final now = DateTime.now();
    final classroom = Classroom(
      id: _uuid.v4(),
      code: code,
      name: name.trim().isEmpty ? 'Untitled class' : name.trim(),
      teacherId: teacherId,
      createdAt: now,
      updatedAt: now,
    );

    await FirebaseService.db
        .collection('classrooms')
        .doc(classroom.id)
        .set(classroom.toJson());
    await HiveService.cacheClassroom(classroom);

    state = AsyncData([classroom, ...?state.value]);
    return classroom;
  }

  /// Generate a new code for [classroom]. Existing memberships survive.
  Future<Classroom> regenerateCode(Classroom classroom) async {
    final updated = await JoinCodeService.regenerateCode(classroom);
    state = AsyncData([
      for (final c in state.value ?? const <Classroom>[])
        if (c.id == updated.id) updated else c,
    ]);
    return updated;
  }

  /// Rename [classroom] to [newName].
  Future<void> renameClass(Classroom classroom, String newName) async {
    if (!FirebaseService.isConfigured) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == classroom.name) return;
    final updated = classroom.copyWith(name: trimmed, updatedAt: DateTime.now());
    await FirebaseService.db
        .collection('classrooms')
        .doc(updated.id)
        .set(updated.toJson());
    await HiveService.cacheClassroom(updated);
    state = AsyncData([
      for (final c in state.value ?? const <Classroom>[])
        if (c.id == updated.id) updated else c,
    ]);
  }

  /// Delete [classroom] and all its memberships.
  Future<void> deleteClass(Classroom classroom) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    // Drop members first.
    final members = await FirebaseService.db
        .collection('classroom_members')
        .where('classroom_id', isEqualTo: classroom.id)
        .get();
    for (final d in members.docs) {
      await d.reference.delete();
    }
    await FirebaseService.db
        .collection('classrooms')
        .doc(classroom.id)
        .delete();
    await HiveService.deleteClassroomLocal(classroom.id);

    state = AsyncData([
      for (final c in state.value ?? const <Classroom>[])
        if (c.id != classroom.id) c,
    ]);
  }

  /// Remove [profileId] from [classroom]'s roster.
  ///
  /// Cascades to this teacher's own `child_time_limits/{profileId}` and
  /// `child_alarms` (where the teacher is the setter) so the learner
  /// stops being controlled by an educator they no longer report to.
  /// Other educators' policies are left intact — they may still apply.
  Future<void> removeStudent(Classroom classroom, String profileId) async {
    if (!FirebaseService.isConfigured) return;
    await FirebaseService.db
        .collection('classroom_members')
        .doc('${classroom.id}_$profileId')
        .delete();
    await HiveService.removeMemberLocal(classroom.id, profileId);
    await _cascadeEducatorPoliciesForProfile(profileId);
  }

  /// Bulk-remove students from [classroom]'s roster.
  ///
  /// Uses a single Firestore batch so all deletions land atomically.
  /// Used by the multi-select UI on the Manage Classes screen.
  Future<void> removeStudents(
      Classroom classroom, List<String> profileIds) async {
    if (!FirebaseService.isConfigured) return;
    if (profileIds.isEmpty) return;
    await const FirestoreRepository()
        .removeMembers(classroom.id, profileIds);
    for (final id in profileIds) {
      await HiveService.removeMemberLocal(classroom.id, id);
      await _cascadeEducatorPoliciesForProfile(id);
    }
  }

  /// Drop this educator's time-limit + alarm rules for the given
  /// learner. Best-effort — failures don't block the membership
  /// removal that the user asked for. Other educators' rules are
  /// left untouched (their `setter_profile_id` doesn't match `arg`).
  Future<void> _cascadeEducatorPoliciesForProfile(String profileId) async {
    final teacherId = arg;
    final db = FirebaseService.db;
    try {
      // Drop the time limit only if THIS teacher set it.
      final limitDoc = await db
          .collection('child_time_limits')
          .doc(profileId)
          .get();
      if (limitDoc.exists &&
          (limitDoc.data()?['setter_profile_id'] as String?) == teacherId) {
        await limitDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking.
    }
    try {
      // Drop alarms set by THIS teacher targeting this learner.
      final alarms = await db
          .collection('child_alarms')
          .where('child_profile_id', isEqualTo: profileId)
          .where('setter_profile_id', isEqualTo: teacherId)
          .get();
      if (alarms.docs.isNotEmpty) {
        final batch = db.batch();
        for (final d in alarms.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {
      // Non-blocking.
    }
    try {
      // Drop the unlock override only if THIS teacher set it. Other
      // educators' overrides survive — they may still apply to the
      // learner from a different group/classroom.
      final overrideDoc = await db
          .collection('child_unlock_overrides')
          .doc(profileId)
          .get();
      if (overrideDoc.exists &&
          (overrideDoc.data()?['setter_profile_id'] as String?) ==
              teacherId) {
        await overrideDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking.
    }
  }

  /// Rename how a student appears in [classroom]'s roster.
  ///
  /// Patches only the [ClassroomMember.displayName] field — the underlying
  /// [UserProfile.name] is untouched. Use this to dedupe collisions like
  /// "Maria" / "Maria (2)" without rewriting the student's profile.
  Future<void> renameMember(
      Classroom classroom, String profileId, String newDisplayName) async {
    if (!FirebaseService.isConfigured) return;
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) return;
    await const FirestoreRepository().updateMemberDisplayName(
      classroomId: classroom.id,
      profileId: profileId,
      newDisplayName: trimmed,
    );
  }

  /// Manually enrol a student that hasn't joined from their own device.
  ///
  /// Creates a placeholder [UserProfile] (id prefix `manual_`) plus a
  /// matching [ClassroomMember] row. Returns the synthetic profile id.
  /// The UI flags these placeholders with a "Manual — not yet joined"
  /// badge based on the id prefix.
  Future<String> addManualStudent(
      Classroom classroom, String displayName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Student name is required.');
    }
    return const FirestoreRepository().addManualClassroomMember(
      classroomId: classroom.id,
      displayName: trimmed,
      teacherProfileId: arg,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final classroomManagementProvider = AsyncNotifierProviderFamily<
    ClassroomManagementNotifier, List<Classroom>, String>(
  ClassroomManagementNotifier.new,
);

/// Lists members of a classroom, reading directly from Firestore.
final classroomMembersProvider =
    FutureProvider.family<List<ClassroomMember>, String>(
        (ref, classroomId) async {
  if (!FirebaseService.isConfigured) return const [];
  final snap = await FirebaseService.db
      .collection('classroom_members')
      .where('classroom_id', isEqualTo: classroomId)
      .get();
  final members = snap.docs
      .map(
          (d) => ClassroomMember.fromJson(Map<String, dynamic>.from(d.data())))
      .toList()
    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  return members;
});
