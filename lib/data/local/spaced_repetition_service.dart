import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/knowledge_tracing_service.dart';
import '../models/models.dart';

/// Per-word accuracy record used by the spaced repetition algorithm.
class WordAccuracy {
  final String wordId;
  final int correct;
  final int total;
  final DateTime lastSeen;

  const WordAccuracy({
    required this.wordId,
    this.correct = 0,
    this.total = 0,
    required this.lastSeen,
  });

  double get accuracy => total > 0 ? correct / total : 0.0;

  /// Priority score: lower accuracy + longer time unseen = higher priority.
  /// Range roughly 0.0 (well-known, recently seen) to 2.0+ (unknown, stale).
  double get priority {
    final daysSince = DateTime.now().difference(lastSeen).inHours / 24.0;
    final forgettingFactor = (daysSince / 3.0).clamp(
      0.0,
      1.0,
    ); // peaks at 3 days
    final difficultyFactor = 1.0 - accuracy; // 0 = perfect, 1 = never correct
    return difficultyFactor + forgettingFactor;
  }

  WordAccuracy recordAttempt(bool wasCorrect) {
    return WordAccuracy(
      wordId: wordId,
      correct: correct + (wasCorrect ? 1 : 0),
      total: total + 1,
      lastSeen: DateTime.now(),
    );
  }
}

/// Manages per-word accuracy data and produces smart review word lists.
class SpacedRepetitionService {
  static const String _boxName = 'progress';

  static Box get _box => Hive.box(_boxName);

  // ─── Persistence ────────────────────────────────────

  /// Returns the accuracy map for a given profile.
  static Map<String, WordAccuracy> getWordAccuracies(String profileId) {
    final data = _box.get('sr_$profileId');
    if (data == null) return {};
    final map = Map<String, dynamic>.from(data as Map);
    return map.map((key, value) {
      final m = Map<String, dynamic>.from(value as Map);
      return MapEntry(
        key,
        WordAccuracy(
          wordId: key,
          correct: m['correct'] as int? ?? 0,
          total: m['total'] as int? ?? 0,
          lastSeen: DateTime.parse(m['lastSeen'] as String),
        ),
      );
    });
  }

  static Future<void> _saveWordAccuracies(
    String profileId,
    Map<String, WordAccuracy> accuracies,
  ) async {
    final data = accuracies.map(
      (key, wa) => MapEntry(key, {
        'correct': wa.correct,
        'total': wa.total,
        'lastSeen': wa.lastSeen.toIso8601String(),
      }),
    );
    await _box.put('sr_$profileId', data);
  }

  // ─── Recording ──────────────────────────────────────

  /// Record a single word attempt (correct or wrong) for spaced repetition.
  ///
  /// Every word-level flow in the app (games, tutor quizzes, flashcards,
  /// guided practice) funnels through here, so this is also the single
  /// choke point that feeds the Elo knowledge-tracing model.
  static Future<void> recordWordAttempt({
    required String profileId,
    required String wordId,
    required bool wasCorrect,
  }) async {
    final accs = getWordAccuracies(profileId);
    final existing =
        accs[wordId] ?? WordAccuracy(wordId: wordId, lastSeen: DateTime.now());
    accs[wordId] = existing.recordAttempt(wasCorrect);
    await _saveWordAccuracies(profileId, accs);
    try {
      await KnowledgeTracingService.recordAttempt(
        profileId: profileId,
        wordId: wordId,
        wasCorrect: wasCorrect,
      );
    } catch (_) {
      // Elo is a derived model — never let it break the primary SR write.
    }
  }

  /// Batch record after a game (list of word IDs and whether each was correct).
  static Future<void> recordBatch({
    required String profileId,
    required Map<String, bool> results, // wordId -> wasCorrect
  }) async {
    final accs = getWordAccuracies(profileId);
    for (final entry in results.entries) {
      final existing =
          accs[entry.key] ??
          WordAccuracy(wordId: entry.key, lastSeen: DateTime.now());
      accs[entry.key] = existing.recordAttempt(entry.value);
    }
    await _saveWordAccuracies(profileId, accs);
    try {
      await KnowledgeTracingService.recordBatch(
        profileId: profileId,
        results: results,
      );
    } catch (_) {
      // Elo is a derived model — never let it break the primary SR write.
    }
  }

  // ─── Smart Review ───────────────────────────────────

  /// Returns a prioritized list of flashcards for review.
  /// Words the student struggles with and hasn't seen recently come first.
  /// Unseen words are also included with moderate priority.
  static List<Flashcard> getReviewWords({
    required String profileId,
    required List<Flashcard> allCards,
    int count = 10,
  }) {
    final accs = getWordAccuracies(profileId);

    // Build scored list — every card gets a priority
    final scored = allCards.map((card) {
      final wa = accs[card.id];
      if (wa == null) {
        // Never seen → moderate-high priority (0.8)
        return (card, 0.8);
      }
      return (card, wa.priority);
    }).toList();

    // Sort descending by priority (weakest first)
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    return scored.take(count).map((e) => e.$1).toList();
  }

  /// Elo-blended review list: combines the forgetting-curve [WordAccuracy]
  /// priority (recency + raw accuracy) with the knowledge-tracing model's
  /// predicted failure probability (1 − p). The blend keeps the proven
  /// recency behaviour while letting the Elo estimate pull forward words
  /// the student is *predicted* to miss even when raw accuracy looks okay.
  ///
  /// [getReviewWords] remains the default path; consumers opt in per call
  /// so the two rankings can be compared in the study.
  static List<Flashcard> getReviewWordsElo({
    required String profileId,
    required List<Flashcard> allCards,
    int count = 10,
    double eloWeight = 0.5,
  }) {
    final accs = getWordAccuracies(profileId);
    final mastery = KnowledgeTracingService.masterySnapshot(profileId);
    final srWeight = 1.0 - eloWeight;

    final scored = allCards.map((card) {
      // Normalize the ~0..2 priority into 0..1; unseen words keep the same
      // moderate-high default as getReviewWords.
      final wa = accs[card.id];
      final srScore = ((wa?.priority ?? 0.8) / 2.0).clamp(0.0, 1.0);
      // Unseen by Elo → neutral 0.5 failure probability.
      final eloScore = 1.0 - (mastery[card.id] ?? 0.5);
      return (card, srWeight * srScore + eloWeight * eloScore);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(count).map((e) => e.$1).toList();
  }

  /// Returns weak words (accuracy < threshold) sorted by worst accuracy first.
  static List<(Flashcard, WordAccuracy)> getWeakWords({
    required String profileId,
    required List<Flashcard> allCards,
    double threshold = 0.6,
  }) {
    final accs = getWordAccuracies(profileId);
    final weak = <(Flashcard, WordAccuracy)>[];
    for (final card in allCards) {
      final wa = accs[card.id];
      if (wa != null && wa.total >= 2 && wa.accuracy < threshold) {
        weak.add((card, wa));
      }
    }
    weak.sort((a, b) => a.$2.accuracy.compareTo(b.$2.accuracy));
    return weak;
  }

  /// Summary stats for a profile.
  static ({int totalAttempted, int totalCorrect, int wordsStruggling})
  getSummary(String profileId) {
    final accs = getWordAccuracies(profileId);
    int attempted = 0;
    int correct = 0;
    int struggling = 0;
    for (final wa in accs.values) {
      attempted += wa.total;
      correct += wa.correct;
      if (wa.total >= 2 && wa.accuracy < 0.6) struggling++;
    }
    return (
      totalAttempted: attempted,
      totalCorrect: correct,
      wordsStruggling: struggling,
    );
  }
}
