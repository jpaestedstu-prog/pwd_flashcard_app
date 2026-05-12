import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/local/seed_data.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Reports which FSL sign-language videos are available, and resolves them
/// to cached on-device files for playback.
///
/// Videos are hosted on **GitHub Releases** (free, no billing, no quotas),
/// with the URLs listed in a bundled JSON manifest at
/// `assets/data/fsl_video_manifest.json`. The manifest is regenerated
/// every time `tools/publish_fsl_videos.mjs` uploads a new release.
///
/// At runtime:
///   1. The bundled manifest is parsed once on first call.
///   2. Video files are downloaded on demand via `flutter_cache_manager`
///      and served from disk on every subsequent play (offline-safe).
///
/// Class name kept as [FslAssetsService] for backward-compatibility with
/// existing callers; conceptually this is the FSL video catalog.
class FslAssetsService {
  FslAssetsService._();

  static const String _manifestAsset = 'assets/data/fsl_video_manifest.json';

  static Future<FslAvailability>? _cache;
  static final Map<String, _FslVideoMeta> _byKey = {};

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

  /// Returns the cached availability snapshot. First call parses the
  /// bundled manifest; subsequent calls reuse the same Future.
  static Future<FslAvailability> load() {
    return _cache ??= _resolve();
  }

  /// Drops the in-memory snapshot so the next [load] re-reads the manifest.
  /// Used by tests; useful in production after a hot-reload.
  static void reset() {
    _cache = null;
    _byKey.clear();
  }

  static Future<FslAvailability> _resolve() async {
    final metas = await _loadMetas();
    _byKey
      ..clear()
      ..addEntries(metas.map((m) => MapEntry(m.key, m)));
    return _buildAvailability(metas);
  }

  static Future<List<_FslVideoMeta>> _loadMetas() async {
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      final decoded = json.decode(raw);
      final entries = decoded is Map<String, dynamic>
          ? (decoded['entries'] as List?) ?? const []
          : decoded is List
              ? decoded
              : const [];
      return entries
          .whereType<Map<String, dynamic>>()
          .map(_FslVideoMeta.fromMap)
          .where((m) => m.downloadUrl.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      // No manifest yet (first run before videos are published, or asset
      // missing) — degrade gracefully so FSL screens render the "coming
      // soon" state instead of crashing.
      return const [];
    }
  }

  static FslAvailability _buildAvailability(List<_FslVideoMeta> metas) {
    final cards = <Flashcard>[];
    final perCategory = <FlashcardCategory, int>{};
    for (final card in SeedData.allFlashcards) {
      if (_byKey.containsKey(_keyFor(card))) {
        cards.add(card);
        perCategory.update(card.category, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return FslAvailability(
      availablePaths: metas.map((m) => m.downloadUrl).toSet(),
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

  /// Public download URL for the card's video, or null if not registered.
  static String? downloadUrlFor(Flashcard card) =>
      _byKey[_keyFor(card)]?.downloadUrl;

  /// True if a video is registered for [card].
  static bool hasVideo(Flashcard card) =>
      _byKey.containsKey(_keyFor(card));

  /// Resolves the card's video to a cached on-device file.
  ///
  /// First call downloads from GitHub Releases; subsequent calls (and calls
  /// while offline) return immediately from disk. Throws [StateError] if no
  /// video is registered for the card — callers should check [hasVideo] /
  /// [downloadUrlFor] first when they want a "no video yet" UI state.
  static Future<File> cachedFileFor(Flashcard card) async {
    final url = downloadUrlFor(card);
    if (url == null) {
      throw StateError(
        'No FSL video registered for "${card.wordEnglish}" '
        '(category: ${card.category.label}).',
      );
    }
    return _videoCache.getSingleFile(url, key: _keyFor(card));
  }

  /// Best-effort warm-up — kicks off a download so the next play is instant.
  /// Safe to call without awaiting; network failures are swallowed.
  static Future<void> prefetch(Flashcard card) async {
    final url = downloadUrlFor(card);
    if (url == null) return;
    try {
      await _videoCache.downloadFile(url, key: _keyFor(card));
    } catch (_) {
      // Ignore — the on-demand fetch will retry when the user plays.
    }
  }
}

/// Snapshot of which FSL videos are registered right now.
///
/// Held by `fslAvailabilityProvider` and consumed by FSL screens / games
/// to drive category pickers, empty states, and the practice-mode gate.
class FslAvailability {
  /// Every FSL download URL listed in the bundled manifest.
  final Set<String> availablePaths;

  /// Flashcards from [SeedData] that have a matching registered video.
  final List<Flashcard> cardsWithVideo;

  /// How many videos each category currently has.
  final Map<FlashcardCategory, int> videoCountByCategory;

  const FslAvailability({
    required this.availablePaths,
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

  /// Whether [card] has a matching registered video.
  bool hasVideo(Flashcard card) => FslAssetsService.hasVideo(card);
}

/// Internal: parsed entry from `assets/data/fsl_video_manifest.json`.
///
/// Mirrors the shape produced by `tools/publish_fsl_videos.mjs`:
/// ```json
/// { "category": "Animals",
///   "slug": "dog",
///   "word_english": "Dog",
///   "word_filipino": "Aso",
///   "download_url": "https://github.com/.../dog.mp4" }
/// ```
class _FslVideoMeta {
  final String category;
  final String slug;
  final String downloadUrl;

  const _FslVideoMeta({
    required this.category,
    required this.slug,
    required this.downloadUrl,
  });

  String get key => '${category}__$slug';

  factory _FslVideoMeta.fromMap(Map<String, dynamic> m) => _FslVideoMeta(
        category: (m['category'] as String?) ?? '',
        slug: (m['slug'] as String?) ?? '',
        downloadUrl: (m['download_url'] as String?) ?? '',
      );
}
