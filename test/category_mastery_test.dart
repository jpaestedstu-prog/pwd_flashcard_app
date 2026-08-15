import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/progress/models/category_mastery.dart';

/// Coverage vs. accuracy.
///
/// `LearningProgress.categoryProgress` reads like a completion ratio but its
/// only writer blends `0.7 * previous + 0.3 * (score / total)` — a rolling
/// average of game accuracy. Five surfaces consumed it as completion, and the
/// certificate screen multiplied it by the card count to print a word total on
/// a physical award. These tests pin the two measures apart.
///
/// Plain `test()` — pure model, no Hive, no widgets.
void main() {
  const category = FlashcardCategory.animals;

  List<Flashcard> cards(int count) => [
    for (var i = 0; i < count; i++)
      Flashcard(
        id: 'c$i',
        wordEnglish: 'Word $i',
        wordFilipino: 'Salita $i',
        category: category,
      ),
  ];

  LearningProgress progressWith({
    Set<String> learned = const {},
    Map<String, double> accuracy = const {},
  }) => LearningProgress(
    profileId: 'p1',
    lastActivityDate: DateTime(2026, 8, 15),
    learnedWordIds: learned,
    categoryProgress: accuracy,
  );

  test('coverage counts distinct words learned, not accuracy', () {
    // The exact shape of the old bug: a high accuracy average on a category
    // the learner has barely opened. 0.83 * 20 printed "17/20 words learned".
    final mastery = CategoryMastery.forProgress(
      progressWith(
        learned: {'c0', 'c1', 'c2'},
        accuracy: {category.label: 0.83},
      ),
      cards(20),
    );

    final animals = mastery[category]!;
    expect(animals.wordsLearned, 3);
    expect(animals.totalWords, 20);
    expect(animals.coverage, closeTo(0.15, 0.001));
    expect(animals.accuracy, 0.83);
    expect(
      animals.isMastered,
      isFalse,
      reason: 'three of twenty words is not mastery, however accurate',
    );
  });

  test('a finished category counts even when accuracy is low', () {
    // The mirror case: every word met, but answered messily along the way.
    final mastery = CategoryMastery.forProgress(
      progressWith(
        learned: {for (var i = 0; i < 10; i++) 'c$i'},
        accuracy: {category.label: 0.4},
      ),
      cards(10),
    );

    expect(mastery[category]!.coverage, 1.0);
    expect(mastery[category]!.isMastered, isTrue);
  });

  test('a category the learner never played has no accuracy at all', () {
    // Distinct from scoring zero — the research export has to tell them apart,
    // so accuracy stays null rather than defaulting to 0.0.
    final mastery = CategoryMastery.forProgress(progressWith(), cards(5));

    expect(mastery[category]!.accuracy, isNull);
    expect(mastery[category]!.coverage, 0.0);
    expect(mastery[category]!.isStarted, isFalse);
  });

  test('custom cards count toward the denominator', () {
    // The certificate screen counted with `SeedData.getByCategory` while the
    // Progress tab counted with `allFlashcardsProvider`, so a teacher who added
    // their own cards saw two different totals for one category.
    final withCustom = [
      ...cards(4),
      const Flashcard(
        id: 'custom1',
        wordEnglish: 'Kalabaw',
        wordFilipino: 'Kalabaw',
        category: category,
        isCustom: true,
      ),
    ];

    final mastery = CategoryMastery.forProgress(
      progressWith(learned: {'c0', 'c1', 'c2', 'c3'}),
      withCustom,
    );

    expect(mastery[category]!.totalWords, 5);
    expect(mastery[category]!.coverage, closeTo(0.8, 0.001));
  });

  test('every category is represented, including empty ones', () {
    // The exports write one column per category and must not skip any.
    final mastery = CategoryMastery.forProgress(progressWith(), cards(3));

    expect(mastery.keys.toSet(), FlashcardCategory.values.toSet());
    for (final entry in mastery.entries) {
      if (entry.key != category) {
        expect(entry.value.totalWords, 0);
        expect(
          entry.value.coverage,
          0.0,
          reason: 'an empty category must not divide by zero',
        );
        expect(entry.value.isMastered, isFalse);
      }
    }
  });

  test('words learned in another category do not leak across', () {
    final mixed = [
      ...cards(3),
      const Flashcard(
        id: 'f1',
        wordEnglish: 'Rice',
        wordFilipino: 'Kanin',
        category: FlashcardCategory.foodAndDrinks,
      ),
    ];

    final mastery = CategoryMastery.forProgress(
      progressWith(learned: {'c0', 'f1'}),
      mixed,
    );

    expect(mastery[category]!.wordsLearned, 1);
    expect(mastery[FlashcardCategory.foodAndDrinks]!.wordsLearned, 1);
  });
}
