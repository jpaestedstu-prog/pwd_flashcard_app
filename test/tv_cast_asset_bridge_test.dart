import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_asset_bridge.dart';

/// Guards the category-visual fields the redesigned TV flashcard reads. The
/// TV-side `renderFlashcards` in `app.js` paints the accent strip, badge, and
/// picture tile from `catColor` / `catColorDark` (applied inline because the
/// TV CSS avoids `var()`), plus `catLabel` / `catEmoji` — so a missing or
/// malformed field silently breaks the card on every connected TV.
void main() {
  group('TvCastAssetBridge.categoryVisual', () {
    final hex = RegExp(r'^#[0-9a-f]{6}$');

    test('every category yields all four keys', () {
      for (final cat in FlashcardCategory.values) {
        final v = TvCastAssetBridge.categoryVisual(cat);
        expect(v.keys, containsAll(['catLabel', 'catEmoji', 'catColor', 'catColorDark']));
        expect(v['catLabel'], isNotEmpty);
        expect(v['catEmoji'], isNotEmpty);
      }
    });

    test('colours are lowercase #RRGGBB hex', () {
      for (final cat in FlashcardCategory.values) {
        final v = TvCastAssetBridge.categoryVisual(cat);
        expect(v['catColor'], matches(hex), reason: '$cat catColor');
        expect(v['catColorDark'], matches(hex), reason: '$cat catColorDark');
      }
    });

    test('label matches the in-app category label', () {
      expect(
        TvCastAssetBridge.categoryVisual(FlashcardCategory.animals)['catLabel'],
        FlashcardCategory.animals.label,
      );
    });

    test('hex conversion is exact for a known category colour', () {
      // Animals = Color(0xFFFFCC80) pastel, darkColor = Color(0xFFE65100).
      final v = TvCastAssetBridge.categoryVisual(FlashcardCategory.animals);
      expect(v['catColor'], '#ffcc80');
      expect(v['catColorDark'], '#e65100');
    });
  });

  // The TV serves flashcard photos/GIFs from /api/image. The on-device cache
  // stores files under hashed keys with no extension, so the MIME type is
  // sniffed from the bytes — getting this right is what lets GIFs animate in
  // the TV browser. A wrong type would break the photo/GIF flip on every TV.
  group('TvCastAssetBridge.imageContentType', () {
    test('detects GIF from magic bytes (GIF89a / GIF87a)', () {
      // "GIF89a"
      expect(
        TvCastAssetBridge.imageContentType(
          [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
        ),
        'image/gif',
      );
      // "GIF87a"
      expect(
        TvCastAssetBridge.imageContentType(
          [0x47, 0x49, 0x46, 0x38, 0x37, 0x61],
        ),
        'image/gif',
      );
    });

    test('detects PNG from magic bytes', () {
      expect(
        TvCastAssetBridge.imageContentType(
          [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
        ),
        'image/png',
      );
    });

    test('detects JPEG from magic bytes', () {
      expect(
        TvCastAssetBridge.imageContentType([0xff, 0xd8, 0xff, 0xe0]),
        'image/jpeg',
      );
    });

    test('detects WebP from RIFF/WEBP magic bytes', () {
      // "RIFF" .... "WEBP"
      expect(
        TvCastAssetBridge.imageContentType([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size (ignored)
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]),
        'image/webp',
      );
    });

    test('falls back to the file extension when bytes are unknown', () {
      final unknown = [0x00, 0x01, 0x02, 0x03];
      expect(TvCastAssetBridge.imageContentType(unknown, 'cat.gif'), 'image/gif');
      expect(TvCastAssetBridge.imageContentType(unknown, 'dog.png'), 'image/png');
      expect(TvCastAssetBridge.imageContentType(unknown, 'x.JPEG'), 'image/jpeg');
      expect(TvCastAssetBridge.imageContentType(unknown, 'y.webp'), 'image/webp');
    });

    test('defaults to image/jpeg for empty / unrecognised data', () {
      expect(TvCastAssetBridge.imageContentType(const []), 'image/jpeg');
      expect(
        TvCastAssetBridge.imageContentType([0x00, 0x11], 'noext'),
        'image/jpeg',
      );
    });

    test('magic bytes win over a mismatched extension', () {
      // Real GIF bytes but a .jpg name → still served as a GIF so it animates.
      expect(
        TvCastAssetBridge.imageContentType(
          [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
          'mislabeled.jpg',
        ),
        'image/gif',
      );
    });
  });

  // Story sign-language clips: the cast serves a story page's FSL video from
  // /api/story-video keyed by a cache key that MUST match the in-app reader's
  // (`story_<id>_s<page>`) so the cast and the reader reuse one cached file.
  group('TvCastAssetBridge story FSL', () {
    test('storyFslCacheKey uses the in-app story_<id>_s<page> convention', () {
      expect(TvCastAssetBridge.storyFslCacheKey('s_a01', 0), 'story_s_a01_s0');
      expect(TvCastAssetBridge.storyFslCacheKey('s_a01', 3), 'story_s_a01_s3');
    });

    test('storyFslUrl returns the page clip when present, null otherwise', () {
      // Find a story whose first page carries an FSL clip — at least one seeded
      // story does (the matcher fails loudly if the data ever loses them all).
      final withFsl = SeedStories.all
          .where((s) => s.fslForSentence(0) != null)
          .toList();
      expect(
        withFsl,
        isNotEmpty,
        reason: 'expected at least one story with a page-0 FSL clip',
      );
      final story = withFsl.first;
      expect(TvCastAssetBridge.storyFslUrl(story, 0), story.fslForSentence(0));
      // Out of range → null (never throws).
      expect(TvCastAssetBridge.storyFslUrl(story, 9999), isNull);
      expect(TvCastAssetBridge.storyFslUrl(story, -1), isNull);
    });

    test('storyFslUrl is null for a story page without a clip', () {
      final withoutFsl = SeedStories.all
          .where((s) => s.fslForSentence(0) == null)
          .toList();
      expect(
        withoutFsl,
        isNotEmpty,
        reason: 'expected at least one story without a page-0 FSL clip',
      );
      expect(TvCastAssetBridge.storyFslUrl(withoutFsl.first, 0), isNull);
    });
  });
}
