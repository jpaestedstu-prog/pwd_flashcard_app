import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_speech.dart';

const _card = Flashcard(
  id: 't_cat',
  wordEnglish: 'Cat',
  wordFilipino: 'Pusa',
  exampleSentence: 'The cat sleeps all day.',
  category: FlashcardCategory.animals,
);

const _noExample = Flashcard(
  id: 't_bare',
  wordEnglish: 'Swim',
  wordFilipino: 'Lumangoy',
  category: FlashcardCategory.actions,
);

/// A sentence that never mentions the word is not a clue.
const _irrelevantExample = Flashcard(
  id: 't_odd',
  wordEnglish: 'Cat',
  wordFilipino: 'Pusa',
  exampleSentence: 'It sleeps all day.',
  category: FlashcardCategory.animals,
);

LearningProgress _progress() => LearningProgress(
      profileId: 'p1',
      lastActivityDate: DateTime.now(),
    );

void main() {
  group('TutorEngine.hintForWord', () {
    test('scaffolds with topic, first letter and length', () {
      final content = TutorEngine.hintForWord(_card).content;
      expect(content, contains('Animals'));
      expect(content, contains('"P"'));
      expect(content, contains('4 letters'));
    });

    test('never states the answer outright', () {
      final content = TutorEngine.hintForWord(_card).content;
      expect(content, isNot(contains('Pusa')));
    });

    test('masks the word in the example sentence', () {
      final content = TutorEngine.hintForWord(_card).content;
      expect(content, contains('The ___ sleeps all day.'));
      expect(content.toLowerCase(), isNot(contains('the cat sleeps')));
    });

    test('omits the sentence when there is none', () {
      final content = TutorEngine.hintForWord(_noExample).content;
      expect(content, isNot(contains('___')));
      expect(content, contains('"L"'));
      expect(content, contains('8 letters'));
    });

    test('omits a sentence that does not mention the word', () {
      final content = TutorEngine.hintForWord(_irrelevantExample).content;
      expect(content, isNot(contains('___')));
      expect(content, isNot(contains('It sleeps all day')));
    });

    test('localizes to Filipino', () {
      final content = TutorEngine.hintForWord(_card, isFilipino: true).content;
      expect(content, contains('Nagsisimula'));
      expect(content, contains('letra'));
      expect(content, isNot(contains('Pusa')));
    });

    test('the masked blank is speakable', () {
      final spoken =
          TutorSpeech.forSpeech(TutorEngine.hintForWord(_card).content);
      expect(spoken, contains('blank'));
      expect(spoken, isNot(contains('_')));
    });
  });

  group('hint routing', () {
    test('with a question pending, help addresses that question', () {
      final msg = TutorEngine.respondToQuestion(
        'hint',
        _progress(),
        'p1',
        activeCard: _card,
      );
      expect(msg.content, contains('4 letters'));
    });

    test('with nothing pending, help falls back to a study tip', () {
      final msg = TutorEngine.respondToQuestion('hint', _progress(), 'p1');
      expect(msg.content, isNot(contains('letters')));
      expect(msg.content, contains('💡'));
    });

    test('"help" is routed the same way as "hint"', () {
      final msg = TutorEngine.respondToQuestion(
        'help me please',
        _progress(),
        'p1',
        activeCard: _card,
      );
      expect(msg.content, contains('Animals'));
    });

    test('every seed card produces a usable hint', () {
      for (final card in SeedData.allFlashcards) {
        final content = TutorEngine.hintForWord(card).content;
        expect(content, isNotEmpty, reason: card.wordEnglish);
        expect(content, isNot(contains(card.wordFilipino)),
            reason: card.wordEnglish);
      }
    });
  });
}
