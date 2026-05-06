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
  Future<void> removeChild(HomeGroup group, String profileId) async {
    if (!FirebaseService.isConfigured) return;
    await FirebaseService.db
        .collection('home_group_members')
        .doc('${group.id}_$profileId')
        .delete();
    await HiveService.removeHomeGroupMemberLocal(group.id, profileId);
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
