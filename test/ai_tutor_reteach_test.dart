import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';

/// A wrong answer used to end at "the correct answer is X" and move straight
/// on. These pin the re-teach content the tutor now shows instead, plus the
/// retry-round announcement that re-asks the missed words before the lesson
/// is allowed to finish.

const _rich = Flashcard(
  id: 't_bird',
  wordEnglish: 'Bird',
  wordFilipino: 'Ibon',
  exampleSentence: 'The bird sings in the tree.',
  definition: 'A bird has wings and can fly.',
  category: FlashcardCategory.animals,
);

const _bare = Flashcard(
  id: 't_soup',
  wordEnglish: 'Soup',
  wordFilipino: 'Sabaw',
  category: FlashcardCategory.foodAndDrinks,
);

void main() {
  group('TutorEngine.reteach', () {
    test('re-states the word pair so the miss becomes a teaching moment', () {
      final msg = TutorEngine.reteach(_rich);
      expect(msg.role, TutorMessageRole.tutor);
      expect(msg.content, contains('Bird'));
      expect(msg.content, contains('Ibon'));
      expect(msg.content, contains(FlashcardCategory.animals.emoji));
    });

    test('includes the example sentence and definition when the card has them',
        () {
      final msg = TutorEngine.reteach(_rich);
      expect(msg.content, contains('The bird sings in the tree.'));
      expect(msg.content, contains('A bird has wings and can fly.'));
    });

    test('degrades cleanly for a card with no example or definition', () {
      final msg = TutorEngine.reteach(_bare);
      expect(msg.content, contains('Soup'));
      expect(msg.content, contains('Sabaw'));
      // No empty quote / info rows left behind.
      expect(msg.content, isNot(contains('💬')));
      expect(msg.content, isNot(contains('ℹ️')));
      expect(msg.content.trim(), msg.content);
    });

    test('speaks Filipino when the learner is in Filipino', () {
      final msg = TutorEngine.reteach(_rich, isFilipino: true);
      expect(msg.content, contains('Balikan'));
      expect(msg.content, contains('Ibon'));
    });

    test('carries the word id so the bubble can add a picture / sign', () {
      final action = TutorEngine.reteach(_rich).action;
      expect(action?.type, TutorActionType.reteach);
      expect(action?.wordId, _rich.id);
      // It teaches, it does not ask — no options, no button, no route.
      expect(action?.options, isNull);
      expect(action?.correctAnswer, isNull);
      expect(action?.targetRoute, isNull);
    });

    test('the reteach action survives a persistence round-trip', () {
      final original = TutorEngine.reteach(_rich).action!;
      final restored = TutorAction.fromJson(original.toJson());
      expect(restored.type, TutorActionType.reteach);
      expect(restored.wordId, _rich.id);
    });
  });

  group('TutorEngine.reviewRoundIntro', () {
    test('announces the retry round with the missed-word count', () {
      final msg = TutorEngine.reviewRoundIntro(2);
      expect(msg.content, contains('2'));
      expect(msg.content, contains('words'));
    });

    test('uses the singular for a single missed word', () {
      final msg = TutorEngine.reviewRoundIntro(1);
      expect(msg.content, contains('1 word'));
      expect(msg.content, isNot(contains('1 words')));
    });

    test('localizes to Filipino', () {
      final msg = TutorEngine.reviewRoundIntro(2, isFilipino: true);
      expect(msg.content, contains('Balikan'));
      expect(msg.content, contains('2'));
    });
  });

  group('TutorEngine.cardById', () {
    test('resolves a real seed card', () {
      final target = SeedData.allFlashcards.first;
      expect(TutorEngine.cardById(target.id)?.id, target.id);
    });

    test('returns null for an unknown id rather than throwing', () {
      // Lesson/retry rebuilds skip ids that no longer resolve.
      expect(TutorEngine.cardById('definitely_not_a_card'), isNull);
    });
  });
}
