import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/services/educator_policy_cascade.dart';
import '../../../core/services/firebase_service.dart';
import '../../../data/local/hive_service.dart';
import '../../routine/models/routine_models.dart';
import '../../routine/services/routine_service.dart';
import '../models/assessment_models.dart';
import 'assessment_media_store.dart';
import 'assessment_service.dart';

/// Clears what a teacher or parent made for learners who have since deleted
/// their own profiles.
///
/// A learner's tablet removes everything the learner owns when their profile
/// is deleted — their results and their video answers among it. What their
/// educator made for them belongs to the educator: the learner's place and
/// feedback on an assignment, the routines set for them, and the pictures,
/// videos and sounds on both; the time limit, alarms, unlock and routine-day
/// actions set for them, and the notes written about them. The rules let
/// only the educator's own device
/// change those, so this runs there, at sync, and notices who is gone.
///
/// Careful by construction, because what it removes cannot come back: a
/// learner counts as gone only when the SERVER says their profile does not
/// exist, and never while their profile is on this device (a learner made
/// offline whose profile has not reached the cloud yet looks the same from
/// the server's side). Anything it cannot check, it leaves.
class DeletedLearnerCleanup {
  const DeletedLearnerCleanup();

  /// Test seams: which of the ids have no profile on the server; and the
  /// routines this educator has set.
  static Future<Set<String>> Function(Set<String> ids)? debugMissingProfiles;
  static Future<List<Routine>> Function(String setterId)? debugRoutines;

  /// Test seams: the learners this educator set a policy for (a time limit,
  /// alarm, unlock or routine-day action); and forgetting one learner's.
  static Future<Set<String>> Function(String setterId)? debugPolicyLearners;
  static Future<void> Function(String setterId, String learnerId)?
  debugForgetLearner;

  /// What becomes of [assignments] once the [gone] learners leave them:
  /// the ones that keep other learners lose these learners' places and
  /// feedback, the ones left with nobody are deleted, and [media] is the
  /// feedback files that go with the removed feedback. Pure.
  static ({
    List<AssessmentAssignment> update,
    List<AssessmentAssignment> remove,
    Set<String> media,
  })
  planAssignments(Iterable<AssessmentAssignment> assignments, Set<String> gone) {
    final update = <AssessmentAssignment>[];
    final remove = <AssessmentAssignment>[];
    final media = <String>{};
    for (final a in assignments) {
      final leaving = a.studentIds.where(gone.contains).toSet();
      if (leaving.isEmpty) continue;
      if (leaving.length == a.studentIds.toSet().length) {
        remove.add(a);
        continue;
      }
      update.add(a.withoutLearners(leaving));
      for (final id in leaving) {
        media.addAll(a.feedbackFor(id)?.media.storedValues ?? const {});
      }
    }
    return (update: update, remove: remove, media: media);
  }

  /// The routines among [routines] set for a learner who is [gone]. Pure.
  static List<Routine> routinesFor(Iterable<Routine> routines, Set<String> gone) =>
      [for (final r in routines) if (gone.contains(r.childProfileId)) r];

  /// Which of [ids] have no profile document, asked of the server itself.
  /// Throws when it cannot be reached.
  static Future<Set<String>> missingProfiles(Set<String> ids) async {
    final seam = debugMissingProfiles;
    if (seam != null) return seam(ids);
    final found = <String>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, (i + 30).clamp(0, list.length));
      final snap = await FirebaseService.db
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(const GetOptions(source: Source.server));
      found.addAll(snap.docs.map((d) => d.id));
    }
    return ids.difference(found);
  }

  /// Checks [educatorId]'s assignments and routines and clears what was made
  /// for learners who are gone. The writes go through [saveAssignment] and
  /// [deleteAssignment] (the assignments notifier, so its list repaints and a
  /// deleted assignment's files go with it). Never throws.
  Future<({int assignments, int routines})> run(
    String educatorId, {
    required Future<CloudSyncOutcome> Function(AssessmentAssignment) saveAssignment,
    required Future<CloudSyncOutcome> Function(String assignmentId)
    deleteAssignment,
  }) async {
    const nothing = (assignments: 0, routines: 0);
    if (educatorId.isEmpty) return nothing;
    if (!FirebaseService.isConfigured && debugMissingProfiles == null) {
      return nothing;
    }
    try {
      final assignments = AssessmentService.getAssignments(educatorId);
      List<Routine> routines;
      try {
        routines = await (debugRoutines ??
                const RoutineService().listBySetterFromServer)(educatorId);
      } on Object {
        routines = const [];
      }

      Set<String> policyLearners;
      try {
        policyLearners = await (debugPolicyLearners ?? _policyLearners)(
          educatorId,
        );
      } on Object {
        policyLearners = const {};
      }

      final candidates = <String>{
        for (final a in assignments) ...a.studentIds,
        for (final r in routines) r.childProfileId,
        ...policyLearners,
      }..removeWhere((id) => id.isEmpty || _isOnThisDevice(id));
      if (candidates.isEmpty) return nothing;

      final gone = await missingProfiles(candidates);
      if (gone.isEmpty) return nothing;

      final plan = planAssignments(assignments, gone);
      for (final a in plan.update) {
        await saveAssignment(a);
      }
      if (plan.media.isNotEmpty) {
        await const AssessmentMediaStore().discardUnreferenced(plan.media);
      }
      for (final a in plan.remove) {
        await deleteAssignment(a.id);
      }
      final stale = routinesFor(routines, gone);
      for (final r in stale) {
        await const RoutineService().delete(r.id, known: r);
      }
      for (final id in gone) {
        await (debugForgetLearner ?? _forgetLearner)(educatorId, id);
      }
      return (
        assignments: plan.update.length + plan.remove.length,
        routines: stale.length,
      );
    } on Object catch (e) {
      // Offline, or a read refused: try again next sync.
      if (kDebugMode) debugPrint('DeletedLearnerCleanup skipped: $e');
      return nothing;
    }
  }

  /// The learners [setterId] set a time limit, alarm, unlock or
  /// routine-day action for, asked of the server.
  static Future<Set<String>> _policyLearners(String setterId) async {
    if (!FirebaseService.isConfigured) return const {};
    final db = FirebaseService.db;
    const server = GetOptions(source: Source.server);
    final out = <String>{};
    // Keyed by the learner.
    for (final col in const ['child_time_limits', 'child_unlock_overrides']) {
      final snap = await db
          .collection(col)
          .where('setter_profile_id', isEqualTo: setterId)
          .get(server);
      out.addAll(snap.docs.map((d) => d.id));
    }
    // Naming the learner.
    for (final col in const ['child_alarms', 'routine_actions']) {
      final snap = await db
          .collection(col)
          .where('setter_profile_id', isEqualTo: setterId)
          .get(server);
      for (final d in snap.docs) {
        final id = d.data()['child_profile_id'];
        if (id is String && id.isNotEmpty) out.add(id);
      }
    }
    return out;
  }

  /// Removes what [setterId] set or wrote for [learnerId] outside
  /// assignments and routines. Best-effort, each part on its own.
  static Future<void> _forgetLearner(String setterId, String learnerId) async {
    if (!FirebaseService.isConfigured) return;
    await EducatorPolicyCascade.dropPoliciesSetBy(
      setterProfileId: setterId,
      childProfileId: learnerId,
    );
    final db = FirebaseService.db;
    Future<void> deleteAll(Query<Map<String, dynamic>> query) async {
      try {
        final snap = await query.get();
        for (final d in snap.docs) {
          try {
            await d.reference.delete();
          } on Object {
            // The next sync tries again.
          }
        }
      } on Object {
        // Offline or refused: the next sync tries again.
      }
    }

    await deleteAll(
      db
          .collection('routine_actions')
          .where('child_profile_id', isEqualTo: learnerId)
          .where('setter_profile_id', isEqualTo: setterId),
    );
    final uid = FirebaseService.currentUid;
    if (uid != null && uid.isNotEmpty) {
      await deleteAll(
        db
            .collection('parent_teacher_notes')
            .doc(learnerId)
            .collection('notes')
            .where('author_uid', isEqualTo: uid),
      );
    }
  }

  static bool _isOnThisDevice(String profileId) {
    try {
      return HiveService.getProfileById(profileId) != null;
    } on Object {
      // No profile store (a test harness): treat as present, so nothing goes.
      return true;
    }
  }
}
