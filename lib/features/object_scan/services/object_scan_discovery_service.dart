import 'package:flutter/foundation.dart';
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

  /// Values written during this session, consulted **before** the box.
  ///
  /// Hive publishes a `put` to the box only once the disk write completes, and
  /// every write here is deliberately fire-and-forget (never awaited from
  /// widget code — see [recordDiscovery]). Word Hunt then reads the collection
  /// straight back on the same frame: the 🎒 count, the NEW badges, the hunt
  /// targets and the achievement check all run immediately after a discovery.
  /// Without this mirror those reads would show the *pre-write* state and a
  /// just-found word would look like it had not been found.
  static final Map<String, Object?> _written = {};

  static Object? _read(String key) =>
      _written.containsKey(key) ? _written[key] : _box.get(key);

  static void _write(String key, Object? value) {
    _written[key] = value;
    _box.put(key, value);
  }

  /// Drops the session mirror so a test can seed the box directly with
  /// `box.put` and have this service read the seeded value.
  @visibleForTesting
  static void resetWriteCache() => _written.clear();

  static String _discoveriesKey(String profileId) =>
      'object_scan_discoveries_$profileId';
  static String _starDayKey(String profileId) =>
      'object_scan_star_day_$profileId';
  static String _gameStarsKey(String profileId) =>
      'object_scan_game_stars_$profileId';
  static String _findsDayKey(String profileId) =>
      'object_scan_finds_day_$profileId';
  static String _streakKey(String profileId) => 'object_scan_streak_$profileId';

  static String _dayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  /// Guests get a shared bucket so the feature still feels rewarding
  /// without a profile.
  static String _id(String? profileId) =>
      (profileId == null || profileId.isEmpty) ? 'guest' : profileId;

  /// All word ids this profile has ever discovered with the camera.
  static Set<String> discoveredWordIds(String? profileId) {
    final raw = _read(_discoveriesKey(_id(profileId)));
    if (raw is! List) return {};
    return raw.whereType<String>().toSet();
  }

  static bool isDiscovered(String? profileId, String wordId) =>
      discoveredWordIds(profileId).contains(wordId);

  /// Size of the profile's collection, **guarded** so it can be read from
  /// contexts where Hive may not be up — the achievement predicates run from
  /// pure-Dart tests and from report generation, neither of which opens boxes.
  /// A closed box reads as "nothing collected yet", never as a crash.
  static int discoveryCount(String? profileId) {
    try {
      return discoveredWordIds(profileId).length;
    } catch (_) {
      return 0;
    }
  }

  /// How many *new* words this profile found today. Unlike
  /// [starsAwardedToday] this is not capped, so it keeps counting after the
  /// fifth star of the day — the hunt goes on even when the rewards stop.
  static int findsToday(String? profileId, {DateTime? now}) {
    final raw = _read(_findsDayKey(_id(profileId)));
    if (raw is! Map) return 0;
    if (raw['day'] != _dayKey(now ?? DateTime.now())) return 0;
    return (raw['count'] as int?) ?? 0;
  }

  /// Consecutive days this profile has found at least one new word, counting
  /// today. A streak whose last find was **yesterday** is still alive (the day
  /// is not over yet); anything older reads as 0.
  ///
  /// Deliberately separate from [LearningProgress.streakDays], which counts any
  /// learning activity: this one is about going out and looking.
  static int huntStreak(String? profileId, {DateTime? now}) {
    final raw = _read(_streakKey(_id(profileId)));
    if (raw is! Map) return 0;
    final today = now ?? DateTime.now();
    final lastDay = raw['lastDay'];
    if (lastDay != _dayKey(today) &&
        lastDay != _dayKey(today.subtract(const Duration(days: 1)))) {
      return 0;
    }
    return (raw['streak'] as int?) ?? 0;
  }

  /// Guarded [huntStreak], for the same reason as [discoveryCount].
  static int safeHuntStreak(String? profileId, {DateTime? now}) {
    try {
      return huntStreak(profileId, now: now);
    } catch (_) {
      return 0;
    }
  }

  /// Bumps today's find count and rolls the hunt streak forward. Called only
  /// for a genuinely new word, so re-photographing the same chair all morning
  /// neither inflates the count nor extends the streak.
  static void _recordFindDay(String id, DateTime now) {
    final today = _dayKey(now);
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

    final findsRaw = _read(_findsDayKey(id));
    final countSoFar = (findsRaw is Map && findsRaw['day'] == today)
        ? findsRaw['count']
        : 0;
    _write(_findsDayKey(id), {
      'day': today,
      'count': ((countSoFar as int?) ?? 0) + 1,
    });

    final streakRaw = _read(_streakKey(id));
    final lastDay = streakRaw is Map ? streakRaw['lastDay'] : null;
    if (lastDay == today) return; // already counted today
    final previous =
        (streakRaw is Map ? streakRaw['streak'] as int? : null) ?? 0;
    _write(_streakKey(id), {
      'lastDay': today,
      'streak': lastDay == yesterday ? previous + 1 : 1,
    });
  }

  /// Stars already granted today, resetting automatically at midnight.
  static int starsAwardedToday(String? profileId, {DateTime? now}) {
    final raw = _read(_starDayKey(_id(profileId)));
    if (raw is! Map) return 0;
    if (raw['day'] != _dayKey(now ?? DateTime.now())) return 0;
    return (raw['count'] as int?) ?? 0;
  }

  /// Logs a discovery. Returns whether the word is new for this profile and
  /// whether a star reward should be granted. Writes are fire-and-forget —
  /// never awaited from widget code (see Hive FakeAsync deadlock note).
  static DiscoveryResult recordDiscovery(
    String? profileId,
    String wordId, {
    DateTime? now,
  }) {
    final id = _id(profileId);
    final discovered = discoveredWordIds(profileId);
    final isNew = !discovered.contains(wordId);
    if (isNew) {
      discovered.add(wordId);
      _write(_discoveriesKey(id), discovered.toList());
      _recordFindDay(id, now ?? DateTime.now());
    }

    var starAwarded = false;
    if (isNew) {
      final today = _dayKey(now ?? DateTime.now());
      final awarded = starsAwardedToday(profileId, now: now);
      if (awarded < dailyStarCap) {
        starAwarded = true;
        _write(_starDayKey(id), {'day': today, 'count': awarded + 1});
      }
    }
    return DiscoveryResult(isNew: isNew, starAwarded: starAwarded);
  }

  /// Claims the once-per-day game star for winning [wordId]'s single-word
  /// round (Word Hunt focus mode). Returns true on the first win of that
  /// word today; false on same-day replays, so "Play Again" can't farm
  /// stars — the 0–3 rating celebration still shows either way. Resets at
  /// midnight like the discovery-star cap.
  static bool tryAwardGameStar(
    String? profileId,
    String wordId, {
    DateTime? now,
  }) {
    final id = _id(profileId);
    final today = _dayKey(now ?? DateTime.now());
    final raw = _read(_gameStarsKey(id));
    var wordIds = const <String>[];
    if (raw is Map && raw['day'] == today) {
      wordIds =
          (raw['wordIds'] as List?)?.whereType<String>().toList() ?? const [];
      if (wordIds.contains(wordId)) return false;
    }
    _write(_gameStarsKey(id), {
      'day': today,
      'wordIds': [...wordIds, wordId],
    });
    return true;
  }
}
