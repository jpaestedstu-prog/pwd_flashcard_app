import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Verifies the shipped media manifests parse and wire to real seed cards.
/// This is the safety net that catches a mis-keyed override (wrong category
/// label or word spelling) — the manifest key must match
/// `[Category label]__[wordEnglish lowercased]` exactly or the card gets no
/// media.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Flashcard byId(String id) =>
      SeedData.allFlashcards.firstWhere((c) => c.id == id);

  setUp(() async {
    FlashcardPhotoService.reset();
    ActionClipService.reset();
    await FlashcardPhotoService.load();
    await ActionClipService.load();
  });

  tearDown(() {
    FlashcardPhotoService.reset();
    ActionClipService.reset();
  });

  group('Photo manifest', () {
    test('every original-category seed card resolves to a photo URL', () {
      const original = {
        FlashcardCategory.animals,
        FlashcardCategory.colorsAndShapes,
        FlashcardCategory.numbers,
        FlashcardCategory.bodyParts,
        FlashcardCategory.foodAndDrinks,
        FlashcardCategory.familyAndGreetings,
        FlashcardCategory.clothing,
        FlashcardCategory.weather,
        FlashcardCategory.classroom,
        FlashcardCategory.transportation,
        FlashcardCategory.emotions,
        FlashcardCategory.daysAndTime,
      };
      // The first 12 cards of each original category are the ones with photos
      // (later Word-Hunt extras / Flower aren't in the manifest).
      for (final cat in original) {
        final cards = SeedData.getByCategory(cat).take(12);
        for (final card in cards) {
          expect(FlashcardPhotoService.hasPhoto(card), isTrue,
              reason: 'No photo wired for ${card.category.label} / '
                  '${card.wordEnglish} (check the manifest key)');
        }
      }
    });

    test('multi-word keys match (Thank You, Good Morning, T-shirt, Partly Cloudy)', () {
      for (final id in ['g08', 'g11', 'cl01', 'w11']) {
        final card = byId(id);
        expect(FlashcardPhotoService.hasPhoto(card), isTrue,
            reason: '${card.wordEnglish} key mismatch');
        expect(FlashcardPhotoService.urlFor(card), contains('postimg.cc'));
      }
    });

    test('Actions category has no photos yet (left dormant on purpose)', () {
      for (final card in SeedData.getByCategory(FlashcardCategory.actions)) {
        expect(FlashcardPhotoService.hasPhoto(card), isFalse);
      }
    });
  });

  group('Clip manifest', () {
    test('clips wired for the 10 demonstrated categories (incl. Body Parts)', () {
      const withClips = {
        FlashcardCategory.animals,
        FlashcardCategory.bodyParts,
        FlashcardCategory.foodAndDrinks,
        FlashcardCategory.familyAndGreetings,
        FlashcardCategory.clothing,
        FlashcardCategory.weather,
        FlashcardCategory.classroom,
        FlashcardCategory.transportation,
        FlashcardCategory.emotions,
        FlashcardCategory.daysAndTime,
      };
      for (final cat in withClips) {
        for (final card in SeedData.getByCategory(cat).take(12)) {
          expect(ActionClipService.hasClip(card), isTrue,
              reason: 'No clip wired for ${card.category.label} / '
                  '${card.wordEnglish}');
        }
      }
    });

    test('Colors, Numbers and Actions have no clips (by design)', () {
      const noClips = {
        FlashcardCategory.colorsAndShapes,
        FlashcardCategory.numbers,
        FlashcardCategory.actions,
      };
      for (final cat in noClips) {
        for (final card in SeedData.getByCategory(cat)) {
          expect(ActionClipService.hasClip(card), isFalse,
              reason: '${card.wordEnglish} should not have a clip');
        }
      }
    });
  });
}
