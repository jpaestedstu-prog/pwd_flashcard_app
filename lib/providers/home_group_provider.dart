import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/firebase_service.dart';
import '../core/services/home_group_code_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/home_group.dart';
import '../data/models/home_group_member.dart';
import '../data/remote/firestore_repository.dart';

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
    if (!FirebaseService.isConfigured) {
      return HiveService.getHomeGroupsByOwner(parentProfileId);
    }

    final snap = await FirebaseService.db
        .collection('home_groups')
        .where('owner_profile_id', isEqualTo: parentProfileId)
        .get();
    final groups = snap.docs
        .map((d) => HomeGroup.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final g in groups) {
      await HiveService.cacheHomeGroup(g);
    }
    return groups;
  }

  /// Create a new home group with a unique join code.
  Future<HomeGroup> createGroup(String name) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final parentProfileId = arg;

    // Pre-flight: ensure the parent profile exists in Firestore so the
    // `ownsProfile(owner_profile_id)` security check passes on create.
    final parent = HiveService.getProfileById(parentProfileId);
    if (parent != null) {
      try {
        await const FirestoreRepository().saveProfile(parent);
      } catch (e) {
        throw Exception(
            'Could not sync parent profile to cloud before creating group: $e');
      }
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

    state = AsyncData([group, ...?state.value]);
    return group;
  }

  /// Generate a new code for [group]. Existing memberships survive.
  Future<HomeGroup> regenerateCode(HomeGroup group) async {
    final updated = await HomeGroupCodeService.regenerateCode(group);
    state = AsyncData([
      for (final g in state.value ?? const <HomeGroup>[])
        if (g.id == updated.id) updated else g,
    ]);
    return updated;
  }

  /// Rename [group] to [newName].
  Future<void> renameGroup(HomeGroup group, String newName) async {
    if (!FirebaseService.isConfigured) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == group.name) return;
    final updated = group.copyWith(name: trimmed, updatedAt: DateTime.now());
    await FirebaseService.db
        .collection('home_groups')
        .doc(updated.id)
        .set(updated.toJson());
    await HiveService.cacheHomeGroup(updated);
    state = AsyncData([
      for (final g in state.value ?? const <HomeGroup>[])
        if (g.id == updated.id) updated else g,
    ]);
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

    state = AsyncData([
      for (final g in state.value ?? const <HomeGroup>[])
        if (g.id != group.id) g,
    ]);
  }

  /// Remove [profileId] from [group]'s roster.
  ///
  /// Cascades to this parent's own `child_time_limits/{profileId}` and
  /// `child_alarms` (where this parent is the setter) so the child
  /// stops being controlled by a parent they no longer belong to.
  /// Other educators' policies are left intact.
  Future<void> removeChild(HomeGroup group, String profileId) async {
    if (!FirebaseService.isConfigured) return;
    await FirebaseService.db
        .collection('home_group_members')
        .doc('${group.id}_$profileId')
        .delete();
    await HiveService.removeHomeGroupMemberLocal(group.id, profileId);
    await _cascadeEducatorPoliciesForProfile(profileId);
  }

  /// Bulk-remove children from [group]'s roster.
  ///
  /// Mirrors [ClassroomManagementNotifier.removeStudents]. Used by the
  /// multi-select UI on the Manage Home Groups screen.
  Future<void> removeChildren(
      HomeGroup group, List<String> profileIds) async {
    if (!FirebaseService.isConfigured) return;
    if (profileIds.isEmpty) return;
    await const FirestoreRepository()
        .removeHomeGroupMembers(group.id, profileIds);
    for (final id in profileIds) {
      await HiveService.removeHomeGroupMemberLocal(group.id, id);
      await _cascadeEducatorPoliciesForProfile(id);
    }
  }

  /// Drop this parent's time-limit + alarm rules for the given child.
  /// Best-effort — failures don't block the membership removal. Mirror
  /// of [ClassroomManagementNotifier._cascadeEducatorPoliciesForProfile].
  Future<void> _cascadeEducatorPoliciesForProfile(String profileId) async {
    final parentId = arg;
    final db = FirebaseService.db;
    try {
      final limitDoc = await db
          .collection('child_time_limits')
          .doc(profileId)
          .get();
      if (limitDoc.exists &&
          (limitDoc.data()?['setter_profile_id'] as String?) == parentId) {
        await limitDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking.
    }
    try {
      final alarms = await db
          .collection('child_alarms')
          .where('child_profile_id', isEqualTo: profileId)
          .where('setter_profile_id', isEqualTo: parentId)
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
      // Drop the unlock override only if THIS parent set it.
      final overrideDoc = await db
          .collection('child_unlock_overrides')
          .doc(profileId)
          .get();
      if (overrideDoc.exists &&
          (overrideDoc.data()?['setter_profile_id'] as String?) == parentId) {
        await overrideDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking.
    }
  }

  /// Rename how a child appears in [group]'s roster.
  Future<void> renameMember(
      HomeGroup group, String profileId, String newDisplayName) async {
    if (!FirebaseService.isConfigured) return;
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) return;
    await const FirestoreRepository().updateHomeGroupMemberDisplayName(
      homeGroupId: group.id,
      profileId: profileId,
      newDisplayName: trimmed,
    );
  }

  /// Manually enrol a child that hasn't joined from their own device.
  ///
  /// Parent-side mirror of [ClassroomManagementNotifier.addManualStudent].
  /// Returns the synthetic profile id (prefix `manual_`).
  Future<String> addManualChild(HomeGroup group, String displayName) async {
    if (!FirebaseService.isConfigured) {
      throw Exception(
          'Cloud sync not connected. Restart the app or check Firebase setup.');
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Child name is required.');
    }
    return const FirestoreRepository().addManualHomeGroupMember(
      homeGroupId: group.id,
      displayName: trimmed,
      parentProfileId: arg,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final homeGroupManagementProvider = AsyncNotifierProviderFamily<
    HomeGroupManagementNotifier, List<HomeGroup>, String>(
  HomeGroupManagementNotifier.new,
);

/// Lists members of a home group, reading directly from Firestore.
final homeGroupMembersProvider =
    FutureProvider.family<List<HomeGroupMember>, String>(
        (ref, homeGroupId) async {
  if (!FirebaseService.isConfigured) {
    return HiveService.getHomeGroupMembers(homeGroupId);
  }
  final snap = await FirebaseService.db
      .collection('home_group_members')
      .where('home_group_id', isEqualTo: homeGroupId)
      .get();
  final members = snap.docs
      .map((d) =>
          HomeGroupMember.fromJson(Map<String, dynamic>.from(d.data())))
      .toList()
    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  return members;
});
