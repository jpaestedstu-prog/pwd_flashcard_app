import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('Flashcard', () {
    const card = Flashcard(
      id: 'test01',
      wordEnglish: 'Dog',
      wordFilipino: 'Aso',
      exampleSentence: 'The dog barks.',
      imageAsset: 'assets/images/flashcards/test01.png',
      category: FlashcardCategory.animals,
    );

    test('toJson produces correct map', () {
      final json = card.toJson();
      expect(json['id'], 'test01');
      expect(json['wordEnglish'], 'Dog');
      expect(json['wordFilipino'], 'Aso');
      expect(json['exampleSentence'], 'The dog barks.');
      expect(json['imageAsset'], 'assets/images/flashcards/test01.png');
      expect(json['category'], FlashcardCategory.animals.index);
      expect(json['isCustom'], false);
    });

    test('fromJson creates identical card', () {
      final json = card.toJson();
      final restored = Flashcard.fromJson(json);
      expect(restored.id, card.id);
      expect(restored.wordEnglish, card.wordEnglish);
      expect(restored.wordFilipino, card.wordFilipino);
      expect(restored.exampleSentence, card.exampleSentence);
      expect(restored.imageAsset, card.imageAsset);
      expect(restored.category, card.category);
      expect(restored.isCustom, card.isCustom);
    });

    test('toJson → fromJson roundtrip preserves equality', () {
      final json = card.toJson();
      final restored = Flashcard.fromJson(json);
      expect(restored, equals(card));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'min01',
        'wordEnglish': 'Cat',
        'wordFilipino': 'Pusa',
        'category': FlashcardCategory.animals.index,
      };
      final minimal = Flashcard.fromJson(json);
      expect(minimal.id, 'min01');
      expect(minimal.exampleSentence, isNull);
      expect(minimal.imageAsset, isNull);
      expect(minimal.isCustom, false);
    });

    test('copyWith creates new instance with changed fields', () {
      final copy = card.copyWith(wordEnglish: 'Pup', isCustom: true);
      expect(copy.wordEnglish, 'Pup');
      expect(copy.isCustom, true);
      // Unchanged fields
      expect(copy.id, card.id);
      expect(copy.wordFilipino, card.wordFilipino);
    });

    test('equality operator works', () {
      const card2 = Flashcard(
        id: 'test01',
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
        exampleSentence: 'The dog barks.',
        imageAsset: 'assets/images/flashcards/test01.png',
        category: FlashcardCategory.animals,
      );
      expect(card, equals(card2));
      expect(card.hashCode, card2.hashCode);
    });

    test('equality fails for different cards', () {
      const other = Flashcard(
        id: 'test02',
        wordEnglish: 'Cat',
        wordFilipino: 'Pusa',
        category: FlashcardCategory.animals,
      );
      expect(card, isNot(equals(other)));
    });
  });

  group('GameScore', () {
    test('toJson → fromJson roundtrip', () {
      final score = GameScore(
        gameType: GameType.wordMatch,
        score: 8,
        total: 10,
        starsEarned: 2,
        date: DateTime(2025, 6, 15, 14, 30),
      );
      final json = score.toJson();
      final restored = GameScore.fromJson(json);
      expect(restored.gameType, score.gameType);
      expect(restored.score, score.score);
      expect(restored.total, score.total);
      expect(restored.starsEarned, score.starsEarned);
      expect(restored.date, score.date);
    });
  });

  group('LearningProgress', () {
    test('copyWith preserves unmodified fields', () {
      final progress = LearningProgress(
        profileId: 'p1',
        wordsLearned: 10,
        streakDays: 3,
        lastActivityDate: DateTime(2025),
        totalStars: 5,
      );
      final updated = progress.copyWith(wordsLearned: 20);
      expect(updated.wordsLearned, 20);
      expect(updated.streakDays, 3);
      expect(updated.totalStars, 5);
      expect(updated.profileId, 'p1');
    });
  });

  group('AppSettings', () {
    test('defaults are correct', () {
      const settings = AppSettings();
      expect(settings.fontScale, 1.0);
      expect(settings.highContrastMode, false);
      expect(settings.ttsEnabled, true);
      expect(settings.soundEffects, true);
    });

    test('copyWith changes specific fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        fontScale: 1.5,
        highContrastMode: true,
      );
      expect(updated.fontScale, 1.5);
      expect(updated.highContrastMode, true);
      expect(updated.ttsEnabled, true); // unchanged
    });
  });
}
