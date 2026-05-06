import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/spaced_repetition_service.dart';
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

  // ─── Auto-Generate Assessments ─────────────────────────

  /// Generate a pre-test or post-test assessment from seed data
  static Assessment generateStandardAssessment({
    required String profileId,
    required AssessmentType type,
    List<FlashcardCategory> categories = const [],
    GameDifficulty difficulty = GameDifficulty.medium,
    int questionCount = 15,
  }) {
    final cats = categories.isEmpty ? FlashcardCategory.values.toList() : categories;
    final allCards = <Flashcard>[];
    for (final cat in cats) {
      allCards.addAll(SeedData.getByCategory(cat));
    }

    // For post-tests, prioritize words the student has seen
    List<Flashcard> selectedCards;
    if (type == AssessmentType.postTest) {
      final accuracies = SpacedRepetitionService.getWordAccuracies(profileId);
      final seen = allCards.where((c) => accuracies.containsKey(c.id)).toList();
      final unseen = allCards.where((c) => !accuracies.containsKey(c.id)).toList();
      selectedCards = [...seen, ...unseen];
    } else {
      selectedCards = List.from(allCards)..shuffle(Random());
    }

    final count = min(questionCount, selectedCards.length);
    selectedCards = selectedCards.take(count).toList();

    final questions = <AssessmentQuestion>[];
    final rng = Random();

    for (final card in selectedCards) {
      final format = _randomFormat(difficulty, rng);
      final question = _generateQuestion(card, allCards, format, rng);
      questions.add(question);
    }

    return Assessment(
      id: _uuid.v4(),
      title: '${type.label} — ${cats.length == FlashcardCategory.values.length ? "All Categories" : cats.map((c) => c.label).join(", ")}',
      description: type.description,
      type: type,
      questions: questions,
      categories: cats,
      difficulty: difficulty,
      timeLimitMinutes: difficulty == GameDifficulty.hard ? 10 : null,
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
