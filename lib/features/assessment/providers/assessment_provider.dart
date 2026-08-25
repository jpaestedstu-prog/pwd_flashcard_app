import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../services/assessment_cloud_service.dart';
import '../services/assessment_service.dart';

// ─── Assessment Results Provider ─────────────────────────

class AssessmentResultsNotifier extends StateNotifier<List<AssessmentResult>> {
  final String profileId;
  final AssessmentCloudService cloud;

  AssessmentResultsNotifier(this.profileId,
      {this.cloud = const AssessmentCloudService()})
      : super(AssessmentService.getResults(profileId));

  void refresh() {
    state = AssessmentService.getResults(profileId);
  }

  Future<void> saveResult(AssessmentResult result) async {
    await cloud.saveResult(profileId, result);
    state = AssessmentService.getResults(profileId);
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
  return AssessmentResultsNotifier(profile?.id ?? '');
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
    await cloud.deleteAssessment(profileId, assessmentId);
    state = AssessmentService.getAssessments(profileId);
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
    final outcome = await cloud.deleteAssignment(educatorId, assignmentId);
    refresh();
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
/// Resolves immediately to nothing when Firebase is unconfigured, so the
/// offline-only and test paths are unaffected.
final learnerAssignmentSyncProvider = FutureProvider.family<void, String>((
  ref,
  profileId,
) async {
  await const AssessmentCloudService().hydrateLearner(profileId);
});

/// The educator's mirror of [learnerAssignmentSyncProvider]: their templates,
/// their assignments, and their assignees' results. Watched by the assessment
/// hub, Assign Tasks and Assignment Tracking — one round trip serves all three.
final educatorAssessmentSyncProvider = FutureProvider.family<void, String>((
  ref,
  educatorId,
) async {
  await const AssessmentCloudService().hydrateEducator(educatorId);

  // Hydration writes straight to Hive, which these two notifiers cannot see:
  // they load once and then only re-read after their own writes. Without this
  // the "Check for new results" button pulled correctly and changed nothing on
  // screen — an assignment deleted on the teacher's other tablet sat in the
  // list until the app was restarted. Safe after the await: the provider's own
  // build has already returned.
  ref.read(assignmentsProvider.notifier).refresh();
  ref.read(customAssessmentsProvider.notifier).refresh();
});
