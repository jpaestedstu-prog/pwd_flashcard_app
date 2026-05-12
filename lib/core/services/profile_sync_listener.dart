import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
import 'firebase_service.dart';

/// Subscribes to Firestore `profiles/{profileId}` snapshots for every
/// profile this device knows about so educator-driven name patches
/// (see [FirestoreRepository.updateMemberDisplayName] and
/// [FirestoreRepository.updateHomeGroupMemberDisplayName]) propagate
/// to the learner's own device without a relaunch.
///
/// Mirrors the shape of [ProgressSyncListener] — minimal scope: we only
/// hydrate the `name` field back into the cached [UserProfile] in Hive.
/// Other profile fields are still authored locally on the owning device,
/// so a noisy full-doc replace would risk clobbering an in-flight edit
/// (e.g. a learner picking a new avatar at the same time).
///
/// Loop avoidance: snapshots with `hasPendingWrites == true` are local
/// echoes and are ignored.
class ProfileSyncListener {
  final FirebaseFirestore _db;

  /// profileId → active subscription. One per profile we're watching.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subs = {};

  final StreamController<String> _changes = StreamController.broadcast();

  ProfileSyncListener({FirebaseFirestore? db})
      : _db = db ?? FirebaseService.db;

  /// Emits the profileId of any profile doc whose remote `name` was just
  /// hydrated into Hive. Consumers can use this to refresh UI state.
  Stream<String> get changes => _changes.stream;

  /// Begin listening for every non-guest profile currently in Hive.
  ///
  /// Safe to call repeatedly — already-subscribed profileIds are
  /// skipped. Call after sign-in completes (so reads carry an auth uid)
  /// and again whenever a new profile is added on this device.
  void start() {
    if (!FirebaseService.isConfigured) return;
    for (final raw in HiveService.getProfiles()) {
      final id = raw['id'] as String?;
      if (id == null) continue;
      // Player-mode profiles never reach the cloud.
      if ((raw['isGuestPlayer'] as bool?) ?? false) continue;
      _subscribe(id);
    }
  }

  void _subscribe(String profileId) {
    if (_subs.containsKey(profileId)) return;
    final ref = _db.collection('profiles').doc(profileId);
    _subs[profileId] = ref.snapshots(includeMetadataChanges: false).listen(
      (snap) => _handleSnapshot(profileId, snap),
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('ProfileSyncListener[$profileId] error: $e');
        }
      },
    );
  }

  void _handleSnapshot(
      String profileId, DocumentSnapshot<Map<String, dynamic>> snap) {
    // Skip echoes of our own pending writes.
    if (snap.metadata.hasPendingWrites) return;
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;

    final remoteName = data['name'] as String?;
    if (remoteName == null || remoteName.trim().isEmpty) return;

    try {
      final cached = HiveService.getProfileById(profileId);
      if (cached == null) return;
      if (cached.name == remoteName) return; // already in sync
      // Bypass LocalRepository so this hydration doesn't bounce back
      // out as a remote write.
      final updated = cached.copyWith(name: remoteName);
      HiveService.saveProfile(updated);
      _changes.add(profileId);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ProfileSyncListener[$profileId] decode failed: $e\n$st');
      }
    }
  }

  /// Add a single profile to the watch set after [start] has run.
  /// Safe to call any time — no-op if already subscribed.
  void watch(String profileId) {
    if (FirebaseService.isConfigured) _subscribe(profileId);
  }

  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _changes.close();
  }
}
