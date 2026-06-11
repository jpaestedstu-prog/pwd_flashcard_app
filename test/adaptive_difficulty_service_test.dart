import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/adaptive_difficulty_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// In-memory Hive setup for unit tests.
Future<void> _initHive() async {
  Hive.init('./build/test_cache/adaptive_difficulty');
  if (!Hive.isBoxOpen('progress')) {
    await Hive.openBox('progress');
  }
  // recordGameResult fires LearningLevelService.maybePromote, which reads
  // the profiles box via HiveService.getProfileById. Open it so the
  // fire-and-forget promotion path doesn't throw a HiveError.
  if (!Hive.isBoxOpen('profiles')) {
    await Hive.openBox('profiles');
  }
}

void main() {
  late Box box;

  setUpAll(() async {
    await _initHive();
    box = Hive.box('progress');
  });

  setUp(() async {
    await box.clear();
    await Hive.box('profiles').clear();
  });

  // ─── getDifficultyEmoji ────────────────────────────────────

  group('getDifficultyEmoji', () {
    test('returns correct emoji for each difficulty', () {
      expect(AdaptiveDifficultyService.getDifficultyEmoji(GameDifficulty.easy),
          '😊');
      expect(
          AdaptiveDifficultyService.getDifficultyEmoji(GameDifficulty.medium),
          '💪');
      expect(AdaptiveDifficultyService.getDifficultyEmoji(GameDifficulty.hard),
          '🔥');
    });
  });

  // ─── suggestDifficulty ─────────────────────────────────────

  group('suggestDifficulty', () {
    test('returns easy when no accuracy data exists', () {
      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'new_user',
      );
      expect(result, GameDifficulty.easy);
    });

    test('returns easy when accuracy < 40%', () {
      // Seed spaced repetition data: 2 correct out of 10 = 20%
      box.put('sr_low_acc', {
        'word1': {
          'correct': 1,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 1,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'low_acc',
      );
      expect(result, GameDifficulty.easy);
    });

    test('returns medium when accuracy 40–70%', () {
      // 6 correct out of 10 = 60%
      box.put('sr_mid_acc', {
        'word1': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'mid_acc',
      );
      expect(result, GameDifficulty.medium);
    });

    test('returns hard when accuracy > 70%', () {
      // 9 correct out of 10 = 90%
      box.put('sr_high_acc', {
        'word1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 4,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'high_acc',
      );
      expect(result, GameDifficulty.hard);
    });

    test('returns easy when totalAttempts is 0', () {
      box.put('sr_zero', {
        'word1': {
          'correct': 0,
          'total': 0,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'zero',
      );
      expect(result, GameDifficulty.easy);
    });

    test('boundary: exactly 40% returns medium', () {
      // 4 correct out of 10 = 40%
      box.put('sr_boundary40', {
        'word1': {
          'correct': 2,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 2,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'boundary40',
      );
      expect(result, GameDifficulty.medium);
    });

    test('boundary: exactly 70% returns medium', () {
      // 7 correct out of 10 = 70%
      box.put('sr_boundary70', {
        'word1': {
          'correct': 4,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'word2': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.suggestDifficulty(
        profileId: 'boundary70',
      );
      expect(result, GameDifficulty.medium);
    });
  });

  // ─── getSuggestionReason ───────────────────────────────────

  group('getSuggestionReason', () {
    test('returns starter message when no attempts', () {
      final reason = AdaptiveDifficultyService.getSuggestionReason(
        profileId: 'starter',
      );
      expect(reason, contains('just getting started'));
    });

    test('returns low-accuracy message when < 40%', () {
      box.put('sr_low_reason', {
        'word1': {
          'correct': 1,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final reason = AdaptiveDifficultyService.getSuggestionReason(
        profileId: 'low_reason',
      );
      expect(reason, contains('easier questions'));
    });

    test('returns balanced message when 40–70%', () {
      box.put('sr_mid_reason', {
        'word1': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final reason = AdaptiveDifficultyService.getSuggestionReason(
        profileId: 'mid_reason',
      );
      expect(reason, contains('balanced challenge'));
    });

    test('returns strong message when > 70%', () {
      box.put('sr_high_reason', {
        'word1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final reason = AdaptiveDifficultyService.getSuggestionReason(
        profileId: 'high_reason',
      );
      expect(reason, contains('doing great'));
    });
  });

  // ─── getAdaptiveWordOrder ──────────────────────────────────

  group('getAdaptiveWordOrder', () {
    final cards = [
      const Flashcard(
        id: 'c1',
        wordEnglish: 'Cat',
        wordFilipino: 'Pusa',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c2',
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c3',
        wordEnglish: 'Bird',
        wordFilipino: 'Ibon',
        category: FlashcardCategory.animals,
      ),
    ];

    test('returns cards unchanged when no accuracy data', () {
      final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
        profileId: 'empty',
        cards: cards,
      );
      expect(result.length, 3);
    });

    test('puts weak words first', () {
      box.put('sr_order', {
        'c1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 100% accuracy
        'c2': {
          'correct': 1,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 20% accuracy
        'c3': {
          'correct': 3,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 60% accuracy
      });

      final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
        profileId: 'order',
        cards: cards,
      );

      // Weakest word (c2, 20%) should come first
      expect(result.first.id, 'c2');
      // Strongest word (c1, 100%) should come last
      expect(result.last.id, 'c1');
    });

    test('unseen words get moderate priority', () {
      // Only c1 has data; c2 and c3 are unseen
      box.put('sr_unseen', {
        'c1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 100% accuracy
      });

      final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
        profileId: 'unseen',
        cards: cards,
      );

      // c1 (100% accurate) should not be first
      expect(result.first.id, isNot('c1'));
    });
  });

  // ─── recordGameResult & suggestForGame ─────────────────────

  group('recordGameResult', () {
    test('records a result and returns new difficulty', () {
      final newDiff = AdaptiveDifficultyService.recordGameResult(
        profileId: 'gamer',
        gameType: GameType.wordMatch,
        category: FlashcardCategory.animals,
        score: 5,
        total: 5,
        playedDifficulty: GameDifficulty.easy,
      );
      expect(GameDifficulty.values, contains(newDiff));
    });

    test('history is stored after recording', () {
      AdaptiveDifficultyService.recordGameResult(
        profileId: 'hist_test',
        gameType: GameType.spellingBee,
        category: null,
        score: 3,
        total: 10,
        playedDifficulty: GameDifficulty.medium,
        durationSeconds: 120,
      );

      final history = AdaptiveDifficultyService.getHistory('hist_test');
      expect(history, isNotEmpty);
      expect(history.first.gameType, 'spellingBee');
      expect(history.first.accuracy, closeTo(0.3, 0.01));
      expect(history.first.durationSeconds, 120);
    });

    test('returns hard after streak of high scores', () {
      // Record 3 games with 100% accuracy
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'streak_high',
          gameType: GameType.memoryMatch,
          category: null,
          score: 10,
          total: 10,
          playedDifficulty: GameDifficulty.medium,
        );
      }

      final result = AdaptiveDifficultyService.suggestForGame(
        profileId: 'streak_high',
        gameType: GameType.memoryMatch,
      );
      expect(result, GameDifficulty.hard);
    });

    test('returns easy after streak of low scores', () {
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'streak_low',
          gameType: GameType.dragAndDrop,
          category: null,
          score: 1,
          total: 10,
          playedDifficulty: GameDifficulty.hard,
        );
      }

      final result = AdaptiveDifficultyService.suggestForGame(
        profileId: 'streak_low',
        gameType: GameType.dragAndDrop,
      );
      expect(result, GameDifficulty.easy);
    });

    test('category overrides are stored', () {
      AdaptiveDifficultyService.recordGameResult(
        profileId: 'cat_override',
        gameType: GameType.wordMatch,
        category: FlashcardCategory.animals,
        score: 9,
        total: 10,
        playedDifficulty: GameDifficulty.easy,
      );

      final catOverrides =
          AdaptiveDifficultyService.getCategoryOverrides('cat_override');
      expect(catOverrides, isNotEmpty);
    });
  });

  // ─── suggestForGame ────────────────────────────────────────

  group('suggestForGame', () {
    test('falls back to global suggestion when no overrides', () {
      final result = AdaptiveDifficultyService.suggestForGame(
        profileId: 'no_overrides',
        gameType: GameType.flashcardQuiz,
      );
      // No data → fallback to global suggestDifficulty → easy
      expect(result, GameDifficulty.easy);
    });

    test('uses game-type override when available', () {
      // Record enough results to create a game override
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'game_override',
          gameType: GameType.spellingBee,
          category: null,
          score: 10,
          total: 10,
          playedDifficulty: GameDifficulty.easy,
        );
      }

      final result = AdaptiveDifficultyService.suggestForGame(
        profileId: 'game_override',
        gameType: GameType.spellingBee,
      );
      expect(result, GameDifficulty.hard);
    });
  });

  // ─── getHistory ────────────────────────────────────────────

  group('getHistory', () {
    test('returns empty list for new profile', () {
      expect(AdaptiveDifficultyService.getHistory('nobody'), isEmpty);
    });

    test('returns entries sorted most recent first', () {
      // Record 3 games sequentially
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'timeline',
          gameType: GameType.wordMatch,
          category: null,
          score: i + 1,
          total: 10,
          playedDifficulty: GameDifficulty.easy,
        );
      }

      final history = AdaptiveDifficultyService.getHistory('timeline');
      expect(history.length, 3);
      // Most recent should be first
      expect(
        history.first.timestamp.isAfter(history.last.timestamp) ||
            history.first.timestamp.isAtSameMomentAs(history.last.timestamp),
        isTrue,
      );
    });
  });

  // ─── getSummary ────────────────────────────────────────────

  group('getSummary', () {
    test('returns default summary for new profile', () {
      final summary = AdaptiveDifficultyService.getSummary('fresh');
      expect(summary.totalGamesTracked, 0);
      expect(summary.recentAccuracy, 0);
      expect(summary.trend, DifficultyTrend.stable);
      expect(summary.gameOverrides, isEmpty);
      expect(summary.categoryOverrides, isEmpty);
    });

    test('computes non-stable trend with enough varied data', () {
      // Record 10 games with varying scores: first 5 low, last 5 high
      // Enough data to exceed the 0.1 threshold even if timestamp
      // sorting is unstable within the same millisecond.
      for (var i = 0; i < 10; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'trend_test',
          gameType: GameType.wordMatch,
          category: null,
          score: i < 5 ? 1 : 10,
          total: 10,
          playedDifficulty: GameDifficulty.easy,
        );
      }

      final summary = AdaptiveDifficultyService.getSummary('trend_test');
      expect(summary.totalGamesTracked, 10);
      // With enough data, the trend should be non-stable in either direction
      expect(
        summary.trend,
        anyOf(DifficultyTrend.improving, DifficultyTrend.declining),
      );
    });

    test('trendLabel returns correct labels', () {
      final summary = AdaptiveDifficultyService.getSummary('label_test');
      expect(summary.trendLabel, contains('Stable'));
    });
  });

  // ─── DifficultyHistoryEntry ────────────────────────────────

  group('DifficultyHistoryEntry', () {
    test('toMap / fromMap roundtrip', () {
      final entry = DifficultyHistoryEntry(
        timestamp: DateTime(2025, 6, 1, 10, 30),
        gameType: 'wordMatch',
        category: 'animals',
        difficulty: 'medium',
        accuracy: 0.75,
        durationSeconds: 90,
      );

      final map = entry.toMap();
      final restored = DifficultyHistoryEntry.fromMap(map);

      expect(restored.gameType, entry.gameType);
      expect(restored.category, entry.category);
      expect(restored.difficulty, entry.difficulty);
      expect(restored.accuracy, entry.accuracy);
      expect(restored.durationSeconds, entry.durationSeconds);
    });

    test('fromMap handles null category and durationSeconds', () {
      final entry = DifficultyHistoryEntry(
        timestamp: DateTime(2025, 6),
        gameType: 'spellingBee',
        difficulty: 'easy',
        accuracy: 0.5,
      );

      final map = entry.toMap();
      final restored = DifficultyHistoryEntry.fromMap(map);
      expect(restored.category, isNull);
      expect(restored.durationSeconds, isNull);
    });
  });

  // ─── AdaptiveSummary ───────────────────────────────────────

  group('AdaptiveSummary', () {
    test('trendLabel and trendDescription have correct values', () {
      const improving = AdaptiveSummary(
        currentGlobal: GameDifficulty.medium,
        totalGamesTracked: 10,
        recentAccuracy: 0.8,
        trend: DifficultyTrend.improving,
        gameOverrides: {},
        categoryOverrides: {},
      );
      expect(improving.trendLabel, contains('Improving'));
      expect(improving.trendDescription, contains('upward'));

      const stable = AdaptiveSummary(
        currentGlobal: GameDifficulty.easy,
        totalGamesTracked: 5,
        recentAccuracy: 0.5,
        trend: DifficultyTrend.stable,
        gameOverrides: {},
        categoryOverrides: {},
      );
      expect(stable.trendLabel, contains('Stable'));
      expect(stable.trendDescription, contains('consistent'));

      const declining = AdaptiveSummary(
        currentGlobal: GameDifficulty.hard,
        totalGamesTracked: 8,
        recentAccuracy: 0.3,
        trend: DifficultyTrend.declining,
        gameOverrides: {},
        categoryOverrides: {},
      );
      expect(declining.trendLabel, contains('Needs Support'));
      expect(declining.trendDescription, contains('dropping'));
    });
  });

  // ─── suggestDifficulty with category filter ────────────────

  group('suggestDifficulty category filter', () {
    test('filters accuracy stats to the selected categories', () {
      final animalCard = SeedData.allFlashcards
          .firstWhere((c) => c.category == FlashcardCategory.animals);
      final colorCard = SeedData.allFlashcards
          .firstWhere((c) => c.category == FlashcardCategory.colorsAndShapes);

      box.put('sr_cat_filter', {
        animalCard.id: {
          'correct': 0,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 0% in animals
        colorCard.id: {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 100% in colors
      });

      expect(
        AdaptiveDifficultyService.suggestDifficulty(
          profileId: 'cat_filter',
          categories: [FlashcardCategory.animals],
        ),
        GameDifficulty.easy,
      );
      expect(
        AdaptiveDifficultyService.suggestDifficulty(
          profileId: 'cat_filter',
          categories: [FlashcardCategory.colorsAndShapes],
        ),
        GameDifficulty.hard,
      );
      // Unfiltered: 5/10 = 50% → medium
      expect(
        AdaptiveDifficultyService.suggestDifficulty(profileId: 'cat_filter'),
        GameDifficulty.medium,
      );
    });

    test('falls back to overall stats for unattempted categories', () {
      final animalCard = SeedData.allFlashcards
          .firstWhere((c) => c.category == FlashcardCategory.animals);
      box.put('sr_cat_unattempted', {
        animalCard.id: {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      expect(
        AdaptiveDifficultyService.suggestDifficulty(
          profileId: 'cat_unattempted',
          categories: [FlashcardCategory.weather],
        ),
        GameDifficulty.hard,
      );
    });
  });

  // ─── getAdaptiveWordOrder (weighted mode) ──────────────────

  group('getAdaptiveWordOrder weighted mode', () {
    final cards = [
      const Flashcard(
        id: 'c1',
        wordEnglish: 'Cat',
        wordFilipino: 'Pusa',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c2',
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c3',
        wordEnglish: 'Bird',
        wordFilipino: 'Ibon',
        category: FlashcardCategory.animals,
      ),
    ];

    test('returns a valid permutation of the input', () {
      box.put('sr_weighted', {
        'c1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'c2': {
          'correct': 1,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
        profileId: 'weighted',
        cards: cards,
        random: Random(42),
      );
      expect(result.length, 3);
      expect(result.map((c) => c.id).toSet(), {'c1', 'c2', 'c3'});
    });

    test('favors weak words at the front across seeds', () {
      box.put('sr_weighted_bias', {
        'c1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 100% → priority ~0
        'c2': {
          'correct': 0,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        }, // 0% → priority ~1
      });

      var weakFirst = 0;
      for (var seed = 0; seed < 100; seed++) {
        final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
          profileId: 'weighted_bias',
          cards: cards.sublist(0, 2),
          random: Random(seed),
        );
        if (result.first.id == 'c2') weakFirst++;
      }
      // ~95% expected; deterministic given the fixed seeds.
      expect(weakFirst, greaterThan(75));
    });

    test('shuffles instead of returning input order when no data', () {
      final result = AdaptiveDifficultyService.getAdaptiveWordOrder(
        profileId: 'weighted_empty',
        cards: cards,
        random: Random(7),
      );
      expect(result.length, 3);
      expect(result.map((c) => c.id).toSet(), {'c1', 'c2', 'c3'});
    });
  });

  // ─── pickGameCards ─────────────────────────────────────────

  group('pickGameCards', () {
    final cards = [
      const Flashcard(
        id: 'c1',
        wordEnglish: 'Cat',
        wordFilipino: 'Pusa',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c2',
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
        category: FlashcardCategory.animals,
      ),
      const Flashcard(
        id: 'c3',
        wordEnglish: 'Bird',
        wordFilipino: 'Ibon',
        category: FlashcardCategory.animals,
      ),
    ];

    test('respects count', () {
      final result = AdaptiveDifficultyService.pickGameCards(
        profileId: 'pick_count',
        cards: cards,
        count: 2,
        random: Random(1),
      );
      expect(result.length, 2);
    });

    test('returns the whole pool when count exceeds it', () {
      final result = AdaptiveDifficultyService.pickGameCards(
        profileId: 'pick_over',
        cards: cards,
        count: 10,
        random: Random(1),
      );
      expect(result.length, 3);
    });

    test('plain shuffle for guests (null profileId)', () {
      final result = AdaptiveDifficultyService.pickGameCards(
        profileId: null,
        cards: cards,
        count: 3,
        random: Random(1),
      );
      expect(result.map((c) => c.id).toSet(), {'c1', 'c2', 'c3'});
    });

    test('strongly favors the weak word for the first pick', () {
      box.put('sr_pick_bias', {
        'c1': {
          'correct': 5,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
        'c2': {
          'correct': 0,
          'total': 5,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      });

      var weakPicked = 0;
      for (var seed = 0; seed < 100; seed++) {
        final picked = AdaptiveDifficultyService.pickGameCards(
          profileId: 'pick_bias',
          cards: cards.sublist(0, 2),
          count: 1,
          random: Random(seed),
        );
        if (picked.single.id == 'c2') weakPicked++;
      }
      expect(weakPicked, greaterThan(75));
    });
  });

  // ─── suggestForGame fallback chain ─────────────────────────

  group('suggestForGame fallback chain', () {
    test('uses category history from other game types when game is new', () {
      // Weak in animals (3 × 20%) across word match games…
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'chain',
          gameType: GameType.wordMatch,
          category: FlashcardCategory.animals,
          score: 1,
          total: 5,
          playedDifficulty: GameDifficulty.medium,
        );
      }
      // …but strong in emotions (5 × 80%) across memory match games.
      for (var i = 0; i < 5; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'chain',
          gameType: GameType.memoryMatch,
          category: FlashcardCategory.emotions,
          score: 4,
          total: 5,
          playedDifficulty: GameDifficulty.medium,
        );
      }

      // Spelling Bee was never played: the category window decides.
      expect(
        AdaptiveDifficultyService.suggestForGame(
          profileId: 'chain',
          gameType: GameType.spellingBee,
          category: FlashcardCategory.animals,
        ),
        GameDifficulty.easy,
      );
      expect(
        AdaptiveDifficultyService.suggestForGame(
          profileId: 'chain',
          gameType: GameType.spellingBee,
          category: FlashcardCategory.emotions,
        ),
        GameDifficulty.hard,
      );
    });

    test('falls back to the stored game override when history aged out', () {
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'aged',
          gameType: GameType.spellingBee,
          category: null,
          score: 5,
          total: 5,
          playedDifficulty: GameDifficulty.medium,
        );
      }
      // Simulate the history cap dropping old entries while the
      // override survives.
      box.put('adaptive_history_aged', []);

      expect(
        AdaptiveDifficultyService.suggestForGame(
          profileId: 'aged',
          gameType: GameType.spellingBee,
        ),
        GameDifficulty.hard,
      );
    });
  });

  // ─── getSuggestionReasonForGame ────────────────────────────

  group('getSuggestionReasonForGame', () {
    test('falls back to starter message with no history', () {
      final reason = AdaptiveDifficultyService.getSuggestionReasonForGame(
        profileId: 'fresh_reason',
        gameType: GameType.wordMatch,
      );
      expect(reason, contains('just getting started'));
    });

    test('mentions the game and recent accuracy when played before', () {
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'wm_reason',
          gameType: GameType.wordMatch,
          category: null,
          score: 5,
          total: 5,
          playedDifficulty: GameDifficulty.medium,
        );
      }

      final reason = AdaptiveDifficultyService.getSuggestionReasonForGame(
        profileId: 'wm_reason',
        gameType: GameType.wordMatch,
      );
      expect(reason, contains('Word Match'));
      expect(reason, contains('100%'));
      expect(reason, contains('real challenge'));
    });

    test('uses overall recent games for a game not yet played', () {
      for (var i = 0; i < 3; i++) {
        AdaptiveDifficultyService.recordGameResult(
          profileId: 'overall_reason',
          gameType: GameType.memoryMatch,
          category: null,
          score: 1,
          total: 5,
          playedDifficulty: GameDifficulty.easy,
        );
      }

      final reason = AdaptiveDifficultyService.getSuggestionReasonForGame(
        profileId: 'overall_reason',
        gameType: GameType.spellingBee,
      );
      expect(reason, contains('Across your recent games'));
      expect(reason, contains('easier questions'));
    });
  });
}
