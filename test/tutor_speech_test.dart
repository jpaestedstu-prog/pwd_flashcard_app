import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_speech.dart';

/// The tutor's bubbles are written for the eye. These pin what a learner who
/// only has the audio actually hears.

/// Anything a screen reader would announce as a symbol name.
final _decorative = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2100}-\u{21FF}\u{2300}-\u{23FF}'
  r'\u{25A0}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}]',
  unicode: true,
);

void main() {
  group('TutorSpeech.forSpeech', () {
    test('drops the emoji and keeps the sentence', () {
      final out = TutorSpeech.forSpeech(
          '✅ Correct! The answer is "Ibon". Well done! 🎉');
      expect(out, 'Correct! The answer is "Ibon". Well done!.');
      expect(out, isNot(matches(_decorative)));
    });

    test('a quiz prompt loses its header decoration but keeps both lines', () {
      final out = TutorSpeech.forSpeech(
          '❓ Quick Quiz!\n\nWhat is the Filipino for "Soup"?');
      expect(out, contains('Quick Quiz'));
      expect(out, contains('What is the Filipino for "Soup"?'));
      expect(out, isNot(contains('\n')));
      expect(out, isNot(matches(_decorative)));
    });

    test('a lesson position reads as a position, not a fraction', () {
      final out = TutorSpeech.forSpeech('📚 Lesson 1/3\n\nWhat is this?');
      expect(out, contains('Lesson 1 of 3'));
      expect(out, isNot(contains('1/3')));
    });

    test('Filipino gets the Filipino position wording', () {
      final out = TutorSpeech.forSpeech('📚 Aralin 2/3\n\nAno ito?',
          isFilipino: true);
      expect(out, contains('Aralin 2 sa 3'));
    });

    test('no doubled full stops when joining lines that already end in one',
        () {
      final out = TutorSpeech.forSpeech('Line one.\n\nLine two.');
      expect(out, isNot(contains('..')));
    });

    test('punctuation stranded by a stripped emoji is cleaned up', () {
      final out =
          TutorSpeech.forSpeech('❓ A 🐶 Animals quiz — your favorite!');
      expect(out.trimLeft(), startsWith('A'));
      expect(out, isNot(startsWith('—')));
      expect(out, contains('Animals quiz'));
    });

    test('an emoji-only bubble speaks nothing rather than clicking', () {
      expect(TutorSpeech.forSpeech('🎉🎉🎉'), isEmpty);
      expect(TutorSpeech.forSpeech('   '), isEmpty);
    });

    test('plain text passes through essentially unchanged', () {
      const plain = 'Try asking me about a category';
      expect(TutorSpeech.forSpeech(plain), 'Try asking me about a category.');
    });
  });

  group('every engine message is speakable', () {
    test('no real tutor message leaves decoration in the spoken form', () {
      final card = SeedData.allFlashcards.first;
      final messages = [
        TutorEngine.greet('Ana'),
        TutorEngine.askInterests(),
        TutorEngine.quizForWord(card),
        TutorEngine.reteach(card),
        TutorEngine.reviewRoundIntro(2),
        TutorEngine.quickQuiz(),
      ];
      for (final m in messages) {
        final spoken = TutorSpeech.forSpeech(m.content);
        expect(spoken, isNotEmpty, reason: m.content);
        expect(spoken, isNot(matches(_decorative)), reason: m.content);
        expect(spoken, isNot(contains('\n')), reason: m.content);
      }
    });
  });
}
