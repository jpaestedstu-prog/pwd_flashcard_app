import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../../data/local/seed_data.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Reports which FSL sign-language videos are available to this build and
/// resolves them to playable [VideoSource]s.
///
/// A card's video can come from three places, checked in order:
///   1. Local bundled asset under `assets/videos/fsl/<Category>/<word>.mp4`.
///   2. A direct download URL registered in `assets/data/fsl_video_manifest.json`
///      as `download_url` (used for the original GitHub-Releases hosting).
///   3. A Streamable page URL registered in the same manifest as
///      `streamable_url` — resolved at first play via Streamable's public API
///      (`https://api.streamable.com/videos/<id>`) to a signed CDN URL, then
///      downloaded and cached by [_videoCache]. The cache key is the card key,
///      not the URL, so cached files survive Streamable URL rotations.
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

  static Future<FslAvailability>? _cache;

  /// All entries parsed from the cloud manifest, in manifest order. Exposed
  /// via [manifestEntries] for word-level consumers (Speech→Sign interpreter)
  /// that need the full vocabulary rather than a seed [Flashcard].
  static final List<FslManifestEntry> _manifestEntries = [];

  /// Card key → resolved bundled asset path (case-preserved).
  static final Map<String, String> _assetPathByKey = {};

  /// Card key → optional direct download URL for cloud fallback.
  static final Map<String, String> _downloadUrlByKey = {};

  /// Card key → optional Streamable page URL (resolved at runtime).
  static final Map<String, String> _streamableUrlByKey = {};

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
    _manifestEntries.clear();
    _assetPathByKey.clear();
    _downloadUrlByKey.clear();
    _streamableUrlByKey.clear();
  }

  static Future<FslAvailability> _resolve() async {
    _manifestEntries.clear();
    _assetPathByKey.clear();
    _downloadUrlByKey.clear();
    _streamableUrlByKey.clear();

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

    // 4. Pull optional cloud URLs (direct downloads and Streamable pages)
    //    from the cloud manifest. These are used when a card has no local
    //    asset — gives the app a graceful path for cloud-hosted videos.
    await _loadCloudFallbackUrls();

    return _buildAvailability();
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
        final streamableUrl = (e['streamable_url'] as String?) ?? '';
        if (streamableUrl.isNotEmpty) _streamableUrlByKey[key] = streamableUrl;
        if (category.isNotEmpty && slug.isNotEmpty) {
          _manifestEntries.add(FslManifestEntry(
            category: category,
            slug: slug,
            wordEnglish: (e['word_english'] as String?) ?? slug,
            wordFilipino: (e['word_filipino'] as String?) ?? '',
            downloadUrl: directUrl.isNotEmpty ? directUrl : null,
            streamableUrl: streamableUrl.isNotEmpty ? streamableUrl : null,
          ));
        }
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
          _streamableUrlByKey.containsKey(key);
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

  /// Streamable page URL for the card's video, or null if not registered.
  static String? streamableUrlFor(Flashcard card) =>
      _streamableUrlByKey[_keyFor(card)];

  /// True if a video is bundled locally for [card].
  static bool hasVideo(Flashcard card) =>
      _assetPathByKey.containsKey(_keyFor(card));

  // ─── Entry-level API (word-level consumers, e.g. Speech→Sign) ──────

  /// Stable lookup key for a manifest entry — `<category>__<slug>`, matching
  /// what [_loadCloudFallbackUrls] stores in the URL maps. For entries whose
  /// slug equals the lowercased English word this coincides with the
  /// [Flashcard] key, so downloads are shared with flashcard plays.
  static String _entryKey(FslManifestEntry entry) =>
      '${entry.category}__${entry.slug}';

  /// All entries from the cloud manifest, in manifest order. Triggers the
  /// initial manifest parse on first call.
  static Future<List<FslManifestEntry>> manifestEntries() async {
    await load();
    return List.unmodifiable(_manifestEntries);
  }

  /// Resolves a manifest entry to a playable [VideoSource], or null when all
  /// sources fail. Mirrors [videoSourceFor] but keyed by manifest entry
  /// instead of seed [Flashcard].
  static Future<VideoSource?> videoSourceForEntry(FslManifestEntry entry) async {
    final localPath = _assetPathByKey[_entryKey(entry)];
    if (localPath != null) return _AssetVideoSource(localPath);

    final file = await cachedVideoFileForEntry(entry);
    return file != null ? _FileVideoSource(file) : null;
  }

  /// Resolves the entry's video to an on-device cached [File], downloading on
  /// first call. Same resolution chain as [cachedVideoFile]: disk cache →
  /// direct `download_url` → Streamable.
  static Future<File?> cachedVideoFileForEntry(FslManifestEntry entry) async {
    final key = _entryKey(entry);

    try {
      final cached = await _videoCache.getFileFromCache(key);
      if (cached != null) return cached.file;
    } catch (_) {
      // ignore and fall through to a fresh download
    }

    final directUrl = entry.downloadUrl;
    if (directUrl != null) {
      try {
        return await _videoCache.getSingleFile(directUrl, key: key);
      } catch (_) {
        // fall through to Streamable
      }
    }

    final streamableUrl = entry.streamableUrl;
    if (streamableUrl != null) {
      try {
        final resolved = await _resolveStreamableDirectUrl(streamableUrl);
        if (resolved != null) {
          return await _videoCache.getSingleFile(resolved, key: key);
        }
      } catch (_) {
        // give up
      }
    }

    return null;
  }

  /// True if the entry's video can play without network — bundled or already
  /// in the disk cache.
  static Future<bool> isEntryCached(FslManifestEntry entry) async {
    final key = _entryKey(entry);
    if (_assetPathByKey.containsKey(key)) return true;
    try {
      final cached = await _videoCache.getFileFromCache(key);
      return cached != null;
    } catch (_) {
      return false;
    }
  }

  /// True if any video source exists for the card — bundled, direct download,
  /// or Streamable. Use this to gate UI that triggers an async resolve.
  static bool hasAnyVideoSource(Flashcard card) {
    final key = _keyFor(card);
    return _assetPathByKey.containsKey(key) ||
        _downloadUrlByKey.containsKey(key) ||
        _streamableUrlByKey.containsKey(key);
  }

  /// Resolves the card's video to a playable [VideoSource], or null if no
  /// source is available. Local bundled assets take precedence over cloud
  /// sources; direct download URLs take precedence over Streamable.
  ///
  /// May perform an HTTP call (to resolve a Streamable ID) and/or a download
  /// (via [_videoCache]) on first play. Subsequent calls for the same card
  /// hit the disk cache and return immediately.
  static Future<VideoSource?> videoSourceFor(Flashcard card) async {
    final localPath = assetPathFor(card);
    if (localPath != null) return _AssetVideoSource(localPath);

    final file = await cachedVideoFile(card);
    return file != null ? _FileVideoSource(file) : null;
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
  /// Streamable. The cache key is the card key (not the URL), so cached files
  /// survive Streamable URL rotations.
  static Future<File?> cachedVideoFile(Flashcard card) async {
    final key = _keyFor(card);

    // Cache hit short-circuits any cloud work — important for offline play
    // and to avoid re-resolving Streamable URLs that may have rotated.
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
        // fall through to Streamable
      }
    }

    final streamableUrl = streamableUrlFor(card);
    if (streamableUrl != null) {
      try {
        final resolved = await _resolveStreamableDirectUrl(streamableUrl);
        if (resolved != null) {
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

    final streamableUrl = streamableUrlFor(card);
    if (streamableUrl != null) {
      try {
        final resolved = await _resolveStreamableDirectUrl(streamableUrl);
        if (resolved != null) {
          await _videoCache.downloadFile(resolved, key: key);
        }
      } catch (_) {}
    }
  }

  /// Calls Streamable's public API for [streamableUrl] (e.g.
  /// `https://streamable.com/p34d5t`) and returns the direct mp4 CDN URL.
  ///
  /// Returns null on parse failure, missing fields, or HTTP errors. The
  /// returned URL is signed and expires (~24h) — callers should pipe it
  /// through [_videoCache.getSingleFile] keyed by the card so the resolved
  /// content is cached locally and the URL itself doesn't need to be reused.
  static Future<String?> _resolveStreamableDirectUrl(
    String streamableUrl,
  ) async {
    final id = _extractStreamableId(streamableUrl);
    if (id == null) return null;
    final apiUrl = Uri.parse('https://api.streamable.com/videos/$id');
    final client = HttpClient();
    try {
      final req = await client.getUrl(apiUrl);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final data = json.decode(body);
      if (data is! Map<String, dynamic>) return null;
      final files = data['files'];
      if (files is! Map<String, dynamic>) return null;
      final preferred = files['mp4'] ?? files['mp4-mobile'];
      if (preferred is! Map<String, dynamic>) return null;
      final url = preferred['url'];
      if (url is! String || url.isEmpty) return null;
      return url.startsWith('//') ? 'https:$url' : url;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Pulls the short ID out of a Streamable URL like
  /// `https://streamable.com/p34d5t` or `https://streamable.com/e/p34d5t`.
  static String? _extractStreamableId(String url) {
    final match = RegExp(
      r'streamable\.com/(?:e/|s/)?([A-Za-z0-9]+)',
    ).firstMatch(url);
    return match?.group(1);
  }
}

/// One row of `assets/data/fsl_video_manifest.json` — a word with at least
/// one cloud video source. Unlike [Flashcard] this carries the manifest's own
/// bilingual labels, so word-level features (Speech→Sign interpreter) can
/// match and display vocabulary without going through [SeedData].
class FslManifestEntry {
  final String category;
  final String slug;
  final String wordEnglish;
  final String wordFilipino;
  final String? downloadUrl;
  final String? streamableUrl;

  const FslManifestEntry({
    required this.category,
    required this.slug,
    required this.wordEnglish,
    required this.wordFilipino,
    this.downloadUrl,
    this.streamableUrl,
  });
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
  /// bundled locally, a direct download URL, or a Streamable URL.
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
