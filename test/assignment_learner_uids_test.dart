import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';

/// Any copy of the app could list every assignment and harvest learners'
/// profile ids from `studentIds`: a learner's `studentIds` array-contains
/// query is one no security rule can hold to that learner. Since 1.2.2 the
/// learner's tablet also looks its work up by its own uid (`student_uids`),
/// the query the rules *can* restrict, and merges the two until the old one
/// is closed.
AssessmentAssignment _a(String id, List<String> learners) =>
    AssessmentAssignment.fromJson({
      'id': id,
      'assessmentId': 'tpl-$id',
      'assignedBy': 'teacher-1',
      'studentIds': learners,
      'assignedAt': DateTime(2026, 10, 4).toIso8601String(),
    });

void main() {
  test('both lookups, each assignment once', () {
    final got = AssessmentCloudService.assignmentsForLearner(
      'ana',
      byUid: [_a('pre', ['ana', 'ben'])],
      byLegacy: [_a('pre', ['ana', 'ben']), _a('post', ['ana'])],
    );
    expect(got.map((a) => a.id).toSet(), {'pre', 'post'});
  });

  test("a tablet shared by two learners gets only this learner's work", () {
    // The uid lookup returns every assignment for any learner on the tablet.
    final got = AssessmentCloudService.assignmentsForLearner(
      'ana',
      byUid: [_a('ana-test', ['ana']), _a('ben-test', ['ben'])],
      byLegacy: const [],
    );
    expect(got.map((a) => a.id), ['ana-test']);
  });

  test('once the rules refuse the old lookup, the uid one carries on', () {
    final got = AssessmentCloudService.assignmentsForLearner(
      'ana',
      byUid: [_a('pre', ['ana'])],
      byLegacy: null,
    );
    expect(got.map((a) => a.id), ['pre']);
  });

  test('work from an educator tablet that has not added uids yet still arrives', () {
    final got = AssessmentCloudService.assignmentsForLearner(
      'ana',
      byUid: const [],
      byLegacy: [_a('old', ['ana'])],
    );
    expect(got.map((a) => a.id), ['old']);
  });
}
