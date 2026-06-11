import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/cloud_sync_exceptions.dart';
import '../core/services/educator_policy_cascade.dart';
import '../core/services/firebase_service.dart';
import '../core/services/join_code_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/classroom.dart';
import '../data/models/classroom_member.dart';
import '../data/remote/firestore_repository.dart';
import 'firestore_stream_helpers.dart';

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
    // Auth gate: every Firestore rule starts with `signedIn()`, so if
    // the anonymous sign-in failed at startup (Anonymous Auth disabled
    // in the Firebase Console, offline first launch) the snapshot read
    // would come back as raw `permission-denied`. Surface a typed
    // [CloudAuthMissingException] instead so the screen can map it to
    // setup-help copy rather than leaking the Firestore error code.
    if (FirebaseService.isConfigured) {
      final uid = await FirebaseService.ensureSignedIn();
      if (uid == null) {
        throw CloudAuthMissingException(FirebaseService.lastInitError);
      }
    }
    // Subscribe to live Firestore changes via the leaf stream provider —
    // every emission pushes a new AsyncData into our state. Mutations
    // (createClass / renameClass / deleteClass / regenerateCode) no
    // longer need to optimistically rewrite `state`: the snapshot
    // listener fires within ~1s after the write lands.
    ref.listen<AsyncValue<List<Classroom>>>(
      classroomsByTeacherStreamProvider(teacherId),
      (_, next) {
        next.when(
          data: (list) => state = AsyncData(list),
          loading: () {},
          error: (e, s) => state = AsyncError(e, s),
        );
      },
    );
    return ref.read(classroomsByTeacherStreamProvider(teacherId).future);
  }

  /// Create a new classroom with a unique join code.
  Future<Classroom> createClass(String name) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    // Auth must be resolved before any owner-scoped write — same
    // rationale as [build]. Throws [CloudAuthMissingException] if the
    // device never finished anonymous sign-in.
    final uid = await FirebaseService.ensureSignedIn();
    if (uid == null) {
      throw CloudAuthMissingException(FirebaseService.lastInitError);
    }
    final teacherId = arg;

    // Pre-flight: the strict rule for `classrooms/{id}` create requires
    // `ownsProfile(teacher_id)` — i.e. the teacher profile must already
    // exist in Firestore with `owner_uid` matching this device's auth
    // uid. Push the teacher profile first (idempotent merge) so the rule
    // check passes even if the original background sync never landed.
    // Without this, a freshly-created teacher would hit `permission-denied`
    // on their first class. [FirestoreRepository.saveProfile] also throws
    // [OwnerUidMismatchException] when this profile already belongs to a
    // different uid — we let that propagate so the screen can offer the
    // "Reset for this device" affordance.
    final teacher = HiveService.getProfileById(teacherId);
    if (teacher != null) {
      await const FirestoreRepository().saveProfile(teacher);
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
    // No optimistic `state =` here — the Firestore snapshot listener in
    // `build()` pushes the new value automatically.
    return classroom;
  }

  /// Generate a new code for [classroom]. Existing memberships survive.
  Future<Classroom> regenerateCode(Classroom classroom) async {
    return JoinCodeService.regenerateCode(classroom);
  }

  /// Rename [classroom] to [newName].
  ///
  /// Throws if cloud sync is offline so the dialog surfaces a clear
  /// error instead of "Save" silently doing nothing. Empty / unchanged
  /// names are already guarded at the dialog layer (see
  /// [CloudAwareTextDialog]), so a same-name call here is a defensive
  /// no-op rather than a surfaced exception.
  Future<void> renameClass(Classroom classroom, String newName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Class name is required.');
    }
    if (trimmed == classroom.name) return;
    final updated =
        classroom.copyWith(name: trimmed, updatedAt: DateTime.now());
    // Sparse merge: only the fields that actually changed. Avoids
    // clobbering any forward-compat fields a future client may have
    // added to this doc (full-doc `set` would erase them).
    await FirebaseService.db
        .collection('classrooms')
        .doc(updated.id)
        .set({
      'name': updated.name,
      'updated_at': updated.updatedAt.toIso8601String(),
    }, SetOptions(merge: true));
    await HiveService.cacheClassroom(updated);
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
  }

  /// Remove [profileId] from [classroom]'s roster.
  ///
  /// Cascades to this teacher's own `child_time_limits/{profileId}` and
  /// `child_alarms` (where the teacher is the setter) so the learner
  /// stops being controlled by an educator they no longer report to.
  /// Other educators' policies are left intact — they may still apply.
  Future<void> removeStudent(Classroom classroom, String profileId) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    await FirebaseService.db
        .collection('classroom_members')
        .doc('${classroom.id}_$profileId')
        .delete();
    await HiveService.removeMemberLocal(classroom.id, profileId);
    await EducatorPolicyCascade.dropPoliciesSetBy(
      setterProfileId: arg,
      childProfileId: profileId,
    );
  }

  /// Bulk-remove students from [classroom]'s roster.
  ///
  /// Uses a single Firestore batch so all deletions land atomically.
  /// Used by the multi-select UI on the Manage Classes screen.
  Future<void> removeStudents(
      Classroom classroom, List<String> profileIds) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    if (profileIds.isEmpty) return;
    await const FirestoreRepository()
        .removeMembers(classroom.id, profileIds);
    for (final id in profileIds) {
      await HiveService.removeMemberLocal(classroom.id, id);
      await EducatorPolicyCascade.dropPoliciesSetBy(
        setterProfileId: arg,
        childProfileId: id,
      );
    }
  }

  /// Rename how a student appears in [classroom]'s roster.
  ///
  /// Patches only the [ClassroomMember.displayName] field — the underlying
  /// [UserProfile.name] is touched too via the audit-row → rule path in
  /// [FirestoreRepository.updateMemberDisplayName].
  ///
  /// Throws when cloud sync is offline or the name is empty so the
  /// dialog can render a clear error instead of silently doing nothing.
  Future<void> renameMember(
      Classroom classroom, String profileId, String newDisplayName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Display name is required.');
    }
    await const FirestoreRepository().updateMemberDisplayName(
      classroomId: classroom.id,
      profileId: profileId,
      newDisplayName: trimmed,
    );
  }

  /// Manual refresh — kept as a safety net for the management screen's
  /// IconButton. Cancels and resubscribes the underlying Firestore stream
  /// so a stale listener (e.g. after a long suspend) gets a fresh start.
  Future<void> refresh() async {
    ref.invalidate(classroomsByTeacherStreamProvider(arg));
  }
}

final classroomManagementProvider = AsyncNotifierProviderFamily<
    ClassroomManagementNotifier, List<Classroom>, String>(
  ClassroomManagementNotifier.new,
);

/// Live members of a classroom — Firestore `.snapshots()` subscription.
///
/// Emits a fresh `List<ClassroomMember>` every time a member doc in this
/// classroom is added / changed / deleted. Replaces the old one-shot
/// `FutureProvider` so the teacher's roster reflects student joins from
/// another device within seconds, without a manual refresh.
///
/// Always emits the Hive cache first so unplugged tablets render the
/// last-known roster instantly; falls back to cache-only when Firebase
/// isn't configured (single-device demos).
final classroomMembersProvider =
    StreamProvider.family.autoDispose<List<ClassroomMember>, String>(
        (ref, classroomId) async* {
  final cached = HiveService.getMembers(classroomId)
    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  yield cached;
  if (!FirebaseService.isConfigured) return;
  yield* FirebaseService.db
      .collection('classroom_members')
      .where('classroom_id', isEqualTo: classroomId)
      .snapshots()
      .map((snap) {
    final members = snap.docs
        .map((d) =>
            ClassroomMember.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    // Fire-and-forget Hive write so offline launches stay fresh.
    for (final m in members) {
      // ignore: discarded_futures
      HiveService.addMemberLocal(m);
    }
    return members;
  });
});
