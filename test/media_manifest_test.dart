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
        expect(FlashcardPhotoService.urlFor(card), contains('res.cloudinary.com'));
      }
    });

    test('Actions category has no photos yet (left dormant on purpose)', () {
      for (final card in SeedData.getByCategory(FlashcardCategory.actions)) {
        expect(FlashcardPhotoService.hasPhoto(card), isFalse);
      }
    });

    test('every cartoon is paired with a realistic photo', () {
      // A cartoon with no photo would render a flip hint that leads nowhere.
      for (final card in SeedData.allFlashcards) {
        if (FlashcardPhotoService.cartoonUrlFor(card) == null) continue;
        expect(FlashcardPhotoService.hasPhoto(card), isTrue,
            reason: '${card.category.label} / ${card.wordEnglish} has a cartoon '
                'but no photo to flip to');
      }
    });

    test('Colors & Shapes and Numbers are realistic-only (no flip)', () {
      // The photograph *is* the lesson for these, so they deliberately ship
      // one face and must not offer a tap-to-flip.
      for (final cat in const [
        FlashcardCategory.colorsAndShapes,
        FlashcardCategory.numbers,
      ]) {
        for (final card in SeedData.getByCategory(cat).take(12)) {
          expect(FlashcardPhotoService.cartoonUrlFor(card), isNull,
              reason: '${card.wordEnglish} should have no cartoon');
          expect(FlashcardPhotoService.canFlip(card), isFalse);
        }
      }
    });

    test('the other ten categories flip, and every URL is a direct image', () {
      const flipping = {
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
      final seen = <String, String>{};
      for (final cat in flipping) {
        for (final card in SeedData.getByCategory(cat).take(12)) {
          expect(FlashcardPhotoService.canFlip(card), isTrue,
              reason: '${card.category.label} / ${card.wordEnglish} should '
                  'have both faces');
          final urls = {
            'cartoon': FlashcardPhotoService.cartoonUrlFor(card)!,
            'photo': FlashcardPhotoService.urlFor(card)!,
          };
          urls.forEach((face, url) {
            final where = '${card.wordEnglish} $face';
            expect(Uri.parse(url).path.toLowerCase(),
                anyOf(endsWith('.png'), endsWith('.jpg'), endsWith('.jpeg')),
                reason: '$where is not a direct image: $url');
            expect(seen.containsKey(url), isFalse,
                reason: 'picture reused by ${seen[url]} and $where');
            seen[url] = where;
          });
        }
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

    test('no Streamable URLs survive — they expire', () {
      for (final card in SeedData.allFlashcards) {
        expect(ActionClipService.urlFor(card) ?? '',
            isNot(contains('streamable.com')),
            reason: '${card.category.label} / ${card.wordEnglish} still points '
                'at Streamable');
      }
    });

    test('clips are direct media files, and isGifFor matches the extension', () {
      // resolveClip picks the decoder (Image.file vs VideoPlayerController)
      // from the authored extension, so a share-page URL with no extension
      // would silently be treated as a video.
      for (final card in SeedData.allFlashcards) {
        final url = ActionClipService.urlFor(card);
        if (url == null) continue;
        final path = Uri.parse(url).path.toLowerCase();
        expect(path, anyOf(endsWith('.gif'), endsWith('.mp4')),
            reason: '${card.category.label} / ${card.wordEnglish} clip URL has '
                'no recognisable media extension');
        expect(ActionClipService.isGifFor(card), path.endsWith('.gif'),
            reason: 'isGifFor disagrees with the URL extension for '
                '${card.category.label} / ${card.wordEnglish}');
      }
    });
  });
}
