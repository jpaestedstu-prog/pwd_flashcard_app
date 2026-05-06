import 'dart:math';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../models/guided_practice_models.dart';

/// Generates guided practice sessions from flashcard data.
class GuidedPracticeService {
  GuidedPracticeService._();

  static final _random = Random();

  /// Generate a 5-step guided practice session for a category.
  /// Steps progress from easy (review) to harder (quiz).
  static GuidedPracticeSession generateSession({
    required FlashcardCategory category,
    required List<Flashcard> availableCards,
    Set<String> weakWordIds = const {},
  }) {
    if (availableCards.isEmpty) {
      availableCards = SeedData.getByCategory(category);
    }

    // Prioritize weak words, then shuffle
    final prioritized = <Flashcard>[
      ...availableCards.where((c) => weakWordIds.contains(c.id)),
      ...availableCards.where((c) => !weakWordIds.contains(c.id)),
    ];

    // Take up to 5 unique cards
    final sessionCards = prioritized.take(5).toList();
    if (sessionCards.length < 5) {
      // Pad with random cards if less than 5
      while (sessionCards.length < 5 && availableCards.isNotEmpty) {
        final card =
            availableCards[_random.nextInt(availableCards.length)];
        if (!sessionCards.contains(card)) sessionCards.add(card);
        if (sessionCards.length >= availableCards.length) break;
      }
    }

    // Build steps: review → listen → fill-blank → match → quiz
    final stepTypes = [
      PracticeStepType.flashcardReview,
      PracticeStepType.listenAndRepeat,
      PracticeStepType.fillInBlank,
      PracticeStepType.matchPair,
      PracticeStepType.miniQuiz,
    ];

    final steps = <PracticeStep>[];
    for (int i = 0; i < sessionCards.length && i < stepTypes.length; i++) {
      final card = sessionCards[i];
      final type = stepTypes[i];

      // Generate options for quiz/match steps
      List<String>? options;
      if (type == PracticeStepType.miniQuiz ||
          type == PracticeStepType.matchPair) {
        options = _generateOptions(card, availableCards);
      }

      // Generate hints
      String? hint;
      if (type == PracticeStepType.fillInBlank) {
        hint = _generateFillHint(card.wordEnglish);
      }

      steps.add(PracticeStep(
        type: type,
        targetCard: card,
        hint: hint,
        options: options,
      ));
    }

    return GuidedPracticeSession(
      category: category,
      steps: steps,
      startedAt: DateTime.now(),
    );
  }

  /// Generate 4 multiple-choice options (1 correct + 3 distractors)
  static List<String> _generateOptions(
      Flashcard correct, List<Flashcard> pool) {
    final options = <String>[correct.wordFilipino];
    final distractors = pool
        .where((c) => c.id != correct.id)
        .map((c) => c.wordFilipino)
        .toList()
      ..shuffle(_random);
    for (final d in distractors) {
      if (options.length >= 4) break;
      if (!options.contains(d)) options.add(d);
    }
    // Pad if not enough distractors
    while (options.length < 4) {
      options.add('—');
    }
    options.shuffle(_random);
    return options;
  }

  /// Generate a hint for fill-in-blank (show first+last letter)
  static String _generateFillHint(String word) {
    if (word.length <= 2) return '_ ' * word.length;
    final chars = word.split('');
    return chars.asMap().entries.map((e) {
      if (e.key == 0 || e.key == chars.length - 1) return e.value;
      return '_';
    }).join(' ');
  }
}
