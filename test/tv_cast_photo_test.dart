import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_asset_bridge.dart';

/// End-to-end check that the TV-side photo gate is wired to the real
/// `assets/data/flashcard_photo_manifest.json`. `TvCastAssetBridge.hasPhoto`
/// is what makes the cast server emit `slide.photo` (and therefore what makes
/// the TV's emoji→photo flip fire), so if the manifest wiring breaks the TV
/// silently falls back to emoji-only — exactly what this guards against.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvCastAssetBridge.hasPhoto (manifest-driven)', () {
    setUp(() async {
      FlashcardPhotoService.reset();
      await FlashcardPhotoService.load();
    });

    tearDown(FlashcardPhotoService.reset);

    test('seeded cards with a manifest override report a photo', () {
      final animals = SeedData.getByCategory(FlashcardCategory.animals);
      final withPhotos = animals.where(TvCastAssetBridge.hasPhoto).toList();
      // The shipped manifest configures real photos for many Animals cards, so
      // the TV must offer at least some of them.
      expect(
        withPhotos,
        isNotEmpty,
        reason: 'expected manifest photo overrides for Animals cards',
      );

      // "dog" is a stable, intentionally-configured override — a good canary
      // that the lookup key (Category label + lowercased word) still matches.
      final dog = animals.firstWhere(
        (c) => c.wordEnglish.toLowerCase() == 'dog',
      );
      expect(TvCastAssetBridge.hasPhoto(dog), isTrue);
    });

    test('hasPhoto is false once the manifest is reset (emoji fallback)', () {
      FlashcardPhotoService.reset(); // drop the parsed manifest, do not reload
      final dog = SeedData.getByCategory(
        FlashcardCategory.animals,
      ).firstWhere((c) => c.wordEnglish.toLowerCase() == 'dog');
      // No bundled imageAsset on seed cards + no manifest → no photo source,
      // so the TV correctly shows only the emoji.
      expect(dog.imageAsset, anyOf(isNull, isEmpty));
      expect(TvCastAssetBridge.hasPhoto(dog), isFalse);
    });
  });

  // Gate that drives the phone-side "Show Me" button + the TV's `slide.clip`.
  // Mirrors the photo gate but for the action-clip manifest.
  group('TvCastAssetBridge.hasActionClip (manifest-driven)', () {
    setUp(() async {
      ActionClipService.reset();
      await ActionClipService.load();
    });

    tearDown(ActionClipService.reset);

    test('seeded cards with a clip override report an action clip', () {
      final animals = SeedData.getByCategory(FlashcardCategory.animals);
      expect(animals.where(TvCastAssetBridge.hasActionClip), isNotEmpty);

      final dog = animals.firstWhere(
        (c) => c.wordEnglish.toLowerCase() == 'dog',
      );
      expect(TvCastAssetBridge.hasActionClip(dog), isTrue);
      // The shipped manifest hosts dog as a direct Cloudinary .gif, so it is
      // served as an animated image rather than through video_player.
      expect(TvCastAssetBridge.actionClipIsGif(dog), isTrue);
    });

    test('hasActionClip is false once the manifest is reset', () {
      ActionClipService.reset();
      final dog = SeedData.getByCategory(
        FlashcardCategory.animals,
      ).firstWhere((c) => c.wordEnglish.toLowerCase() == 'dog');
      expect(TvCastAssetBridge.hasActionClip(dog), isFalse);
    });
  });
}
