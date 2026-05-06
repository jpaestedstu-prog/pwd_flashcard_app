import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../services/assessment_service.dart';

// ─── Assessment Results Provider ─────────────────────────

class AssessmentResultsNotifier extends StateNotifier<List<AssessmentResult>> {
  final String profileId;

  AssessmentResultsNotifier(this.profileId)
      : super(AssessmentService.getResults(profileId));

  void refresh() {
    state = AssessmentService.getResults(profileId);
  }

  Future<void> saveResult(AssessmentResult result) async {
    await AssessmentService.saveResult(profileId, result);
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

  CustomAssessmentsNotifier(this.profileId)
      : super(AssessmentService.getAssessments(profileId));

  void refresh() {
    state = AssessmentService.getAssessments(profileId);
  }

  Future<void> saveAssessment(Assessment assessment) async {
    await AssessmentService.saveAssessment(profileId, assessment);
    state = AssessmentService.getAssessments(profileId);
  }

  Future<void> deleteAssessment(String assessmentId) async {
    await AssessmentService.deleteAssessment(profileId, assessmentId);
    state = AssessmentService.getAssessments(profileId);
  }
}

final customAssessmentsProvider =
    StateNotifierProvider<CustomAssessmentsNotifier, List<Assessment>>((ref) {
  final profile = ref.watch(profileProvider);
  return CustomAssessmentsNotifier(profile?.id ?? '');
});
