import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/cloud_sync_exceptions.dart';
import '../core/services/educator_policy_cascade.dart';
import '../core/services/firebase_service.dart';
import '../core/services/home_group_code_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/home_group.dart';
import '../data/models/home_group_member.dart';
import '../data/remote/firestore_repository.dart';
import 'firestore_stream_helpers.dart';

/// Parent-facing state for the "Manage Home Groups" screen.
///
/// Mirrors [ClassroomManagementNotifier] in shape but operates on the
/// `home_groups` and `home_group_members` collections. All operations
/// write directly to Firestore so data is visible in the console without
/// a sync replay delay.
class HomeGroupManagementNotifier
    extends FamilyAsyncNotifier<List<HomeGroup>, String> {
  static const _uuid = Uuid();

  /// `arg` is the parent's profileId (NOT auth uid) — same convention as
  /// the classroom provider, so the security rule helper for ownership
  /// can be a one-liner mirror of `ownsClassroomTeacher`.
  @override
  Future<List<HomeGroup>> build(String parentProfileId) async {
    if (parentProfileId.isEmpty) return const [];
    // Auth gate — mirror of [ClassroomManagementNotifier.build]. If the
    // anonymous sign-in failed (Anonymous Auth disabled in the Firebase
    // Console, offline first launch) we throw a typed exception the
    // screen maps to setup-help copy rather than leaking the raw
    // `permission-denied` Firestore code.
    if (FirebaseService.isConfigured) {
      final uid = await FirebaseService.ensureSignedIn();
      if (uid == null) {
        throw CloudAuthMissingException(FirebaseService.lastInitError);
      }
    }
    // Subscribe to live Firestore changes via the leaf stream provider.
    // Mutation methods no longer need to optimistically rewrite `state`.
    ref.listen<AsyncValue<List<HomeGroup>>>(
      homeGroupsByOwnerStreamProvider(parentProfileId),
      (_, next) {
        next.when(
          data: (list) => state = AsyncData(list),
          loading: () {},
          error: (e, s) => state = AsyncError(e, s),
        );
      },
    );
    return ref.read(homeGroupsByOwnerStreamProvider(parentProfileId).future);
  }

  /// Create a new home group with a unique join code.
  Future<HomeGroup> createGroup(String name) async {
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
    final parentProfileId = arg;

    // Pre-flight: ensure the parent profile exists in Firestore so the
    // `ownsProfile(owner_profile_id)` security check passes on create.
    // [FirestoreRepository.saveProfile] throws [OwnerUidMismatchException]
    // when the profile belongs to a different uid — we let it propagate
    // so the screen can surface the "Reset for this device" affordance.
    final parent = HiveService.getProfileById(parentProfileId);
    if (parent != null) {
      await const FirestoreRepository().saveProfile(parent);
    }

    final code = await HomeGroupCodeService.generateUniqueCode();
    final now = DateTime.now();
    final group = HomeGroup(
      id: _uuid.v4(),
      code: code,
      name: name.trim().isEmpty ? 'My Family' : name.trim(),
      ownerProfileId: parentProfileId,
      createdAt: now,
      updatedAt: now,
    );

    await FirebaseService.db
        .collection('home_groups')
        .doc(group.id)
        .set(group.toJson());
    await HiveService.cacheHomeGroup(group);
    // No optimistic `state =`; snapshot listener in `build()` updates state.
    return group;
  }

  /// Generate a new code for [group]. Existing memberships survive.
  Future<HomeGroup> regenerateCode(HomeGroup group) async {
    return HomeGroupCodeService.regenerateCode(group);
  }

  /// Rename [group] to [newName].
  ///
  /// Throws when cloud sync is offline or the name is empty so the
  /// dialog can render a clear error instead of silently doing nothing.
  /// Same-name calls are a defensive no-op (already guarded at the
  /// dialog layer).
  Future<void> renameGroup(HomeGroup group, String newName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Group name is required.');
    }
    if (trimmed == group.name) return;
    final updated = group.copyWith(name: trimmed, updatedAt: DateTime.now());
    // Sparse merge: only the fields that changed, so forward-compat
    // fields on the doc aren't clobbered.
    await FirebaseService.db
        .collection('home_groups')
        .doc(updated.id)
        .set({
      'name': updated.name,
      'updated_at': updated.updatedAt.toIso8601String(),
    }, SetOptions(merge: true));
    await HiveService.cacheHomeGroup(updated);
  }

  /// Delete [group] and all its memberships.
  Future<void> deleteGroup(HomeGroup group) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final members = await FirebaseService.db
        .collection('home_group_members')
        .where('home_group_id', isEqualTo: group.id)
        .get();
    for (final d in members.docs) {
      await d.reference.delete();
    }
    await FirebaseService.db
        .collection('home_groups')
        .doc(group.id)
        .delete();
    await HiveService.deleteHomeGroupLocal(group.id);
  }

  /// Remove [profileId] from [group]'s roster.
  ///
  /// Cascades to this parent's own `child_time_limits/{profileId}` and
  /// `child_alarms` (where this parent is the setter) so the child
  /// stops being controlled by a parent they no longer belong to.
  /// Other educators' policies are left intact.
  ///
  /// Throws when cloud sync is offline so the caller can surface a
  /// clear error rather than silently doing nothing.
  Future<void> removeChild(HomeGroup group, String profileId) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    await FirebaseService.db
        .collection('home_group_members')
        .doc('${group.id}_$profileId')
        .delete();
    await HiveService.removeHomeGroupMemberLocal(group.id, profileId);
    await EducatorPolicyCascade.dropPoliciesSetBy(
      setterProfileId: arg,
      childProfileId: profileId,
    );
  }

  /// Bulk-remove children from [group]'s roster.
  ///
  /// Mirrors [ClassroomManagementNotifier.removeStudents]. Used by the
  /// multi-select UI on the Manage Home Groups screen.
  Future<void> removeChildren(
      HomeGroup group, List<String> profileIds) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    if (profileIds.isEmpty) return;
    await const FirestoreRepository()
        .removeHomeGroupMembers(group.id, profileIds);
    for (final id in profileIds) {
      await HiveService.removeHomeGroupMemberLocal(group.id, id);
      await EducatorPolicyCascade.dropPoliciesSetBy(
        setterProfileId: arg,
        childProfileId: id,
      );
    }
  }

  /// Rename how a child appears in [group]'s roster.
  ///
  /// Throws when cloud sync is offline or the name is empty so the
  /// dialog can render a clear error instead of silently doing nothing.
  Future<void> renameMember(
      HomeGroup group, String profileId, String newDisplayName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Display name is required.');
    }
    await const FirestoreRepository().updateHomeGroupMemberDisplayName(
      homeGroupId: group.id,
      profileId: profileId,
      newDisplayName: trimmed,
    );
  }

  /// Manual refresh — cancels and resubscribes the underlying Firestore
  /// stream. Kept as a safety net for the management screen's IconButton.
  Future<void> refresh() async {
    ref.invalidate(homeGroupsByOwnerStreamProvider(arg));
  }
}

final homeGroupManagementProvider = AsyncNotifierProviderFamily<
    HomeGroupManagementNotifier, List<HomeGroup>, String>(
  HomeGroupManagementNotifier.new,
);

/// Live members of a home group — Firestore `.snapshots()` subscription.
///
/// Mirrors [classroomMembersProvider]: emits a fresh list whenever a
/// member doc is added / changed / deleted, so the parent's roster
/// reflects child joins from another device within seconds.
final homeGroupMembersProvider =
    StreamProvider.family.autoDispose<List<HomeGroupMember>, String>(
        (ref, homeGroupId) async* {
  final cached = HiveService.getHomeGroupMembers(homeGroupId)
    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  yield cached;
  if (!FirebaseService.isConfigured) return;
  yield* FirebaseService.db
      .collection('home_group_members')
      .where('home_group_id', isEqualTo: homeGroupId)
      .snapshots()
      .map((snap) {
    final members = snap.docs
        .map((d) =>
            HomeGroupMember.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    for (final m in members) {
      // ignore: discarded_futures
      HiveService.addHomeGroupMemberLocal(m);
    }
    return members;
  });
});
