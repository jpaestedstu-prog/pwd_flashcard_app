import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../models/friend_models.dart';

/// Public-facing directory of profiles keyed by username.
///
/// Doc id is the lowercased username, which gives:
///   * O(1) lookup-by-handle (no `where(...)` query, no composite index)
///   * Natural uniqueness — `set()` with `SetOptions(merge: true)` on the
///     existing doc would overwrite, so callers MUST verify availability
///     via [isUsernameTaken] before claiming.
///
/// Firestore schema (`profile_directory/{usernameLower}`):
/// ```
/// username:   string  (mirrors doc id, kept on the body for portability)
/// profile_id: string
/// name:       string
/// role_index: int     (UserRole index)
/// owner_uid:  string  (Firebase Anonymous Auth uid of the writer)
/// updated_at: ISO8601 string
/// ```
///
/// Reads are open to any signed-in user (security rule below); writes
/// require the caller to own the profile referenced by [profile_id].
class ProfileDirectoryService {
  ProfileDirectoryService._();

  static final ProfileDirectoryService instance = ProfileDirectoryService._();

  /// Hard ceiling on any single directory round-trip so a stalled
  /// network can't freeze the Add Friend flow.
  static const Duration _lookupTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('profile_directory');

  /// Whether the given handle is already claimed by another profile.
  /// Returns `false` when Firebase is unconfigured so single-device demos
  /// don't blow up the create flow.
  Future<bool> isUsernameTaken(String username) async {
    if (!FirebaseService.isConfigured) return false;
    final u = username.trim().toLowerCase();
    if (u.isEmpty) return true;
    try {
      final doc = await _col.doc(u).get().timeout(_lookupTimeout);
      return doc.exists;
    } catch (e, st) {
      ErrorHandler.report(e, st, 'ProfileDirectoryService.isUsernameTaken');
      // Treat lookup failure as "taken" so the caller picks a different
      // suffix instead of risking a collision on an unreachable server.
      return true;
    }
  }

  /// Upsert the directory entry for [profile]. No-op for player-mode or
  /// profiles missing a [UserProfile.username].
  Future<void> upsert(UserProfile profile) async {
    if (!FirebaseService.isConfigured) return;
    if (profile.isGuestPlayer) return;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    // The directory entry belongs to the profile's owner, and the security
    // rule denies writes from non-owners. Skip rather than attempt (and log)
    // a guaranteed permission-denied write — e.g. a teacher viewing a class
    // member's profile they don't own. The owner keeps the entry fresh.
    if (profile.ownerUid != null && profile.ownerUid != uid) return;
    final handle = profile.username?.trim().toLowerCase();
    if (handle == null || handle.isEmpty) return;

    final entry = DirectoryEntry(
      username: handle,
      profileId: profile.id,
      name: profile.name,
      roleIndex: profile.role.index,
      ownerUid: profile.ownerUid ?? uid,
      updatedAt: DateTime.now(),
    );

    try {
      await _col
          .doc(handle)
          .set(entry.toJson(), SetOptions(merge: true))
          .timeout(_lookupTimeout);
      // Mirror into the local cache by profile id so subsequent inbox
      // renders can resolve names without an extra round-trip.
      await HiveService.cacheDirectoryEntry(profile.id, entry.toJson());
    } catch (e, st) {
      ErrorHandler.report(e, st, 'ProfileDirectoryService.upsert');
    }
  }

  /// Resolve a username -> DirectoryEntry. Null if Firebase is offline
  /// or the handle isn't claimed.
  Future<DirectoryEntry?> lookupByUsername(String username) async {
    if (!FirebaseService.isConfigured) return null;
    final u = username.trim().toLowerCase();
    if (u.isEmpty) return null;
    try {
      final doc = await _col.doc(u).get().timeout(_lookupTimeout);
      if (!doc.exists) return null;
      final entry = DirectoryEntry.fromJson(doc.data()!);
      await HiveService.cacheDirectoryEntry(entry.profileId, entry.toJson());
      return entry;
    } catch (e, st) {
      ErrorHandler.report(e, st, 'ProfileDirectoryService.lookupByUsername');
      return null;
    }
  }

  /// Resolve a profile id -> DirectoryEntry. Backed by the Hive cache so
  /// the inbox renders names instantly across cold launches.
  Future<DirectoryEntry?> lookupByProfileId(String profileId) async {
    // Hive first — synchronous and survives offline cold starts.
    final cached = HiveService.getCachedDirectoryEntry(profileId);
    if (cached != null) {
      try {
        return DirectoryEntry.fromJson(cached);
      } catch (_) {
        // Fallthrough — corrupted cache, refetch.
      }
    }
    if (!FirebaseService.isConfigured) return null;
    try {
      // No doc id by profile id alone — query by field.
      final snap = await _col
          .where('profile_id', isEqualTo: profileId)
          .limit(1)
          .get()
          .timeout(_lookupTimeout);
      if (snap.docs.isEmpty) return null;
      final entry = DirectoryEntry.fromJson(snap.docs.first.data());
      await HiveService.cacheDirectoryEntry(profileId, entry.toJson());
      return entry;
    } catch (e, st) {
      ErrorHandler.report(e, st, 'ProfileDirectoryService.lookupByProfileId');
      return null;
    }
  }

  /// Best-effort batch resolve. Returns a map keyed by profile id; ids
  /// that couldn't be resolved are simply omitted.
  Future<Map<String, DirectoryEntry>> lookupMany(
      Iterable<String> profileIds) async {
    final out = <String, DirectoryEntry>{};
    for (final id in profileIds.toSet()) {
      final entry = await lookupByProfileId(id);
      if (entry != null) out[id] = entry;
    }
    if (kDebugMode) {
      debugPrint(
          'ProfileDirectoryService.lookupMany: ${out.length}/${profileIds.length} resolved');
    }
    return out;
  }
}
