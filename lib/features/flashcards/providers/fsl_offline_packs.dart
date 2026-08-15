import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// How much of one category is already on the device.
class FslPackCoverage {
  /// Words in this category that have a sign clip registered at all. The rest
  /// have no sign recorded yet and can never be downloaded — see the coverage
  /// gap in `fsl_video_manifest.json`.
  final int downloadable;

  /// Of those, how many are already on disk (or bundled) and play offline.
  final int ready;

  /// Bytes those downloaded clips occupy. Bundled clips count 0 — they ship in
  /// the APK and clearing them isn't on offer.
  final int bytes;

  const FslPackCoverage({
    this.downloadable = 0,
    this.ready = 0,
    this.bytes = 0,
  });

  bool get isComplete => downloadable > 0 && ready >= downloadable;
  bool get isEmpty => ready == 0;
  double get fraction => downloadable == 0 ? 0 : ready / downloadable;
}

/// What the packs screen is doing right now.
enum FslPackStatus { idle, scanning, downloading, clearing }

class FslOfflinePacksState {
  final FslPackStatus status;
  final Map<FlashcardCategory, FslPackCoverage> byCategory;

  /// The category being downloaded or cleared, so only its row shows a spinner.
  /// Null during a "download everything" run, which shows progress on the
  /// summary row instead.
  final FlashcardCategory? busyCategory;

  /// Progress of the run in flight.
  final int done;
  final int total;

  /// The word currently downloading, for the "Saving 'Horse'…" line.
  final String label;

  /// Clips whose download failed. Reported rather than retried: the word still
  /// works, it just needs the network again next time.
  final int failed;

  const FslOfflinePacksState({
    this.status = FslPackStatus.idle,
    this.byCategory = const {},
    this.busyCategory,
    this.done = 0,
    this.total = 0,
    this.label = '',
    this.failed = 0,
  });

  bool get isBusy =>
      status == FslPackStatus.downloading || status == FslPackStatus.clearing;
  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  int get totalDownloadable =>
      byCategory.values.fold(0, (n, c) => n + c.downloadable);
  int get totalReady => byCategory.values.fold(0, (n, c) => n + c.ready);
  int get totalBytes => byCategory.values.fold(0, (n, c) => n + c.bytes);

  FslOfflinePacksState copyWith({
    FslPackStatus? status,
    Map<FlashcardCategory, FslPackCoverage>? byCategory,
    FlashcardCategory? busyCategory,
    bool clearBusyCategory = false,
    int? done,
    int? total,
    String? label,
    int? failed,
  }) => FslOfflinePacksState(
    status: status ?? this.status,
    byCategory: byCategory ?? this.byCategory,
    busyCategory: clearBusyCategory
        ? null
        : (busyCategory ?? this.busyCategory),
    done: done ?? this.done,
    total: total ?? this.total,
    label: label ?? this.label,
    failed: failed ?? this.failed,
  );
}

/// Downloads FSL sign clips ahead of time so the dictionary works without a
/// network.
///
/// Nothing is bundled with the app: every sign is fetched from Cloudinary the
/// first time a learner opens it. In the classrooms this project targets that
/// is the difference between a lesson and a stall — and for a Deaf learner the
/// sign *is* the content, so "no connection" means the feature is simply gone.
///
/// So the dictionary offers packs: pull one category (or all 142 clips) at a
/// moment of the teacher's choosing, on whatever connection they have, after
/// which those words play from disk forever. The counterpart matters just as
/// much on a shared school tablet — a full set is roughly a gigabyte, so each
/// pack can be given back.
///
/// Every download is best-effort and contained per clip: one dead URL is
/// counted and skipped, never retried in a loop, because the word still works
/// (it just falls back to downloading on demand).
class FslOfflinePacksNotifier extends Notifier<FslOfflinePacksState> {
  /// Set while a run is in flight; checked between clips so Cancel takes effect
  /// at the next boundary rather than orphaning a download mid-write.
  bool _cancelRequested = false;

  @override
  FslOfflinePacksState build() {
    ref.onDispose(() => _cancelRequested = true);
    return const FslOfflinePacksState();
  }

  /// Cards in [category] that have a clip registered, so could be downloaded.
  static List<Flashcard> downloadableIn(FlashcardCategory category) =>
      SeedData.getByCategory(
        category,
      ).where(FslAssetsService.hasAnyVideoSource).toList(growable: false);

  /// Asks the run in flight to stop after the clip it is on.
  void cancel() {
    if (!state.isBusy) return;
    _cancelRequested = true;
  }

  /// Re-reads what is on disk. Call when the packs UI opens; the scan is a
  /// cache lookup plus a stat per clip, so it is cheap enough to redo rather
  /// than try to keep a running total honest across evictions.
  Future<void> refresh() async {
    if (state.isBusy) return;
    state = state.copyWith(status: FslPackStatus.scanning);
    state = state.copyWith(
      status: FslPackStatus.idle,
      byCategory: await _scan(),
    );
  }

  Future<Map<FlashcardCategory, FslPackCoverage>> _scan() async {
    // Which words have a clip at all comes from the manifest, and
    // `hasAnyVideoSource` answers "no" until it is parsed. Opening this sheet
    // on a cold start would otherwise report every category as having no signs
    // recorded, and offer no downloads at all.
    await FslAssetsService.load();

    final result = <FlashcardCategory, FslPackCoverage>{};
    for (final category in FlashcardCategory.values) {
      final cards = downloadableIn(category);
      var ready = 0;
      var bytes = 0;
      for (final card in cards) {
        // One disk lookup per clip, not two: `cachedBytes` already returns 0
        // for anything not on disk, and a bundled clip is ready without
        // occupying any of the space this screen offers to reclaim.
        if (FslAssetsService.hasVideo(card)) {
          ready++;
          continue;
        }
        final cached = await FslAssetsService.cachedBytes(card);
        if (cached > 0) {
          ready++;
          bytes += cached;
        }
      }
      result[category] = FslPackCoverage(
        downloadable: cards.length,
        ready: ready,
        bytes: bytes,
      );
    }
    return result;
  }

  /// Downloads every missing clip in [category].
  Future<void> downloadCategory(FlashcardCategory category) =>
      _download([category], busy: category);

  /// Downloads every missing clip in every category.
  Future<void> downloadAll() => _download(FlashcardCategory.values);

  Future<void> _download(
    List<FlashcardCategory> categories, {
    FlashcardCategory? busy,
  }) async {
    if (state.isBusy) return;
    _cancelRequested = false;

    // Only fetch what is actually missing, so re-running a partly-finished pack
    // resumes instead of re-downloading a gigabyte.
    final pending = <Flashcard>[];
    for (final category in categories) {
      for (final card in downloadableIn(category)) {
        if (!await FslAssetsService.isCached(card)) pending.add(card);
      }
    }
    if (pending.isEmpty) {
      await refresh();
      return;
    }

    state = state.copyWith(
      status: FslPackStatus.downloading,
      busyCategory: busy,
      clearBusyCategory: busy == null,
      done: 0,
      total: pending.length,
      failed: 0,
      label: '',
    );

    var done = 0;
    var failed = 0;
    for (final card in pending) {
      if (_cancelRequested) break;
      state = state.copyWith(label: card.wordEnglish);
      try {
        await FslAssetsService.prefetch(card);
        // `prefetch` swallows its own failures, so confirm rather than trust:
        // an offline run would otherwise report every clip as saved.
        if (!await FslAssetsService.isCached(card)) failed++;
      } catch (_) {
        failed++;
      }
      done++;
      state = state.copyWith(done: done, failed: failed);
    }

    state = state.copyWith(
      status: FslPackStatus.idle,
      byCategory: await _scan(),
      clearBusyCategory: true,
      label: '',
    );
  }

  /// Gives back the disk used by [category]'s downloaded clips.
  Future<void> clearCategory(FlashcardCategory category) async {
    if (state.isBusy) return;
    state = state.copyWith(
      status: FslPackStatus.clearing,
      busyCategory: category,
    );
    for (final card in downloadableIn(category)) {
      await FslAssetsService.evict(card);
    }
    state = state.copyWith(
      status: FslPackStatus.idle,
      byCategory: await _scan(),
      clearBusyCategory: true,
    );
  }
}

final fslOfflinePacksProvider =
    NotifierProvider<FslOfflinePacksNotifier, FslOfflinePacksState>(
      FslOfflinePacksNotifier.new,
    );

/// "348 MB" / "1.2 GB" — sized for a row of text, not precision.
String formatPackBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) {
    return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
  }
  final inMb = bytes / mb;
  return '${inMb < 10 ? inMb.toStringAsFixed(1) : inMb.round()} MB';
}
