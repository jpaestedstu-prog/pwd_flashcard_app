import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../models/tutor_models.dart';

const _uuid = Uuid();

/// Rule-based adaptive tutor engine.
/// Analyzes learning progress and generates contextual messages,
/// hints, practice suggestions, and mini-quizzes.
class TutorEngine {
  TutorEngine._();

  static final _random = Random();

  /// Generate an initial greeting message
  static TutorMessage greet(String studentName, {bool isFilipino = false}) {
    final greetings = isFilipino
        ? [
            'Kumusta, $studentName! 👋 Ako ang iyong tutor. Paano kita matutulungan ngayon?',
            'Magandang araw, $studentName! 🌟 Handa ka na bang matuto?',
            'Hello, $studentName! 📚 Tanungin mo ako tungkol sa mga salita!',
          ]
        : [
            'Hi $studentName! 👋 I\'m your learning buddy. How can I help today?',
            'Hello $studentName! 🌟 Ready to learn some new words?',
            'Hey $studentName! 📚 Ask me about any vocabulary topic!',
          ];

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: greetings[_random.nextInt(greetings.length)],
      timestamp: DateTime.now(),
    );
  }

  /// Analyze progress and generate a contextual response
  static TutorMessage analyzeAndRespond(
    LearningProgress progress,
    String studentName,
    String profileId, {
    bool isFilipino = false,
  }) {
    // Check for weak categories
    final weakCategories = <String>[];
    final strongCategories = <String>[];
    for (final entry in progress.categoryProgress.entries) {
      if (entry.value < 0.4) {
        weakCategories.add(entry.key);
      } else if (entry.value >= 0.8) {
        strongCategories.add(entry.key);
      }
    }

    // Check streak
    if (progress.streakDays >= 7) {
      return _streakCelebration(progress.streakDays, isFilipino: isFilipino);
    }

    // Check if there are weak categories
    if (weakCategories.isNotEmpty) {
      return _weakCategoryAdvice(weakCategories.first,
          isFilipino: isFilipino);
    }

    // Celebrate strong categories
    if (strongCategories.isNotEmpty) {
      return _strongCategoryMessage(strongCategories, isFilipino: isFilipino);
    }

    // Default: offer today's personalized learning plan.
    return offerLearningPlan(progress, profileId, isFilipino: isFilipino);
  }

  /// Generate a response to a student question
  static TutorMessage respondToQuestion(
    String question,
    LearningProgress progress,
    String profileId, {
    bool isFilipino = false,
  }) {
    final lowerQ = question.toLowerCase();

    // Check for category queries
    for (final cat in FlashcardCategory.values) {
      if (lowerQ.contains(cat.label.toLowerCase())) {
        return _categoryInfo(cat, progress, isFilipino: isFilipino);
      }
    }

    // Check for help/hint requests
    if (lowerQ.contains('help') ||
        lowerQ.contains('hint') ||
        lowerQ.contains('tulong') ||
        lowerQ.contains('pahiwatig')) {
      return _provideHint(progress, isFilipino: isFilipino);
    }

    // Check for quiz requests
    if (lowerQ.contains('quiz') ||
        lowerQ.contains('test') ||
        lowerQ.contains('pagsusulit')) {
      return _quickQuiz(isFilipino: isFilipino);
    }

    // Check for learning-plan / daily lesson requests
    if (lowerQ.contains('plan') ||
        lowerQ.contains('lesson') ||
        lowerQ.contains('today') ||
        lowerQ.contains('aralin') ||
        lowerQ.contains('ngayon')) {
      return offerLearningPlan(progress, profileId, isFilipino: isFilipino);
    }

    // Check for practice requests
    if (lowerQ.contains('practice') ||
        lowerQ.contains('review') ||
        lowerQ.contains('pagsasanay')) {
      return _suggestPractice(progress, isFilipino: isFilipino);
    }

    // Check for progress queries
    if (lowerQ.contains('progress') ||
        lowerQ.contains('score') ||
        lowerQ.contains('how am i') ||
        lowerQ.contains('pag-unlad')) {
      return _progressSummary(progress, isFilipino: isFilipino);
    }

    // Default response
    final defaults = isFilipino
        ? [
            'Subukan mong tanungin ako tungkol sa isang kategorya, o sabihin "quiz" para sa isang mabilisang pagsusulit! 😊',
            'Pwede mong sabihin: "practice", "hint", "quiz", o tanungin mo ako tungkol sa anumang kategorya! 📖',
            'Hindi ko masyadong naintindihan. Subukan mo: "Tulong sa Animals" o "Bigyan mo ako ng quiz"! 🤔',
          ]
        : [
            'Try asking me about a category, or say "quiz" for a quick question! 😊',
            'You can say: "practice", "hint", "quiz", or ask about any category! 📖',
            'I\'m not sure what you mean. Try: "Help with Animals" or "Give me a quiz"! 🤔',
          ];

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: defaults[_random.nextInt(defaults.length)],
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _streakCelebration(int days,
      {bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '🔥 Wow! $days-araw na streak! Napakahusay mo! Ituloy mo lang, ikaw ang pinakamagaling!'
          : '🔥 Amazing! $days-day streak! You\'re doing incredible! Keep it up, superstar!',
      timestamp: DateTime.now(),
      action: const TutorAction(type: TutorActionType.encouragement),
    );
  }

  static TutorMessage _weakCategoryAdvice(String category,
      {bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📝 Napansin ko na kailangan mo pa ng kaunting practice sa "$category". Gusto mo bang mag-practice doon?'
          : '📝 I noticed "$category" needs some practice. Want to work on it? Tap below to start!',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.practiceRedirect,
        targetRoute: '/guided-practice',
      ),
    );
  }

  static TutorMessage _strongCategoryMessage(List<String> categories,
      {bool isFilipino = false}) {
    final catList = categories.take(3).join(', ');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '⭐ Napakagaling mo sa: $catList! Subukan natin ang mas mahirap na kategorya?'
          : '⭐ You\'re doing great in: $catList! Want to try a harder category?',
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _wordOfTheDay({bool isFilipino = false}) {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) {
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: isFilipino
            ? 'Handa ka na bang matuto? Sabihin "quiz" o "practice"! 📚'
            : 'Ready to learn? Say "quiz" or "practice"! 📚',
        timestamp: DateTime.now(),
      );
    }
    final card = allCards[_random.nextInt(allCards.length)];
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📖 Salita ng Araw:\n\nEnglish: ${card.wordEnglish}\nFilipino: ${card.wordFilipino}\n${card.exampleSentence != null ? '\n"${card.exampleSentence}"' : ''}'
          : '📖 Word of the Day:\n\nEnglish: ${card.wordEnglish}\nFilipino: ${card.wordFilipino}\n${card.exampleSentence != null ? '\n"${card.exampleSentence}"' : ''}',
      timestamp: DateTime.now(),
      action: const TutorAction(type: TutorActionType.wordOfTheDay),
    );
  }

  static TutorMessage _categoryInfo(
      FlashcardCategory cat, LearningProgress progress,
      {bool isFilipino = false}) {
    final prog = progress.categoryProgress[cat.label] ?? 0.0;
    final pct = (prog * 100).round();
    final cards = SeedData.getByCategory(cat);
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📊 ${cat.label}: $pct% na-master mo. Mayroong ${cards.length} salita sa kategiryang ito. ${prog < 0.5 ? 'Kailangan pa ng practice!' : 'Magaling ang progress mo!'}'
          : '📊 ${cat.label}: You\'ve mastered $pct%. There are ${cards.length} words in this category. ${prog < 0.5 ? 'Let\'s practice more!' : 'Great progress!'}',
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _provideHint(LearningProgress progress,
      {bool isFilipino = false}) {
    final hints = isFilipino
        ? [
            '💡 Subukan mong gamitin ang Flashcards araw-araw. Ang pag-uulit ang susi sa pag-alala!',
            '💡 Maglaro ng mga games pagkatapos mag-review ng flashcards — mas matanda ang mga salita.',
            '💡 Basahin ang mga stories para makita kung paano ginagamit ang mga salita sa pangungusap.',
            '💡 Gamitin ang Smart Review para i-focus ang mga salitang mahirap para sa iyo.',
          ]
        : [
            '💡 Try reviewing Flashcards every day. Repetition is key to remembering!',
            '💡 Play games after reviewing flashcards — it reinforces the words.',
            '💡 Read stories to see how words are used in sentences.',
            '💡 Use Smart Review to focus on words you find difficult.',
          ];
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: hints[_random.nextInt(hints.length)],
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _quickQuiz({bool isFilipino = false}) {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) {
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: isFilipino
            ? 'Walang available na quiz ngayon.'
            : 'No quiz available right now.',
        timestamp: DateTime.now(),
      );
    }

    final card = allCards[_random.nextInt(allCards.length)];
    return quizForWord(card, isFilipino: isFilipino);
  }

  /// Builds a multiple-choice quiz message for a specific [card]. The action
  /// carries [wordId]/[categoryLabel] so a correct answer can be recorded
  /// against spaced-repetition and progress tracking.
  static TutorMessage quizForWord(Flashcard card,
      {bool isFilipino = false, String? prefix}) {
    final allCards = SeedData.allFlashcards;
    // Generate 3 wrong options
    final wrongOptions = allCards
        .where((c) => c.id != card.id)
        .map((c) => c.wordFilipino)
        .toSet()
        .toList()
      ..shuffle(_random);
    final options = [card.wordFilipino, ...wrongOptions.take(3)]
      ..shuffle(_random);

    final head = prefix ?? (isFilipino ? '❓ Mabilisang Quiz!' : '❓ Quick Quiz!');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '$head\n\nAno ang Filipino ng "${card.wordEnglish}"?'
          : '$head\n\nWhat is the Filipino for "${card.wordEnglish}"?',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.quickQuiz,
        question: card.wordEnglish,
        options: options,
        correctAnswer: card.wordFilipino,
        wordId: card.id,
        categoryLabel: card.category.label,
      ),
    );
  }

  /// Picks today's personalized learning plan — 3 flashcards prioritized by the
  /// learner's spaced-repetition data (weakest / least-recently-seen first),
  /// falling back to unseen words. Reuses [SpacedRepetitionService.getReviewWords].
  static List<Flashcard> buildLearningPlan(
    LearningProgress progress,
    String profileId, {
    int count = 3,
  }) {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) return const [];
    return SpacedRepetitionService.getReviewWords(
      profileId: profileId,
      allCards: allCards,
      count: count,
    );
  }

  /// A message that invites the learner to start today's learning plan. The
  /// [TutorActionType.startLesson] action carries the chosen [planWordIds].
  static TutorMessage offerLearningPlan(
    LearningProgress progress,
    String profileId, {
    bool isFilipino = false,
  }) {
    final plan = buildLearningPlan(progress, profileId);
    if (plan.isEmpty) {
      return _wordOfTheDay(isFilipino: isFilipino);
    }
    final preview = plan.map((c) => c.wordEnglish).join(', ');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '🎯 Handa na ang iyong aralin ngayon! Mag-aaral tayo ng ${plan.length} salita: $preview.\n\nPindutin sa ibaba para magsimula — may bituin kang makukuha!'
          : '🎯 Today\'s lesson is ready! We\'ll practice ${plan.length} words: $preview.\n\nTap below to start — you\'ll earn stars!',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.startLesson,
        planWordIds: plan.map((c) => c.id).toList(),
      ),
    );
  }

  static TutorMessage _suggestPractice(LearningProgress progress,
      {bool isFilipino = false}) {
    // Find the weakest category to suggest
    String? weakest;
    double minProg = 2.0;
    for (final entry in progress.categoryProgress.entries) {
      if (entry.value < minProg) {
        minProg = entry.value;
        weakest = entry.key;
      }
    }

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📝 ${weakest != null ? 'Irekomenda ko ang practice sa "$weakest".' : 'Subukan ang Guided Practice para sa anumang kategorya!'} Pindutin ang button sa ibaba para magsimula.'
          : '📝 ${weakest != null ? 'I recommend practicing "$weakest".' : 'Try Guided Practice for any category!'} Tap the button below to start.',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.practiceRedirect,
        targetRoute: '/guided-practice',
      ),
    );
  }

  static TutorMessage _progressSummary(LearningProgress progress,
      {bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📊 Ito ang iyong progress:\n\n📖 ${progress.wordsLearned} salita ang natutunan\n⭐ ${progress.totalStars} bituin\n🔥 ${progress.streakDays}-araw na streak\n🎮 ${progress.recentScores.length} laro na nilaro\n\nItuloy mo lang ang magandang gawa!'
          : '📊 Here\'s your progress:\n\n📖 ${progress.wordsLearned} words learned\n⭐ ${progress.totalStars} stars earned\n🔥 ${progress.streakDays}-day streak\n🎮 ${progress.recentScores.length} games played\n\nKeep up the great work!',
      timestamp: DateTime.now(),
    );
  }
}
