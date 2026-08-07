import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'media_cache_key.dart';
import 'media_url_resolver.dart';

/// Resolves a flashcard's two picture faces — an illustrated "cartoon" and a
/// realistic photograph — and serves them from an on-device cache, mirroring the
/// "host & download" model already used for FSL videos by [FslAssetsService].
///
/// Pictures are NOT bundled in the APK (keeps it small). Instead a tiny JSON
/// manifest — `assets/data/flashcard_photo_manifest.json` — points at where the
/// images are hosted:
///
/// ```json
/// {
///   "base_url": "https://example.com/flashcard-photos",
///   "ext": "png",
///   "cartoons":  { "Animals__dog": "https://example.com/cartoon/dog.png" },
///   "overrides": { "Animals__dog": "https://example.com/real/dog.png" }
/// }
/// ```
///
/// The realistic photo for a card is, in order of precedence:
///   1. `overrides["<Category label>__<wordEnglish lowercased>"]`, else
///   2. `<base_url>/<Category label>/<wordEnglish>.<ext>` (path segments are
///      percent-encoded, so `Food & Drinks/Ice Cream.png` is handled).
///
/// The cartoon face is override-only (`cartoons[...]`). A card carrying both
/// faces supports tap-to-flip ([canFlip]); one with only a photo — Colors &
/// Shapes and Numbers, where the photograph *is* the lesson — renders the photo
/// without a flip.
///
/// When neither face is configured the card has **no** picture source and
/// callers fall back to the emoji rendering. This means the feature is dormant
/// on a fresh checkout (nothing to download, nothing can break) and "lights up"
/// the moment the manifest is populated.
///
/// The first time a photo is shown it is downloaded and cached on disk; every
/// later view (including fully offline) is served from that cache.
class FlashcardPhotoService {
  FlashcardPhotoService._();

  static const String _manifestAsset =
      'assets/data/flashcard_photo_manifest.json';

  static String _baseUrl = '';
  static String _ext = 'jpg';
  static final Map<String, String> _overrides = {};

  /// Card key → illustrated ("cartoon") face. This is the face shown first; the
  /// realistic photo in [_overrides] is revealed by tap-to-flip. Deliberately
  /// override-only: there is no `base_url` pattern for cartoons, so a card
  /// without an entry here is realistic-only and simply doesn't flip.
  static final Map<String, String> _cartoons = {};

  /// Card key → extra example photos (page or direct URLs). Powers the
  /// "Examples" gallery, used to enrich simple cards (colors, numbers) with
  /// several real-world photographs of the same concept.
  static final Map<String, List<String>> _galleries = {};

  /// Card key → already-resolved on-device file, for synchronous reads from
  /// [FlashcardImage] without re-touching the disk cache on every rebuild.
  static final Map<String, File> _resolved = {};

  static Future<void>? _loaded;

  /// Dedicated cache namespace. Photos never change once published, so a long
  /// stale period and a generous object cap are appropriate.
  static final BaseCacheManager _photoCache = CacheManager(
    Config(
      'flashcard_photos_cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 400,
    ),
  );

  /// Test-only seam, mirroring [StoryImageService.debugResolverOverride]. When
  /// set it replaces the real resolve + download, so widget tests can exercise
  /// the two-faced card without touching the disk cache or the network (neither
  /// is available under the test binding, and `flutter_cache_manager` throws
  /// uncatchable `MissingPluginException`s there). Null in production.
  @visibleForTesting
  static Future<File?> Function(String url, String cacheKey)?
      debugResolverOverride;

  /// Parses the manifest once. Safe to call repeatedly (returns the same
  /// Future). Call early in app startup so [hasPhoto] is accurate by first
  /// render; failures are swallowed so a missing/!malformed manifest simply
  /// leaves the feature dormant.
  static Future<void> load() => _loaded ??= _load();

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        _baseUrl = (decoded['base_url'] as String?)?.trim() ?? '';
        final ext = (decoded['ext'] as String?)?.trim();
        if (ext != null && ext.isNotEmpty) _ext = ext.replaceAll('.', '');
        final overrides = decoded['overrides'];
        if (overrides is Map) {
          overrides.forEach((k, v) {
            if (v is String && v.trim().isNotEmpty) {
              _overrides[k.toString()] = v.trim();
            }
          });
        }
        final cartoons = decoded['cartoons'];
        if (cartoons is Map) {
          cartoons.forEach((k, v) {
            if (v is String && v.trim().isNotEmpty) {
              _cartoons[k.toString()] = v.trim();
            }
          });
        }
        final galleries = decoded['galleries'];
        if (galleries is Map) {
          galleries.forEach((k, v) {
            if (v is List) {
              final urls = v
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (urls.isNotEmpty) _galleries[k.toString()] = urls;
            }
          });
        }
      }
    } catch (_) {
      // No manifest / malformed → feature stays dormant (emoji fallback).
    }
  }

  /// Clears parsed manifest + in-memory resolutions. Used by tests.
  static void reset() {
    _loaded = null;
    _baseUrl = '';
    _ext = 'jpg';
    _overrides.clear();
    _cartoons.clear();
    _galleries.clear();
    _resolved.clear();
  }

  /// Stable lookup key — `<Category label>__<wordEnglish lowercased>`, matching
  /// the FSL convention so overrides can be authored consistently.
  static String _keyFor(Flashcard card) =>
      '${card.category.label}__${card.wordEnglish.toLowerCase()}';

  /// The remote URL for [card]'s photo, or null when no source is configured.
  static String? urlFor(Flashcard card) {
    final override = _overrides[_keyFor(card)];
    if (override != null) return override;
    if (_baseUrl.isEmpty) return null;
    final cat = Uri.encodeComponent(card.category.label);
    final word = Uri.encodeComponent(card.wordEnglish);
    return '$_baseUrl/$cat/$word.$_ext';
  }

  /// True if a downloadable photo source exists for [card].
  static bool hasPhoto(Flashcard card) => urlFor(card) != null;

  /// The illustrated ("cartoon") face for [card], or null when it has none.
  /// Colors & Shapes and Numbers are realistic-only by design.
  static String? cartoonUrlFor(Flashcard card) => _cartoons[_keyFor(card)];

  /// True if [card] has an illustrated face as well as a photo — i.e. the card
  /// supports tap-to-flip. A card with only one face never flips.
  static bool canFlip(Flashcard card) =>
      cartoonUrlFor(card) != null && urlFor(card) != null;

  /// Synchronously returns the cached photo if it was already resolved this
  /// session, else null. Lets [FlashcardImage] paint instantly on rebuilds.
  static File? resolvedFile(Flashcard card) => _resolved[_keyFor(card)];

  /// Synchronous counterpart of [resolvedFile] for the cartoon face.
  static File? resolvedCartoon(Flashcard card) =>
      _resolved['${_keyFor(card)}__cartoon'];

  /// Resolves [card]'s cartoon face to an on-device file, downloading + caching
  /// it on first call. Null when the card has no cartoon or the fetch fails.
  /// Never throws.
  static Future<File?> cartoonFile(Flashcard card) async {
    final url = cartoonUrlFor(card);
    if (url == null) return null;
    final key = '${_keyFor(card)}__cartoon';
    final existing = _resolved[key];
    if (existing != null) return existing;

    final file = await _download(url, key);
    if (file != null) _resolved[key] = file;
    return file;
  }

  /// Resolves [card]'s photo to an on-device file, downloading + caching it on
  /// first call. Returns null when there is no source or the fetch fails (the
  /// caller then shows the emoji). Never throws.
  static Future<File?> photoFile(Flashcard card) async {
    final key = _keyFor(card);
    final existing = _resolved[key];
    if (existing != null) return existing;

    final url = urlFor(card);
    if (url == null) return null;

    final file = await _download(url, key);
    if (file != null) _resolved[key] = file;
    return file;
  }

  /// Warms the face that renders first for [card] — the cartoon, or the photo
  /// on realistic-only cards.
  ///
  /// Pictures are fetched on demand, so without this a card shows its emoji for
  /// the first moment it appears. Call it as soon as a screen knows which cards
  /// it will show. Safe to call without awaiting and safe to call repeatedly:
  /// an already-resolved card returns immediately, and failures are swallowed
  /// (the emoji fallback covers them). A no-op when the manifest hasn't been
  /// loaded, which is what keeps it inert in tests.
  static Future<void> prefetch(Flashcard card) async {
    if (cartoonUrlFor(card) != null) {
      await cartoonFile(card);
    } else if (hasPhoto(card)) {
      await photoFile(card);
    }
  }

  /// Warms *both* faces, so a tap-to-flip is instant instead of showing the
  /// loading spinner. Used for the card the viewer is currently showing.
  static Future<void> prefetchBothFaces(Flashcard card) async {
    await prefetch(card);
    if (cartoonUrlFor(card) != null && hasPhoto(card)) await photoFile(card);
  }

  /// Fire-and-forget [prefetch] across a set of cards — e.g. the hand a game
  /// just dealt. Errors are contained per card so one bad URL can't stop the
  /// rest.
  static void prefetchAll(Iterable<Flashcard> cards) {
    for (final card in cards) {
      prefetch(card).catchError((_) {});
    }
  }

  /// Extra example-photo URLs for [card]'s "Examples" gallery (empty if none).
  static List<String> galleryUrls(Flashcard card) =>
      _galleries[_keyFor(card)] ?? const [];

  /// True if [card] has at least one extra example photo to show in a gallery.
  static bool hasGallery(Flashcard card) => galleryUrls(card).isNotEmpty;

  /// Downloads + caches the gallery photo at [index] for [card]. Returns null
  /// when out of range or the fetch fails.
  static Future<File?> galleryFile(Flashcard card, int index) async {
    final urls = galleryUrls(card);
    if (index < 0 || index >= urls.length) return null;
    return _download(urls[index], '${_keyFor(card)}__ex$index');
  }

  /// Resolves a (possibly share-page) [url] to a direct media URL, then
  /// downloads + caches it. The disk key combines [cacheKey] with the source
  /// URL, so re-arting a card supersedes the old picture instead of serving it
  /// forever — see [MediaCacheKey]. Never throws.
  static Future<File?> _download(String url, String cacheKey) async {
    final override = debugResolverOverride;
    if (override != null) return override(url, cacheKey);

    final diskKey = MediaCacheKey.forUrl(cacheKey, url);
    try {
      final cached = await _photoCache.getFileFromCache(diskKey);
      if (cached != null) return cached.file;
    } catch (_) {
      // fall through to a fresh download
    }

    final direct = await MediaUrlResolver.resolve(url);
    if (direct == null) return null;

    try {
      return await _photoCache.getSingleFile(direct, key: diskKey);
    } catch (_) {
      return null;
    }
  }
}
