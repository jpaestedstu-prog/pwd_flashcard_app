import 'package:hive_flutter/hive_flutter.dart';
import '../../data/local/spaced_repetition_service.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'learning_level_service.dart';

/// Suggests game difficulty and word selection based on the student's
/// historical accuracy data from spaced repetition.
class AdaptiveDifficultyService {
  AdaptiveDifficultyService._();

  /// Suggest a difficulty level based on the student's overall accuracy
  /// and optionally filtered by selected categories.
  ///
  /// - accuracy < 40% → Easy
  /// - accuracy 40–70% → Medium
  /// - accuracy > 70% → Hard
  static GameDifficulty suggestDifficulty({
    required String profileId,
    List<FlashcardCategory> categories = const [],
  }) {
    final accuracies = SpacedRepetitionService.getWordAccuracies(profileId);

    if (accuracies.isEmpty) {
      // No data yet — start with Easy
      return GameDifficulty.easy;
    }

    // Filter by categories if provided
    Iterable<WordAccuracy> relevantAccuracies;
    if (categories.isNotEmpty) {
      // We need flashcard data to know which words belong to which category,
      // but we only have word IDs in accuracy data. Use overall stats instead
      // when category-specific filtering isn't available.
      relevantAccuracies = accuracies.values;
    } else {
      relevantAccuracies = accuracies.values;
    }

    // Calculate overall accuracy
    int totalCorrect = 0;
    int totalAttempts = 0;
    for (final wa in relevantAccuracies) {
      totalCorrect += wa.correct;
      totalAttempts += wa.total;
    }

    if (totalAttempts == 0) return GameDifficulty.easy;

    final overallAccuracy = totalCorrect / totalAttempts;

    if (overallAccuracy < 0.4) return GameDifficulty.easy;
    if (overallAccuracy <= 0.7) return GameDifficulty.medium;
    return GameDifficulty.hard;
  }

  /// Get a human-readable explanation of why a difficulty was suggested.
  static String getSuggestionReason({
    required String profileId,
  }) {
    final summary = SpacedRepetitionService.getSummary(profileId);

    if (summary.totalAttempted == 0) {
      return "You're just getting started! We'll begin with easy questions.";
    }

    final accuracy = summary.totalCorrect / summary.totalAttempted;
    final pct = (accuracy * 100).round();

    if (accuracy < 0.4) {
      return 'Your accuracy is $pct%. Let\'s practice with easier questions to build confidence!';
    }
    if (accuracy <= 0.7) {
      return 'Your accuracy is $pct%. A balanced challenge to keep you growing!';
    }
    return 'Your accuracy is $pct%. You\'re doing great — time for a real challenge!';
  }

  /// Returns flashcards reordered to prioritize weak words first.
  /// This helps games focus on words the student struggles with.
  static List<Flashcard> getAdaptiveWordOrder({
    required String profileId,
    required List<Flashcard> cards,
  }) {
    final accuracies = SpacedRepetitionService.getWordAccuracies(profileId);

    if (accuracies.isEmpty) return cards;

    // Score each card: lower accuracy = higher priority
    final scored = cards.map((card) {
      final wa = accuracies[card.id];
      if (wa == null) {
        // Never seen → moderate priority
        return (card, 0.7);
      }
      return (card, wa.priority);
    }).toList();

    // Sort descending by priority (weakest first)
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    return scored.map((e) => e.$1).toList();
  }

  /// Returns a difficulty icon string for display.
  static String getDifficultyEmoji(GameDifficulty difficulty) {
    return switch (difficulty) {
      GameDifficulty.easy => '😊',
      GameDifficulty.medium => '💪',
      GameDifficulty.hard => '🔥',
    };
  }

  // ═══════════════════════════════════════════════════════════
  // ADAPTIVE ENGINE  —  tracks per-game-type & per-category
  // difficulty with automatic adjustments after each game.
  // ═══════════════════════════════════════════════════════════

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  /// Storage key for the difficulty history list.
  static String _historyKey(String profileId) =>
      'adaptive_history_$profileId';

  /// Storage key for per-game-type overrides.
  static String _gameOverrideKey(String profileId) =>
      'adaptive_game_overrides_$profileId';

  /// Storage key for per-category overrides.
  static String _catOverrideKey(String profileId) =>
      'adaptive_cat_overrides_$profileId';

  // ─── Record & Adjust ─────────────────────────────────────

  /// Call this after a game completes. Records the outcome and adjusts
  /// difficulty for the given game type and category.
  ///
  /// Returns the new suggested difficulty.
  static GameDifficulty recordGameResult({
    required String profileId,
    required GameType gameType,
    required FlashcardCategory? category,
    required int score,
    required int total,
    required GameDifficulty playedDifficulty,
    int? durationSeconds,
  }) {
    final accuracy = total > 0 ? score / total : 0.0;

    // 1. Persist history entry
    _addHistoryEntry(
      profileId: profileId,
      gameType: gameType,
      category: category,
      difficulty: playedDifficulty,
      accuracy: accuracy,
      durationSeconds: durationSeconds,
    );

    // 2. Re-evaluate difficulty based on the sliding window
    final newDifficulty = _computeAdaptiveDifficulty(
      profileId: profileId,
      gameType: gameType,
      category: category,
    );

    // 3. Save overrides
    _setGameOverride(profileId, gameType, newDifficulty);
    if (category != null) {
      _setCategoryOverride(profileId, category, newDifficulty);
    }

    // 4. Consider promoting the learner's adaptive level. Fire-and-forget;
    // the result toast is handled (when wired) in the level-up provider.
    // Wrapped in unawaited-style so a transient Firestore failure here
    // never bubbles up to the game UI.
    // ignore: discarded_futures
    LearningLevelService.maybePromote(profileId);

    return newDifficulty;
  }

  /// Suggest difficulty scoped to a specific game type & optional category.
  /// Falls back to the global suggestion if no override exists.
  static GameDifficulty suggestForGame({
    required String profileId,
    required GameType gameType,
    FlashcardCategory? category,
  }) {
    // Check game-type override first
    final gameOverrides = _getGameOverrides(profileId);
    if (gameOverrides.containsKey(gameType.name)) {
      return _difficultyFromName(gameOverrides[gameType.name]!);
    }

    // Then category override
    if (category != null) {
      final catOverrides = _getCategoryOverrides(profileId);
      if (catOverrides.containsKey(category.name)) {
        return _difficultyFromName(catOverrides[category.name]!);
      }
    }

    // Fallback to global
    return suggestDifficulty(profileId: profileId);
  }

  /// Return the full difficulty history for a student (most recent first).
  static List<DifficultyHistoryEntry> getHistory(String profileId) {
    final raw = _box.get(_historyKey(profileId));
    if (raw == null) return [];
    final list = (raw as List).cast<Map>();
    return list
        .map((m) => DifficultyHistoryEntry.fromMap(
            Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get per-game-type difficulty overrides.
  static Map<String, GameDifficulty> getGameOverrides(String profileId) {
    final raw = _getGameOverrides(profileId);
    return raw.map((k, v) => MapEntry(k, _difficultyFromName(v)));
  }

  /// Get per-category difficulty overrides.
  static Map<String, GameDifficulty> getCategoryOverrides(
      String profileId) {
    final raw = _getCategoryOverrides(profileId);
    return raw.map((k, v) => MapEntry(k, _difficultyFromName(v)));
  }

  /// Get a textual summary of the engine's current state for a student.
  static AdaptiveSummary getSummary(String profileId) {
    final history = getHistory(profileId);

    if (history.isEmpty) {
      return AdaptiveSummary(
        currentGlobal: suggestDifficulty(profileId: profileId),
        totalGamesTracked: 0,
        recentAccuracy: 0,
        trend: DifficultyTrend.stable,
        gameOverrides: {},
        categoryOverrides: {},
      );
    }

    // Recent 10 games
    final recent = history.take(10).toList();
    final recentAcc = recent.isEmpty
        ? 0.0
        : recent.map((e) => e.accuracy).reduce((a, b) => a + b) /
            recent.length;

    // Trend: compare first half vs second half of recent
    DifficultyTrend trend = DifficultyTrend.stable;
    if (recent.length >= 4) {
      final mid = recent.length ~/ 2;
      final firstHalf = recent.sublist(0, mid);
      final secondHalf = recent.sublist(mid);
      final firstAvg =
          firstHalf.map((e) => e.accuracy).reduce((a, b) => a + b) /
              firstHalf.length;
      final secondAvg =
          secondHalf.map((e) => e.accuracy).reduce((a, b) => a + b) /
              secondHalf.length;
      final diff = firstAvg - secondAvg;
      if (diff > 0.1) {
        trend = DifficultyTrend.improving;
      } else if (diff < -0.1) {
        trend = DifficultyTrend.declining;
      }
    }

    return AdaptiveSummary(
      currentGlobal: suggestDifficulty(profileId: profileId),
      totalGamesTracked: history.length,
      recentAccuracy: recentAcc,
      trend: trend,
      gameOverrides: getGameOverrides(profileId),
      categoryOverrides: getCategoryOverrides(profileId),
    );
  }

  // ─── Internal Helpers ────────────────────────────────────

  static GameDifficulty _computeAdaptiveDifficulty({
    required String profileId,
    required GameType gameType,
    FlashcardCategory? category,
  }) {
    final history = getHistory(profileId);

    // Use the last 5 games of the same type for game-specific tuning
    final gameHistory = history
        .where((h) => h.gameType == gameType.name)
        .take(5)
        .toList();

    // Use overall recent 10 as fallback
    final recentAll = history.take(10).toList();

    final scores = gameHistory.isNotEmpty ? gameHistory : recentAll;

    if (scores.isEmpty) return GameDifficulty.easy;

    final avgAcc =
        scores.map((e) => e.accuracy).reduce((a, b) => a + b) /
            scores.length;

    // Check for streaks of high/low performance (last 3 games)
    final last3 = scores.take(3).toList();
    final allHigh = last3.length == 3 && last3.every((e) => e.accuracy >= 0.85);
    final allLow = last3.length == 3 && last3.every((e) => e.accuracy < 0.4);

    // Streak-based fast adjustment
    if (allHigh) return GameDifficulty.hard;
    if (allLow) return GameDifficulty.easy;

    // Smooth threshold-based adjustment
    if (avgAcc < 0.4) return GameDifficulty.easy;
    if (avgAcc <= 0.7) return GameDifficulty.medium;
    return GameDifficulty.hard;
  }

  static void _addHistoryEntry({
    required String profileId,
    required GameType gameType,
    required FlashcardCategory? category,
    required GameDifficulty difficulty,
    required double accuracy,
    int? durationSeconds,
  }) {
    final entry = DifficultyHistoryEntry(
      timestamp: DateTime.now(),
      gameType: gameType.name,
      category: category?.name,
      difficulty: difficulty.name,
      accuracy: accuracy,
      durationSeconds: durationSeconds,
    );

    final key = _historyKey(profileId);
    final existing = (_box.get(key) as List?)?.cast<Map>() ?? [];
    existing.add(entry.toMap());

    // Cap at 200 entries to avoid unbounded growth
    if (existing.length > 200) {
      existing.removeRange(0, existing.length - 200);
    }

    _box.put(key, existing);
  }

  static Map<String, String> _getGameOverrides(String profileId) {
    final raw = _box.get(_gameOverrideKey(profileId));
    if (raw == null) return {};
    return Map<String, String>.from(raw as Map);
  }

  static void _setGameOverride(
    String profileId,
    GameType gameType,
    GameDifficulty difficulty,
  ) {
    final overrides = _getGameOverrides(profileId);
    overrides[gameType.name] = difficulty.name;
    _box.put(_gameOverrideKey(profileId), overrides);
  }

  static Map<String, String> _getCategoryOverrides(String profileId) {
    final raw = _box.get(_catOverrideKey(profileId));
    if (raw == null) return {};
    return Map<String, String>.from(raw as Map);
  }

  static void _setCategoryOverride(
    String profileId,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) {
    final overrides = _getCategoryOverrides(profileId);
    overrides[category.name] = difficulty.name;
    _box.put(_catOverrideKey(profileId), overrides);
  }

  static GameDifficulty _difficultyFromName(String name) {
    return GameDifficulty.values.firstWhere(
      (d) => d.name == name,
      orElse: () => GameDifficulty.medium,
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────

/// Tracks which direction a student's performance is trending.
enum DifficultyTrend { improving, stable, declining }

/// A single recorded game outcome for difficulty tracking.
class DifficultyHistoryEntry {
  final DateTime timestamp;
  final String gameType;
  final String? category;
  final String difficulty;
  final double accuracy;
  final int? durationSeconds;

  const DifficultyHistoryEntry({
    required this.timestamp,
    required this.gameType,
    this.category,
    required this.difficulty,
    required this.accuracy,
    this.durationSeconds,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'gameType': gameType,
        'category': category,
        'difficulty': difficulty,
        'accuracy': accuracy,
        'durationSeconds': durationSeconds,
      };

  factory DifficultyHistoryEntry.fromMap(Map<String, dynamic> m) {
    return DifficultyHistoryEntry(
      timestamp: DateTime.parse(m['timestamp'] as String),
      gameType: m['gameType'] as String,
      category: m['category'] as String?,
      difficulty: m['difficulty'] as String,
      accuracy: (m['accuracy'] as num).toDouble(),
      durationSeconds: m['durationSeconds'] as int?,
    );
  }
}

/// High-level summary of the adaptive engine's state for a student.
class AdaptiveSummary {
  final GameDifficulty currentGlobal;
  final int totalGamesTracked;
  final double recentAccuracy;
  final DifficultyTrend trend;
  final Map<String, GameDifficulty> gameOverrides;
  final Map<String, GameDifficulty> categoryOverrides;

  const AdaptiveSummary({
    required this.currentGlobal,
    required this.totalGamesTracked,
    required this.recentAccuracy,
    required this.trend,
    required this.gameOverrides,
    required this.categoryOverrides,
  });

  String get trendLabel => switch (trend) {
        DifficultyTrend.improving => '📈 Improving',
        DifficultyTrend.stable => '➡️ Stable',
        DifficultyTrend.declining => '📉 Needs Support',
      };

  String get trendDescription => switch (trend) {
        DifficultyTrend.improving =>
          'Performance is trending upward — great progress!',
        DifficultyTrend.stable =>
          'Performance is consistent — steady learning pace.',
        DifficultyTrend.declining =>
          'Recent scores are dropping — consider easier activities.',
      };
}
