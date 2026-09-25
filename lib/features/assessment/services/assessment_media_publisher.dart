import '../../../core/services/shared_media_service.dart';
import '../models/assessment_media.dart';
import '../models/assessment_models.dart';
import 'assessment_cloud_service.dart';
import 'assessment_media_store.dart';
import 'assessment_service.dart';

/// Shares the files an educator picked while they were offline, once they
/// are back online.
///
/// The editor shares a picked file straight away; this is the retry. A file
/// that could not be shared at pick time is saved as `file://` — usable on
/// that tablet only — and every educator sync sweeps their own assessments
/// and assignments for such values, shares them, and saves the rows again so
/// the `shared://` value reaches every learner's tablet.
class AssessmentMediaPublisher {
  const AssessmentMediaPublisher({
    this.cloud = const AssessmentCloudService(),
    this.store = const AssessmentMediaStore(),
  });

  final AssessmentCloudService cloud;
  final AssessmentMediaStore store;

  /// One sweep at a time: two syncs landing together must not upload the
  /// same file twice.
  static bool _running = false;

  /// Returns how many rows were re-saved with shared media.
  Future<int> publishPending(String educatorId) async {
    if (educatorId.isEmpty || _running) return 0;
    if (!const SharedMediaService().available) return 0;
    _running = true;
    try {
      var changed = 0;
      for (final assessment in AssessmentService.getAssessments(educatorId)) {
        if (!assessment.questions.any(_questionPending)) continue;
        final questions = <AssessmentQuestion>[];
        var touched = false;
        for (final q in assessment.questions) {
          final media = await store.shareAll(
            q.media,
            ownerProfileId: educatorId,
          );
          final pictures = <String, String>{};
          for (final e in q.choiceImages.entries) {
            final shared = await store.shareAll(
              AssessmentMedia(photo: e.value),
              ownerProfileId: educatorId,
            );
            pictures[e.key] = shared.photo;
          }
          final changed =
              media != q.media ||
              pictures.entries.any((e) => q.choiceImages[e.key] != e.value);
          touched = touched || changed;
          questions.add(
            changed ? q.copyWith(media: media, choiceImages: pictures) : q,
          );
        }
        if (touched) {
          await cloud.saveAssessment(
            educatorId,
            assessment.withQuestions(questions),
          );
          changed++;
        }
      }
      for (final assignment in AssessmentService.getAssignments(educatorId)) {
        final pending =
            _pending(assignment.media) ||
            assignment.feedback.values.any((f) => _pending(f.media));
        if (!pending) continue;
        final instructions = await store.shareAll(
          assignment.media,
          ownerProfileId: educatorId,
        );
        var touched = instructions != assignment.media;
        var updated = assignment.withMedia(instructions);
        for (final entry in assignment.feedback.entries) {
          final media = await store.shareAll(
            entry.value.media,
            ownerProfileId: educatorId,
          );
          if (media == entry.value.media) continue;
          touched = true;
          updated = updated.withFeedback(
            entry.key,
            AssessmentFeedback(
              note: entry.value.note,
              media: media,
              updatedAt: entry.value.updatedAt,
            ),
          );
        }
        if (touched) {
          await cloud.saveAssignment(educatorId, updated);
          changed++;
        }
      }
      return changed;
    } finally {
      _running = false;
    }
  }

  /// The learner's half: video answers recorded while offline, shared now
  /// so their teacher's tablet can play them. Returns how many results were
  /// updated.
  Future<int> publishLearnerAnswers(String learnerId) async {
    if (learnerId.isEmpty || _running) return 0;
    if (!const SharedMediaService().available) return 0;
    _running = true;
    try {
      var changed = 0;
      for (final result in AssessmentService.getResults(learnerId)) {
        if (!result.answers.any(_answerPending)) continue;
        var touched = false;
        final answers = <QuestionAnswer>[];
        for (final a in result.answers) {
          if (!_answerPending(a)) {
            answers.add(a);
            continue;
          }
          final shared = await store.share(
            a.givenAnswer,
            ownerProfileId: learnerId,
          );
          touched = touched || shared.value != a.givenAnswer;
          answers.add(a.withGivenAnswer(shared.value));
        }
        if (touched) {
          await cloud.updateResult(learnerId, result.withAnswers(answers));
          changed++;
        }
      }
      return changed;
    } finally {
      _running = false;
    }
  }

  static bool _answerPending(QuestionAnswer a) =>
      a.needsReview && AssessmentMediaStore.isOwnFile(a.givenAnswer);

  static bool _pending(AssessmentMedia media) =>
      media.deviceFiles.any(AssessmentMediaStore.isOwnFile);

  static bool _questionPending(AssessmentQuestion q) =>
      _pending(q.media) ||
      q.choiceImages.values.any(AssessmentMediaStore.isOwnFile);
}
