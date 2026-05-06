import 'package:flutter/services.dart';

import '../../data/local/seed_data.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Reports which FSL sign-language videos are actually bundled, so the
/// games can show a category-aware empty state and the picker can hide
/// categories that don't have enough content yet.
///
/// Resolution is asset-manifest-based (cheap, no per-file probes) and
/// memoised for the lifetime of the app.
class FslAssetsService {
  FslAssetsService._();

  static Future<FslAvailability>? _cache;

  static String videoPathFor(Flashcard card) =>
      'assets/videos/fsl/${card.category.label}/${card.wordEnglish.toLowerCase()}.mp4';

  /// Returns the cached availability snapshot. Subsequent calls reuse the
  /// same Future so the manifest is parsed once.
  static Future<FslAvailability> load() {
    return _cache ??= _resolve();
  }

  /// Drops the cache. Useful for tests; not used at runtime.
  static void reset() => _cache = null;

  static Future<FslAvailability> _resolve() async {
    Set<String> assetPaths;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      assetPaths = manifest
          .listAssets()
          .where((p) => p.endsWith('.mp4') && p.startsWith('assets/videos/fsl/'))
          .toSet();
    } catch (_) {
      // If the manifest can't be loaded (rare), treat as empty rather
      // than crashing the games.
      assetPaths = const <String>{};
    }

    final cardsWithVideo = <Flashcard>[];
    final perCategory = <FlashcardCategory, int>{};

    for (final card in SeedData.allFlashcards) {
      if (assetPaths.contains(videoPathFor(card))) {
        cardsWithVideo.add(card);
        perCategory.update(card.category, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return FslAvailability(
      availablePaths: assetPaths,
      cardsWithVideo: List.unmodifiable(cardsWithVideo),
      videoCountByCategory: Map.unmodifiable(perCategory),
    );
  }
}

class FslAvailability {
  /// Every FSL .mp4 asset path bundled with the build.
  final Set<String> availablePaths;

  /// Flashcards from [SeedData] that have a matching FSL video.
  final List<Flashcard> cardsWithVideo;

  /// How many FSL videos each category currently bundles.
  final Map<FlashcardCategory, int> videoCountByCategory;

  const FslAvailability({
    required this.availablePaths,
    required this.cardsWithVideo,
    required this.videoCountByCategory,
  });

  /// True if at least one category has enough videos for either FSL game
  /// to be playable.
  bool get hasAnyVideos => cardsWithVideo.isNotEmpty;

  /// Categories that have at least [min] videos — usable in either FSL
  /// game without bouncing the user to an empty state.
  Set<FlashcardCategory> playableCategories({int min = 2}) {
    return videoCountByCategory.entries
        .where((e) => e.value >= min)
        .map((e) => e.key)
        .toSet();
  }

  /// Whether [card] has a matching bundled FSL video.
  bool hasVideo(Flashcard card) =>
      availablePaths.contains(FslAssetsService.videoPathFor(card));
}
