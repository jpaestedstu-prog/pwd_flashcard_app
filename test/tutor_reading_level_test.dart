import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';
import 'package:pwdpwdpwd/features/ai_tutor/widgets/tutor_persona.dart';

LearningProgress _progress() => LearningProgress(
      profileId: 'p1',
      lastActivityDate: DateTime.now(),
      wordsLearned: 3,
      totalStars: 5,
      streakDays: 1,
      categoryProgress: const {'Animals': 0.25},
    );

String _reply(String q, {required bool simple}) => TutorEngine.respondToQuestion(
      q,
      _progress(),
      'p1',
      simple: simple,
    ).content;

void main() {
  // The lesson-plan path reads spaced-repetition data from the `progress` box.
  setUpAll(() async {
    Hive.init('./build/test_cache/tutor_reading_level');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
  });

  group('who gets the plain-language register', () {
    test('a Child does, whatever their profile', () {
      expect(
        TutorPersona.simpleLanguageFor(UserRole.child, DisabilityType.none),
        isTrue,
      );
    });

    test('cognitive and multiple do, whatever their role', () {
      for (final type in [DisabilityType.cognitive, DisabilityType.multiple]) {
        expect(TutorPersona.simpleLanguageFor(UserRole.student, type), isTrue,
            reason: '$type');
      }
    });

    test('a Student or Player with no such need keeps the full register', () {
      for (final role in [UserRole.student, UserRole.player]) {
        expect(TutorPersona.simpleLanguageFor(role, DisabilityType.none),
            isFalse,
            reason: '$role');
        expect(TutorPersona.simpleLanguageFor(role, DisabilityType.hearing),
            isFalse,
            reason: '$role');
      }
    });

    test('no active profile falls back to the full register', () {
      expect(
        TutorPersona.simpleLanguageFor(null, DisabilityType.none),
        isFalse,
      );
    });
  });

  group('category info', () {
    test('plain register counts real words instead of a percentage', () {
      final simple = _reply('tell me about animals', simple: true);
      expect(simple, isNot(contains('%')));
      expect(simple, isNot(contains('mastered')));
      expect(simple, contains('of 12 words'));
    });

    test('full register keeps the percentage wording', () {
      final full = _reply('tell me about animals', simple: false);
      expect(full, contains('%'));
      expect(full, contains('mastered'));
    });
  });

  group('progress summary', () {
    test('plain register drops the jargon', () {
      final simple = _reply('progress', simple: true);
      expect(simple, contains('You know 3 words'));
      expect(simple, contains('You have 5 stars'));
      expect(simple, isNot(contains('words learned')));
      expect(simple, isNot(contains('games played')));
    });

    test('plain register gets singular/plural right', () {
      final msg = TutorEngine.respondToQuestion(
        'progress',
        LearningProgress(
          profileId: 'p1',
          lastActivityDate: DateTime.now(),
          wordsLearned: 1,
          streakDays: 1,
        ),
        'p1',
        simple: true,
      ).content;
      expect(msg, contains('1 word\n'));
      expect(msg, contains('1 day in a row'));
      expect(msg, isNot(contains('1 words')));
      expect(msg, isNot(contains('1 days')));
    });

    test('full register is unchanged', () {
      final full = _reply('progress', simple: false);
      expect(full, contains('words learned'));
      expect(full, contains('games played'));
    });
  });

  group('study tips and lesson offer', () {
    test('plain tips avoid abstract advice', () {
      // Sample enough times to cover the whole rotation.
      for (var i = 0; i < 30; i++) {
        final tip = _reply('hint', simple: true);
        expect(tip, isNot(contains('Repetition')));
        expect(tip, isNot(contains('reinforces')));
      }
    });

    test('the lesson offer is shorter in the plain register', () {
      final simple =
          TutorEngine.offerLearningPlan(_progress(), 'p1', simple: true).content;
      final full =
          TutorEngine.offerLearningPlan(_progress(), 'p1').content;
      expect(simple.length, lessThan(full.length));
      expect(simple, contains('Let\'s learn'));
      expect(full, contains('Today\'s lesson is ready'));
    });
  });
}
