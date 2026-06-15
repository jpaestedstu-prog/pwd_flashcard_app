import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'media_url_resolver.dart';

/// Resolves a real photograph for a flashcard and serves it from an on-device
/// cache, mirroring the "host & download" model already used for FSL videos by
/// [FslAssetsService].
///
/// Photos are NOT bundled in the APK (keeps it small). Instead a tiny JSON
/// manifest — `assets/data/flashcard_photo_manifest.json` — points at where the
/// images are hosted:
///
/// ```json
/// {
///   "base_url": "https://example.com/flashcard-photos",
///   "ext": "jpg",
///   "overrides": { "Animals__dog": "https://example.com/custom/dog.jpg" }
/// }
/// ```
///
/// The URL for a card is, in order of precedence:
///   1. `overrides["<Category label>__<wordEnglish lowercased>"]`, else
///   2. `<base_url>/<Category label>/<wordEnglish>.<ext>` (path segments are
///      percent-encoded, so `Food & Drinks/Ice Cream.jpg` is handled).
///
/// When `base_url` is empty and no override matches, the card has **no** photo
/// source and callers fall back to the emoji rendering. This means the feature
/// is dormant on a fresh checkout (nothing to download, nothing can break) and
/// "lights up" the moment a real `base_url` is configured.
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

  /// Synchronously returns the cached file if it was already resolved this
  /// session, else null. Lets [FlashcardImage] paint instantly on rebuilds.
  static File? resolvedFile(Flashcard card) => _resolved[_keyFor(card)];

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
  /// downloads + caches it under [cacheKey]. The cache key is stable (card
  /// based), so signed/expiring source URLs don't matter once cached. Never
  /// throws.
  static Future<File?> _download(String url, String cacheKey) async {
    try {
      final cached = await _photoCache.getFileFromCache(cacheKey);
      if (cached != null) return cached.file;
    } catch (_) {
      // fall through to a fresh download
    }

    final direct = await MediaUrlResolver.resolve(url);
    if (direct == null) return null;

    try {
      return await _photoCache.getSingleFile(direct, key: cacheKey);
    } catch (_) {
      return null;
    }
  }
}
