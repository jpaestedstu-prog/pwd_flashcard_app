import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/child_time_limit.dart';

/// Per-child time-limit CRUD against Firestore + Hive cache.
///
/// One Firestore document lives at `child_time_limits/{childProfileId}`.
/// The keying choice (doc id == child id) means the child's device can
/// `.snapshots()` directly without a query, which keeps the live-update
/// path cheap.
///
/// Mirrors the pattern of `ChildAlarmService` (created next).
class ChildTimeLimitService {
  const ChildTimeLimitService();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('child_time_limits');

  /// Fetch the limit for [childProfileId], hitting Hive when offline.
  Future<ChildTimeLimit?> getForChild(String childProfileId) async {
    if (!FirebaseService.isConfigured) {
      return HiveService.getChildTimeLimit(childProfileId);
    }
    final doc = await _col.doc(childProfileId).get();
    if (!doc.exists) return null;
    final limit =
        ChildTimeLimit.fromJson(Map<String, dynamic>.from(doc.data()!));
    await HiveService.cacheChildTimeLimit(limit);
    return limit;
  }

  /// Live stream of the limit document.
  ///
  /// Used by the [LockEnforcer] on the child's device so a parent's edit
  /// from another device propagates within seconds. The stream emits
  /// `null` when no document exists yet (fresh child).
  Stream<ChildTimeLimit?> watchForChild(String childProfileId) {
    if (!FirebaseService.isConfigured) {
      // Best-effort offline stream: emit current cache, then nothing.
      return Stream.value(HiveService.getChildTimeLimit(childProfileId));
    }
    return _col.doc(childProfileId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final raw = snap.data();
      if (raw == null) return null;
      try {
        final limit = ChildTimeLimit.fromJson(Map<String, dynamic>.from(raw));
        // Fire-and-forget cache update; not awaited so a slow disk
        // doesn't gate the stream emission.
        HiveService.cacheChildTimeLimit(limit);
        return limit;
      } catch (_) {
        return null;
      }
    }).handleError((Object e, StackTrace s) {
      // Route stream errors (transient permission-denied during sign-out,
      // network blips) through the silent diagnostics path so the global
      // "Something went wrong" snackbar never lights up for child-side
      // policy listening. The parent-side editor still raises real
      // failures inline through `save()`.
      ErrorHandler.report(e, s, 'ChildTimeLimitStream:silent');
    });
  }

  /// Persist [limit] to Firestore + Hive. Stamps `owner_uid` so the
  /// security rule on `child_time_limits/{id}` accepts the write.
  ///
  /// Uses a clean overwrite (not merge) so a parent saving on top of a
  /// teacher's prior limit cleanly replaces every field — including
  /// `setter_*`. With merge, a `setter_profile_id` from a previous
  /// educator could linger and break the rule predicate on the next
  /// edit. There is exactly one document per child, so a clean replace
  /// is correct.
  Future<void> save(ChildTimeLimit limit) async {
    final updated = limit.copyWith(updatedAt: DateTime.now());
    await HiveService.cacheChildTimeLimit(updated);
    if (!FirebaseService.isConfigured) return;
    final payload = updated.toJson()
      ..['owner_uid'] = FirebaseService.currentUid;
    try {
      await _col.doc(updated.childProfileId).set(payload);
    } on FirebaseException catch (e) {
      // Surface the real Firestore error (e.g. permission-denied) to
      // the screen's snackbar so the educator sees what's wrong instead
      // of a generic stream failure.
      throw Exception('Could not save time limits (${e.code}): ${e.message}');
    }
  }

  /// Remove all restrictions for [childProfileId]. The doc is deleted
  /// (rather than zeroed) so the [LockEnforcer]'s `null` short-circuit
  /// kicks in and skips evaluation entirely.
  Future<void> clear(String childProfileId) async {
    await HiveService.deleteChildTimeLimitLocal(childProfileId);
    if (!FirebaseService.isConfigured) return;
    await _col.doc(childProfileId).delete();
  }
}
