import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/services/media_cache_key.dart';
import '../../../core/services/media_url_resolver.dart';
import '../../routine/services/routine_media_store.dart';
import '../../routine/widgets/routine_media.dart';
import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';

/// Where an attached media value can be played from right now.
enum MediaAvailability {
  /// On this device: a picked file, a bundled asset, or a link already
  /// downloaded.
  ready,

  /// A picked file that is not on this device — it was chosen on another
  /// tablet, and there is no shared storage for it to travel through.
  otherDevice,

  /// A link that could not be downloaded (offline, or a dead link).
  unreachable,
}

/// Downloads linked assessment media once and replays it from disk.
///
/// Its own cache, not the FSL clip cache: that one is sized for the app's
/// sign library and a teacher's photos should not evict a Deaf learner's
/// signs. Keys go through [MediaCacheKey.forUrl], so a re-hosted file is a
/// miss rather than the stale copy — the lesson of the GIF re-host.
class AssessmentMediaCache {
  const AssessmentMediaCache._();

  static final BaseCacheManager _cache = CacheManager(
    Config(
      'assessment_media_cache',
      stalePeriod: const Duration(days: 120),
      maxNrOfCacheObjects: 300,
    ),
  );

  /// How long one item may take to download before it counts as missing.
  static const Duration perItem = Duration(seconds: 45);

  /// Replaces the download in tests; returns the file or null.
  static Future<File?> Function(String url)? debugFetch;

  static String _keyFor(String url) =>
      MediaCacheKey.forUrl('assessment_media', url.trim());

  static bool _isLink(String value) {
    final v = value.trim();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  /// The local file for [value], downloading a link if need be. Null for a
  /// bundled asset (play it with the asset APIs), a missing device file, or a
  /// download that failed.
  static Future<File?> fileFor(String value) async {
    final v = value.trim();
    if (v.isEmpty || isAssetMedia(v)) return null;
    if (RoutineMediaStore.isDeviceFile(v)) {
      final f = File(RoutineMediaStore.pathOf(v));
      return await f.exists() ? f : null;
    }
    if (!_isLink(v)) return null;
    final fetch = debugFetch;
    if (fetch != null) return fetch(v);
    try {
      final cached = await _cache.getFileFromCache(_keyFor(v));
      if (cached != null) return cached.file;
    } catch (_) {
      // Fall through to a fresh download.
    }
    final direct = await MediaUrlResolver.resolve(v);
    if (direct == null || direct.isEmpty) return null;
    try {
      return await _cache.getSingleFile(direct, key: _keyFor(v));
    } catch (_) {
      return null;
    }
  }

  /// Whether [value] can be shown on this device now, downloading a link if
  /// need be.
  static Future<MediaAvailability> availabilityOf(String value) async {
    final v = value.trim();
    if (isAssetMedia(v)) return MediaAvailability.ready;
    if (RoutineMediaStore.isDeviceFile(v)) {
      return await File(RoutineMediaStore.pathOf(v)).exists()
          ? MediaAvailability.ready
          : MediaAvailability.otherDevice;
    }
    File? file;
    try {
      file = await fileFor(v).timeout(perItem);
    } catch (_) {
      file = null;
    }
    return file != null ? MediaAvailability.ready : MediaAvailability.unreachable;
  }

  /// The media values in [assessment] that [presentation] will actually show —
  /// a learner who does not sign is not held up by a sign video they would
  /// never see.
  static List<String> valuesIn(
    Assessment assessment,
    AssessmentMediaPresentation presentation,
  ) => {
    for (final q in assessment.questions)
      for (final kind in presentation.kindsFor(q.media)) q.media.urlFor(kind).trim(),
  }.toList();

  /// Makes every value available offline and returns the ones that are still
  /// not — empty means the test can start with everything in place.
  static Future<List<String>> prepare(Iterable<String> values) async {
    final missing = <String>[];
    for (final value in values.toSet()) {
      if (await availabilityOf(value) != MediaAvailability.ready) {
        missing.add(value);
      }
    }
    return missing;
  }

  /// The media values of an assignment's instructions this learner will see.
  static Iterable<String> instructionValues(
    AssessmentAssignment assignment,
    AssessmentMediaPresentation presentation,
  ) => presentation
      .kindsFor(assignment.media)
      .map((k) => assignment.media.urlFor(k).trim());

  /// Downloads whatever links [values] holds in the background, while the
  /// tablet is online. Failures are ignored: the check before a test starts
  /// catches them, and a sheet shows its own "could not load".
  static Future<void> prefetchValues(Iterable<String> values) async {
    for (final v in values.where(_isLink).toSet()) {
      try {
        await fileFor(v).timeout(perItem);
      } catch (_) {
        // Best effort.
      }
    }
  }
}
