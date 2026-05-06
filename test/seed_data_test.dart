import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('SeedData', () {
    test('contains 144 flashcards', () {
      expect(SeedData.allFlashcards.length, 144);
    });

    test('all flashcards have unique IDs', () {
      final ids = SeedData.allFlashcards.map((c) => c.id).toSet();
      expect(ids.length, SeedData.allFlashcards.length);
    });

    test('all categories have flashcards', () {
      for (final cat in FlashcardCategory.values) {
        final cards = SeedData.getByCategory(cat);
        expect(cards, isNotEmpty,
            reason: '${cat.label} should have flashcards');
      }
    });

    test('all flashcards have non-empty English and Filipino words', () {
      for (final card in SeedData.allFlashcards) {
        expect(card.wordEnglish, isNotEmpty,
            reason: 'Card ${card.id} missing English word');
        expect(card.wordFilipino, isNotEmpty,
            reason: 'Card ${card.id} missing Filipino word');
      }
    });

    test('seed flashcards use emoji fallback (no imageAsset)', () {
      // Seed data intentionally omits imageAsset so the emoji fallback
      // is used instead of missing PNG files.
      for (final card in SeedData.allFlashcards) {
        expect(card.imageAsset, isNull,
            reason: 'Card ${card.id} should not have imageAsset (use emoji)');
      }
    });

    test('getByCategory filters correctly', () {
      final animals = SeedData.getByCategory(FlashcardCategory.animals);
      for (final card in animals) {
        expect(card.category, FlashcardCategory.animals);
      }
    });

    test('default decks exist for all categories', () {
      final deckCategories =
          SeedData.defaultDecks.map((d) => d.category).toSet();
      for (final cat in FlashcardCategory.values) {
        expect(deckCategories.contains(cat), true,
            reason: 'Missing deck for ${cat.label}');
      }
    });
  });

  group('Enums', () {
    test('all GameType values have labels', () {
      for (final type in GameType.values) {
        expect(type.label, isNotEmpty);
      }
    });

    test('all FlashcardCategory values have labels and icons', () {
      for (final cat in FlashcardCategory.values) {
        expect(cat.label, isNotEmpty);
        expect(cat.icon, isNotNull);
        expect(cat.color, isNotNull);
      }
    });

    test('all GameDifficulty values have labels and descriptions', () {
      for (final diff in GameDifficulty.values) {
        expect(diff.label, isNotEmpty);
        expect(diff.description, isNotEmpty);
      }
    });

    test('UserRole values have labels', () {
      for (final role in UserRole.values) {
        expect(role.label, isNotEmpty);
      }
    });
  });
}
