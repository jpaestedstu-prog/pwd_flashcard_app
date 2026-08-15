import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../../data/local/seed_data.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'media_url_resolver.dart';

/// Reports which FSL sign-language videos are available to this build and
/// resolves them to playable [VideoSource]s.
///
/// A card's video can come from three places, checked in order:
///   1. Local bundled asset under `assets/videos/fsl/<Category>/<word>.mp4`.
///   2. A direct download URL registered in `assets/data/fsl_video_manifest.json`
///      as `download_url` (used for the original GitHub-Releases hosting).
///   3. A secondary CDN URL registered in the same manifest as `stream_url`
///      (currently Cloudinary) — passed through [MediaUrlResolver] at first
///      play, then downloaded and cached by [_videoCache]. The cache key is
///      the card key, not the URL, so cached files survive URL rotations and
///      a re-host doesn't invalidate anything already on disk.
///
/// Filenames are matched to flashcards case-insensitively, so files can be
/// `DOG.mp4`, `dog.mp4`, or `Dog.mp4`; the original case is preserved when
/// the path is handed to [VideoPlayerController.asset].
class FslAssetsService {
  FslAssetsService._();

  static const String _manifestAsset = 'assets/data/fsl_video_manifest.json';
  static const String _fslAssetPrefix = 'assets/videos/fsl/';

  /// Filename-stem aliases for cards whose video file is named differently
  /// from the seed `wordEnglish`. Keyed by `[Category label]__[wordEnglish
  /// lowercased]`; the value is the lowercased file stem (no extension) the
  /// matcher should look for instead.
  ///
  /// Add an entry here whenever a category gets a video whose filename can't
  /// be derived directly from the flashcard's English word — typically:
  /// singular/plural mismatches, digits used in place of number words, or
  /// disambiguating prefixes (e.g. `food - chicken` so it doesn't collide
  /// with the Animals video of the same name).
  static const Map<String, String> _filenameAliases = {
    // Body Parts: seed plural → file singular
    'Body Parts__eyes': 'eye',
    'Body Parts__ears': 'ear',
    'Body Parts__hands': 'hand',
    'Body Parts__fingers': 'finger',
    'Body Parts__knees': 'knee',

    // Clothing: synonym
    'Clothing__glasses': 'eyeglasses',

    // Emotions: verb/adjective forms used in the file names
    'Emotions__loved': 'love',
    'Emotions__scared': 'scary',
    'Emotions__sleepy': 'sleep',
    'Emotions__surprised': 'surprise',

    // Food & Drinks: prefixed to avoid collision with Animals/chicken
    'Food & Drinks__chicken': 'food - chicken',

    // Numbers: word → digit
    'Numbers__one': '1',
    'Numbers__two': '2',
    'Numbers__three': '3',
    'Numbers__four': '4',
    'Numbers__five': '5',
    'Numbers__six': '6',
    'Numbers__seven': '7',
    'Numbers__eight': '8',
    'Numbers__nine': '9',
    'Numbers__ten': '10',
    'Numbers__twenty': '20',
    'Numbers__hundred': '100',

    // Weather: closely related forms
    'Weather__rainy': 'rain',
    'Weather__storm': 'storms',
  };

  /// Card keys that should reuse **another card's** clip, keyed
  /// `[Category label]__[wordEnglish lowercased]` → the manifest key to borrow.
  ///
  /// Different from [_filenameAliases], which only redirects the *filename* of
  /// a bundled asset within the same category. This maps across categories, for
  /// the case where two seed cards are the same word and therefore the same
  /// sign — re-shooting it would produce an identical video.
  ///
  /// Only add a pair when the sign is genuinely identical. A word that merely
  /// looks related (`open` the verb vs `open` the adjective) can be a different
  /// sign entirely, and pointing a learner at the wrong one is worse than
  /// telling them it hasn't been recorded yet.
  static const Map<String, String> _crossCategoryAliases = {
    // "Walk" is one sign; it exists as a Transportation card (a way to get
    // somewhere) and an Actions verb. Same hands, same clip.
    'Actions__walk': 'Transportation__walk',
  };

  static Future<FslAvailability>? _cache;

  /// Card key → resolved bundled asset path (case-preserved).
  static final Map<String, String> _assetPathByKey = {};

  /// Card key → optional direct download URL for cloud fallback.
  static final Map<String, String> _downloadUrlByKey = {};

  /// Card key → optional secondary CDN URL (resolved at runtime).
  static final Map<String, String> _streamUrlByKey = {};

  /// Cache manager dedicated to FSL videos. Separate key namespace from any
  /// other CacheManager use in the app, longer max-age (videos never change
  /// once published), and a generous object count cap.
  static final BaseCacheManager _videoCache = CacheManager(
    Config(
      'fsl_videos_cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Returns the cached availability snapshot. First call parses the asset
  /// manifest (and the optional cloud manifest); subsequent calls reuse the
  /// same Future.
  static Future<FslAvailability> load() {
    return _cache ??= _resolve();
  }

  /// Drops the in-memory snapshot so the next [load] re-reads the manifest.
  /// Used by tests; useful in production after a hot-reload.
  static void reset() {
    _cache = null;
    _assetPathByKey.clear();
    _downloadUrlByKey.clear();
    _streamUrlByKey.clear();
  }

  static Future<FslAvailability> _resolve() async {
    _assetPathByKey.clear();
    _downloadUrlByKey.clear();
    _streamUrlByKey.clear();

    // 1. Discover locally bundled videos from the asset manifest.
    final assetPaths = await _scanBundledAssets();

    // 2. Build category → filename-stem map from the asset paths.
    //    e.g. "assets/videos/fsl/Animals/DOG.mp4" → ("Animals", "dog")
    final localByCategoryStem = <String, String>{};
    for (final path in assetPaths) {
      final parts = path.substring(_fslAssetPrefix.length).split('/');
      if (parts.length != 2) continue;
      final category = parts[0];
      final fileName = parts[1];
      if (!fileName.toLowerCase().endsWith('.mp4')) continue;
      final stem = fileName
          .substring(0, fileName.length - 4)
          .toLowerCase()
          .trim();
      localByCategoryStem['${category}__$stem'] = path;
    }

    // 3. Match each flashcard against the bundled assets, case-insensitively.
    //    For cards whose filename doesn't follow the default pattern
    //    (`<wordEnglish>.mp4`), [_filenameAliases] redirects to the actual
    //    stem on disk.
    for (final card in SeedData.allFlashcards) {
      final key = _keyFor(card);
      final aliasStem = _filenameAliases[key];
      final lookupKey = aliasStem != null
          ? '${card.category.label}__$aliasStem'
          : key;
      final path = localByCategoryStem[lookupKey];
      if (path != null) {
        _assetPathByKey[key] = path;
      }
    }

    // 4. Pull optional cloud URLs (direct downloads and the secondary CDN)
    //    from the cloud manifest. These are used when a card has no local
    //    asset — gives the app a graceful path for cloud-hosted videos.
    await _loadCloudFallbackUrls();

    // 5. Let a card borrow an identical sign from another category.
    _applyCrossCategoryAliases();

    return _buildAvailability();
  }

  /// Copies a lender's sources onto the borrower's key, so every downstream
  /// lookup — availability, resolve, prefetch, the offline packs scan — treats
  /// the borrowed clip as the borrower's own with no special-casing.
  ///
  /// A card that has a clip of its own always wins; this only fills holes. The
  /// disk cache still keys by card, so a borrowed sign is stored once per card
  /// rather than shared — a few MB of duplication, in exchange for eviction and
  /// byte accounting that stay per-card and obvious.
  static void _applyCrossCategoryAliases() {
    _crossCategoryAliases.forEach((borrower, lender) {
      final alreadyHasOwn =
          _assetPathByKey.containsKey(borrower) ||
          _downloadUrlByKey.containsKey(borrower) ||
          _streamUrlByKey.containsKey(borrower);
      if (alreadyHasOwn) return;

      final asset = _assetPathByKey[lender];
      if (asset != null) _assetPathByKey[borrower] = asset;
      final direct = _downloadUrlByKey[lender];
      if (direct != null) _downloadUrlByKey[borrower] = direct;
      final stream = _streamUrlByKey[lender];
      if (stream != null) _streamUrlByKey[borrower] = stream;
    });
  }

  /// Returns all `.mp4` paths bundled under `assets/videos/fsl/`.
  static Future<List<String>> _scanBundledAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest
          .listAssets()
          .where(
            (p) =>
                p.startsWith(_fslAssetPrefix) &&
                p.toLowerCase().endsWith('.mp4'),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Best-effort parse of the cloud manifest. Failures are non-fatal —
  /// callers just won't have a download URL for cloud-only cards.
  static Future<void> _loadCloudFallbackUrls() async {
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      final decoded = json.decode(raw);
      final entries = decoded is Map<String, dynamic>
          ? (decoded['entries'] as List?) ?? const []
          : decoded is List
          ? decoded
          : const [];
      for (final e in entries) {
        if (e is! Map) continue;
        final category = (e['category'] as String?) ?? '';
        final slug = (e['slug'] as String?) ?? '';
        final key = '${category}__$slug';
        final directUrl = (e['download_url'] as String?) ?? '';
        if (directUrl.isNotEmpty) _downloadUrlByKey[key] = directUrl;
        final streamUrl = (e['stream_url'] as String?) ?? '';
        if (streamUrl.isNotEmpty) _streamUrlByKey[key] = streamUrl;
      }
    } catch (_) {
      // No manifest yet (first run, asset missing) — degrade gracefully.
    }
  }

  static FslAvailability _buildAvailability() {
    final cards = <Flashcard>[];
    final perCategory = <FlashcardCategory, int>{};
    for (final card in SeedData.allFlashcards) {
      final key = _keyFor(card);
      final available =
          _assetPathByKey.containsKey(key) ||
          _downloadUrlByKey.containsKey(key) ||
          _streamUrlByKey.containsKey(key);
      if (available) {
        cards.add(card);
        perCategory.update(card.category, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return FslAvailability(
      cardsWithVideo: List.unmodifiable(cards),
      videoCountByCategory: Map.unmodifiable(perCategory),
    );
  }

  /// Stable lookup key — `<Category label>__<wordEnglish lowercased>`.
  ///
  /// Two seed cards share the slug `chicken` (Animals + Food & Drinks),
  /// so this key MUST include the category to disambiguate.
  static String _keyFor(Flashcard card) =>
      '${card.category.label}__${card.wordEnglish.toLowerCase()}';

  /// Bundled asset path for the card's video, or null if not bundled.
  /// Suitable for [VideoPlayerController.asset]. The original filename case
  /// is preserved (e.g. `assets/videos/fsl/Animals/DOG.mp4`).
  static String? assetPathFor(Flashcard card) => _assetPathByKey[_keyFor(card)];

  /// Public download URL for the card's video, or null if not registered in
  /// the cloud manifest. Used by [cachedFileFor] for cloud-only builds.
  static String? downloadUrlFor(Flashcard card) =>
      _downloadUrlByKey[_keyFor(card)];

  /// Secondary CDN URL for the card's video, or null if not registered.
  static String? streamUrlFor(Flashcard card) => _streamUrlByKey[_keyFor(card)];

  /// True if a video is bundled locally for [card].
  static bool hasVideo(Flashcard card) =>
      _assetPathByKey.containsKey(_keyFor(card));

  /// True if any video source exists for the card — bundled, direct download,
  /// or secondary CDN. Use this to gate UI that triggers an async resolve.
  static bool hasAnyVideoSource(Flashcard card) {
    final key = _keyFor(card);
    return _assetPathByKey.containsKey(key) ||
        _downloadUrlByKey.containsKey(key) ||
        _streamUrlByKey.containsKey(key);
  }

  /// Resolves the card's video to a playable [VideoSource], or null if no
  /// source is available. Local bundled assets take precedence over cloud
  /// sources; `download_url` takes precedence over `stream_url`.
  ///
  /// May perform a download (via [_videoCache]) on first play. Subsequent
  /// calls for the same card hit the disk cache and return immediately.
  static Future<VideoSource?> videoSourceFor(Flashcard card) async {
    final localPath = assetPathFor(card);
    if (localPath != null) return _AssetVideoSource(localPath);

    final file = await cachedVideoFile(card);
    return file != null ? _FileVideoSource(file) : null;
  }

  /// Resolves an arbitrary FSL clip URL (e.g. a Story clip) to a playable
  /// [VideoSource], downloading and caching it on first play.
  ///
  /// Unlike [videoSourceFor], this is not tied to a seed [Flashcard] — it backs
  /// the Stories feature, whose sentence / question / option sign-language
  /// clips are not flashcards. [cacheKey] must be stable and unique per clip so
  /// the on-disk cache survives a re-host and is reused across
  /// sessions (offline replay). Shares the same [_videoCache] namespace as the
  /// flashcard videos; the distinct key prefix keeps the two from colliding.
  ///
  /// Returns null when [pageUrl] is blank, can't be resolved to a direct file,
  /// or the download fails — callers should degrade gracefully (e.g. a
  /// "video unavailable" message) rather than crash.
  static Future<VideoSource?> videoSourceForUrl(
    String pageUrl, {
    required String cacheKey,
  }) async {
    if (pageUrl.trim().isEmpty) return null;

    // Cache hit short-circuits all network work — instant, offline-safe replay
    // and immunity to a source URL being rotated or re-hosted.
    try {
      final cached = await _videoCache.getFileFromCache(cacheKey);
      if (cached != null) return _FileVideoSource(cached.file);
    } catch (_) {
      // ignore and fall through to a fresh resolve/download
    }

    final direct = await MediaUrlResolver.resolve(pageUrl);
    if (direct == null || direct.isEmpty) return null;
    try {
      final file = await _videoCache.getSingleFile(direct, key: cacheKey);
      return _FileVideoSource(file);
    } catch (_) {
      return null;
    }
  }

  /// Resolves an arbitrary FSL clip URL (e.g. a Story clip) to an on-device
  /// cached [File], downloading and caching it on first call.
  ///
  /// The file-returning counterpart of [videoSourceForUrl]: it always yields a
  /// real file on disk, so the TV Cast server can stream it off disk with Range
  /// support (the same model as [cachedVideoFile] for flashcards). [cacheKey]
  /// must be stable and unique per clip and is shared with [videoSourceForUrl]
  /// (and the in-app Story player) so the cast and the in-app reader reuse the
  /// exact same cached file. Returns null when [pageUrl] is blank, can't be
  /// resolved to a direct file, or the download fails.
  static Future<File?> cachedVideoFileForUrl(
    String pageUrl, {
    required String cacheKey,
  }) async {
    if (pageUrl.trim().isEmpty) return null;

    // Cache hit short-circuits all network work — instant, offline-safe replay
    // and immunity to a source URL being rotated or re-hosted.
    try {
      final cached = await _videoCache.getFileFromCache(cacheKey);
      if (cached != null) return cached.file;
    } catch (_) {
      // ignore and fall through to a fresh resolve/download
    }

    final direct = await MediaUrlResolver.resolve(pageUrl);
    if (direct == null || direct.isEmpty) return null;
    try {
      return await _videoCache.getSingleFile(direct, key: cacheKey);
    } catch (_) {
      return null;
    }
  }

  /// True if the clip behind [cacheKey] is already present in the on-device disk
  /// cache (no network needed to play it). Backs the cast UI's per-page FSL
  /// readiness badge for Stories, the URL-keyed analogue of [isCached].
  static Future<bool> isUrlCached(String cacheKey) async {
    try {
      final cached = await _videoCache.getFileFromCache(cacheKey);
      return cached != null;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort warm-up for a share-page FSL clip — kicks off a download so the
  /// next play is instant. Safe to call without awaiting; failures are
  /// swallowed and an already-cached clip is a no-op. The URL-keyed analogue of
  /// [prefetch], used by the cast notifier to prime Story sign-language clips.
  static Future<void> prefetchUrl(
    String pageUrl, {
    required String cacheKey,
  }) async {
    if (pageUrl.trim().isEmpty) return;
    try {
      final cached = await _videoCache.getFileFromCache(cacheKey);
      if (cached != null) return;
    } catch (_) {}
    try {
      final direct = await MediaUrlResolver.resolve(pageUrl);
      if (direct == null || direct.isEmpty) return;
      await _videoCache.downloadFile(direct, key: cacheKey);
    } catch (_) {}
  }

  /// Resolves the card's video to an on-device cached [File], downloading
  /// and caching it from the cloud manifest on first call. Returns null if
  /// no cloud source is registered or all sources fail.
  ///
  /// Unlike [videoSourceFor] this always yields a real file on disk, so the
  /// TV Cast server can stream it off disk with Range support. Bundled assets
  /// (if ever added) are served separately from the asset bundle and are not
  /// handled here — see [assetPathFor].
  ///
  /// Resolution order: in-memory disk cache → direct `download_url` →
  /// `stream_url`. The cache key is the card key (not the URL), so cached
  /// files survive a re-host of either source.
  static Future<File?> cachedVideoFile(Flashcard card) async {
    final key = _keyFor(card);

    // Cache hit short-circuits any cloud work — important for offline play
    // and to avoid re-resolving URLs that may have rotated.
    try {
      final cached = await _videoCache.getFileFromCache(key);
      if (cached != null) return cached.file;
    } catch (_) {
      // ignore and fall through to a fresh download
    }

    final directUrl = downloadUrlFor(card);
    if (directUrl != null) {
      try {
        return await _videoCache.getSingleFile(directUrl, key: key);
      } catch (_) {
        // fall through to the secondary CDN
      }
    }

    final streamUrl = streamUrlFor(card);
    if (streamUrl != null) {
      try {
        final resolved = await MediaUrlResolver.resolve(streamUrl);
        if (resolved != null && resolved.isNotEmpty) {
          return await _videoCache.getSingleFile(resolved, key: key);
        }
      } catch (_) {
        // give up
      }
    }

    return null;
  }

  /// True if the card's video is already present in the on-device disk cache
  /// (no network needed to play it). Bundled assets are always "cached" in
  /// this sense. Used by the TV Cast phone UI to show a per-word readiness
  /// badge without triggering a download.
  static Future<bool> isCached(Flashcard card) async {
    if (hasVideo(card)) return true;
    try {
      final cached = await _videoCache.getFileFromCache(_keyFor(card));
      return cached != null;
    } catch (_) {
      return false;
    }
  }

  /// Bytes [card]'s clip occupies on disk, or 0 when it isn't downloaded.
  ///
  /// Backs the offline sign packs UI, which has to answer "how much of this
  /// tablet am I about to spend?" before a teacher commits to a download, and
  /// "how much would I get back?" before they clear one. Bundled assets report
  /// 0: they ship inside the APK and freeing them is not on offer.
  static Future<int> cachedBytes(Flashcard card) async {
    if (hasVideo(card)) return 0;
    try {
      final cached = await _videoCache.getFileFromCache(_keyFor(card));
      if (cached == null) return 0;
      return await cached.file.length();
    } catch (_) {
      return 0;
    }
  }

  /// Drops [card]'s downloaded clip from the disk cache. No-op when the clip
  /// is bundled or was never downloaded; the word keeps working, it just needs
  /// the network again on next play.
  static Future<void> evict(Flashcard card) async {
    if (hasVideo(card)) return;
    try {
      await _videoCache.removeFile(_keyFor(card));
    } catch (_) {
      // Already gone, or the cache is mid-write — either way there is nothing
      // for the caller to do about it.
    }
  }

  /// Resolves the card's video to a cached on-device file via the cloud
  /// fallback. Kept for backward compatibility with callers that need a
  /// `File` directly — new code should prefer [videoSourceFor].
  ///
  /// Throws [StateError] if no download URL is registered for the card.
  static Future<File> cachedFileFor(Flashcard card) async {
    final url = downloadUrlFor(card);
    if (url == null) {
      throw StateError(
        'No FSL download URL registered for "${card.wordEnglish}" '
        '(category: ${card.category.label}).',
      );
    }
    return _videoCache.getSingleFile(url, key: _keyFor(card));
  }

  /// Best-effort warm-up — kicks off a download so the next play is instant.
  /// Safe to call without awaiting; network failures are swallowed. No-op
  /// when the video is already bundled locally.
  static Future<void> prefetch(Flashcard card) async {
    if (hasVideo(card)) return;
    final key = _keyFor(card);

    // Skip if already cached.
    try {
      final cached = await _videoCache.getFileFromCache(key);
      if (cached != null) return;
    } catch (_) {}

    final directUrl = downloadUrlFor(card);
    if (directUrl != null) {
      try {
        await _videoCache.downloadFile(directUrl, key: key);
        return;
      } catch (_) {}
    }

    final streamUrl = streamUrlFor(card);
    if (streamUrl != null) {
      try {
        final resolved = await MediaUrlResolver.resolve(streamUrl);
        if (resolved != null && resolved.isNotEmpty) {
          await _videoCache.downloadFile(resolved, key: key);
        }
      } catch (_) {}
    }
  }
}

/// A playable handle to an FSL video. Hides whether the video came from a
/// bundled asset or a downloaded file so callers can construct a controller
/// uniformly.
abstract class VideoSource {
  /// Builds a fresh [VideoPlayerController] for this source. Caller owns
  /// the lifecycle (init / play / dispose).
  VideoPlayerController createController();
}

class _AssetVideoSource implements VideoSource {
  final String assetPath;
  const _AssetVideoSource(this.assetPath);
  @override
  VideoPlayerController createController() =>
      VideoPlayerController.asset(assetPath);
}

class _FileVideoSource implements VideoSource {
  final File file;
  const _FileVideoSource(this.file);
  @override
  VideoPlayerController createController() => VideoPlayerController.file(file);
}

/// Snapshot of which FSL videos are available right now.
///
/// Held by `fslAvailabilityProvider` and consumed by FSL screens / games
/// to drive category pickers, empty states, and the practice-mode gate.
class FslAvailability {
  /// Flashcards from [SeedData] that have an available video source —
  /// bundled locally, a direct download URL, or a secondary CDN URL.
  final List<Flashcard> cardsWithVideo;

  /// How many videos each category currently has available.
  final Map<FlashcardCategory, int> videoCountByCategory;

  const FslAvailability({
    required this.cardsWithVideo,
    required this.videoCountByCategory,
  });

  /// True if at least one category has any videos.
  bool get hasAnyVideos => cardsWithVideo.isNotEmpty;

  /// Categories that have at least [min] videos — usable by the FSL games
  /// without bouncing the user to an empty state.
  Set<FlashcardCategory> playableCategories({int min = 2}) {
    return videoCountByCategory.entries
        .where((e) => e.value >= min)
        .map((e) => e.key)
        .toSet();
  }

  /// Whether [card] has a matching video source.
  bool hasVideo(Flashcard card) => FslAssetsService.hasAnyVideoSource(card);
}
