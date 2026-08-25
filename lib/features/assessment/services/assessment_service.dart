import 'dart:async';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/assessment_models.dart';
import '../models/custom_quiz_models.dart';

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

  /// Resolve an assessment template by [assessmentId], wherever it lives on
  /// this device.
  ///
  /// Templates are stored per creator (`assessments_<profileId>`), so a learner
  /// opening an assessment their educator assigned can never find it under
  /// their own key. Every route that only accepted a pre-built [Assessment] via
  /// go_router's `extra` therefore dead-ended back on the hub whenever the id
  /// was all the caller had — which is the case for a deep link, and was the
  /// case for the educator's own custom-assessment tiles.
  ///
  /// The `progress` box is shared by every profile on the device, so scan each
  /// creator's list and then fall back to the stored pre-test templates. A
  /// single unparseable record is skipped rather than failing the whole lookup.
  /// Returns null when nothing matches.
  static Assessment? findAssessmentById(String assessmentId) {
    if (assessmentId.isEmpty) return null;
    for (final key in _box.keys.toList()) {
      if (!key.toString().startsWith('assessments_')) continue;
      final raw = _box.get(key);
      if (raw is! List) continue;
      for (final entry in raw) {
        if (entry is! Map) continue;
        try {
          final json = Map<String, dynamic>.from(entry);
          if (json['id'] != assessmentId) continue;
          return Assessment.fromJson(json);
        } catch (_) {
          // Corrupt record — keep looking rather than dead-end the learner.
        }
      }
    }
    try {
      return getPreTestTemplate(assessmentId);
    } catch (_) {
      return null;
    }
  }

  /// Union [incoming] into this profile's stored templates, keyed by id.
  ///
  /// Used by the cloud hydrate: a device must end up with everything it knew
  /// plus everything the cloud knew, without a pull wiping work created here
  /// while offline. The incoming (cloud) copy wins a same-id collision — it is
  /// the version other devices are already reading.
  static Future<void> mergeAssessments(
      String profileId, List<Assessment> incoming) async {
    if (incoming.isEmpty) return;
    final deleted = getPendingDeletions('assessments_$profileId');
    final byId = {for (final a in getAssessments(profileId)) a.id: a};
    for (final a in incoming) {
      // A row this device deleted while offline must not come back just
      // because the cloud has not caught up yet.
      if (deleted.contains(a.id)) continue;
      byId[a.id] = a;
    }
    await _box.put(
      'assessments_$profileId',
      byId.values.map((a) => a.toJson()).toList(),
    );
  }

  // ─── Deletion Tombstones ───────────────────────────────

  /// Ids deleted on this device whose cloud delete has not been confirmed.
  ///
  /// Without these a delete made offline was silently undone: the row went
  /// from Hive immediately, the Firestore delete failed, and the very next
  /// hydrate pulled the still-present cloud copy straight back. The educator
  /// deleted an assignment, watched it vanish, and found it again the next
  /// time they opened the screen.
  ///
  /// A tombstone does two jobs until the cloud delete is confirmed: it makes
  /// [mergeAssessments] / [mergeAssignments] refuse to resurrect the id, and
  /// it tells the next connected hydrate to retry the delete. It is cleared
  /// the moment the cloud acknowledges, so only genuinely pending deletions
  /// take up space.
  static const String tombstonePrefix = 'deleted_';

  /// Pending deletions for a storage bucket, e.g. `assessments_<profileId>`
  /// or `assignments_<educatorId>`.
  static Set<String> getPendingDeletions(String bucket) {
    final raw = _box.get('$tombstonePrefix$bucket');
    if (raw is! List) return {};
    return raw.map((e) => e.toString()).toSet();
  }

  static Future<void> markDeleted(String bucket, String id) async {
    final ids = getPendingDeletions(bucket)..add(id);
    await _box.put('$tombstonePrefix$bucket', ids.toList());
  }

  /// Forget a tombstone — the cloud has confirmed the delete (or never had
  /// the row to begin with).
  static Future<void> clearDeletion(String bucket, String id) async {
    final ids = getPendingDeletions(bucket);
    if (!ids.remove(id)) return;
    if (ids.isEmpty) {
      await _box.delete('$tombstonePrefix$bucket');
    } else {
      await _box.put('$tombstonePrefix$bucket', ids.toList());
    }
  }

  // ─── Synced-id Ledger ──────────────────────────────────

  /// Ids this device has confirmed exist in the cloud.
  ///
  /// Needed to answer a question a pull alone cannot: a local row the cloud
  /// did not return is *either* something created here while offline and not
  /// yet uploaded, *or* something another device deleted. Pushing the second
  /// case resurrects a deleted row; deleting the first loses work. The ledger
  /// tells them apart — an id in here was in the cloud once, so its absence
  /// now is a deletion.
  ///
  /// Only ids are stored, and an entry is dropped as soon as the row is gone,
  /// so this stays proportional to what the educator actually owns.
  static const String syncedPrefix = 'synced_';

  static Set<String> getSyncedIds(String bucket) {
    final raw = _box.get('$syncedPrefix$bucket');
    if (raw is! List) return {};
    return raw.map((e) => e.toString()).toSet();
  }

  static Future<void> markSynced(String bucket, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final current = getSyncedIds(bucket);
    final before = current.length;
    current.addAll(ids);
    if (current.length == before) return;
    await _box.put('$syncedPrefix$bucket', current.toList());
  }

  static Future<void> unmarkSynced(String bucket, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final current = getSyncedIds(bucket);
    final before = current.length;
    current.removeAll(ids);
    if (current.length == before) return;
    if (current.isEmpty) {
      await _box.delete('$syncedPrefix$bucket');
    } else {
      await _box.put('$syncedPrefix$bucket', current.toList());
    }
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

  /// Union [incoming] into this profile's stored results, keyed by id.
  ///
  /// Results are append-only in practice, so this is a straight union; the
  /// same last-100 cap as [saveResult] applies, keeping the newest by
  /// completion time rather than by arrival order.
  static Future<void> mergeResults(
      String profileId, List<AssessmentResult> incoming) async {
    if (incoming.isEmpty) return;
    final byId = {for (final r in getResults(profileId)) r.id: r};
    for (final r in incoming) {
      byId[r.id] = r;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    if (merged.length > 100) {
      merged.removeRange(0, merged.length - 100);
    }
    await _box.put(
      'assessment_results_$profileId',
      merged.map((r) => r.toJson()).toList(),
    );
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

  // ─── Custom Quiz Materialisation ───────────────────────

  /// Turn a [CustomQuiz] recipe into a concrete [Assessment].
  ///
  /// A quiz stores card ids and permitted formats, not questions — it re-rolls
  /// them on every play, which is right for practice and wrong for an
  /// assignment. An assigned instrument has to be fixed: every learner must sit
  /// the same items, and the educator's tracking has to line up against one
  /// question set. So assigning a quiz mints an immutable Assessment and hands
  /// *that* out; the quiz stays a reusable generator.
  ///
  /// [id] defaults to a fresh uuid, which is what assigning wants — the same
  /// quiz handed out twice is two separate sittings, tracked separately. The
  /// play-now path passes the quiz's own id so a learner's practice history
  /// keeps grouping under it.
  ///
  /// Cards that no longer exist are skipped, so a quiz can outlive a deleted
  /// flashcard; the caller should treat an empty question list as "not
  /// assignable" rather than handing out a blank test.
  static Assessment materialiseQuiz(
    CustomQuiz quiz,
    List<Flashcard> allCards, {
    String? id,
    Random? random,
  }) {
    final rng = random ?? Random();
    final byId = {for (final c in allCards) c.id: c};
    final cards = quiz.flashcardIds
        .map((cardId) => byId[cardId])
        .whereType<Flashcard>()
        .toList();

    final formats = quiz.questionFormats.isEmpty
        ? const [QuestionFormat.multipleChoice]
        : quiz.questionFormats;

    final questions = [
      for (final card in cards)
        _buildQuizQuestion(
          card,
          formats[rng.nextInt(formats.length)],
          allCards,
          rng,
        ),
    ];

    return Assessment(
      id: id ?? _uuid.v4(),
      title: quiz.title,
      type: AssessmentType.custom,
      questions: questions,
      difficulty: quiz.difficulty,
      timeLimitMinutes: quiz.timeLimitMinutes,
      createdBy: quiz.createdBy,
      createdAt: DateTime.now(),
    );
  }

  /// The Quiz Builder's own question wording, moved here verbatim so the
  /// play-now path and the assign path cannot drift. Deliberately *not* merged
  /// with [_generateQuestion] above: that one phrases items differently and
  /// changing what a learner reads is not part of making quizzes assignable.
  static AssessmentQuestion _buildQuizQuestion(
    Flashcard card,
    QuestionFormat format,
    List<Flashcard> allCards,
    Random random,
  ) {
    List<String> choicesWithDistractors() {
      final others = allCards.where((c) => c.id != card.id).toList()
        ..shuffle(random);
      final wrong = others.take(3).map((c) => c.wordFilipino).toList();
      return [card.wordFilipino, ...wrong]..shuffle(random);
    }

    switch (format) {
      case QuestionFormat.multipleChoice:
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText: 'What is the Filipino word for "${card.wordEnglish}"?',
          correctAnswer: card.wordFilipino,
          choices: choicesWithDistractors(),
          category: card.category,
        );

      case QuestionFormat.fillInBlank:
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'Fill in the blank: The Filipino translation of '
              '"${card.wordEnglish}" is _____.',
          correctAnswer: card.wordFilipino,
          choices: const [],
          format: QuestionFormat.fillInBlank,
          category: card.category,
        );

      case QuestionFormat.trueFalse:
        final others = allCards.where((c) => c.id != card.id).toList()
          ..shuffle(random);
        // With no other card to borrow a wrong answer from, the only
        // statement we can make truthfully is the true one.
        final isTrue = others.isEmpty || random.nextBool();
        final displayWord = isTrue
            ? card.wordFilipino
            : others.first.wordFilipino;
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'True or False: "${card.wordEnglish}" is "$displayWord" in Filipino.',
          correctAnswer: isTrue ? 'True' : 'False',
          choices: const ['True', 'False'],
          format: QuestionFormat.trueFalse,
          category: card.category,
        );

      case QuestionFormat.matchPairs:
        // Falls back to multiple choice for matching
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText: 'Match: "${card.wordEnglish}" → ?',
          correctAnswer: card.wordFilipino,
          choices: choicesWithDistractors(),
          category: card.category,
        );
    }
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

  /// Union [incoming] into this educator's stored assignments, keyed by id.
  static Future<void> mergeAssignments(
      String educatorId, List<AssessmentAssignment> incoming) async {
    if (incoming.isEmpty) return;
    final deleted = getPendingDeletions('assignments_$educatorId');
    final byId = {for (final a in getAssignments(educatorId)) a.id: a};
    for (final a in incoming) {
      if (deleted.contains(a.id)) continue;
      byId[a.id] = a;
    }
    await _box.put(
      'assignments_$educatorId',
      byId.values.map((a) => a.toJson()).toList(),
    );
  }

  /// Stop showing [learnerId] any locally-stored assignment whose id is not in
  /// [keepIds]. Returns true if anything changed.
  ///
  /// The learner's half of cross-device deletion. `_reconcile` settles an
  /// *educator's* own buckets, but a learner's device holds copies of those
  /// buckets too — put there by `hydrateLearner` — and nothing was clearing
  /// them. A teacher who withdrew an assignment found their pupil still being
  /// told to do it, on every launch, for good.
  ///
  /// This removes the learner from the row rather than deleting the row, so a
  /// shared tablet holding work for a sibling or classmate keeps theirs. A row
  /// left naming nobody is dropped. If this device is also the educator's, the
  /// trim is harmless: their own authoritative pull merges the full row back.
  ///
  /// [keepIds] must come from a *server-sourced* query — a cached answer can
  /// be empty or stale without error, and acting on it would withdraw work
  /// that was never cancelled.
  ///
  /// **Rows the educator has not synced yet are never touched.** On a shared
  /// tablet the educator's own buckets live beside the learner's copies, and a
  /// row created while the educator was offline is legitimately absent from
  /// the learner's cloud query — its absence proves nothing. Withdrawing from
  /// it emptied the row and destroyed work that had not had its chance to
  /// upload. Same principle as [AssessmentCloudService.classifyLocalRows]:
  /// missing from the cloud only means *deleted* if it was ever *in* the cloud.
  static Future<bool> withdrawLearnerFromAssignmentsExcept(
    String learnerId,
    Set<String> keepIds,
  ) async {
    if (learnerId.isEmpty) return false;
    var changed = false;

    for (final key in _box.keys.toList()) {
      final bucket = key.toString();
      if (!bucket.startsWith('assignments_')) continue;
      final raw = _box.get(key);
      if (raw is! List) continue;
      final synced = getSyncedIds(bucket);

      final kept = <Map<String, dynamic>>[];
      var touched = false;
      for (final entry in raw) {
        if (entry is! Map) continue;
        Map<String, dynamic> json;
        try {
          json = Map<String, dynamic>.from(entry);
        } catch (_) {
          continue;
        }
        final ids = List<String>.from(
          (json['studentIds'] as List? ?? const []).map((e) => e.toString()),
        );
        final id = json['id']?.toString() ?? '';
        if (keepIds.contains(id) ||
            !ids.contains(learnerId) ||
            !synced.contains(id)) {
          kept.add(json);
          continue;
        }
        touched = true;
        ids.remove(learnerId);
        if (ids.isEmpty) continue; // nobody left to show it to
        kept.add({...json, 'studentIds': ids});
      }

      if (!touched) continue;
      changed = true;
      if (kept.isEmpty) {
        await _box.delete(key);
      } else {
        await _box.put(key, kept);
      }
    }
    return changed;
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

  /// Pending assignments for [studentId] paired with the template each one
  /// points at, ready to hand straight to the test screen.
  ///
  /// An assignment is only *openable* if its template is still on this device;
  /// one whose assessment the educator has since deleted is dropped rather than
  /// listed as a tile that cannot be tapped. Sorted soonest-deadline first,
  /// with undated assignments last, so the thing due tomorrow is on top.
  static List<({AssessmentAssignment assignment, Assessment assessment})>
      getOpenableAssignments(String studentId) {
    final open = <({AssessmentAssignment assignment, Assessment assessment})>[];
    for (final assignment in getPendingAssignments(studentId)) {
      final assessment = findAssessmentById(assignment.assessmentId);
      if (assessment == null) continue;
      open.add((assignment: assignment, assessment: assessment));
    }
    open.sort((a, b) {
      final da = a.assignment.deadline;
      final db = b.assignment.deadline;
      if (da == null && db == null) {
        return b.assignment.assignedAt.compareTo(a.assignment.assignedAt);
      }
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return open;
  }

  /// Build completion status for each student in an assignment.
  ///
  /// [names] is an optional profile-id → display-name map, which the caller
  /// should fill from `educatorLearnerRosterProvider`. Local Hive alone is not
  /// enough once assignments cross devices: a student who joined the class
  /// from their own tablet has a roster entry but no local profile row, and
  /// every tracking row for them read "Unknown".
  static List<StudentAssignmentStatus> getAssignmentStatuses(
      AssessmentAssignment assignment,
      {Map<String, String> names = const {}}) {
    final statuses = <StudentAssignmentStatus>[];
    final allProfiles = HiveService.getAllProfilesWithProgress();

    for (final studentId in assignment.studentIds) {
      final profileMatch = allProfiles
          .where((d) => d.$1.id == studentId);
      final name = names[studentId] ??
          (profileMatch.isNotEmpty
              ? profileMatch.first.$1.name
              : 'Unknown');

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
