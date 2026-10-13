import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/services/educator_roster_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../data/local/hive_service.dart';
import '../models/assessment_models.dart';
import 'assessment_service.dart';

// `CloudSyncOutcome` moved to core when Routines needed the same three-way
// answer. Re-exported so the screens and tests that already import it through
// this service keep compiling.
export '../../../core/services/cloud_sync_outcome.dart'
    show CloudSyncOutcome, isOwnershipRefusalError, outcomeForError;

/// Mirrors the assessment module between Hive and Firestore, so the
/// educator → learner assignment loop closes across devices instead of only
/// on a shared tablet.
///
/// Three collections, each a flat top-level doc so the security rules can pin
/// writes to a profile the caller owns:
///
/// * `assessments/{assessmentId}` — the template. Readable by any signed-in
///   user because a learner has to fetch a template their educator wrote.
/// * `assessment_assignments/{assignmentId}` — carries `studentIds` and, since
///   1.2.2, `student_uids` (the learners' device uids). A learner finds their
///   own work by their uid — a query the rules can hold to that one learner,
///   which `studentIds` (profile ids) never can be. The rules closed the
///   older `studentIds` lookup on 2026-10-04 (see firestore.rules); the
///   educator's hydrate fills `student_uids` in on work set before 1.2.2.
/// * `assessment_results/{resultId}` — the learner's answers, which the
///   educator reads back to fill in Assignment Tracking.
///
/// **Local-first, cloud best-effort.** Every write lands in Hive first, so the
/// UI updates immediately and nothing is lost offline; the Firestore write is
/// fire-and-forget and a failure is logged, never surfaced — the same contract
/// [ParentTeacherNotesCloudService] uses.
///
/// **Deletes are tombstoned**, which is where this diverges from the notes
/// service. A delete that cannot reach Firestore records the id locally so the
/// next pull will not resurrect it and the next connected hydrate retries the
/// remote delete. See `AssessmentService.getPendingDeletions`.
///
/// Hydration is one-shot and pull-then-push: screens call it on open, it
/// unions the cloud into Hive (see `AssessmentService.merge*`, which never let
/// a pull wipe work created here while offline) and then re-uploads the local
/// rows the cloud is missing, so anything written during an offline window
/// still reaches it on the next connected open. That applies to all three
/// record types — an educator's templates and assignments, and a learner's
/// results — because each is written by, and only writable by, its own side.
///
/// **One profile syncs from one device at a time.** Restoring a profile with
/// its recovery code re-stamps `profiles/{id}.owner_uid` to the new device,
/// and every rule here pins writes to the owning uid — so the device it was
/// restored away from keeps working locally but can no longer write to the
/// cloud for that profile. That is the intended design, not a bug to route
/// around; see `docs/multi_device_sync.md`. What this service owes the user is
/// honesty about it, which is [CloudSyncOutcome.notOwner].
class AssessmentCloudService {
  const AssessmentCloudService();

  /// Whether Firestore refused this write outright, as opposed to not being
  /// reachable. Kept as a static so the existing call sites read unchanged;
  /// the logic lives in `core/services/cloud_sync_outcome.dart`.
  static bool isOwnershipRefusal(Object e) => isOwnershipRefusalError(e);

  static const String assessmentsCollection = 'assessments';
  static const String assignmentsCollection = 'assessment_assignments';
  static const String resultsCollection = 'assessment_results';

  /// Firestore's cap on the values of a `whereIn` / `arrayContainsAny` filter.
  static const int _whereInLimit = 30;

  /// Names per query for documents asked for by id. The rules count each
  /// name as a document read, and a request may make 20 in all, lookups
  /// included: 21 names are refused whatever the rules say, and 30 (this
  /// service's chunk before 1.4.1) refused every pull of more than 20.
  static const int _byIdLimit = 10;

  /// The assigned learners' device uids, beside `studentIds`.
  static const String studentUidsField = 'student_uids';

  /// Profile id → owning device uid, looked up this run.
  static final Map<String, String> _ownerUidCache = {};

  /// The device uids that own [learnerIds]' profiles, sorted. Best-effort and
  /// never throws: a profile that cannot be read right now is left out, and
  /// the educator's next hydrate fills it in.
  Future<List<String>> _ownerUidsOf(Iterable<String> learnerIds) async {
    final ids = learnerIds.toSet();
    final missing = ids.where((id) => !_ownerUidCache.containsKey(id));
    await Future.wait(missing.map((id) async {
      try {
        final doc = await _db
            .collection('profiles')
            .doc(id)
            .get()
            .timeout(remoteTimeout);
        final uid = doc.data()?['owner_uid'];
        if (uid is String && uid.isNotEmpty) _ownerUidCache[id] = uid;
      } catch (_) {}
    }));
    return {
      for (final id in ids)
        if (_ownerUidCache[id] != null) _ownerUidCache[id]!,
    }.toList()
      ..sort();
  }

  /// Puts [learnerIds] on this device's roster before an assignment names
  /// them: since 1.4.1 the rules take an assignment only when every learner
  /// and device it names is on the setter's roster. Each is filed under
  /// the class or family group of [educatorId] they are in ('device' for a
  /// learner on this tablet). Best effort; their uids come from
  /// [_ownerUidsOf], which must have run. Returns those now on the roster
  /// with their uids, or null when the roster could not be read.
  Future<Map<String, String>?> _ensureRostered(
    String educatorId,
    Iterable<String> learnerIds,
  ) async {
    final uids = <String, String>{
      for (final id in learnerIds) id: ?_ownerUidCache[id],
    };
    if (uids.isEmpty) return const {};
    return const EducatorRosterService().ensure(
      uids,
      viaOf: (id) => _groupOf(educatorId, id),
    );
  }

  /// The class or family group of [educatorId] that [learnerId] is in, as
  /// this device has it cached; 'device' for a learner on this tablet.
  static String _groupOf(String educatorId, String learnerId) {
    try {
      for (final c in HiveService.getClassroomsByTeacher(educatorId)) {
        if (HiveService.getMembers(c.id).any((m) => m.profileId == learnerId)) {
          return c.id;
        }
      }
      for (final g in HiveService.getHomeGroupsByOwner(educatorId)) {
        if (HiveService.getHomeGroupMembers(g.id)
            .any((m) => m.profileId == learnerId)) {
          return g.id;
        }
      }
      if (HiveService.getProfileById(learnerId) != null) return 'device';
    } catch (_) {
      // Boxes not open (tests): the note is only this device's own.
    }
    return 'assigned';
  }

  /// [learnerId]'s assignments out of the two lookups — by this device's uid,
  /// and the older `studentIds` one ([byLegacy] is null once the rules refuse
  /// it) — each once, and only theirs: a tablet shared by two learners gets
  /// both learners' work back from the uid lookup.
  @visibleForTesting
  static List<AssessmentAssignment> assignmentsForLearner(
    String learnerId, {
    required List<AssessmentAssignment> byUid,
    required List<AssessmentAssignment>? byLegacy,
  }) {
    final byId = <String, AssessmentAssignment>{};
    for (final a in [...byUid, ...?byLegacy]) {
      if (a.studentIds.contains(learnerId)) byId[a.id] = a;
    }
    return byId.values.toList();
  }

  /// Only the work set by one of the learner's own educators.
  ///
  /// The cloud lets any device file an assignment naming a learner (their
  /// device id and profile id are enough), so a stranger could put a "test"
  /// of their own words and pictures in front of a child. [educatorIds] are
  /// the teachers of the classes and the owners of the family groups the
  /// learner belongs to; an assignment made on this same tablet
  /// ([isLocalProfile], a shared classroom tablet) is theirs too. Null when
  /// they could not be told (offline, a failed lookup): then nothing is
  /// dropped, because hiding a real test is worse than one stray one.
  @visibleForTesting
  static List<AssessmentAssignment> fromOwnEducators(
    List<AssessmentAssignment> assignments, {
    required Set<String>? educatorIds,
    required bool Function(String profileId) isLocalProfile,
  }) {
    if (educatorIds == null) return assignments;
    return [
      for (final a in assignments)
        if (educatorIds.contains(a.assignedBy) || isLocalProfile(a.assignedBy))
          a,
    ];
  }

  /// The teachers of [learnerId]'s classes and the owners of their family
  /// groups, as the server knows them. Null unless the server answered every
  /// lookup (see [fromOwnEducators]).
  Future<Set<String>?> _learnerEducators(String learnerId) async {
    try {
      Future<Set<String>> owners(
        String members,
        String groups,
        String groupField,
        String ownerField,
      ) async {
        final snap = await _db
            .collection(members)
            .where('profile_id', isEqualTo: learnerId)
            .get(const GetOptions(source: Source.server))
            .timeout(remoteTimeout);
        final out = <String>{};
        for (final m in snap.docs) {
          final groupId = m.data()[groupField] as String?;
          if (groupId == null || groupId.isEmpty) continue;
          final g = await _db
              .collection(groups)
              .doc(groupId)
              .get(const GetOptions(source: Source.server))
              .timeout(remoteTimeout);
          final owner = g.data()?[ownerField] as String?;
          if (owner != null && owner.isNotEmpty) out.add(owner);
        }
        return out;
      }

      final teachers = await owners(
        'classroom_members',
        'classrooms',
        'classroom_id',
        'teacher_id',
      );
      final parents = await owners(
        'home_group_members',
        'home_groups',
        'home_group_id',
        'owner_profile_id',
      );
      return {...teachers, ...parents};
    } catch (e, s) {
      _log('learnerEducators', e, s);
      return null;
    }
  }

  /// How long any single Firestore call may take before it is treated as
  /// "did not reach the cloud".
  ///
  /// **A Firestore write future does not complete while offline.** The SDK
  /// queues the write locally and resolves the future only once the server
  /// acknowledges it, so an `await ... .set()` with no network hangs forever —
  /// which is exactly what left the Assign button stuck on "Assigning…" and
  /// meant the honest "not sent yet" message never appeared in the one case
  /// that matters most. Time-boxing every remote call turns that hang into a
  /// clean [CloudSyncOutcome.localOnly].
  ///
  /// Nothing is lost by giving up early: the queued write still flushes on its
  /// own when the connection returns, and `_pushMissing*` re-uploads on the
  /// next connected open whatever didn't.
  static const Duration remoteTimeout = Duration(seconds: 5);

  FirebaseFirestore get _db => FirebaseService.db;

  bool get _enabled => FirebaseService.isConfigured;

  void _log(String what, Object error, StackTrace stack) {
    // Deliberately not routed through ErrorHandler: a sync hiccup must never
    // put a "Something went wrong" banner in front of a teacher mid-lesson.
    if (kDebugMode) {
      debugPrint('AssessmentCloudService.$what failed: $error');
      debugPrint(stack.toString());
    }
  }

  // ─── Writes ─────────────────────────────────────────────

  /// Save a template locally, then mirror it. [ownerProfileId] is the educator
  /// whose Hive bucket holds it, and is what the security rule checks — not
  /// `Assessment.createdBy`, which legacy rows set to the literal `'teacher'`.
  Future<void> saveAssessment(
    String ownerProfileId,
    Assessment assessment,
  ) async {
    await AssessmentService.saveAssessment(ownerProfileId, assessment);
    if (!_enabled) return;
    try {
      await _db
          .collection(assessmentsCollection)
          .doc(assessment.id)
          .set({
            ...assessment.toJson(),
            'created_by_profile_id': ownerProfileId,
            'owner_uid': FirebaseService.currentUid,
          })
          .timeout(remoteTimeout);
      await AssessmentService.markSynced('assessments_$ownerProfileId', [
        assessment.id,
      ]);
    } catch (e, s) {
      _log('saveAssessment', e, s);
    }
  }

  /// Delete a template locally and in the cloud.
  ///
  /// The tombstone is written *before* the local delete and cleared only once
  /// Firestore confirms, so a delete that fails offline is neither forgotten
  /// nor undone by the next pull.
  Future<CloudSyncOutcome> deleteAssessment(
    String ownerProfileId,
    String assessmentId,
  ) async {
    final bucket = 'assessments_$ownerProfileId';
    await AssessmentService.markDeleted(bucket, assessmentId);
    await AssessmentService.deleteAssessment(ownerProfileId, assessmentId);
    if (!_enabled) return CloudSyncOutcome.localOnly;
    try {
      await _db
          .collection(assessmentsCollection)
          .doc(assessmentId)
          .delete()
          .timeout(remoteTimeout);
      await AssessmentService.clearDeletion(bucket, assessmentId);
      await AssessmentService.unmarkSynced(bucket, [assessmentId]);
      return CloudSyncOutcome.synced;
    } catch (e, s) {
      _log('deleteAssessment', e, s);
      return isOwnershipRefusal(e)
          ? CloudSyncOutcome.notOwner
          : CloudSyncOutcome.localOnly;
    }
  }

  /// Save an assignment locally, then mirror it, reporting which happened.
  Future<CloudSyncOutcome> saveAssignment(
    String educatorId,
    AssessmentAssignment assignment,
  ) async {
    await AssessmentService.saveAssignment(educatorId, assignment);
    if (!_enabled) return CloudSyncOutcome.localOnly;
    try {
      final learnerUids = await _ownerUidsOf(assignment.studentIds);
      await _ensureRostered(educatorId, assignment.studentIds);
      await _db
          .collection(assignmentsCollection)
          .doc(assignment.id)
          .set({
            ...assignment.toJson(),
            studentUidsField: learnerUids,
            'owner_uid': FirebaseService.currentUid,
          })
          .timeout(remoteTimeout);
      await AssessmentService.markSynced('assignments_$educatorId', [
        assignment.id,
      ]);
      return CloudSyncOutcome.synced;
    } catch (e, s) {
      _log('saveAssignment', e, s);
      return isOwnershipRefusal(e)
          ? CloudSyncOutcome.notOwner
          : CloudSyncOutcome.localOnly;
    }
  }

  /// Delete an assignment locally and in the cloud. See [deleteAssessment]
  /// for why the tombstone is written first.
  Future<CloudSyncOutcome> deleteAssignment(
    String educatorId,
    String assignmentId,
  ) async {
    final bucket = 'assignments_$educatorId';
    await AssessmentService.markDeleted(bucket, assignmentId);
    await AssessmentService.deleteAssignment(educatorId, assignmentId);
    if (!_enabled) return CloudSyncOutcome.localOnly;
    try {
      await _db
          .collection(assignmentsCollection)
          .doc(assignmentId)
          .delete()
          .timeout(remoteTimeout);
      await AssessmentService.clearDeletion(bucket, assignmentId);
      await AssessmentService.unmarkSynced(bucket, [assignmentId]);
      return CloudSyncOutcome.synced;
    } catch (e, s) {
      _log('deleteAssignment', e, s);
      return isOwnershipRefusal(e)
          ? CloudSyncOutcome.notOwner
          : CloudSyncOutcome.localOnly;
    }
  }

  /// Saves [result] on the device, then uploads it. Returns false when the
  /// upload did not go through (the result is safe locally either way), so
  /// the caller can make sure it is pushed once the connection returns —
  /// see [AssessmentResultsNotifier.saveResult].
  /// Replaces a result already saved — locally, then in the cloud (the
  /// learner's own document, which the rules let their device update).
  Future<bool> updateResult(String learnerId, AssessmentResult result) async {
    await AssessmentService.replaceResult(learnerId, result);
    if (!_enabled) return true;
    try {
      await _db
          .collection(resultsCollection)
          .doc(result.id)
          .set({...result.toJson(), 'owner_uid': FirebaseService.currentUid})
          .timeout(remoteTimeout);
      return true;
    } catch (e, s) {
      _log('updateResult', e, s);
      return false;
    }
  }

  Future<bool> saveResult(String learnerId, AssessmentResult result) async {
    await AssessmentService.saveResult(learnerId, result);
    if (!_enabled) return true;
    try {
      await _db
          .collection(resultsCollection)
          .doc(result.id)
          .set({...result.toJson(), 'owner_uid': FirebaseService.currentUid})
          .timeout(remoteTimeout);
      return true;
    } catch (e, s) {
      _log('saveResult', e, s);
      return false;
    }
  }

  // ─── Hydration ──────────────────────────────────────────

  /// Pull everything this educator needs to run Assign Tasks and Assignment
  /// Tracking: their own templates, their own assignments, and the results
  /// their assignees have submitted from any device.
  ///
  /// True only when the pull completed and the server itself answered for
  /// the templates and the assignments — the point at which this tablet
  /// holds everything the educator made, which is what the orphaned-file
  /// sweep needs to know before it deletes anything.
  Future<bool> hydrateEducator(String educatorId) async {
    if (!_enabled || educatorId.isEmpty) return false;
    try {
      // Replay first, so the pull below reflects the deletes this device made
      // offline rather than handing them straight back.
      await _replayPendingDeletions(educatorId);

      final assessmentDocs = await _db
          .collection(assessmentsCollection)
          .where('created_by_profile_id', isEqualTo: educatorId)
          .get()
          .timeout(remoteTimeout);
      final cloudAssessments = _decode(assessmentDocs.docs, Assessment.fromJson);
      await AssessmentService.mergeAssessments(educatorId, cloudAssessments);

      final assignmentDocs = await _db
          .collection(assignmentsCollection)
          .where('assignedBy', isEqualTo: educatorId)
          .get()
          .timeout(remoteTimeout);
      final cloudAssignments =
          _decode(assignmentDocs.docs, AssessmentAssignment.fromJson);
      await AssessmentService.mergeAssignments(educatorId, cloudAssignments);
      await _backfillLearnerUids(educatorId, assignmentDocs.docs);

      // Everyone this educator has ever set work for. Their results are what
      // turns a tracking row from Pending into a score.
      final assignees = AssessmentService.getAssignments(educatorId)
          .expand((a) => a.studentIds)
          .toSet();
      await _pullResultsFor(assignees);

      final cloudAssessmentIds = cloudAssessments.map((a) => a.id).toSet();
      final cloudAssignmentIds = cloudAssignments.map((a) => a.id).toSet();

      // Whether each answer is authoritative. `get()` falls back to Firestore's
      // local cache when the server is unreachable and returns whatever is
      // cached — possibly nothing — *without throwing*, so an empty result is
      // not by itself evidence that the cloud is empty. Only a server-sourced
      // snapshot may be read as "these are all the rows that exist".
      final assessmentsAuthoritative = !assessmentDocs.metadata.isFromCache;
      final assignmentsAuthoritative = !assignmentDocs.metadata.isFromCache;
      await AssessmentService.markSynced(
        'assessments_$educatorId',
        cloudAssessmentIds,
      );
      await AssessmentService.markSynced(
        'assignments_$educatorId',
        cloudAssignmentIds,
      );

      await _reconcile(
        educatorId,
        cloudAssessmentIds: cloudAssessmentIds,
        cloudAssignmentIds: cloudAssignmentIds,
        assessmentsAuthoritative: assessmentsAuthoritative,
        assignmentsAuthoritative: assignmentsAuthoritative,
      );
      return assessmentsAuthoritative && assignmentsAuthoritative;
    } catch (e, s) {
      _log('hydrateEducator', e, s);
      return false;
    }
  }

  /// Pull the work assigned to this learner from any educator, plus the
  /// templates those assignments point at, so the hub can open them.
  ///
  /// Returns false when the pull failed — a timeout on a slow classroom
  /// network is the usual case — so [LearnerAssignmentSync] can try again
  /// rather than leave assigned work invisible until the app is reopened.
  /// True when it completed, or when there is nothing to pull from.
  Future<bool> hydrateLearner(String learnerId) async {
    if (!_enabled || learnerId.isEmpty) return true;
    try {
      final mine = await _queryLearnerAssignments(learnerId);
      final assignments = mine.assignments;

      // Work withdrawn elsewhere has to stop nagging here. Only a
      // server-sourced snapshot may be read as "this is all of their work" —
      // see [classifyLocalRows] for why a cached answer cannot be trusted.
      if (mine.complete) {
        await AssessmentService.withdrawLearnerFromAssignmentsExcept(
          learnerId,
          assignments.map((a) => a.id).toSet(),
        );
      }

      if (assignments.isNotEmpty) {
        // Assignments are stored under the educator who made them, which is
        // also where `getAssignmentsForStudent` scans for them.
        final byEducator = <String, List<AssessmentAssignment>>{};
        for (final a in assignments) {
          byEducator.putIfAbsent(a.assignedBy, () => []).add(a);
        }
        for (final entry in byEducator.entries) {
          await AssessmentService.mergeAssignments(entry.key, entry.value);
        }

        await _pullTemplates(
          assignments.map((a) => a.assessmentId).toSet(),
          byEducator,
        );
      }

      // Their own results, in both directions, and NOT gated on having any
      // assignments — a learner with none still has results worth syncing.
      //
      // Pull: `getPendingAssignments` decides what is still outstanding by
      // comparing against them, so work sat on the family tablet would
      // otherwise keep nagging on the school one.
      //
      // Push: a result submitted with no signal reaches Firestore *only*
      // here. Without it an offline completion stayed on the learner's device
      // for good and their educator's tracking row never left Pending.
      final cloudResultIds = await _pullResultsFor({learnerId});
      await _pushMissingResults(learnerId, knownResultIds: cloudResultIds);
      return true;
    } catch (e, s) {
      _log('hydrateLearner', e, s);
      return false;
    }
  }

  /// Every assignment naming [learnerId], live, as [revisionKey]s.
  ///
  /// A Firestore listener rather than a poll: it costs one read per document
  /// that actually changes, it reconnects by itself when a classroom network
  /// drops and comes back, and it tells a learner's tablet about new work the
  /// moment the teacher presses Assign — without the learner having to leave
  /// and reopen the app. Empty (never emits) without Firebase.
  ///
  /// Keyed by revision, not bare id, so feedback an educator writes on work
  /// the learner already has — an FSL video telling a Deaf child how they
  /// did — also arrives while the app is open. Compared against the same key
  /// computed from this device's copy, so an unchanged row costs nothing.
  ///
  /// Two listeners — by this device's uid, and the older `studentIds` one —
  /// merged. The older one being refused (the rules closing it) is expected
  /// and only silences it; any other error ends the stream, as before.
  Stream<Set<String>> watchLearnerAssignmentIds(String learnerId) {
    if (!_enabled || learnerId.isEmpty) return const Stream.empty();
    final uid = FirebaseService.currentUid;
    final out = StreamController<Set<String>>();
    var byUid = const <AssessmentAssignment>[];
    final subs = <StreamSubscription<Object?>>[];
    void emit() {
      if (out.isClosed) return;
      out.add({
        for (final a in assignmentsForLearner(
          learnerId,
          byUid: byUid,
          byLegacy: null,
        ))
          revisionKey(a, learnerId),
      });
    }

    out.onListen = () {
      if (uid != null) {
        subs.add(_db
            .collection(assignmentsCollection)
            .where(studentUidsField, arrayContains: uid)
            .snapshots()
            .listen((snap) {
              byUid = _decode(snap.docs, AssessmentAssignment.fromJson);
              emit();
            }, onError: out.addError));
      }
      // The older `studentIds` lookup is closed by the rules (2026-10-04):
      // asking would only ever be refused.
    };
    out.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return out.stream;
  }

  /// `<id>@<this learner's feedback>@<shared media>` — the parts of an
  /// assignment that can change after it is handed out: feedback written
  /// later, and a file picked offline that has since been shared (its value
  /// turns from `file://` into `shared://`, and the learner's copy must
  /// follow or their tablet keeps a file it can never open).
  static String revisionKey(AssessmentAssignment a, String learnerId) {
    final feedback = a.feedbackFor(learnerId);
    final media = [
      ...a.media.storedValues,
      ...?feedback?.media.storedValues,
    ]..sort();
    return '${a.id}@${feedback?.updatedAt.toIso8601String() ?? ''}'
        '@${media.join(',')}'
        '@${a.assessmentEditedAt?.toIso8601String() ?? ''}';
  }

  // ─── Internals ──────────────────────────────────────────

  /// Gives this educator's assignments the learner uids they are missing:
  /// work set before 1.2.2, or a learner whose profile moved to another
  /// tablet — a learner finds their work only by uid since the rules closed
  /// the old `studentIds` lookup. Best-effort, on its own: a refused or
  /// offline update must not stop the rest of the hydrate. Since 1.4.1 the
  /// rules take only the devices of learners on [educatorId]'s device's
  /// roster, so those go on it first and nobody else's device is added.
  Future<void> _backfillLearnerUids(
    String educatorId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      // Fresh lookups: a learner restored elsewhere has a new uid.
      _ownerUidCache.clear();
      final updates = <(DocumentReference<Map<String, dynamic>>, List<String>)>[];
      for (final d in docs) {
        final data = d.data();
        final learners =
            (data['studentIds'] as List?)?.whereType<String>() ?? const [];
        var want = await _ownerUidsOf(learners);
        final onRoster = await _ensureRostered(educatorId, learners);
        if (onRoster != null) {
          final rostered = onRoster.values.toSet();
          want = [for (final uid in want) if (rostered.contains(uid)) uid];
        }
        final have = [
          ...?(data[studentUidsField] as List?)?.whereType<String>(),
        ]..sort();
        if (want.isEmpty || listEquals(want, have)) continue;
        updates.add((d.reference, want));
      }
      await _commitAll([
        for (final (ref, uids) in updates) (ref, {studentUidsField: uids}),
      ], update: true);
    } catch (e, s) {
      _log('backfillLearnerUids', e, s);
    }
  }

  /// [learnerId]'s assignments, found by this device's uid (`student_uids`;
  /// the older `studentIds` lookup is closed by the rules since 2026-10-04).
  /// `complete` only when the server answered — the condition for treating
  /// the list as all of their work.
  Future<({List<AssessmentAssignment> assignments, bool complete})>
  _queryLearnerAssignments(String learnerId) async {
    final uid = FirebaseService.currentUid;
    QuerySnapshot<Map<String, dynamic>>? byUid;
    if (uid != null) {
      byUid = await _db
          .collection(assignmentsCollection)
          .where(studentUidsField, arrayContains: uid)
          .get()
          .timeout(remoteTimeout);
    }
    final mine = assignmentsForLearner(
      learnerId,
      byUid: byUid == null
          ? const []
          : _decode(byUid.docs, AssessmentAssignment.fromJson),
      byLegacy: null,
    );
    final educators = mine.isEmpty ? null : await _learnerEducators(learnerId);
    final assignments = fromOwnEducators(
      mine,
      educatorIds: educators,
      isLocalProfile: (id) {
        try {
          return HiveService.getProfileById(id) != null;
        } on Object {
          return false;
        }
      },
    );
    return (
      assignments: assignments,
      complete: byUid != null && !byUid.metadata.isFromCache,
    );
  }

  List<T> _decode<T>(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final out = <T>[];
    for (final doc in docs) {
      final data = doc.data();
      if (data == null) continue;
      try {
        out.add(fromJson(Map<String, dynamic>.from(data)));
      } catch (e, s) {
        // One malformed doc must not cost the learner the rest of their work.
        _log('decode(${doc.id})', e, s);
      }
    }
    return out;
  }

  /// Fetch the templates for [assessmentIds] and file each under the educator
  /// who assigned it, so `findAssessmentById` can resolve it locally.
  Future<void> _pullTemplates(
    Set<String> assessmentIds,
    Map<String, List<AssessmentAssignment>> byEducator,
  ) async {
    final ownerOf = <String, String>{
      for (final entry in byEducator.entries)
        for (final a in entry.value) a.assessmentId: entry.key,
    };
    for (final chunk in _chunks(assessmentIds.toList(), _byIdLimit)) {
      List<DocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        docs = (await _db
                .collection(assessmentsCollection)
                .where(FieldPath.documentId, whereIn: chunk)
                .get()
                .timeout(remoteTimeout))
            .docs;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        // A list the rules cannot prove in one request: one by one.
        docs = [
          for (final id in chunk)
            await _db
                .collection(assessmentsCollection)
                .doc(id)
                .get()
                .timeout(remoteTimeout),
        ].where((d) => d.exists).toList();
      }
      final byOwner = <String, List<Assessment>>{};
      for (final assessment in _decode(docs, Assessment.fromJson)) {
        final owner = ownerOf[assessment.id];
        if (owner == null) continue;
        byOwner.putIfAbsent(owner, () => []).add(assessment);
      }
      for (final entry in byOwner.entries) {
        await AssessmentService.mergeAssessments(entry.key, entry.value);
      }
    }
  }

  /// Pulls results for [learnerIds] into Hive and returns the ids the cloud
  /// already held, so a caller can work out what still needs uploading.
  ///
  /// Since 1.4.1 the rules check every learner a query names: one who is no
  /// longer this educator's (they left the class) refuses the whole query,
  /// so a refused one is asked again learner by learner, and only theirs is
  /// left out.
  Future<Set<String>> _pullResultsFor(Set<String> learnerIds) async {
    final seen = <String>{};
    if (learnerIds.isEmpty) return seen;
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> query(
      List<String> ids,
    ) async => (await _db
            .collection(resultsCollection)
            .where('profileId', whereIn: ids)
            .get()
            .timeout(remoteTimeout))
        .docs;
    for (final chunk in _chunks(learnerIds.toList())) {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        docs = await query(chunk);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || chunk.length == 1) rethrow;
        docs = [];
        for (final id in chunk) {
          try {
            docs.addAll(await query([id]));
          } on FirebaseException catch (e) {
            if (e.code != 'permission-denied') rethrow;
          }
        }
      }
      final byLearner = <String, List<AssessmentResult>>{};
      for (final result in _decode(docs, AssessmentResult.fromJson)) {
        seen.add(result.id);
        byLearner.putIfAbsent(result.profileId, () => []).add(result);
      }
      for (final entry in byLearner.entries) {
        await AssessmentService.mergeResults(entry.key, entry.value);
      }
    }
    return seen;
  }

  /// Upload this learner's results that the cloud does not have.
  ///
  /// The learner is the only party the rules let write their own results, so
  /// this is the one place an offline completion can ever be recovered.
  Future<void> _pushMissingResults(
    String learnerId, {
    required Set<String> knownResultIds,
  }) async {
    final uid = FirebaseService.currentUid;
    final missing = AssessmentService.getResults(learnerId)
        .where((r) => !knownResultIds.contains(r.id))
        .toList();
    if (missing.isEmpty) return;

    const perBatch = 400;
    for (var i = 0; i < missing.length; i += perBatch) {
      final batch = _db.batch();
      for (final r in missing.skip(i).take(perBatch)) {
        batch.set(
          _db.collection(resultsCollection).doc(r.id),
          {...r.toJson(), 'owner_uid': uid},
        );
      }
      await batch.commit().timeout(remoteTimeout);
    }
  }

  /// Retry the cloud deletes this device could not complete earlier.
  ///
  /// This is the other half of the tombstone: without it an offline delete
  /// would suppress the row locally forever while the cloud kept serving it to
  /// every other device. A tombstone is cleared only on a confirmed delete, so
  /// a still-failing one simply waits for the next hydrate.
  ///
  /// A delete of a document that is already gone (deleted on the educator's
  /// other tablet, or by the deleted-learner check) is refused too: the rules
  /// read the owner from the document they guard. Such a tombstone used to be
  /// retried at every sync, forever. A refused one is now checked against the
  /// server's own list of this educator's documents and, when its document is
  /// not there, cleared: gone is what it asked for.
  Future<void> _replayPendingDeletions(String educatorId) async {
    final buckets = {
      'assessments_$educatorId': (assessmentsCollection, 'created_by_profile_id'),
      'assignments_$educatorId': (assignmentsCollection, 'assignedBy'),
    };
    for (final MapEntry(key: bucket, value: (collection, owner))
        in buckets.entries) {
      final refused = <String>{};
      for (final id in AssessmentService.getPendingDeletions(bucket)) {
        try {
          await _db
              .collection(collection)
              .doc(id)
              .delete()
              .timeout(remoteTimeout);
          await AssessmentService.clearDeletion(bucket, id);
        } on FirebaseException catch (e, s) {
          _log('replayDelete($collection/$id)', e, s);
          if (e.code == 'permission-denied') refused.add(id);
          // Otherwise leave the tombstone in place and try again next time.
        } catch (e, s) {
          _log('replayDelete($collection/$id)', e, s);
        }
      }
      if (refused.isEmpty) continue;
      try {
        final listed = await _db
            .collection(collection)
            .where(owner, isEqualTo: educatorId)
            .get(const GetOptions(source: Source.server))
            .timeout(remoteTimeout);
        for (final id in alreadyGone(
          refused,
          listed.docs.map((d) => d.id).toSet(),
        )) {
          await AssessmentService.clearDeletion(bucket, id);
        }
      } catch (e, s) {
        _log('replayDelete($collection): listing', e, s);
      }
    }
  }

  /// The refused deletes whose documents the server no longer lists for
  /// this educator: already done. Pure.
  @visibleForTesting
  static Set<String> alreadyGone(Set<String> refused, Set<String> listed) =>
      refused.difference(listed);

  /// Decide what to do with local rows the cloud did not return.
  ///
  /// Pure, and separated out because this is the one piece of the sync that
  /// can *destroy* data — it deserves to be exhaustively testable without a
  /// network.
  ///
  /// A missing row means one of two opposite things, and the synced-id ledger
  /// separates them:
  ///
  /// * **never uploaded** — created here during an offline window. Push it.
  ///   Safe unconditionally: it is this device's own unsynced work.
  /// * **deleted on another device** — it was in the cloud once, so its
  ///   absence is a deletion. Remove it locally, or the teacher who deleted an
  ///   assignment on their laptop finds it still on the classroom tablet.
  ///
  /// That second conclusion is only sound when [cloudIsAuthoritative] — i.e.
  /// the snapshot came from the server rather than Firestore's offline cache.
  /// A cached answer can be empty or stale without any error being raised, and
  /// acting on it would delete a teacher's entire question bank because the
  /// wifi dropped. When it is not authoritative, rows in the ledger are left
  /// exactly as they are: not deleted, and not re-pushed either, since we
  /// cannot tell whether the cloud still has them.
  @visibleForTesting
  static ({Set<String> toDelete, Set<String> toPush}) classifyLocalRows({
    required Set<String> localIds,
    required Set<String> cloudIds,
    required Set<String> syncedIds,
    required bool cloudIsAuthoritative,
  }) {
    final toDelete = <String>{};
    final toPush = <String>{};
    for (final id in localIds) {
      if (cloudIds.contains(id)) continue;
      if (syncedIds.contains(id)) {
        if (cloudIsAuthoritative) toDelete.add(id);
      } else {
        toPush.add(id);
      }
    }
    return (toDelete: toDelete, toPush: toPush);
  }

  /// Settle the difference between this device and the cloud.
  ///
  /// See [classifyLocalRows] for the rules. Local deletes go through the plain
  /// service call, *not* the tombstoning one: this deletion came from the
  /// cloud, so there is nothing left to replay and no reason to suppress the
  /// id if it is ever legitimately re-created.
  Future<void> _reconcile(
    String educatorId, {
    required Set<String> cloudAssessmentIds,
    required Set<String> cloudAssignmentIds,
    required bool assessmentsAuthoritative,
    required bool assignmentsAuthoritative,
  }) async {
    final uid = FirebaseService.currentUid;
    final assessmentBucket = 'assessments_$educatorId';
    final assignmentBucket = 'assignments_$educatorId';

    final assessments = AssessmentService.getAssessments(educatorId);
    final assignments = AssessmentService.getAssignments(educatorId);

    final assessmentPlan = classifyLocalRows(
      localIds: assessments.map((a) => a.id).toSet(),
      cloudIds: cloudAssessmentIds,
      syncedIds: AssessmentService.getSyncedIds(assessmentBucket),
      cloudIsAuthoritative: assessmentsAuthoritative,
    );
    final assignmentPlan = classifyLocalRows(
      localIds: assignments.map((a) => a.id).toSet(),
      cloudIds: cloudAssignmentIds,
      syncedIds: AssessmentService.getSyncedIds(assignmentBucket),
      cloudIsAuthoritative: assignmentsAuthoritative,
    );

    for (final id in assessmentPlan.toDelete) {
      await AssessmentService.deleteAssessment(educatorId, id);
      await AssessmentService.unmarkSynced(assessmentBucket, [id]);
    }
    for (final id in assignmentPlan.toDelete) {
      await AssessmentService.deleteAssignment(educatorId, id);
      await AssessmentService.unmarkSynced(assignmentBucket, [id]);
    }

    final writes = <(DocumentReference<Map<String, dynamic>>,
        Map<String, dynamic>)>[];
    for (final a in assessments) {
      if (!assessmentPlan.toPush.contains(a.id)) continue;
      writes.add((
        _db.collection(assessmentsCollection).doc(a.id),
        {
          ...a.toJson(),
          'created_by_profile_id': educatorId,
          'owner_uid': uid,
        },
      ));
    }
    for (final a in assignments) {
      if (!assignmentPlan.toPush.contains(a.id)) continue;
      final learnerUids = await _ownerUidsOf(a.studentIds);
      await _ensureRostered(educatorId, a.studentIds);
      writes.add((
        _db.collection(assignmentsCollection).doc(a.id),
        {
          ...a.toJson(),
          studentUidsField: learnerUids,
          'owner_uid': uid,
        },
      ));
    }

    if (writes.isEmpty) return;

    final refused = await _commitAll(writes);
    // A refused row stays local and unsynced: it is offered again next time.
    await AssessmentService.markSynced(
      assessmentBucket,
      assessmentPlan.toPush.difference(refused),
    );
    await AssessmentService.markSynced(
      assignmentBucket,
      assignmentPlan.toPush.difference(refused),
    );
  }

  /// Writes [writes] (an update of the given fields when [update], else a
  /// whole document) in batches, and returns the ids the rules refused.
  ///
  /// A batch is all or nothing, so one document the rules refuse held back
  /// every other one: since 1.4.1 an assignment that names a learner no
  /// longer on this educator's roster (one who left, or deleted their
  /// profile) is refused, and with it every template and assignment made
  /// offline alongside it. A refused batch is written again one document at
  /// a time.
  Future<Set<String>> _commitAll(
    List<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
    writes, {
    bool update = false,
  }) async {
    final refused = <String>{};
    // Firestore caps a batch at 500 operations.
    const perBatch = 400;
    for (var i = 0; i < writes.length; i += perBatch) {
      final chunk = writes.skip(i).take(perBatch).toList();
      final batch = _db.batch();
      for (final (ref, data) in chunk) {
        update ? batch.update(ref, data) : batch.set(ref, data);
      }
      try {
        await batch.commit().timeout(remoteTimeout);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        for (final (ref, data) in chunk) {
          try {
            await (update ? ref.update(data) : ref.set(data))
                .timeout(remoteTimeout);
          } on FirebaseException catch (e) {
            if (e.code != 'permission-denied') rethrow;
            refused.add(ref.id);
            _log('commit(${ref.id})', e, StackTrace.current);
          }
        }
      }
    }
    return refused;
  }

  /// Firestore rejects a `whereIn` with more than [_whereInLimit] values.
  ///
  /// A class of thirty-one is not hypothetical, so this is pinned by a test
  /// rather than left to the first teacher who hits it.
  @visibleForTesting
  static Iterable<List<String>> chunkIds(List<String> ids) => _chunks(ids);

  /// [chunkIds] for documents asked for by id: [_byIdLimit] names a query.
  @visibleForTesting
  static Iterable<List<String>> chunkDocIds(List<String> ids) =>
      _chunks(ids, _byIdLimit);

  static Iterable<List<String>> _chunks(
    List<String> ids, [
    int size = _whereInLimit,
  ]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }
}
