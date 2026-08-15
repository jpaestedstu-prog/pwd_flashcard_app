import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// How much of a category a learner has actually covered, kept deliberately
/// separate from how accurately they answered inside it.
///
/// **Why this type exists.** `LearningProgress.categoryProgress` reads like a
/// completion ratio and was consumed as one in five places, but its only writer
/// blends `0.7 * previous + 0.3 * (score / total)` — a rolling average of *game
/// accuracy*. The two answer different questions and diverge badly:
///
///   * Five perfect 3-question games in one category push the average to ≈0.83
///     while the learner has seen maybe three of its twenty words.
///   * Twenty words learned at 60% accuracy leaves the average below the bar
///     even though the category is finished.
///
/// Multiplying that average by the card count — which is what the certificate
/// screen did — therefore printed a *word count the learner never reached* on a
/// physical award, and shipped the same figure as a `Progress` column in the
/// research export. Coverage here is counted from [LearningProgress.learnedWordIds],
/// the set of distinct cards actually answered correctly, so the number on the
/// certificate is one the learner can point at.
///
/// [accuracy] is kept and reported alongside rather than thrown away: "how much
/// have I seen" and "how well did I do on it" are both worth knowing, and the
/// research export is more useful carrying both than either alone.
class CategoryMastery {
  final FlashcardCategory category;

  /// Distinct cards in this category the learner has ever answered correctly.
  final int wordsLearned;

  /// Cards in this category — seed *and* custom.
  ///
  /// The certificate screen previously counted with `SeedData.getByCategory`
  /// while the Progress tab counted with `allFlashcardsProvider`, so a teacher
  /// who added their own cards got two different denominators for one category.
  /// Everything now derives from whichever list the caller passes in, and the
  /// providers below pass the full one.
  final int totalWords;

  /// The rolling accuracy average carried on `LearningProgress.categoryProgress`.
  ///
  /// Nullable because a category the learner has never played has no accuracy
  /// at all, which is a different statement from "scored zero" — the research
  /// export needs to tell those apart.
  final double? accuracy;

  const CategoryMastery({
    required this.category,
    required this.wordsLearned,
    required this.totalWords,
    required this.accuracy,
  });

  /// Fraction of the category actually covered, 0.0–1.0.
  double get coverage => totalWords == 0 ? 0.0 : wordsLearned / totalWords;

  /// Whether this category counts as mastered.
  ///
  /// Coverage, not accuracy: an award that says "Mastery" should mean the
  /// learner met most of the words, not that they were accurate on a handful.
  bool get isMastered => totalWords > 0 && coverage >= masteryThreshold;

  /// Whether the learner has touched this category at all.
  bool get isStarted => wordsLearned > 0 || accuracy != null;

  static const double masteryThreshold = 0.8;

  /// Builds one entry per category from [progress] and the [cards] on offer.
  ///
  /// Pure — takes the card list rather than reaching for a provider, so the
  /// exports, the PDF generator and the widget tests can all call it without a
  /// container.
  static Map<FlashcardCategory, CategoryMastery> forProgress(
    LearningProgress progress,
    List<Flashcard> cards,
  ) {
    final byCategory = <FlashcardCategory, List<Flashcard>>{};
    for (final card in cards) {
      (byCategory[card.category] ??= <Flashcard>[]).add(card);
    }

    return {
      for (final category in FlashcardCategory.values)
        category: CategoryMastery(
          category: category,
          wordsLearned: (byCategory[category] ?? const <Flashcard>[])
              .where((c) => progress.learnedWordIds.contains(c.id))
              .length,
          totalWords: (byCategory[category] ?? const <Flashcard>[]).length,
          accuracy: progress.categoryProgress[category.label],
        ),
    };
  }
}

/// Per-category coverage for the active learner, over seed + custom cards.
final categoryMasteryProvider =
    Provider<Map<FlashcardCategory, CategoryMastery>>((ref) {
      final progress = ref.watch(progressProvider);
      final cards = ref.watch(allFlashcardsProvider);
      return CategoryMastery.forProgress(progress, cards);
    });
