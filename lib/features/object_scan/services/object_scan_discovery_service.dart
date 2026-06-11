import 'package:hive_flutter/hive_flutter.dart';

/// Outcome of logging a camera discovery for a word.
class DiscoveryResult {
  /// First time this profile has ever discovered the word.
  final bool isNew;

  /// A star should be granted (new word and the daily cap not yet reached).
  final bool starAwarded;

  const DiscoveryResult({required this.isNew, required this.starAwarded});
}

/// Persists which words each profile has discovered with the Word Hunt
/// camera, and rate-limits the star reward. Stored in the existing Hive
/// `progress` box, mirroring [AdaptiveDifficultyService]'s storage style.
class ObjectScanDiscoveryService {
  ObjectScanDiscoveryService._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  /// At most this many discovery stars per profile per calendar day.
  static const int dailyStarCap = 5;

  static String _discoveriesKey(String profileId) =>
      'object_scan_discoveries_$profileId';
  static String _starDayKey(String profileId) =>
      'object_scan_star_day_$profileId';

  static String _dayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  /// Guests get a shared bucket so the feature still feels rewarding
  /// without a profile.
  static String _id(String? profileId) =>
      (profileId == null || profileId.isEmpty) ? 'guest' : profileId;

  /// All word ids this profile has ever discovered with the camera.
  static Set<String> discoveredWordIds(String? profileId) {
    final raw = _box.get(_discoveriesKey(_id(profileId)));
    if (raw is! List) return {};
    return raw.whereType<String>().toSet();
  }

  static bool isDiscovered(String? profileId, String wordId) =>
      discoveredWordIds(profileId).contains(wordId);

  /// Stars already granted today, resetting automatically at midnight.
  static int starsAwardedToday(String? profileId, {DateTime? now}) {
    final raw = _box.get(_starDayKey(_id(profileId)));
    if (raw is! Map) return 0;
    if (raw['day'] != _dayKey(now ?? DateTime.now())) return 0;
    return (raw['count'] as int?) ?? 0;
  }

  /// Logs a discovery. Returns whether the word is new for this profile and
  /// whether a star reward should be granted. Writes are fire-and-forget —
  /// never awaited from widget code (see Hive FakeAsync deadlock note).
  static DiscoveryResult recordDiscovery(String? profileId, String wordId,
      {DateTime? now}) {
    final id = _id(profileId);
    final discovered = discoveredWordIds(profileId);
    final isNew = !discovered.contains(wordId);
    if (isNew) {
      discovered.add(wordId);
      _box.put(_discoveriesKey(id), discovered.toList());
    }

    var starAwarded = false;
    if (isNew) {
      final today = _dayKey(now ?? DateTime.now());
      final awarded = starsAwardedToday(profileId, now: now);
      if (awarded < dailyStarCap) {
        starAwarded = true;
        _box.put(_starDayKey(id), {'day': today, 'count': awarded + 1});
      }
    }
    return DiscoveryResult(isNew: isNew, starAwarded: starAwarded);
  }
}
