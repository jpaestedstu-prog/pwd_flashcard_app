import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/models/learning_path.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/local/daily_challenge.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/learning_path_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../models/recommendation_models.dart';

/// Generates personalized study recommendations by analysing the student's
/// progress data, spaced-repetition scores, game history, learning-path
/// status, daily challenge completion, and session analytics.
class RecommendationService {
  const RecommendationService._();

  /// Build a full [RecommendationSnapshot] for the given profile.
  static RecommendationSnapshot generate({
    required String profileId,
    required LearningProgress progress,
    required Map<String, LearningPathProgress> pathProgress,
    List<FlashcardCategory> interests = const [],
  }) {
    final allCards = SeedData.allFlashcards;
    final recommendations = <Recommendation>[];

    // ── 1. Weak categories (progress < 50 %) ─────────────────────
    final weakCategories = _findWeakCategories(progress);
    for (final entry in weakCategories) {
      recommendations.add(Recommendation(
        id: 'weak_cat_${entry.key}',
        type: RecommendationType.reviewWeakCategory,
        priority: entry.value < 0.3
            ? RecommendationPriority.high
            : RecommendationPriority.medium,
        title: 'Review ${entry.key}',
        titleFilipino: 'Balikan ang ${entry.key}',
        description:
            'Your progress is ${(entry.value * 100).round()}%. '
            'Let\'s practice to boost your score!',
        descriptionFilipino:
            'Ang progreso mo ay ${(entry.value * 100).round()}%. '
            'Mag-practice tayo para tumaas ang score mo!',
        emoji: _categoryEmoji(entry.key),
        route: '/flashcards/viewer/${_categoryIndexByLabel(entry.key)}',
        category: _categoryByLabel(entry.key),
        relevanceScore: 1.0 - entry.value, // lower progress → higher relevance
      ));
    }

    // ── 2. Spaced-repetition words due ───────────────────────────
    final reviewWords = SpacedRepetitionService.getReviewWords(
      profileId: profileId,
      allCards: allCards,
      count: 5,
    );
    final srSummary = SpacedRepetitionService.getSummary(profileId);
    if (reviewWords.isNotEmpty && srSummary.totalAttempted > 0) {
      recommendations.add(Recommendation(
        id: 'sr_review',
        type: RecommendationType.spacedRepetitionDue,
        priority: RecommendationPriority.high,
        title: 'Smart Review',
        titleFilipino: 'Matalinong Pagsasanay',
        description:
            '${reviewWords.length} words are ready for review based on '
            'your learning pattern.',
        descriptionFilipino:
            '${reviewWords.length} salita ang handa nang balikan '
            'batay sa iyong pattern ng pagkatuto.',
        emoji: '🧠',
        route: '/smart-review',
        relevanceScore: 0.95,
      ));
    }

    // ── 3. Weak words practice ───────────────────────────────────
    final weakWords = SpacedRepetitionService.getWeakWords(
      profileId: profileId,
      allCards: allCards,
    );
    if (weakWords.isNotEmpty) {
      final worst = weakWords.first;
      recommendations.add(Recommendation(
        id: 'weak_words',
        type: RecommendationType.practiceWeakWords,
        priority: RecommendationPriority.high,
        title: 'Practice Tricky Words',
        titleFilipino: 'Magsanay sa Mahirap na Salita',
        description:
            '${weakWords.length} words need extra practice. '
            '"${worst.$1.wordEnglish}" is your trickiest '
            '(${(worst.$2.accuracy * 100).round()}% accuracy).',
        descriptionFilipino:
            '${weakWords.length} salita ang kailangan ng dagdag na '
            'pagsasanay. "${worst.$1.wordFilipino}" ang pinakamahirap '
            '(${(worst.$2.accuracy * 100).round()}% accuracy).',
        emoji: '📝',
        route: '/smart-review',
        relevanceScore: 0.9,
      ));
    }

    // ── 4. Suggested game based on adaptive difficulty ───────────
    final suggestedDifficulty =
        AdaptiveDifficultyService.suggestDifficulty(profileId: profileId);
    final leastPlayedGame = _findLeastPlayedGame(progress.recentScores);
    if (leastPlayedGame != null) {
      final gameRoute = _gameRoute(leastPlayedGame);
      if (gameRoute != null) {
        recommendations.add(Recommendation(
          id: 'game_${leastPlayedGame.name}',
          type: RecommendationType.trySuggestedGame,
          priority: RecommendationPriority.medium,
          title: 'Try ${leastPlayedGame.label}',
          titleFilipino: 'Subukan ang ${leastPlayedGame.label}',
          description:
              'You haven\'t played this game recently. '
              'We suggest ${suggestedDifficulty.name} difficulty.',
          descriptionFilipino:
              'Hindi mo pa nilalaro ito kamakailan. '
              'Iminumungkahi namin ang ${suggestedDifficulty.name} na '
              'kahirapan.',
          emoji: '🎮',
          route: gameRoute,
          queryParams: {'difficulty': suggestedDifficulty.name},
          gameType: leastPlayedGame,
          relevanceScore: 0.7,
        ));
      }
    }

    // ── 5. Continue learning path ────────────────────────────────
    final nextPath = _findNextLearningPath(pathProgress);
    if (nextPath != null) {
      recommendations.add(Recommendation(
        id: 'path_${nextPath.id}',
        type: RecommendationType.continueLearningPath,
        priority: RecommendationPriority.medium,
        title: 'Continue ${nextPath.title}',
        titleFilipino: 'Ipagpatuloy ang ${nextPath.title}',
        description: _learningPathDescription(nextPath, pathProgress),
        descriptionFilipino:
            _learningPathDescriptionFilipino(nextPath, pathProgress),
        emoji: nextPath.emoji,
        route: '/learning-paths/${nextPath.id}',
        category: nextPath.category,
        relevanceScore: 0.75,
      ));
    }

    // ── 6. Daily challenge ───────────────────────────────────────
    if (!DailyChallenge.hasCompletedToday(profileId)) {
      final streak = DailyChallenge.getStreak(profileId);
      recommendations.add(Recommendation(
        id: 'daily_challenge',
        type: RecommendationType.dailyChallengeReminder,
        priority: RecommendationPriority.medium,
        title: 'Daily Challenge',
        titleFilipino: 'Pang-araw-araw na Hamon',
        description: streak > 0
            ? 'Keep your $streak-day streak alive! '
              'Complete today\'s word challenge.'
            : 'Start a new streak! Complete today\'s word challenge '
              'and earn bonus stars.',
        descriptionFilipino: streak > 0
            ? 'Panatilihin ang $streak-araw na streak mo! '
              'Tapusin ang hamon ngayong araw.'
            : 'Magsimula ng bagong streak! Tapusin ang hamon ngayong '
              'araw at kumita ng bonus stars.',
        emoji: '📅',
        route: '/daily-challenge',
        relevanceScore: 0.85,
      ));
    }

    // ── 7. Explore new/unexplored categories ─────────────────────
    // Interest categories are surfaced first, so a learner who picked
    // favourite topics in their profile sees those suggested sooner.
    final unexplored = _findUnexploredCategories(progress, interests);
    if (unexplored.isNotEmpty) {
      final cat = unexplored.first;
      final isInterest = interests.contains(cat);
      recommendations.add(Recommendation(
        id: 'explore_${cat.name}',
        type: RecommendationType.exploreNewCategory,
        priority: isInterest
            ? RecommendationPriority.medium
            : RecommendationPriority.low,
        title: 'Discover ${cat.label}',
        titleFilipino: 'Tuklasin ang ${cat.labelFilipino}',
        description: isInterest
            ? 'One of your favourite topics! Tap to start learning '
                '${cat.label} words!'
            : 'You haven\'t explored ${cat.label} yet. '
                'Tap to start learning new words!',
        descriptionFilipino: isInterest
            ? 'Isa sa mga paborito mong paksa! Pindutin para matuto ng '
                'mga salita sa ${cat.labelFilipino}!'
            : 'Hindi mo pa natutuklas ang ${cat.labelFilipino}. '
                'Pindutin para magsimulang matuto ng mga bagong salita!',
        emoji: _categoryEmojiFromEnum(cat),
        route: '/flashcards/viewer/${cat.index}',
        category: cat,
        relevanceScore: isInterest ? 0.8 : 0.5,
      ));
    }

    // ── 8. Streak motivation ─────────────────────────────────────
    if (progress.streakDays > 0) {
      final daysSinceLast =
          DateTime.now().difference(progress.lastActivityDate).inDays;
      if (daysSinceLast >= 1) {
        recommendations.add(Recommendation(
          id: 'streak',
          type: RecommendationType.increaseStreak,
          priority: RecommendationPriority.high,
          title: 'Keep Your Streak!',
          titleFilipino: 'Panatilihin ang Iyong Streak!',
          description:
              'You have a ${progress.streakDays}-day streak. '
              'Do any activity today to keep it going!',
          descriptionFilipino:
              'May ${progress.streakDays}-araw na streak ka. '
              'Gumawa ng kahit anong aktibidad ngayon para '
              'mapanatili ito!',
          emoji: '🔥',
          route: '/home',
          relevanceScore: 0.92,
        ));
      }
    }

    // Sort by relevance, then priority
    recommendations.sort((a, b) {
      final priorityCmp = a.priority.index.compareTo(b.priority.index);
      if (priorityCmp != 0) return priorityCmp;
      return (b.relevanceScore ?? 0).compareTo(a.relevanceScore ?? 0);
    });

    // Compute summary stats
    final explored = progress.categoryProgress.entries
        .where((e) => e.value > 0)
        .length;
    final accuracies =
        SpacedRepetitionService.getWordAccuracies(profileId);
    double overallAcc = 0;
    if (accuracies.isNotEmpty) {
      int sumCorrect = 0, sumTotal = 0;
      for (final wa in accuracies.values) {
        sumCorrect += wa.correct;
        sumTotal += wa.total;
      }
      overallAcc = sumTotal > 0 ? sumCorrect / sumTotal : 0;
    }

    final weakest = _weakestCategoryLabel(progress);
    final strongest = _strongestCategoryLabel(progress);

    return RecommendationSnapshot(
      recommendations: recommendations,
      wordsNeedingReview: reviewWords.length,
      categoriesExplored: explored,
      totalCategories: FlashcardCategory.values.length,
      overallAccuracy: overallAcc,
      weakestCategoryLabel: weakest,
      strongestCategoryLabel: strongest,
      generatedAt: DateTime.now(),
    );
  }

  // ─── Private helpers ─────────────────────────────────────────

  /// Returns categories with progress < 50 %, sorted ascending.
  static List<MapEntry<String, double>> _findWeakCategories(
      LearningProgress progress) {
    final weak = progress.categoryProgress.entries
        .where((e) => e.value < 0.5 && e.value > 0)
        .toList();
    weak.sort((a, b) => a.value.compareTo(b.value));
    return weak.take(3).toList(); // top 3 weakest
  }

  /// Categories with zero progress, with the learner's chosen interest
  /// categories surfaced first so suggestions feel personalised.
  static List<FlashcardCategory> _findUnexploredCategories(
      LearningProgress progress, List<FlashcardCategory> interests) {
    final unexplored = FlashcardCategory.values.where((cat) {
      final p = progress.categoryProgress[cat.label] ?? 0.0;
      return p == 0.0;
    }).toList();
    unexplored.sort((a, b) {
      final ai = interests.contains(a) ? 0 : 1;
      final bi = interests.contains(b) ? 0 : 1;
      return ai.compareTo(bi);
    });
    return unexplored;
  }

  /// Finds the game type least played in recent scores.
  static GameType? _findLeastPlayedGame(List<GameScore> scores) {
    if (scores.isEmpty) return GameType.wordMatch; // good starter game
    final counts = <GameType, int>{};
    for (final gt in GameType.values) {
      counts[gt] = 0;
    }
    for (final s in scores) {
      counts[s.gameType] = (counts[s.gameType] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first.key;
  }

  /// Finds the next incomplete (or not-started) learning path.
  static LearningPath? _findNextLearningPath(
      Map<String, LearningPathProgress> pathProgress) {
    final allPaths = LearningPathData.allPaths;
    for (final path in allPaths) {
      final prog = pathProgress[path.id];
      if (prog == null || !prog.isCompleted) return path;
    }
    return null; // all completed
  }

  static String _learningPathDescription(
      LearningPath path, Map<String, LearningPathProgress> pathProgress) {
    final prog = pathProgress[path.id];
    if (prog == null) {
      return 'Start the ${path.title} learning path — '
          '${path.totalSteps} steps to master ${path.category.label}!';
    }
    final completed = prog.completedStepIndices.length;
    return 'You\'ve completed $completed/${path.totalSteps} steps. '
        'Keep going!';
  }

  static String _learningPathDescriptionFilipino(
      LearningPath path, Map<String, LearningPathProgress> pathProgress) {
    final prog = pathProgress[path.id];
    if (prog == null) {
      return 'Simulan ang ${path.title} learning path — '
          '${path.totalSteps} hakbang para ma-master ang '
          '${path.category.labelFilipino}!';
    }
    final completed = prog.completedStepIndices.length;
    return 'Natapos mo na ang $completed/${path.totalSteps} hakbang. '
        'Ipagpatuloy!';
  }

  static String? _weakestCategoryLabel(LearningProgress progress) {
    if (progress.categoryProgress.isEmpty) return null;
    final active = progress.categoryProgress.entries
        .where((e) => e.value > 0)
        .toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => a.value.compareTo(b.value));
    return active.first.key;
  }

  static String? _strongestCategoryLabel(LearningProgress progress) {
    if (progress.categoryProgress.isEmpty) return null;
    final active = progress.categoryProgress.entries.toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.value.compareTo(a.value));
    return active.first.key;
  }

  static String _categoryEmoji(String label) {
    final cat = _categoryByLabel(label);
    if (cat == null) return '📚';
    return _categoryEmojiFromEnum(cat);
  }

  static String _categoryEmojiFromEnum(FlashcardCategory cat) {
    return switch (cat) {
      FlashcardCategory.animals => '🐾',
      FlashcardCategory.colorsAndShapes => '🎨',
      FlashcardCategory.numbers => '🔢',
      FlashcardCategory.bodyParts => '🫀',
      FlashcardCategory.foodAndDrinks => '🍔',
      FlashcardCategory.familyAndGreetings => '👨‍👩‍👧',
      FlashcardCategory.clothing => '👕',
      FlashcardCategory.weather => '🌤️',
      FlashcardCategory.classroom => '🏫',
      FlashcardCategory.transportation => '🚌',
      FlashcardCategory.emotions => '😊',
      FlashcardCategory.daysAndTime => '📅',
      FlashcardCategory.actions => '🏃',
    };
  }

  static FlashcardCategory? _categoryByLabel(String label) {
    for (final cat in FlashcardCategory.values) {
      if (cat.label == label) return cat;
    }
    return null;
  }

  static int _categoryIndexByLabel(String label) {
    final cat = _categoryByLabel(label);
    return cat?.index ?? 0;
  }

  static String? _gameRoute(GameType type) {
    return switch (type) {
      GameType.wordMatch => '/games/word-match',
      GameType.spellingBee => '/games/spelling-bee',
      GameType.memoryMatch => '/games/memory-match',
      GameType.dragAndDrop => '/games/drag-drop',
      GameType.flashcardQuiz => '/games/flashcard-quiz',
      GameType.pronunciation => '/games/pronunciation',
      GameType.sentenceBuilder => '/games/sentence-builder',
      GameType.tracing => '/games/tracing',
      GameType.storyQuiz => null,
      GameType.fslPractice => '/games/fsl-practice',
      GameType.jigsawPuzzle => '/games/jigsaw-puzzle',
      GameType.pictureWord => '/games/picture-word',
    };
  }
}
