import 'firebase_service.dart';

/// One-stop cleanup for the per-child policy docs an educator (teacher or
/// parent) wrote when a learner was in their roster.
///
/// Before this helper, the same three-collection cleanup lived twice —
/// once in [ClassroomManagementNotifier] and once in
/// [HomeGroupManagementNotifier] — and both copies could (and did) drift
/// over time. The cascade order matters: time-limit first, then alarms,
/// then unlock override, because dropping the time-limit alone is the
/// most user-visible signal that "this educator no longer controls me".
///
/// All operations are best-effort: a failure on one collection doesn't
/// block the others, since the roster removal that triggered this cascade
/// already succeeded. Failures are swallowed silently — the next removal
/// will retry.
class EducatorPolicyCascade {
  const EducatorPolicyCascade._();

  /// Drop the time-limit, alarms, and unlock override that [setterProfileId]
  /// configured for [childProfileId]. Other educators' policies on the same
  /// child stay intact (their `setter_profile_id` won't match).
  static Future<void> dropPoliciesSetBy({
    required String setterProfileId,
    required String childProfileId,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final db = FirebaseService.db;

    // 1. Time limit — single doc keyed by child profile id.
    try {
      final limitDoc =
          await db.collection('child_time_limits').doc(childProfileId).get();
      if (limitDoc.exists &&
          (limitDoc.data()?['setter_profile_id'] as String?) ==
              setterProfileId) {
        await limitDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking: roster removal already landed.
    }

    // 2. Alarms — N docs per child; filter by setter so we only clear
    //    the ones this educator owns.
    try {
      final alarms = await db
          .collection('child_alarms')
          .where('child_profile_id', isEqualTo: childProfileId)
          .where('setter_profile_id', isEqualTo: setterProfileId)
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

    // 3. Unlock override — single doc keyed by child profile id.
    try {
      final overrideDoc = await db
          .collection('child_unlock_overrides')
          .doc(childProfileId)
          .get();
      if (overrideDoc.exists &&
          (overrideDoc.data()?['setter_profile_id'] as String?) ==
              setterProfileId) {
        await overrideDoc.reference.delete();
      }
    } catch (_) {
      // Non-blocking.
    }
  }
}
