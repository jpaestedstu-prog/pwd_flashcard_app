import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/services/fsl_assets_service.dart';
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
  /// cloud manifest (GitHub Releases / Streamable) on first request and
  /// caching it thereafter. Null if no source is registered or it fails.
  /// The TV Cast server streams this file off disk (with Range support).
  static Future<File?> fslVideoFileFor(Flashcard card) =>
      FslAssetsService.cachedVideoFile(card);

  /// True if any video source — bundled, direct download, or Streamable —
  /// exists for [card]. Used to gate the cast `/api/video/...` URL even
  /// before the clip has been downloaded.
  static bool hasFslVideo(Flashcard card) =>
      FslAssetsService.hasAnyVideoSource(card);

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
