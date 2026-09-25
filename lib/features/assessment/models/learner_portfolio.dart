import '../../../l10n/app_localizations.dart';
import '../services/assessment_service.dart';
import 'assessment_media.dart';
import 'assessment_models.dart';
import 'question_prompt.dart';

/// One thing in a learner's portfolio: a test they sat, or feedback on one.
class PortfolioEntry {
  final DateTime at;

  /// The educator's name for the test; null for one the app names itself
  /// (a pre-test, a post-test), which [titleOf] words in the reader's
  /// language.
  final String? title;

  /// Set for a test sat.
  final AssessmentResult? result;

  /// The educator's feedback on this test, when there is any — for a result
  /// entry it supplies the marks on video answers; on its own it is a
  /// feedback entry.
  final AssessmentFeedback? feedback;

  const PortfolioEntry._({
    required this.at,
    required this.title,
    this.result,
    this.feedback,
  });

  bool get isResult => result != null;

  /// What to call this entry, in the reader's language where the app named
  /// the test.
  String titleOf(AppLocalizations? l10n) {
    final own = title?.trim() ?? '';
    if (own.isNotEmpty) return QuestionPrompt.title(own, l10n);
    return result?.type.labelOf(l10n) ?? '';
  }

  /// The score with a person's marks counted in; null for feedback entries.
  ({int correct, int total, int pending})? get score =>
      result?.reviewedWith(feedback);

  /// [score] as a fraction, or null while nothing in it has a mark.
  double? get fraction {
    final s = score;
    if (s == null || s.total == 0) return null;
    return s.correct / s.total;
  }
}

/// Everything a learner has done and been told in the assessment module,
/// newest first — for the learner, their teacher or parent, and the PDF a
/// parent takes home.
///
/// Pure: [LearnerPortfolio.from] takes the pieces and does no I/O, so the
/// whole thing is unit-testable; [LearnerPortfolio.load] fetches them.
class LearnerPortfolio {
  final String learnerId;
  final List<PortfolioEntry> entries;
  final LearningGainReport? gain;

  const LearnerPortfolio._({
    required this.learnerId,
    required this.entries,
    required this.gain,
  });

  factory LearnerPortfolio.from({
    required String learnerId,
    required List<AssessmentResult> results,
    required List<({AssessmentAssignment assignment, AssessmentFeedback feedback})>
    feedback,
    required String? Function(AssessmentResult result) titleOf,
    LearningGainReport? gain,
  }) {
    // Feedback belongs to the assignment, which names the assessment; a
    // result names the same assessment — that is how a mark on a video
    // answer finds the sitting it is about.
    final feedbackFor = <String, AssessmentFeedback>{
      for (final f in feedback) f.assignment.assessmentId: f.feedback,
    };
    final entries = <PortfolioEntry>[
      for (final r in results)
        PortfolioEntry._(
          at: r.completedAt,
          title: titleOf(r),
          result: r,
          feedback: feedbackFor[r.assessmentId],
        ),
      for (final f in feedback)
        if (f.feedback.note.trim().isNotEmpty || f.feedback.media.hasAny)
          PortfolioEntry._(
            at: f.feedback.updatedAt,
            title: f.assignment.assessmentTitle,
            feedback: f.feedback,
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return LearnerPortfolio._(learnerId: learnerId, entries: entries, gain: gain);
  }

  /// This learner's portfolio as this device knows it.
  factory LearnerPortfolio.load(String learnerId) {
    final assignments = AssessmentService.getAssignmentsForStudent(learnerId);
    String? titleOf(AssessmentResult r) {
      // The study's two tests read the same for everyone, in their language.
      if (r.type == AssessmentType.preTest ||
          r.type == AssessmentType.postTest) {
        return null;
      }
      for (final a in assignments) {
        if (a.assessmentId == r.assessmentId && a.assessmentTitle.isNotEmpty) {
          return a.assessmentTitle;
        }
      }
      return AssessmentService.findAssessmentById(r.assessmentId)?.title;
    }

    return LearnerPortfolio.from(
      learnerId: learnerId,
      results: AssessmentService.getResults(learnerId),
      feedback: AssessmentService.getFeedbackForStudent(learnerId),
      titleOf: titleOf,
      gain: AssessmentService.getLearningGainReport(learnerId),
    );
  }

  List<PortfolioEntry> get results => entries.where((e) => e.isResult).toList();

  int get testsTaken => results.length;

  int get feedbackCount => entries.where((e) => !e.isResult).length;

  int get videoAnswers => [
    for (final e in results) ...e.result!.reviewAnswers,
  ].length;

  /// The mean of every test that has a score (a person's marks counted in),
  /// or null when none has one yet.
  double? get averageScore {
    final scored = [
      for (final e in results)
        if (e.fraction != null) e.fraction!,
    ];
    if (scored.isEmpty) return null;
    return scored.reduce((a, b) => a + b) / scored.length;
  }

  bool get isEmpty => entries.isEmpty;
}
