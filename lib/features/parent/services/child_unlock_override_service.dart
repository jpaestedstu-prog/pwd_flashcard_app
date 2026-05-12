import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/child_unlock_override.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Per-child unlock-override CRUD against Firestore.
///
/// One Firestore document at `child_unlock_overrides/{childProfileId}`.
/// The keying choice (doc id == child id) means the child's device can
/// `.snapshots()` directly without a query — same pattern as
/// `ChildTimeLimitService`.
///
/// An override grants a time-bounded grace window during which
/// [LockEnforcer] should NOT lock the child. Both the lock screen's PIN
/// unlock flow and the educator's "Unlock Now" dashboard button write
/// to the same document so there's one source of truth.
class ChildUnlockOverrideService {
  const ChildUnlockOverrideService();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('child_unlock_overrides');

  /// Live stream of the override document — emits `null` when no
  /// override is set OR when the document can't be parsed. Stream
  /// errors are routed through [ErrorHandler] with a silent source so
  /// transient permission-denied during sign-out doesn't surface a
  /// global "Something went wrong" snackbar.
  Stream<ChildUnlockOverride?> watchForChild(String childProfileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(null);
    }
    return _col.doc(childProfileId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final raw = snap.data();
      if (raw == null) return null;
      try {
        return ChildUnlockOverride.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }).handleError((Object e, StackTrace s) {
      ErrorHandler.report(e, s, 'ChildUnlockOverrideStream:silent');
    });
  }

  /// One-shot read.
  Future<ChildUnlockOverride?> getForChild(String childProfileId) async {
    if (!FirebaseService.isConfigured) return null;
    final doc = await _col.doc(childProfileId).get();
    if (!doc.exists) return null;
    return ChildUnlockOverride.fromJson(
        Map<String, dynamic>.from(doc.data()!));
  }

  /// Persist an unlock window for [childProfileId] until [unlockedUntil].
  ///
  /// Stamps `owner_uid` so the security rule on
  /// `child_unlock_overrides/{id}` (mirror of `child_time_limits`) accepts
  /// the write. Uses a clean overwrite so a parent overriding a teacher's
  /// prior unlock cleanly replaces every field, including `setter_*`.
  Future<void> setUnlock({
    required String childProfileId,
    required DateTime unlockedUntil,
    required UserProfile setter,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final override = ChildUnlockOverride(
      childProfileId: childProfileId,
      setterProfileId: setter.id,
      setterRole: setter.role,
      unlockedUntil: unlockedUntil,
      createdAt: DateTime.now(),
    );
    final payload = override.toJson()
      ..['owner_uid'] = FirebaseService.currentUid;
    try {
      await _col.doc(childProfileId).set(payload);
    } on FirebaseException catch (e) {
      throw Exception(
          'Could not unlock screen (${e.code}): ${e.message}');
    }
  }

  /// Convenience wrapper: unlock for [duration] starting now.
  Future<void> setUnlockFor({
    required String childProfileId,
    required Duration duration,
    required UserProfile setter,
  }) {
    return setUnlock(
      childProfileId: childProfileId,
      unlockedUntil: DateTime.now().add(duration),
      setter: setter,
    );
  }

  /// Delete the override for [childProfileId]. Best-effort — failures are
  /// non-fatal because the override naturally expires anyway.
  Future<void> clear(String childProfileId) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await _col.doc(childProfileId).delete();
    } on FirebaseException catch (_) {
      // Non-blocking — the override expires on its own.
    }
  }

  /// Helper to format the role for snackbars.
  static String roleLabel(UserRole role) =>
      role == UserRole.teacher ? 'teacher' : 'parent';
}
