import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/services/action_clip_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/story_image_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Resolves cast assets (TV-side static files, FSL videos, etc.) from
/// the Flutter rootBundle into raw bytes the shelf HTTP server can stream.
class TvCastAssetBridge {
  TvCastAssetBridge._();

  /// Read a bundled asset as raw bytes. Returns null if the asset is missing.
  static Future<Uint8List?> loadAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Read a bundled text asset as UTF-8 string. Returns null if missing.
  static Future<String?> loadAssetString(String assetPath) async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return null;
    }
  }

  /// Looks up a flashcard by category index and English-word slug.
  /// Slug matching is case-insensitive and ignores non-alphanumerics, so
  /// `family-greetings` / `family_greetings` / `Family%20Greetings` all
  /// resolve identically.
  static Flashcard? findFlashcard(int categoryIndex, String wordSlug) {
    if (categoryIndex < 0 || categoryIndex >= FlashcardCategory.values.length) {
      return null;
    }
    final cat = FlashcardCategory.values[categoryIndex];
    final wantedSlug = _slugify(wordSlug);
    for (final card in SeedData.getByCategory(cat)) {
      if (_slugify(card.wordEnglish) == wantedSlug) return card;
    }
    return null;
  }

  /// Bundled FSL video asset path for [card], or null if not bundled.
  /// Only used for the (currently empty) bundled-asset path; cloud-hosted
  /// videos are served from the on-device cache via [fslVideoFileFor].
  static String? fslAssetPathFor(Flashcard card) {
    return FslAssetsService.assetPathFor(card);
  }

  /// On-device cached file for the card's FSL video, downloading it from the
  /// cloud manifest (GitHub Releases / Cloudinary) on first request and
  /// caching it thereafter. Null if no source is registered or it fails.
  /// The TV Cast server streams this file off disk (with Range support).
  static Future<File?> fslVideoFileFor(Flashcard card) =>
      FslAssetsService.cachedVideoFile(card);

  /// True if any video source — bundled, direct download, or secondary CDN —
  /// exists for [card]. Used to gate the cast `/api/video/...` URL even
  /// before the clip has been downloaded.
  static bool hasFslVideo(Flashcard card) =>
      FslAssetsService.hasAnyVideoSource(card);

  // ─── Real photographs / GIFs (mirrors the in-app "Cards" section) ───
  // The in-app flashcard can show a real photo (or animated GIF) instead of
  // the emoji — bundled with the card (`imageAsset`) or downloaded on demand
  // from the photo manifest ([FlashcardPhotoService]). These let the TV paint
  // the same image so it matches what Student / Child profiles see in-app.

  /// True if a real photo/GIF source exists for [card] — a bundled image asset
  /// or a manifest-configured (downloadable) photograph. Gates the cast
  /// `/api/image/...` URL so the TV only attempts a photo when one exists.
  static bool hasPhoto(Flashcard card) =>
      (card.imageAsset != null && card.imageAsset!.isNotEmpty) ||
      FlashcardPhotoService.hasPhoto(card);

  /// Bundled image-asset path for [card] (custom cards bundle their picture),
  /// or null. The shelf server reads its bytes straight from the asset bundle.
  static String? photoAssetPathFor(Flashcard card) =>
      (card.imageAsset != null && card.imageAsset!.isNotEmpty)
      ? card.imageAsset
      : null;

  /// On-device cached file for [card]'s manifest photo/GIF, downloading it from
  /// the host on first request and caching it thereafter (same host-and-download
  /// model as FSL videos). Null if no manifest source is registered or it fails.
  /// The TV Cast server streams the bytes off this file.
  static Future<File?> photoFileFor(Flashcard card) =>
      FlashcardPhotoService.photoFile(card);

  /// True if [card] has an illustrated face. The TV uses it as the front of the
  /// flip card, mirroring the in-app cartoon ⇄ real-life tap-to-flip.
  static bool hasCartoon(Flashcard card) =>
      FlashcardPhotoService.cartoonUrlFor(card) != null;

  /// On-device cached file for [card]'s cartoon face, downloading it on first
  /// request. Null when the card has none or the fetch fails.
  static Future<File?> cartoonFileFor(Flashcard card) =>
      FlashcardPhotoService.cartoonFile(card);

  // ─── "Show Me" action clips (mirrors the in-app "Show Me" button) ───
  // A short looping clip of the word in motion — MP4 (video) or animated GIF —
  // resolved from the action-clip manifest ([ActionClipService]). The in-app
  // viewer surfaces these via the "Show Me" button; the TV plays them when the
  // teacher taps "Show Me" on the cast screen.

  /// True if a "Show Me" action-clip source exists for [card].
  static bool hasActionClip(Flashcard card) => ActionClipService.hasClip(card);

  /// True if [card]'s action clip is an animated GIF (served as `image/gif`,
  /// rendered as a looping `<img>`) rather than a video container (served as
  /// `video/mp4`, rendered with a `<video>`). Resolved synchronously from the
  /// authored URL so the server can pick the content type without downloading.
  static bool actionClipIsGif(Flashcard card) =>
      ActionClipService.isGifFor(card);

  /// On-device cached file for [card]'s action clip, downloading + caching it
  /// (resolving a share-page URL if one was authored) on first request. Null when no
  /// clip source is registered or the fetch fails. The TV Cast server streams
  /// MP4s off this file (with Range) and serves GIF bytes whole.
  static Future<File?> actionClipFileFor(Flashcard card) async {
    final clip = await ActionClipService.resolveClip(card);
    return clip?.file;
  }

  /// Best-effort image MIME type for [bytes] (falling back to [path]'s
  /// extension, then a generic JPEG). Sniffing the magic bytes is what makes
  /// GIFs work: the on-device cache stores files under hashed keys with no
  /// extension, and a GIF MUST be served as `image/gif` to animate in the TV
  /// browser's `<img>` / CSS background. PNG / JPEG / WebP are detected too so
  /// the right type is always sent.
  static String imageContentType(List<int> bytes, [String path = '']) {
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif'; // "GIF" (GIF87a / GIF89a)
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png'; // \x89PNG
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg'; // \xFF\xD8\xFF
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 && // "RIFF"
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp'; // "WEBP"
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  /// Emoji representation of a card — what the TV renders when there's
  /// no bundled image (the project uses emojis as the per-card visual).
  static String emojiFor(Flashcard card) => FlashcardEmojis.forId(card.id);

  /// Visual descriptor for a flashcard's category, so the TV can paint a card
  /// that mirrors the in-app flashcard (the accent strip, category badge, and
  /// tinted picture tile from the "Cards" section). The category's Material
  /// icon can't render in a TV browser, so it becomes an emoji stand-in; the
  /// pastel + deep colours mirror `category.color` / `category.darkColor`.
  /// Returned as plain strings the shelf server can drop straight into JSON.
  static Map<String, String> categoryVisual(FlashcardCategory cat) => {
    'catLabel': cat.label,
    'catEmoji': _categoryEmoji(cat),
    'catColor': _hexColor(cat.color),
    'catColorDark': _hexColor(cat.darkColor),
  };

  /// Emoji stand-in for each category's Material icon (see [categoryVisual]).
  static String _categoryEmoji(FlashcardCategory cat) => switch (cat) {
    FlashcardCategory.animals => '🐾',
    FlashcardCategory.colorsAndShapes => '🎨',
    FlashcardCategory.numbers => '🔢',
    FlashcardCategory.bodyParts => '🧍',
    FlashcardCategory.foodAndDrinks => '🍎',
    FlashcardCategory.familyAndGreetings => '👋',
    FlashcardCategory.clothing => '👕',
    FlashcardCategory.weather => '☀️',
    FlashcardCategory.classroom => '🏫',
    FlashcardCategory.transportation => '🚌',
    FlashcardCategory.emotions => '😊',
    FlashcardCategory.daysAndTime => '📅',
    FlashcardCategory.actions => '🏃',
  };

  /// `#RRGGBB` for a [Color]. The TV CSS avoids `var()` for old browsers, so
  /// dynamic category colours are applied inline by app.js from these strings.
  static String _hexColor(Color c) {
    String two(double channel) =>
        (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}';
  }

  /// All stories grouped by category. Used by the cast screen's story
  /// picker so the teacher can choose what to cast.
  static List<Story> storiesByCategory(FlashcardCategory category) =>
      SeedStories.getByCategory(category);

  /// Story by ID, or null if not found.
  static Story? findStory(String id) {
    for (final s in SeedStories.all) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ─── Story FSL sign-language clips (mirrors the in-app "Watch in FSL") ───
  // Each story page can carry a Filipino Sign Language clip as a share-page URL
  // (`Story.sentenceFslUrls`). The in-app reader plays it via the "Watch in FSL"
  // button; the TV plays it when the teacher taps "Watch in FSL" on the cast
  // screen. These mirror the flashcard FSL helpers above for the Stories mode.

  /// Stable, unique on-disk cache key for a story page's FSL clip. MUST match
  /// the key the in-app Story reader uses (`story_<id>_s<page>`) so the cast and
  /// the reader reuse the exact same cached file and replay offline.
  static String storyFslCacheKey(String storyId, int pageIndex) =>
      'story_${storyId}_s$pageIndex';

  /// FSL sign-language clip share-page URL for [story]'s page [pageIndex], or
  /// null when that page has no clip. Bounds-checked via [Story.fslForSentence].
  static String? storyFslUrl(Story story, int pageIndex) {
    final url = story.fslForSentence(pageIndex);
    return (url != null && url.isNotEmpty) ? url : null;
  }

  /// On-device cached file for a story page's FSL clip, resolving its share-page
  /// URL and downloading + caching it on first request. Null
  /// when [pageUrl] is blank, can't be resolved, or the fetch fails. The TV Cast
  /// server streams this file off disk (with Range support).
  static Future<File?> storyFslVideoFile(String pageUrl, String cacheKey) =>
      FslAssetsService.cachedVideoFileForUrl(pageUrl, cacheKey: cacheKey);

  // ─── Story cartoon ⇄ real-life flip pictures (mirrors the in-app reader) ──
  // Each story page can carry a cartoon + real-life picture pair
  // (`Story.sentenceImages`). The in-app reader shows them as a tap-to-flip
  // illustration; the TV shows the same pair (cartoon front, real back), with
  // the flip driven by the phone's "Tap to Flip Animation" button. These mirror
  // the flashcard photo helpers above, for the Stories mode.

  /// Cartoon ⇄ real-life picture pair for [story]'s page [pageIndex], or null
  /// when that page has no picture. Bounds-checked via [Story.imageForSentence].
  /// Gates the cast `story.image` block + the `/api/story-image/...` URLs so the
  /// TV only drops the emoji when a real picture pair exists.
  static StoryImagePair? storyImagePair(Story story, int pageIndex) =>
      story.imageForSentence(pageIndex);

  /// Stable, unique on-disk cache key for a story page's cartoon / real picture.
  /// MUST match the key the in-app reader's `StoryImageFlip` uses
  /// (`<storyId>_page<page>_cartoon` / `_real`) so the cast and the reader reuse
  /// the exact same cached file and display offline.
  static String storyImageCacheKey(
    String storyId,
    int pageIndex, {
    required bool real,
  }) => '${storyId}_page${pageIndex}_${real ? 'real' : 'cartoon'}';

  /// On-device cached file for a story picture, resolving its share-page URL
  /// (e.g. `postimg.cc`) and downloading + caching it on first request. Null when
  /// [pageUrl] is blank, can't be resolved, or the fetch fails. The TV Cast
  /// server reads this file's bytes; the in-app reader shares the same cache.
  static Future<File?> storyImageFile(String pageUrl, String cacheKey) =>
      StoryImageService.imageFile(pageUrl, cacheKey: cacheKey);

  static String _slugify(String input) {
    final buf = StringBuffer();
    for (final ch in input.toLowerCase().codeUnits) {
      // a-z, 0-9 — everything else dropped.
      if ((ch >= 0x61 && ch <= 0x7a) || (ch >= 0x30 && ch <= 0x39)) {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }
}
