import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../services/assessment_cloud_service.dart';
import '../services/assessment_media_publisher.dart';
import '../services/deleted_learner_cleanup.dart';
import '../services/shared_media_sweep.dart';
import '../../../core/services/firebase_service.dart';
import '../services/assessment_media_store.dart';
import '../services/assessment_service.dart';

// ─── Assessment Results Provider ─────────────────────────

class AssessmentResultsNotifier extends StateNotifier<List<AssessmentResult>> {
  final String profileId;
  final AssessmentCloudService cloud;

  /// Called when a result could not be uploaded — a test finished with no
  /// signal. The provider wires it to a learner pull, which pushes whatever
  /// the cloud is missing and, failing that, keeps retrying (see
  /// `LearnerAssignmentSync`), so the educator gets the result once the
  /// tablet is back online without the learner reopening the app.
  final void Function()? onUploadMissed;

  AssessmentResultsNotifier(this.profileId,
      {this.cloud = const AssessmentCloudService(), this.onUploadMissed})
      : super(AssessmentService.getResults(profileId));

  void refresh() {
    state = AssessmentService.getResults(profileId);
  }

  Future<void> saveResult(AssessmentResult result) async {
    final uploaded = await cloud.saveResult(profileId, result);
    state = AssessmentService.getResults(profileId);
    if (!uploaded) onUploadMissed?.call();
  }

  List<AssessmentResult> getByType(AssessmentType type) {
    return state.where((r) => r.type == type).toList();
  }

  AssessmentResult? get latestPreTest {
    final results = getByType(AssessmentType.preTest);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results.first;
  }

  AssessmentResult? get latestPostTest {
    final results = getByType(AssessmentType.postTest);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results.first;
  }

  LearningGainReport? get learningGainReport {
    final pre = latestPreTest;
    final post = latestPostTest;
    if (pre == null || post == null) return null;
    return LearningGainReport(preTest: pre, postTest: post);
  }

  bool get hasPreTest => getByType(AssessmentType.preTest).isNotEmpty;
  bool get hasPostTest => getByType(AssessmentType.postTest).isNotEmpty;
}

final assessmentResultsProvider =
    StateNotifierProvider<AssessmentResultsNotifier, List<AssessmentResult>>(
        (ref) {
  final profile = ref.watch(profileProvider);
  final id = profile?.id ?? '';
  return AssessmentResultsNotifier(
    id,
    onUploadMissed: id.isEmpty
        ? null
        : () => ref.invalidate(learnerAssignmentSyncProvider(id)),
  );
});

// ─── Custom Assessments Provider ─────────────────────────

class CustomAssessmentsNotifier extends StateNotifier<List<Assessment>> {
  final String profileId;
  final AssessmentCloudService cloud;

  CustomAssessmentsNotifier(this.profileId,
      {this.cloud = const AssessmentCloudService()})
      : super(AssessmentService.getAssessments(profileId));

  void refresh() {
    state = AssessmentService.getAssessments(profileId);
  }

  Future<void> saveAssessment(Assessment assessment) async {
    await cloud.saveAssessment(profileId, assessment);
    state = AssessmentService.getAssessments(profileId);
  }

  Future<void> deleteAssessment(String assessmentId) async {
    final files = {
      for (final a in state)
        if (a.id == assessmentId)
          for (final q in a.questions) ...q.storedValues,
    };
    await cloud.deleteAssessment(profileId, assessmentId);
    state = AssessmentService.getAssessments(profileId);
    // A picked video can be tens of megabytes on a shared tablet; once no
    // stored assessment or assignment refers to it, it goes too.
    if (files.isNotEmpty) {
      await const AssessmentMediaStore().discardUnreferenced(files);
    }
  }
}

final customAssessmentsProvider =
    StateNotifierProvider<CustomAssessmentsNotifier, List<Assessment>>((ref) {
  final profile = ref.watch(profileProvider);
  return CustomAssessmentsNotifier(profile?.id ?? '');
});

// ─── Assignments Provider ────────────────────────────────

/// Assignments created by one educator, kept live so the surfaces that read
/// them agree.
///
/// Assignment Tracking used to read Hive straight from `build()` and try to
/// repaint after a delete with `(context as Element).markNeedsBuild()` on the
/// *list item's* context — which never recomputed the screen's list, so a
/// deleted assignment stayed on screen until you navigated away and back. A
/// newly assigned one was invisible the same way.
class AssignmentsNotifier extends StateNotifier<List<AssessmentAssignment>> {
  final String educatorId;
  final AssessmentCloudService cloud;

  AssignmentsNotifier(this.educatorId,
      {this.cloud = const AssessmentCloudService()})
      : super(AssessmentService.getAssignments(educatorId));

  void refresh() {
    state = AssessmentService.getAssignments(educatorId);
  }

  /// Returns whether the assignment reached the cloud, so the caller can tell
  /// the educator the truth instead of an unqualified "assigned!".
  Future<CloudSyncOutcome> saveAssignment(
    AssessmentAssignment assignment,
  ) async {
    final outcome = await cloud.saveAssignment(educatorId, assignment);
    refresh();
    return outcome;
  }

  /// Returns whether the deletion reached the cloud. A delete that only
  /// happened here still leaves the work on the learner's device, so the
  /// caller has to be able to say so.
  Future<CloudSyncOutcome> deleteAssignment(String assignmentId) async {
    final files = {
      for (final a in state)
        if (a.id == assignmentId) ...a.storedValues,
    };
    final outcome = await cloud.deleteAssignment(educatorId, assignmentId);
    refresh();
    if (files.isNotEmpty) {
      await const AssessmentMediaStore().discardUnreferenced(files);
    }
    return outcome;
  }
}

final assignmentsProvider =
    StateNotifierProvider<AssignmentsNotifier, List<AssessmentAssignment>>(
        (ref) {
  final profile = ref.watch(profileProvider);
  return AssignmentsNotifier(profile?.id ?? '');
});

// ─── One-shot Cloud Hydration ────────────────────────────

/// Pulls a learner's assigned work down from the cloud, once per profile.
///
/// A `FutureProvider` rather than a call in some screen's `initState`, because
/// the first thing that needs the data is the *home* banner — a learner has no
/// reason to open the Assessment Center to discover work they were never told
/// about. Watching it from a build method triggers exactly one round trip per
/// profile per session and repaints whoever is watching when it lands.
///
/// Resolves immediately to true when Firebase is unconfigured, so the
/// offline-only and test paths are unaffected. False means the pull failed;
/// [LearnerAssignmentSync] retries it.
final learnerAssignmentSyncProvider = FutureProvider.family<bool, String>((
  ref,
  profileId,
) async {
  final ok = await const AssessmentCloudService().hydrateLearner(profileId);
  // Video answers recorded offline reach the teacher once this works.
  await const AssessmentMediaPublisher().publishLearnerAnswers(profileId);
  // Files this learner shared that nothing points at (an app closed in the
  // middle of a test) — only once the pull has put everything here.
  if (ok) await const SharedMediaSweep().run(profileId);
  return ok;
});

/// The educator's mirror of [learnerAssignmentSyncProvider]: their templates,
/// their assignments, and their assignees' results. Watched by the assessment
/// hub, Assign Tasks and Assignment Tracking — one round trip serves all three.
final educatorAssessmentSyncProvider = FutureProvider.family<void, String>((
  ref,
  educatorId,
) async {
  final complete = await const AssessmentCloudService().hydrateEducator(
    educatorId,
  );
  // Files picked while offline are shared now that the pull worked, so the
  // learners' tablets can open them.
  await const AssessmentMediaPublisher().publishPending(educatorId);
  // Learners who deleted their profiles leave this educator's assignments,
  // with their feedback and its files — after the pull, so every assignment
  // is here to check.
  await ref.read(deletedLearnerCleanupProvider(educatorId).future);
  // Files this educator shared that nothing points at — an editor closed
  // by the system before it could save or tidy up.
  if (complete) await const SharedMediaSweep().run(educatorId);

  // Hydration writes straight to Hive, which these two notifiers cannot see:
  // they load once and then only re-read after their own writes. Without this
  // the "Check for new results" button pulled correctly and changed nothing on
  // screen — an assignment deleted on the teacher's other tablet sat in the
  // list until the app was restarted. Safe after the await: the provider's own
  // build has already returned.
  ref.read(assignmentsProvider.notifier).refresh();
  ref.read(customAssessmentsProvider.notifier).refresh();
});

/// Clears what an educator made for learners who have since deleted their
/// profiles — their places and feedback on assignments, the routines set for
/// them, and the files on both. Once per educator per session; watched from
/// the educator's home as well as run after the assessment sync, so an
/// educator who only uses routines is covered too. See
/// [DeletedLearnerCleanup].
final deletedLearnerCleanupProvider = FutureProvider.family<void, String>((
  ref,
  educatorId,
) async {
  // Nothing to check without the cloud — and nothing local is touched then.
  if (!FirebaseService.isConfigured &&
      DeletedLearnerCleanup.debugMissingProfiles == null) {
    return;
  }
  final notifier = ref.read(assignmentsProvider.notifier);
  await const DeletedLearnerCleanup().run(
    educatorId,
    saveAssignment: notifier.saveAssignment,
    deleteAssignment: notifier.deleteAssignment,
  );
});
