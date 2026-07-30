import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';

/// A quiz whose wrong answers come from other categories is answerable by
/// elimination — and the point it awards is then fed to spaced repetition as
/// evidence the learner knows the word. These pin the option quality.

void main() {
  group('TutorEngine.distractorsFor', () {
    test('every seed card gets three same-category distractors', () {
      for (final card in SeedData.allFlashcards) {
        final sameCategory = SeedData.getByCategory(card.category)
            .map((c) => c.wordFilipino)
            .toSet();
        final distractors = TutorEngine.distractorsFor(card);
        expect(distractors.length, 3, reason: card.wordEnglish);
        for (final d in distractors) {
          expect(sameCategory, contains(d),
              reason: '${card.wordEnglish} -> $d');
        }
      }
    });

    test('never repeats the correct answer, even across duplicate words', () {
      // "Chicken" exists in both Animals and Food & Drinks and shares the
      // Filipino word, so id-only filtering would let the answer in twice.
      for (final card in SeedData.allFlashcards) {
        expect(TutorEngine.distractorsFor(card), isNot(contains(card.wordFilipino)),
            reason: card.wordEnglish);
      }
    });

    test('distractors are distinct from each other', () {
      for (final card in SeedData.allFlashcards) {
        final d = TutorEngine.distractorsFor(card);
        expect(d.toSet().length, d.length, reason: card.wordEnglish);
      }
    });

    test('tops up from the wider pool when a category is too small', () {
      final card = SeedData.allFlashcards.first;
      // Ask for more than any single category can supply.
      final many = TutorEngine.distractorsFor(card, count: 40);
      expect(many.length, 40);
      expect(many.toSet().length, 40);
      expect(many, isNot(contains(card.wordFilipino)));
      final ownCategory =
          SeedData.getByCategory(card.category).map((c) => c.wordFilipino).toSet();
      expect(many.any((d) => !ownCategory.contains(d)), isTrue,
          reason: 'should have reached outside the category');
    });
  });

  group('quizForWord option set', () {
    test('always four unique options including the answer', () {
      for (final card in SeedData.allFlashcards) {
        final msg = TutorEngine.quizForWord(card);
        final options = msg.action!.options!;
        expect(options.length, 4, reason: card.wordEnglish);
        expect(options.toSet().length, 4, reason: card.wordEnglish);
        expect(options, contains(card.wordFilipino), reason: card.wordEnglish);
        expect(msg.action!.correctAnswer, card.wordFilipino);
      }
    });

    test('the whole option set stays inside one category', () {
      for (final card in SeedData.allFlashcards) {
        final sameCategory = SeedData.getByCategory(card.category)
            .map((c) => c.wordFilipino)
            .toSet();
        for (final o in TutorEngine.quizForWord(card).action!.options!) {
          expect(sameCategory, contains(o), reason: '${card.wordEnglish} -> $o');
        }
      }
    });

    test('a category quiz is not trivially guessable by category', () {
      // Regression guard for the old behaviour: Animals question, one animal.
      final animals = SeedData.getByCategory(FlashcardCategory.animals);
      final animalWords = animals.map((c) => c.wordFilipino).toSet();
      final msg = TutorEngine.quizForWord(animals.first);
      final animalOptions =
          msg.action!.options!.where(animalWords.contains).length;
      expect(animalOptions, 4);
    });
  });
}
