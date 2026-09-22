import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/question_prompt.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';

/// Generated questions are stored in English and have to stay that way — the
/// stored text is the instrument the post-test, the Class Report and the
/// research export line up against. A Filipino-mode learner used to read
/// those English sentences mid-test. [QuestionPrompt] translates them where
/// they are *shown*.
void main() {
  final fil = AppLocalizationsFil();
  final en = AppLocalizationsEn();

  group('every generated question reads in Filipino', () {
    const cases = {
      'What is the Filipino word for “Dog”?':
          'Ano ang salitang Filipino para sa “Dog”?',
      'What is the English word for “Aso”?':
          'Ano ang salitang Ingles para sa “Aso”?',
      'Fill in the blank: The Filipino translation of “Dog” is _____.':
          'Punan ang patlang: Ang salin sa Filipino ng “Dog” ay _____.',
      'True or False: “Dog” is “Pusa” in Filipino.':
          'Tama o Mali: Ang “Dog” ay “Pusa” sa Filipino.',
      '“Star” in Filipino is “Gunting”': 'Ang “Star” sa Filipino ay “Gunting”',
      'Match: “Dog” → ?': 'Itugma: “Dog” → ?',
      'Type the Filipino word for “Four”:':
          'Isulat ang salitang Filipino para sa “Four”:',
      'Type the English word for “Kanin”:':
          'Isulat ang salitang Ingles para sa “Kanin”:',
      'Watch the sign. Which word is it?':
          'Panoorin ang senyas. Aling salita ito?',
      'Watch the sign. Which word is it? (“Nose”)':
          'Panoorin ang senyas. Aling salita ito? (“Nose”)',
    };
    for (final MapEntry(key: stored, value: shown) in cases.entries) {
      test(stored, () {
        expect(QuestionPrompt.localize(stored, fil), shown);
      });
    }
  });

  test('in English every generated question reads exactly as stored', () {
    // The English ARB wording must match the generators character for
    // character, or English learners would see a changed question.
    for (final stored in const [
      'What is the Filipino word for “Dog”?',
      'What is the English word for “Aso”?',
      'Fill in the blank: The Filipino translation of “Dog” is _____.',
      'True or False: “Dog” is “Pusa” in Filipino.',
      '“Star” in Filipino is “Gunting”',
      'Match: “Dog” → ?',
      'Type the Filipino word for “Four”:',
      'Type the English word for “Kanin”:',
      'Watch the sign. Which word is it?',
    ]) {
      expect(QuestionPrompt.localize(stored, en), stored);
    }
  });

  test('a question a teacher typed is shown as written', () {
    const typed = 'Which animal says moo?';
    expect(QuestionPrompt.localize(typed, fil), typed);
  });

  test('no delegate, no change', () {
    expect(
      QuestionPrompt.localize('What is the Filipino word for “Dog”?', null),
      'What is the Filipino word for “Dog”?',
    );
  });

  group('True / False', () {
    const tf = AssessmentQuestion(
      id: 'q',
      questionText: 'True or False: “Dog” is “Aso” in Filipino.',
      correctAnswer: 'True',
      choices: ['True', 'False'],
      format: QuestionFormat.trueFalse,
    );
    const mc = AssessmentQuestion(
      id: 'm',
      questionText: 'What is the English word for “Tama”?',
      correctAnswer: 'True',
      choices: ['True', 'False'],
    );

    test('reads Tama / Mali, while the stored answer stays True / False', () {
      expect(QuestionPrompt.choice(tf, 'True', fil), 'Tama');
      expect(QuestionPrompt.choice(tf, 'False', fil), 'Mali');
      expect(tf.correctAnswer, 'True');
    });

    test('a word that happens to be "True" in another format is untouched', () {
      expect(QuestionPrompt.choice(mc, 'True', fil), 'True');
    });

    test('a stored answer in the review reads in Filipino', () {
      expect(QuestionPrompt.answer('False', fil), 'Mali');
      expect(QuestionPrompt.answer('Aso', fil), 'Aso');
    });
  });

  group('titles', () {
    test('the class instrument', () {
      expect(
        QuestionPrompt.title('Pre-Test — All Categories', fil),
        'Panimulang Pagsusulit — Lahat ng Kategorya',
      );
      expect(
        QuestionPrompt.title('Post-Test — All Categories', fil),
        startsWith('Panghuling Pagsusulit — '),
      );
    });

    test('a list of categories', () {
      expect(
        QuestionPrompt.title('Pre-Test — Animals, Numbers', fil),
        'Panimulang Pagsusulit — '
        '${FlashcardCategory.animals.labelFilipino}, '
        '${FlashcardCategory.numbers.labelFilipino}',
      );
    });

    test('a mastery test', () {
      expect(
        QuestionPrompt.title('Animals Mastery Test', fil),
        'Pagsusulit sa Kahusayan: ${FlashcardCategory.animals.labelFilipino}',
      );
    });

    test('in English, unchanged', () {
      expect(
        QuestionPrompt.title('Pre-Test — All Categories', en),
        'Pre-Test — All Categories',
      );
      expect(
        QuestionPrompt.title('Animals Mastery Test', en),
        'Animals Mastery Test',
      );
    });

    test('a title a teacher typed is shown as written', () {
      expect(QuestionPrompt.title('Week 3 — Colours', fil), 'Week 3 — Colours');
    });
  });

  test('a category stored by its English name reads in Filipino', () {
    expect(
      QuestionPrompt.categoryName('Animals', fil),
      FlashcardCategory.animals.labelFilipino,
    );
    expect(QuestionPrompt.categoryName('Animals', en), 'Animals');
  });
}
