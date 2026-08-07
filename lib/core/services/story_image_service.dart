import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'media_cache_key.dart';
import 'media_url_resolver.dart';

/// Resolves a story illustration (a cartoon or a real-life photo) from a
/// *share-page* URL and serves it from an on-device cache.
///
/// This mirrors the "host & download" model already used by
/// [FlashcardPhotoService] (images) and `FslAssetsService` (videos): the seed
/// data only stores friendly share-page links (e.g. `https://postimg.cc/<id>`),
/// which [MediaUrlResolver] turns into a direct, downloadable image URL. The
/// first time a picture is shown it is downloaded and cached on disk; every
/// later view — including fully offline — is served from that cache.
///
/// Powers the Stories → Cartoon ⇄ Real-Life tap-to-flip illustrations. Each
/// face caches under its own [cacheKey] (e.g. `s_a01_page0_cartoon`) combined
/// with a fingerprint of the source URL — see [_diskKey] for why the URL has to
/// be part of it.
class StoryImageService {
  StoryImageService._();

  /// cacheKey → already-resolved on-device file, for synchronous reads so a
  /// rebuild can paint instantly without re-touching the disk cache.
  static final Map<String, File> _resolved = {};

  /// Dedicated cache namespace. Story pictures never change once published, so
  /// a long stale period and a generous object cap are appropriate.
  static final BaseCacheManager _cache = CacheManager(
    Config(
      'story_images_cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Test-only seam. When set, it replaces the real resolve + download so
  /// widget tests can run deterministically without touching the disk cache or
  /// the network (which aren't available under the test binding). Null in
  /// production, so the real path is always used there.
  @visibleForTesting
  static Future<File?> Function(String pageUrl, String cacheKey)?
      debugResolverOverride;

  /// Synchronously returns the cached file if it was already resolved this
  /// session, else null. Lets a flip widget paint immediately on rebuilds.
  static File? resolvedFile(String cacheKey) => _resolved[cacheKey];

  /// Resolves [pageUrl] to an on-device file, downloading + caching it on first
  /// call under [cacheKey]. Returns null when the resolve/fetch fails (the
  /// caller then shows a placeholder). Never throws.
  static Future<File?> imageFile(
    String pageUrl, {
    required String cacheKey,
  }) async {
    final existing = _resolved[cacheKey];
    if (existing != null) return existing;

    final override = debugResolverOverride;
    final file = override != null
        ? await override(pageUrl, cacheKey)
        : await _download(pageUrl, cacheKey);
    if (file != null) _resolved[cacheKey] = file;
    return file;
  }

  /// Resolves a (possibly share-page) [url] to a direct image URL, then
  /// downloads + caches it. Re-requesting the same slot with the same URL hits
  /// the disk cache; a changed URL downloads afresh — see [MediaCacheKey] for
  /// why the URL has to be part of the key. Never throws.
  static Future<File?> _download(String url, String cacheKey) async {
    final diskKey = MediaCacheKey.forUrl(cacheKey, url);
    try {
      final cached = await _cache.getFileFromCache(diskKey);
      if (cached != null) return cached.file;
    } catch (_) {
      // fall through to a fresh download
    }

    final direct = await MediaUrlResolver.resolve(url);
    if (direct == null) return null;

    try {
      return await _cache.getSingleFile(direct, key: diskKey);
    } catch (_) {
      return null;
    }
  }

  /// Clears in-memory resolutions. Used by tests.
  static void reset() => _resolved.clear();
}
