import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/shared_media_service.dart';
import '../../../data/local/hive_service.dart';
import '../../routine/services/routine_service.dart';
import 'assessment_service.dart';

/// Deletes files a profile shared that nothing points at any more.
///
/// A file is shared the moment it is picked — so the learner's tablet can
/// have it by the time the teacher presses Save — and the editors tidy up
/// after themselves on save and on cancel. What they cannot tidy is an
/// editor the system closed: Android stops an app in the background, the
/// unsaved test is gone, and its picture or FSL clip stays in the cloud
/// with nothing referring to it (found on a tablet: a 5.5 MB clip and a
/// photo left by one such session).
///
/// So after a sync that is known to be complete, a tablet looks at the files
/// its profile shared, and deletes those that are at least [grace] old and
/// referred to by nothing: no test, assignment, feedback or result on this
/// tablet, no routine here, and no routine in the cloud. The rules let only
/// the profile's own tablet delete its files, so this never reaches past
/// its own. When in doubt — offline, a result history longer than this
/// tablet keeps — it deletes nothing.
class SharedMediaSweep {
  const SharedMediaSweep();

  /// How old an unreferenced file must be before it counts as abandoned —
  /// comfortably longer than anyone keeps an editor open.
  static const Duration grace = Duration(hours: 24);

  /// Test seam: the files [ownerProfileId] shared, with when.
  static Future<List<({String id, DateTime? createdAt})>> Function(
    String ownerProfileId,
  )?
  debugOwned;

  /// Returns how many files it deleted. Never throws.
  Future<int> run(String profileId, {DateTime? now}) async {
    if (profileId.isEmpty) return 0;
    if (!FirebaseService.isConfigured && debugOwned == null) return 0;
    try {
      // A learner's older results fall off this tablet; their video answers
      // would look unreferenced here while the cloud still holds them.
      if (AssessmentService.getResults(profileId).length >=
          AssessmentService.resultsKept) {
        return 0;
      }
      final owned = await (debugOwned ?? _owned)(profileId);
      final cutoff = (now ?? DateTime.now()).subtract(grace);
      final candidates = [
        for (final o in owned)
          if (o.createdAt != null && o.createdAt!.isBefore(cutoff))
            '${SharedMediaService.prefix}${o.id}',
      ];
      if (candidates.isEmpty) return 0;

      final used = <String>{
        ...AssessmentService.referencedMediaValues(),
        ...AssessmentService.resultMediaValues(),
        for (final r in HiveService.getAllCachedRoutines()) ...r.storedMedia,
      };
      var removed = 0;
      for (final value in candidates) {
        if (used.contains(value)) continue;
        if (await const RoutineService().sharedMediaInUse(value)) continue;
        await const SharedMediaService().delete(value);
        removed++;
      }
      return removed;
    } on Object catch (e) {
      if (kDebugMode) debugPrint('SharedMediaSweep skipped: $e');
      return 0;
    }
  }

  static Future<List<({String id, DateTime? createdAt})>> _owned(
    String ownerProfileId,
  ) async {
    final snap = await FirebaseService.db
        .collection(SharedMediaService.collection)
        .where('owner_profile_id', isEqualTo: ownerProfileId)
        .get(const GetOptions(source: Source.server));
    return [
      for (final d in snap.docs)
        (
          id: d.id,
          createdAt: (d.data()['created_at'] as Timestamp?)?.toDate(),
        ),
    ];
  }
}
