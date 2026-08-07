import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/action_clip_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import 'tv_cast_asset_bridge.dart';

/// What a prewarm run is doing right now.
enum PrewarmStatus { idle, running, done, cancelled }

/// Progress of a "prepare this lesson for casting" run.
class TvCastPrewarmState {
  final PrewarmStatus status;

  /// Items finished (successfully or not) out of [total].
  final int done;
  final int total;

  /// The item currently downloading, for the "Preparing 'Horse'…" line.
  final String label;

  /// Items whose download failed. Reported rather than retried: the cast still
  /// works, those pieces just fall back to downloading on demand.
  final int failed;

  /// Identifies what was prepared (`'cat:0'` / `'story:s_a01'`), so the UI can
  /// tell "this category is ready" from a stale result for a different one.
  final String? targetKey;

  const TvCastPrewarmState({
    this.status = PrewarmStatus.idle,
    this.done = 0,
    this.total = 0,
    this.label = '',
    this.failed = 0,
    this.targetKey,
  });

  bool get isRunning => status == PrewarmStatus.running;
  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  TvCastPrewarmState copyWith({
    PrewarmStatus? status,
    int? done,
    int? total,
    String? label,
    int? failed,
    String? targetKey,
  }) => TvCastPrewarmState(
    status: status ?? this.status,
    done: done ?? this.done,
    total: total ?? this.total,
    label: label ?? this.label,
    failed: failed ?? this.failed,
    targetKey: targetKey ?? this.targetKey,
  );
}

/// One thing to pull onto the device before a lesson.
class _WarmItem {
  final String label;
  final Future<void> Function() run;
  const _WarmItem(this.label, this.run);
}

/// Downloads everything a cast will need, up front.
///
/// The cast fetches media lazily: the TV asks for `/api/video/…`, the phone
/// downloads it, and until that finishes the class watches a placeholder. On
/// the school Wi-Fi this project targets that is the difference between a
/// lesson and a stall — an FSL clip is ~8 MB and a category has a dozen.
///
/// So the educator gets one button that pulls the whole category (or story) at
/// a moment of their choosing — during setup, on the staffroom connection —
/// after which the cast plays from disk and survives the network dropping
/// entirely.
///
/// Every step is best-effort: a failed item is counted and skipped, never
/// retried in a loop and never surfaced as an error, because the cast still
/// works without it (that piece just falls back to on-demand download).
class TvCastPrewarmNotifier extends Notifier<TvCastPrewarmState> {
  /// Set while a run is in flight; checked between items so Cancel takes
  /// effect at the next boundary rather than orphaning a download.
  bool _cancelRequested = false;

  @override
  TvCastPrewarmState build() {
    ref.onDispose(() => _cancelRequested = true);
    return const TvCastPrewarmState();
  }

  /// Asks the current run to stop after the item in flight.
  void cancel() {
    if (!state.isRunning) return;
    _cancelRequested = true;
  }

  /// Prepares every card in [category] — sign clip, "Show Me" clip, and both
  /// picture faces.
  Future<void> warmCategory(FlashcardCategory category) =>
      _run('cat:${category.index}', _categoryItems(category));

  /// Prepares every page of [storyId] — sign clip and both picture faces.
  Future<void> warmStory(String storyId) {
    Story? story;
    for (final s in SeedStories.all) {
      if (s.id == storyId) {
        story = s;
        break;
      }
    }
    if (story == null) return Future.value();
    return _run('story:$storyId', _storyItems(story));
  }

  List<_WarmItem> _categoryItems(FlashcardCategory category) {
    final items = <_WarmItem>[];
    for (final card in SeedData.getByCategory(category)) {
      final word = card.wordEnglish;
      // Ordered cheapest-visible-first: the pictures land in a second each, so
      // a teacher who cancels early still has the card faces ready.
      if (FlashcardPhotoService.hasPhoto(card) ||
          FlashcardPhotoService.cartoonUrlFor(card) != null) {
        items.add(
          _WarmItem(word, () => FlashcardPhotoService.prefetchBothFaces(card)),
        );
      }
      if (ActionClipService.hasClip(card)) {
        items.add(_WarmItem(word, () => ActionClipService.resolveClip(card)));
      }
      if (FslAssetsService.hasAnyVideoSource(card)) {
        items.add(_WarmItem(word, () => FslAssetsService.prefetch(card)));
      }
    }
    return items;
  }

  List<_WarmItem> _storyItems(Story story) {
    final items = <_WarmItem>[];
    final pages = story.sentencesEn.length;
    for (var i = 0; i < pages; i++) {
      final page = i;
      final label = 'Page ${page + 1}';
      final pair = TvCastAssetBridge.storyImagePair(story, page);
      if (pair != null) {
        items.add(
          _WarmItem(label, () async {
            await TvCastAssetBridge.storyImageFile(
              pair.cartoonUrl,
              TvCastAssetBridge.storyImageCacheKey(story.id, page, real: false),
            );
            await TvCastAssetBridge.storyImageFile(
              pair.realUrl,
              TvCastAssetBridge.storyImageCacheKey(story.id, page, real: true),
            );
          }),
        );
      }
      final fslUrl = TvCastAssetBridge.storyFslUrl(story, page);
      if (fslUrl != null) {
        items.add(
          _WarmItem(
            label,
            () => FslAssetsService.prefetchUrl(
              fslUrl,
              cacheKey: TvCastAssetBridge.storyFslCacheKey(story.id, page),
            ),
          ),
        );
      }
    }
    return items;
  }

  Future<void> _run(String targetKey, List<_WarmItem> items) async {
    if (state.isRunning) return;
    _cancelRequested = false;

    if (items.isEmpty) {
      // Nothing downloadable (e.g. a story with no pictures or signs) — that's
      // "already ready", not a failure.
      state = TvCastPrewarmState(
        status: PrewarmStatus.done,
        targetKey: targetKey,
      );
      return;
    }

    state = TvCastPrewarmState(
      status: PrewarmStatus.running,
      total: items.length,
      targetKey: targetKey,
    );

    var done = 0;
    var failed = 0;
    for (final item in items) {
      if (_cancelRequested) {
        state = state.copyWith(status: PrewarmStatus.cancelled, label: '');
        return;
      }
      state = state.copyWith(label: item.label);
      try {
        await item.run();
      } catch (_) {
        // Contained per item — one dead URL must not abandon the rest of the
        // lesson, and the cast degrades to on-demand for just that piece.
        failed++;
      }
      done++;
      state = state.copyWith(done: done, failed: failed);
    }

    state = state.copyWith(status: PrewarmStatus.done, label: '');
  }
}

final tvCastPrewarmProvider =
    NotifierProvider<TvCastPrewarmNotifier, TvCastPrewarmState>(
      TvCastPrewarmNotifier.new,
    );
