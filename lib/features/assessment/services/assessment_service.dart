import 'dart:async';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/assessment_models.dart';

/// Service that manages assessment persistence and question generation.
class AssessmentService {
  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);
  static const _uuid = Uuid();

  // ─── Assessment CRUD ───────────────────────────────────

  /// Get all saved assessments (templates) for a profile
  static List<Assessment> getAssessments(String profileId) {
    final raw = _box.get('assessments_$profileId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => Assessment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save or update an assessment template
  static Future<void> saveAssessment(
      String profileId, Assessment assessment) async {
    final list = getAssessments(profileId);
    list.removeWhere((a) => a.id == assessment.id);
    list.add(assessment);
    await _box.put(
      'assessments_$profileId',
      list.map((a) => a.toJson()).toList(),
    );
  }

  /// Delete an assessment template
  static Future<void> deleteAssessment(
      String profileId, String assessmentId) async {
    final list = getAssessments(profileId);
    list.removeWhere((a) => a.id == assessmentId);
    await _box.put(
      'assessments_$profileId',
      list.map((a) => a.toJson()).toList(),
    );
  }

  // ─── Assessment Results CRUD ──────────────────────────

  /// Get all results for a profile
  static List<AssessmentResult> getResults(String profileId) {
    final raw = _box.get('assessment_results_$profileId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) =>
            AssessmentResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save a completed assessment result
  static Future<void> saveResult(
      String profileId, AssessmentResult result) async {
    final list = getResults(profileId);
    list.add(result);
    // Keep last 100 results
    if (list.length > 100) {
      list.removeRange(0, list.length - 100);
    }
    await _box.put(
      'assessment_results_$profileId',
      list.map((r) => r.toJson()).toList(),
    );
  }

  /// Get results filtered by assessment type
  static List<AssessmentResult> getResultsByType(
      String profileId, AssessmentType type) {
    return getResults(profileId).where((r) => r.type == type).toList();
  }

  /// Get the latest pre-test result
  static AssessmentResult? getLatestPreTest(String profileId) {
    final results = getResultsByType(profileId, AssessmentType.preTest);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results.first;
  }

  /// Get the latest post-test result
  static AssessmentResult? getLatestPostTest(String profileId) {
    final results = getResultsByType(profileId, AssessmentType.postTest);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results.first;
  }

  /// Compare pre-test vs post-test
  static LearningGainReport? getLearningGainReport(String profileId) {
    final pre = getLatestPreTest(profileId);
    final post = getLatestPostTest(profileId);
    if (pre == null || post == null) return null;
    return LearningGainReport(preTest: pre, postTest: post);
  }

  // ─── Pre-Test Template Persistence ─────────────────────

  static const String _preTestTemplatePrefix = 'pretest_template_';

  /// Persist a generated pre-test so its post-test can mirror it exactly.
  /// Keyed by the assessment id, which the saved [AssessmentResult] also
  /// references, letting [generateStandardAssessment] look it back up.
  static Future<void> _savePreTestTemplate(Assessment assessment) async {
    await _box.put(
      '$_preTestTemplatePrefix${assessment.id}',
      assessment.toJson(),
    );
  }

  /// Load the stored pre-test template for [assessmentId], or null if absent.
  static Assessment? getPreTestTemplate(String assessmentId) {
    final raw = _box.get('$_preTestTemplatePrefix$assessmentId');
    if (raw == null) return null;
    return Assessment.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ─── Auto-Generate Assessments ─────────────────────────

  /// Generate a pre-test or post-test assessment from seed data.
  ///
  /// Pre-tests draw a random vocabulary sample and are persisted as the
  /// student's instrument (see [_savePreTestTemplate]). Post-tests are built
  /// as a **parallel form** of that same pre-test — identical items, with only
  /// the question order and per-question choice order re-randomized — so that
  /// [LearningGainReport] compares like with like instead of comparing a
  /// random pre-test against a post-test biased toward already-studied words.
  /// If no pre-test template is available (legacy data, or no pre-test taken),
  /// the post-test falls back to a fresh random sample.
  static Assessment generateStandardAssessment({
    required String profileId,
    required AssessmentType type,
    List<FlashcardCategory> categories = const [],
    GameDifficulty difficulty = GameDifficulty.medium,
    int questionCount = 15,
  }) {
    // Post-test: replay the student's completed pre-test as a parallel form.
    if (type == AssessmentType.postTest) {
      final pre = getLatestPreTest(profileId);
      final template =
          pre != null ? getPreTestTemplate(pre.assessmentId) : null;
      if (template != null) {
        return _buildParallelForm(template);
      }
      // No template — fall through to a fresh sample so nothing breaks.
    }

    final cats =
        categories.isEmpty ? FlashcardCategory.values.toList() : categories;
    final allCards = <Flashcard>[];
    for (final cat in cats) {
      allCards.addAll(SeedData.getByCategory(cat));
    }

    final rng = Random();
    final selectedCards = (List.of(allCards)..shuffle(rng))
        .take(min(questionCount, allCards.length))
        .toList();

    final questions = <AssessmentQuestion>[];
    for (final card in selectedCards) {
      final format = _randomFormat(difficulty, rng);
      questions.add(_generateQuestion(card, allCards, format, rng));
    }

    final assessment = Assessment(
      id: _uuid.v4(),
      title:
          '${type.label} — ${cats.length == FlashcardCategory.values.length ? "All Categories" : cats.map((c) => c.label).join(", ")}',
      description: type.description,
      type: type,
      questions: questions,
      categories: cats,
      difficulty: difficulty,
      timeLimitMinutes: difficulty == GameDifficulty.hard ? 10 : null,
      createdBy: 'system',
      createdAt: DateTime.now(),
    );

    // Persist the pre-test so its post-test can mirror it exactly.
    if (type == AssessmentType.preTest) {
      unawaited(_savePreTestTemplate(assessment));
    }

    return assessment;
  }

  /// Builds a post-test that is a parallel form of [preTemplate]: the exact
  /// same items (question ids, prompts, correct answers, distractors) with the
  /// question order and each question's choice order re-randomized to blunt
  /// rote recall. Keeping question ids lets pre/post items be matched 1:1 for
  /// later item analysis.
  static Assessment _buildParallelForm(Assessment preTemplate) {
    final rng = Random();
    final questions = preTemplate.questions
        .map((q) => AssessmentQuestion(
              id: q.id,
              questionText: q.questionText,
              correctAnswer: q.correctAnswer,
              choices: List.of(q.choices)..shuffle(rng),
              format: q.format,
              category: q.category,
              imageAsset: q.imageAsset,
              hint: q.hint,
            ))
        .toList()
      ..shuffle(rng);

    final cats = preTemplate.categories;
    return Assessment(
      id: _uuid.v4(),
      title:
          '${AssessmentType.postTest.label} — ${cats.length == FlashcardCategory.values.length ? "All Categories" : cats.map((c) => c.label).join(", ")}',
      description: AssessmentType.postTest.description,
      type: AssessmentType.postTest,
      questions: questions,
      categories: cats,
      difficulty: preTemplate.difficulty,
      timeLimitMinutes: preTemplate.timeLimitMinutes,
      createdBy: 'system',
      createdAt: DateTime.now(),
    );
  }

  /// Generate a category mastery assessment
  static Assessment generateCategoryMastery({
    required String profileId,
    required FlashcardCategory category,
    GameDifficulty difficulty = GameDifficulty.medium,
  }) {
    final cards = SeedData.getByCategory(category);
    final allCards = SeedData.allFlashcards;
    final rng = Random();
    final count = min(cards.length, difficulty == GameDifficulty.easy ? 8 : (difficulty == GameDifficulty.medium ? 12 : cards.length));
    final selected = (List.of(cards)..shuffle(rng)).take(count).toList();

    final questions = selected.map((card) {
      final format = _randomFormat(difficulty, rng);
      return _generateQuestion(card, allCards, format, rng);
    }).toList();

    return Assessment(
      id: _uuid.v4(),
      title: '${category.label} Mastery Test',
      description: 'Test your mastery of ${category.label} vocabulary',
      type: AssessmentType.categoryMastery,
      questions: questions,
      categories: [category],
      difficulty: difficulty,
      createdBy: 'system',
      createdAt: DateTime.now(),
    );
  }

  // ─── Question Generators ──────────────────────────────

  static QuestionFormat _randomFormat(GameDifficulty difficulty, Random rng) {
    if (difficulty == GameDifficulty.easy) {
      // Only multiple choice and true/false for easy
      return rng.nextBool()
          ? QuestionFormat.multipleChoice
          : QuestionFormat.trueFalse;
    }
    if (difficulty == GameDifficulty.hard) {
      // All formats for hard
      return QuestionFormat.values[rng.nextInt(QuestionFormat.values.length)];
    }
    // Medium: multiple choice, true/false, fill-in-blank
    final formats = [
      QuestionFormat.multipleChoice,
      QuestionFormat.multipleChoice,
      QuestionFormat.trueFalse,
      QuestionFormat.fillInBlank,
    ];
    return formats[rng.nextInt(formats.length)];
  }

  static AssessmentQuestion _generateQuestion(
    Flashcard card,
    List<Flashcard> allCards,
    QuestionFormat format,
    Random rng,
  ) {
    switch (format) {
      case QuestionFormat.multipleChoice:
        return _generateMultipleChoice(card, allCards, rng);
      case QuestionFormat.trueFalse:
        return _generateTrueFalse(card, allCards, rng);
      case QuestionFormat.fillInBlank:
        return _generateFillInBlank(card, rng);
      case QuestionFormat.matchPairs:
        // Fall back to multiple choice for match pairs (handled differently in UI)
        return _generateMultipleChoice(card, allCards, rng);
    }
  }

  static AssessmentQuestion _generateMultipleChoice(
    Flashcard card,
    List<Flashcard> allCards,
    Random rng,
  ) {
    // Randomly decide direction: English→Filipino or Filipino→English
    final englishToFilipino = rng.nextBool();
    final questionText = englishToFilipino
        ? 'What is the Filipino word for "${card.wordEnglish}"?'
        : 'What is the English word for "${card.wordFilipino}"?';
    final correctAnswer = englishToFilipino ? card.wordFilipino : card.wordEnglish;

    // Generate distractors
    final others = allCards
        .where((c) => c.id != card.id)
        .toList()
      ..shuffle(rng);
    final distractors = others
        .take(3)
        .map((c) => englishToFilipino ? c.wordFilipino : c.wordEnglish)
        .toList();

    final choices = [correctAnswer, ...distractors]..shuffle(rng);

    return AssessmentQuestion(
      id: _uuid.v4(),
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: choices,
      category: card.category,
      hint: card.exampleSentence,
    );
  }

  static AssessmentQuestion _generateTrueFalse(
    Flashcard card,
    List<Flashcard> allCards,
    Random rng,
  ) {
    final isTrue = rng.nextBool();
    String displayedTranslation;

    if (isTrue) {
      displayedTranslation = card.wordFilipino;
    } else {
      final others = allCards.where((c) => c.id != card.id).toList()..shuffle(rng);
      displayedTranslation = others.isNotEmpty
          ? others.first.wordFilipino
          : card.wordFilipino;
    }

    final questionText =
        '"${card.wordEnglish}" in Filipino is "$displayedTranslation"';
    final correctAnswer = isTrue ? 'True' : 'False';

    return AssessmentQuestion(
      id: _uuid.v4(),
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: ['True', 'False'],
      format: QuestionFormat.trueFalse,
      category: card.category,
      hint: card.exampleSentence,
    );
  }

  static AssessmentQuestion _generateFillInBlank(
    Flashcard card,
    Random rng,
  ) {
    final askFilipino = rng.nextBool();
    final questionText = askFilipino
        ? 'Type the Filipino word for "${card.wordEnglish}":'
        : 'Type the English word for "${card.wordFilipino}":';
    final correctAnswer = askFilipino ? card.wordFilipino : card.wordEnglish;

    return AssessmentQuestion(
      id: _uuid.v4(),
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: [], // empty for fill-in-blank
      format: QuestionFormat.fillInBlank,
      category: card.category,
      hint: card.exampleSentence,
    );
  }

  // ─── Analytics Helpers ─────────────────────────────────

  /// Get average score percentage per assessment type
  static Map<AssessmentType, double> getAverageScores(String profileId) {
    final results = getResults(profileId);
    final groups = <AssessmentType, List<double>>{};
    for (final r in results) {
      groups.putIfAbsent(r.type, () => []).add(r.percentage);
    }
    return groups.map((type, scores) =>
        MapEntry(type, scores.reduce((a, b) => a + b) / scores.length));
  }

  /// Get score trend over time for a specific type
  static List<({DateTime date, double score})> getScoreTrend(
      String profileId, AssessmentType type) {
    final results = getResultsByType(profileId, type);
    results.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return results
        .map((r) => (date: r.completedAt, score: r.percentage))
        .toList();
  }

  /// Check if pre-test has been taken
  static bool hasCompletedPreTest(String profileId) {
    return getResultsByType(profileId, AssessmentType.preTest).isNotEmpty;
  }

  /// Check if post-test has been taken
  static bool hasCompletedPostTest(String profileId) {
    return getResultsByType(profileId, AssessmentType.postTest).isNotEmpty;
  }

  /// Get custom assessments created by teachers
  static List<Assessment> getCustomAssessments(String profileId) {
    return getAssessments(profileId)
        .where((a) => a.type == AssessmentType.custom)
        .toList();
  }

  // ─── Assignment System ─────────────────────────────────

  /// Get all assignments created by an educator.
  static List<AssessmentAssignment> getAssignments(String educatorId) {
    final raw = _box.get('assignments_$educatorId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => AssessmentAssignment.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save or update an assignment.
  static Future<void> saveAssignment(
      String educatorId, AssessmentAssignment assignment) async {
    final list = getAssignments(educatorId);
    list.removeWhere((a) => a.id == assignment.id);
    list.add(assignment);
    await _box.put(
      'assignments_$educatorId',
      list.map((a) => a.toJson()).toList(),
    );
  }

  /// Delete an assignment.
  static Future<void> deleteAssignment(
      String educatorId, String assignmentId) async {
    final list = getAssignments(educatorId);
    list.removeWhere((a) => a.id == assignmentId);
    await _box.put(
      'assignments_$educatorId',
      list.map((a) => a.toJson()).toList(),
    );
  }

  /// Get assignments for a specific student (across all educators).
  static List<AssessmentAssignment> getAssignmentsForStudent(
      String studentId) {
    final allKeys = _box.keys
        .where((k) => k.toString().startsWith('assignments_'));
    final result = <AssessmentAssignment>[];
    for (final key in allKeys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final assignments = (raw as List)
          .map((e) => AssessmentAssignment.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .where((a) => a.studentIds.contains(studentId))
          .toList();
      result.addAll(assignments);
    }
    return result;
  }

  /// Get pending (not yet completed) assignments for a student.
  static List<AssessmentAssignment> getPendingAssignments(
      String studentId) {
    final assignments = getAssignmentsForStudent(studentId);
    final results = getResults(studentId);
    final completedAssessmentIds =
        results.map((r) => r.assessmentId).toSet();

    return assignments
        .where((a) => !completedAssessmentIds.contains(a.assessmentId))
        .toList();
  }

  /// Build completion status for each student in an assignment.
  static List<StudentAssignmentStatus> getAssignmentStatuses(
      AssessmentAssignment assignment) {
    final statuses = <StudentAssignmentStatus>[];
    final allProfiles = HiveService.getAllProfilesWithProgress();

    for (final studentId in assignment.studentIds) {
      final profileMatch = allProfiles
          .where((d) => d.$1.id == studentId);
      final name = profileMatch.isNotEmpty
          ? profileMatch.first.$1.name
          : 'Unknown';

      final results = getResults(studentId);
      final matchingResult = results
          .where((r) => r.assessmentId == assignment.assessmentId)
          .toList();

      AssignmentStatus status;
      AssessmentResult? result;

      if (matchingResult.isNotEmpty) {
        status = AssignmentStatus.completed;
        result = matchingResult.last;
      } else if (assignment.isOverdue) {
        status = AssignmentStatus.overdue;
      } else {
        status = AssignmentStatus.pending;
      }

      statuses.add(StudentAssignmentStatus(
        studentId: studentId,
        studentName: name,
        status: status,
        result: result,
      ));
    }
    return statuses;
  }
}
