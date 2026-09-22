import '../../../core/accessibility/learner_support.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';

/// Type of assessment
enum AssessmentType {
  preTest,
  postTest,
  categoryMastery,
  custom,
}

extension AssessmentTypeX on AssessmentType {
  String get label => switch (this) {
    AssessmentType.preTest => 'Pre-Test',
    AssessmentType.postTest => 'Post-Test',
    AssessmentType.categoryMastery => 'Category Mastery',
    AssessmentType.custom => 'Custom Assessment',
  };

  String get description => switch (this) {
    AssessmentType.preTest => 'Measure your starting knowledge before learning',
    AssessmentType.postTest => 'See how much you\'ve improved after learning',
    AssessmentType.categoryMastery => 'Test your mastery of a specific category',
    AssessmentType.custom => 'Teacher-created assessment',
  };

  /// Localized [label], for every surface a learner or educator reads.
  ///
  /// Takes a **nullable** l10n and falls back to the English constant, like
  /// `DisabilityTypeX.labelOf`: these strings appear inside semantics labels
  /// on screens that build without the delegate in widget tests, and a `!`
  /// there would turn a missing delegate into a crash rather than a word.
  ///
  /// [label] stays English because the research CSV exports print it — those
  /// must read the same whoever generated them.
  String labelOf(AppLocalizations? l10n) =>
      l10n == null ? label : switch (this) {
        AssessmentType.preTest => l10n.assessPreTest,
        AssessmentType.postTest => l10n.assessPostTest,
        AssessmentType.categoryMastery => l10n.assessCategoryMastery,
        AssessmentType.custom => l10n.assessCustom,
      };

  /// Localized [description].
  String descriptionOf(AppLocalizations? l10n) =>
      l10n == null ? description : switch (this) {
        AssessmentType.preTest => l10n.assessPreTestDesc,
        AssessmentType.postTest => l10n.assessPostTestDesc,
        AssessmentType.categoryMastery => l10n.assessCategoryMasteryDesc,
        AssessmentType.custom => l10n.assessCustomDesc,
      };

  String get emoji => switch (this) {
    AssessmentType.preTest => '📋',
    AssessmentType.postTest => '🎯',
    AssessmentType.categoryMastery => '🏆',
    AssessmentType.custom => '✏️',
  };
}

/// Question format for assessments
enum QuestionFormat {
  multipleChoice,
  fillInBlank,
  matchPairs,
  trueFalse,
  // Appended last so every stored question keeps its index. Watch a sign,
  // pick the word — the only item type that tests what the app teaches a
  // Deaf learner, rather than testing their reading.
  signVideo,
}

/// The formats a person may pick when authoring a question by hand.
///
/// [QuestionFormat.signVideo] is deliberately absent: it needs a flashcard
/// that actually has a sign clip, which the builders do not ask for, so
/// offering it would let an educator save an item that can never play.
/// Sign items are generated (see `AssessmentService.buildSignQuestion`).
const List<QuestionFormat> authorableQuestionFormats = [
  QuestionFormat.multipleChoice,
  QuestionFormat.fillInBlank,
  QuestionFormat.matchPairs,
  QuestionFormat.trueFalse,
];

extension QuestionFormatX on QuestionFormat {
  String get label => switch (this) {
    QuestionFormat.multipleChoice => 'Multiple Choice',
    QuestionFormat.fillInBlank => 'Fill in the Blank',
    QuestionFormat.matchPairs => 'Match Pairs',
    QuestionFormat.trueFalse => 'True or False',
    QuestionFormat.signVideo => 'Watch the Sign',
  };

  /// Localized [label]. Nullable l10n, same reasoning as [AssessmentTypeX].
  String labelOf(AppLocalizations? l10n) =>
      l10n == null ? label : switch (this) {
        QuestionFormat.multipleChoice => l10n.formatMultipleChoice,
        QuestionFormat.fillInBlank => l10n.formatFillInBlank,
        QuestionFormat.matchPairs => l10n.formatMatchPairs,
        QuestionFormat.trueFalse => l10n.formatTrueFalse,
        QuestionFormat.signVideo => l10n.formatSignVideo,
      };
}

/// A single question in an assessment
class AssessmentQuestion {
  final String id;
  final String questionText;
  final String correctAnswer;
  final List<String> choices;
  final QuestionFormat format;
  final FlashcardCategory? category;
  final String? imageAsset;
  final String? hint;

  /// Flashcard id whose sign-language clip this item plays.
  ///
  /// Set only on [QuestionFormat.signVideo] items. The clip itself is
  /// resolved at play time from that id — storing a URL would rot the moment
  /// the media moved, and it has moved before.
  final String? signCardId;

  const AssessmentQuestion({
    required this.id,
    required this.questionText,
    required this.correctAnswer,
    required this.choices,
    this.format = QuestionFormat.multipleChoice,
    this.category,
    this.imageAsset,
    this.hint,
    this.signCardId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'questionText': questionText,
    'correctAnswer': correctAnswer,
    'choices': choices,
    'format': format.index,
    'category': category?.index,
    'imageAsset': imageAsset,
    'hint': hint,
    'signCardId': signCardId,
  };

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    final fmtIndex = json['format'] as int? ?? 0;
    final catIndex = json['category'] as int?;
    return AssessmentQuestion(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      correctAnswer: json['correctAnswer'] as String,
      choices: List<String>.from(json['choices'] as List),
      format: (fmtIndex >= 0 && fmtIndex < QuestionFormat.values.length)
          ? QuestionFormat.values[fmtIndex]
          : QuestionFormat.multipleChoice,
      category: (catIndex != null && catIndex >= 0 && catIndex < FlashcardCategory.values.length)
          ? FlashcardCategory.values[catIndex]
          : null,
      imageAsset: json['imageAsset'] as String?,
      hint: json['hint'] as String?,
      signCardId: json['signCardId'] as String?,
    );
  }
}

/// An assessment definition (template)
class Assessment {
  final String id;
  final String title;
  final String? description;
  final AssessmentType type;
  final List<AssessmentQuestion> questions;
  final List<FlashcardCategory> categories;
  final GameDifficulty difficulty;
  final int? timeLimitMinutes;
  final String createdBy; // profile ID
  final DateTime createdAt;

  const Assessment({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.questions,
    this.categories = const [],
    this.difficulty = GameDifficulty.medium,
    this.timeLimitMinutes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.index,
    'questions': questions.map((q) => q.toJson()).toList(),
    'categories': categories.map((c) => c.index).toList(),
    'difficulty': difficulty.index,
    'timeLimitMinutes': timeLimitMinutes,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Assessment.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    final diffIndex = json['difficulty'] as int? ?? 1;
    return Assessment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: (typeIndex >= 0 && typeIndex < AssessmentType.values.length)
          ? AssessmentType.values[typeIndex]
          : AssessmentType.custom,
      questions: (json['questions'] as List)
          .map((q) => AssessmentQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList(),
      categories: (json['categories'] as List? ?? [])
          .map((c) => c as int)
          .where((c) => c >= 0 && c < FlashcardCategory.values.length)
          .map((c) => FlashcardCategory.values[c])
          .toList(),
      difficulty: (diffIndex >= 0 && diffIndex < GameDifficulty.values.length)
          ? GameDifficulty.values[diffIndex]
          : GameDifficulty.medium,
      timeLimitMinutes: json['timeLimitMinutes'] as int?,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// A single answer given by a student
class QuestionAnswer {
  final String questionId;
  final String givenAnswer;
  final bool isCorrect;
  final int responseTimeMs;

  const QuestionAnswer({
    required this.questionId,
    required this.givenAnswer,
    required this.isCorrect,
    required this.responseTimeMs,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'givenAnswer': givenAnswer,
    'isCorrect': isCorrect,
    'responseTimeMs': responseTimeMs,
  };

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      questionId: json['questionId'] as String,
      givenAnswer: json['givenAnswer'] as String,
      isCorrect: json['isCorrect'] as bool,
      responseTimeMs: json['responseTimeMs'] as int? ?? 0,
    );
  }
}

/// Result of a completed assessment
class AssessmentResult {
  final String id;
  final String assessmentId;
  final String profileId;
  final AssessmentType type;
  final int score;
  final int totalQuestions;
  final List<QuestionAnswer> answers;
  final DateTime completedAt;
  final int durationSeconds;
  final List<FlashcardCategory> categories;
  final Map<String, double> categoryScores; // category label -> percentage

  /// The supports that were in force while this sitting happened — a longer
  /// clock, a shorter choice list.
  ///
  /// Recorded on the *result*, not just the profile, because a profile can be
  /// edited afterwards and a score is only defensible alongside the conditions
  /// it was earned under. Empty on results saved before this existed, which
  /// reads correctly as "no accommodation recorded".
  final Set<LearnerSupportOption> accommodations;

  const AssessmentResult({
    required this.id,
    required this.assessmentId,
    required this.profileId,
    required this.type,
    required this.score,
    required this.totalQuestions,
    required this.answers,
    required this.completedAt,
    required this.durationSeconds,
    this.categories = const [],
    this.categoryScores = const {},
    this.accommodations = const {},
  });

  double get percentage => totalQuestions > 0 ? score / totalQuestions : 0.0;

  String get grade {
    final pct = percentage;
    if (pct >= 0.9) return 'Excellent';
    if (pct >= 0.75) return 'Very Good';
    if (pct >= 0.6) return 'Good';
    if (pct >= 0.4) return 'Needs Improvement';
    return 'Keep Practicing';
  }

  /// [grade] in the reader's language. [grade] itself stays English for the
  /// CSV exports.
  String gradeOf(AppLocalizations? l10n) {
    if (l10n == null) return grade;
    final pct = percentage;
    if (pct >= 0.9) return l10n.gradeExcellent;
    if (pct >= 0.75) return l10n.gradeVeryGood;
    if (pct >= 0.6) return l10n.gradeGood;
    if (pct >= 0.4) return l10n.gradeNeedsImprovement;
    return l10n.gradeKeepPracticing;
  }

  String get gradeEmoji {
    final pct = percentage;
    if (pct >= 0.9) return '🌟';
    if (pct >= 0.75) return '⭐';
    if (pct >= 0.6) return '👍';
    if (pct >= 0.4) return '💪';
    return '📚';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'assessmentId': assessmentId,
    'profileId': profileId,
    'type': type.index,
    'score': score,
    'totalQuestions': totalQuestions,
    'answers': answers.map((a) => a.toJson()).toList(),
    'completedAt': completedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'categories': categories.map((c) => c.index).toList(),
    'categoryScores': categoryScores,
    'accommodations': LearnerSupportCatalog.encode(accommodations),
  };

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    return AssessmentResult(
      id: json['id'] as String,
      assessmentId: json['assessmentId'] as String,
      profileId: json['profileId'] as String,
      type: (typeIndex >= 0 && typeIndex < AssessmentType.values.length)
          ? AssessmentType.values[typeIndex]
          : AssessmentType.custom,
      score: json['score'] as int,
      totalQuestions: json['totalQuestions'] as int,
      answers: (json['answers'] as List)
          .map((a) => QuestionAnswer.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      categories: (json['categories'] as List? ?? [])
          .map((c) => c as int)
          .where((c) => c >= 0 && c < FlashcardCategory.values.length)
          .map((c) => FlashcardCategory.values[c])
          .toList(),
      categoryScores: Map<String, double>.from(json['categoryScores'] as Map? ?? {}),
      accommodations:
          LearnerSupportCatalog.decode(json['accommodations'] as List?),
    );
  }
}

/// Comparison of pre-test vs post-test results
class LearningGainReport {
  final AssessmentResult preTest;
  final AssessmentResult postTest;

  const LearningGainReport({
    required this.preTest,
    required this.postTest,
  });

  double get preTestPercentage => preTest.percentage;
  double get postTestPercentage => postTest.percentage;
  double get improvement => postTestPercentage - preTestPercentage;
  double get improvementPercent =>
      preTestPercentage > 0 ? improvement / preTestPercentage : improvement;

  /// Hake's normalized gain: `(post - pre) / (1 - pre)`.
  ///
  /// Controls for ceiling effects — a student starting near the top can only
  /// gain a small raw amount, so [improvement] understates their learning.
  /// Returns null when the pre-test is already perfect (pre == 100%), where
  /// the metric is undefined (division by zero). May be negative if the score
  /// dropped.
  double? get normalizedGain {
    final headroom = 1.0 - preTestPercentage;
    if (headroom <= 0) return null;
    return improvement / headroom;
  }

  bool get hasImproved => improvement > 0;

  /// [summary] in the reader's language. [summary] stays English for the
  /// exports.
  String summaryOf(AppLocalizations? l10n) {
    if (l10n == null) return summary;
    final pre = (preTestPercentage * 100).round();
    final post = (postTestPercentage * 100).round();
    final gain = (improvement * 100).round();
    if (hasImproved) return l10n.gainImproved(pre, post, gain);
    if (improvement == 0) return l10n.gainSame(pre);
    return l10n.gainChanged(pre, post, gain);
  }

  String get summary {
    final pre = (preTestPercentage * 100).round();
    final post = (postTestPercentage * 100).round();
    final gain = (improvement * 100).round();
    if (hasImproved) {
      return 'Score improved from $pre% to $post% (+$gain%)';
    } else if (improvement == 0) {
      return 'Score remained at $pre%';
    } else {
      return 'Score changed from $pre% to $post% ($gain%)';
    }
  }

  /// Per-category comparison
  Map<String, ({double pre, double post, double gain})> get categoryGains {
    final result = <String, ({double pre, double post, double gain})>{};
    final allCats = {
      ...preTest.categoryScores.keys,
      ...postTest.categoryScores.keys,
    };
    for (final cat in allCats) {
      final pre = preTest.categoryScores[cat] ?? 0.0;
      final post = postTest.categoryScores[cat] ?? 0.0;
      result[cat] = (pre: pre, post: post, gain: post - pre);
    }
    return result;
  }
}

// ─── Assessment Assignment ──────────────────────────────

/// Status of an assignment for a student
enum AssignmentStatus {
  pending,
  completed,
  overdue,
}

extension AssignmentStatusX on AssignmentStatus {
  String get label => switch (this) {
    AssignmentStatus.pending => 'Pending',
    AssignmentStatus.completed => 'Completed',
    AssignmentStatus.overdue => 'Overdue',
  };

  String get emoji => switch (this) {
    AssignmentStatus.pending => '⏳',
    AssignmentStatus.completed => '✅',
    AssignmentStatus.overdue => '⚠️',
  };
}

/// An assessment assigned by an educator to one or more students.
class AssessmentAssignment {
  final String id;
  final String assessmentId;
  final String assessmentTitle;
  final String assignedBy; // educator profile ID
  final List<String> studentIds; // assigned student profile IDs
  final DateTime assignedAt;
  final DateTime? deadline;
  final String? instructions;

  const AssessmentAssignment({
    required this.id,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.assignedBy,
    required this.studentIds,
    required this.assignedAt,
    this.deadline,
    this.instructions,
  });

  /// Whether the deadline has passed.
  bool get isOverdue =>
      deadline != null && DateTime.now().isAfter(deadline!);

  Map<String, dynamic> toJson() => {
    'id': id,
    'assessmentId': assessmentId,
    'assessmentTitle': assessmentTitle,
    'assignedBy': assignedBy,
    'studentIds': studentIds,
    'assignedAt': assignedAt.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'instructions': instructions,
  };

  factory AssessmentAssignment.fromJson(Map<String, dynamic> json) {
    return AssessmentAssignment(
      id: json['id'] as String,
      assessmentId: json['assessmentId'] as String,
      assessmentTitle: json['assessmentTitle'] as String? ?? '',
      assignedBy: json['assignedBy'] as String,
      studentIds: List<String>.from(json['studentIds'] as List),
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      instructions: json['instructions'] as String?,
    );
  }
}

/// Tracks a single student's completion status for an assignment.
class StudentAssignmentStatus {
  final String studentId;
  final String studentName;
  final AssignmentStatus status;
  final AssessmentResult? result;

  const StudentAssignmentStatus({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.result,
  });
}
