import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'firebase_service.dart';

/// Subscribes to Firestore `progress/{profileId}` snapshots for every
/// profile this device knows about, hydrates Hive with what comes back,
/// and emits the affected profileId on [changes] so providers can refresh.
///
/// This is the *down* leg of bidirectional sync: writes still flow
/// out via [LocalRepository]/[SyncQueueService] (the up leg). The down
/// leg is needed so a teacher tablet sees a student's progress update
/// without waiting for the teacher to re-open the app.
///
/// Loop avoidance: snapshots with `hasPendingWrites == true` are local
/// echoes of our own writes — we skip those. Server-confirmed snapshots
/// are applied unconditionally; they're idempotent because Hive's
/// progress doc keys by profileId.
class ProgressSyncListener {
  final FirebaseFirestore _db;

  /// profileId → active subscription. One per profile we're watching.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _subs = {};

  final StreamController<String> _changes = StreamController.broadcast();

  ProgressSyncListener({FirebaseFirestore? db})
    : _db = db ?? FirebaseService.db;

  /// Emits the profileId of any progress doc just hydrated from the
  /// server. Consumers (typically a Riverpod StreamProvider) use this
  /// to re-read Hive and update UI state.
  Stream<String> get changes => _changes.stream;

  /// Begin listening for every non-guest profile currently in Hive.
  ///
  /// Safe to call repeatedly — already-subscribed profileIds are
  /// skipped. Call after sign-in completes (so reads carry an auth uid)
  /// and again whenever a new profile is created if you want immediate
  /// cross-device sync for it.
  void start() {
    if (!FirebaseService.isConfigured) return;
    for (final raw in HiveService.getProfiles()) {
      final id = raw['id'] as String?;
      if (id == null) continue;
      if (!_syncsProgress(raw)) continue;
      _subscribe(id);
    }
  }

  /// Whether a stored profile row's progress belongs in the cloud.
  ///
  /// Mirrors [UserProfile.syncsProgressToCloud], read straight off the Hive
  /// map so `start()` does not have to inflate every profile. The rule this
  /// enforces is that **the down leg is only open where the up leg is**:
  /// subscribing to a document this device never writes means a stale
  /// snapshot can roll local progress backwards, which is exactly what
  /// happened to Player-with-Progress and unlinked Student profiles.
  static bool _syncsProgress(Map<String, dynamic> raw) {
    if ((raw['isGuestPlayer'] as bool?) ?? false) return false;
    final roleIndex = raw['role'] as int?;
    if (roleIndex != null &&
        roleIndex >= 0 &&
        roleIndex < UserRole.values.length &&
        UserRole.values[roleIndex] == UserRole.player) {
      return false;
    }
    final classroomId = raw['classroomId'] as String?;
    return classroomId != null && classroomId.isNotEmpty;
  }

  void _subscribe(String profileId) {
    if (_subs.containsKey(profileId)) return;
    final ref = _db.collection('progress').doc(profileId);
    _subs[profileId] = ref
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snap) => _handleSnapshot(profileId, snap),
          onError: (Object e, StackTrace st) {
            if (kDebugMode) {
              debugPrint('ProgressSyncListener[$profileId] error: $e');
            }
          },
        );
  }

  void _handleSnapshot(
    String profileId,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    // Skip echoes of our own pending writes — those will fire again
    // once confirmed by the server.
    if (snap.metadata.hasPendingWrites) return;
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;

    try {
      final incoming = _progressFromMap(profileId, data);
      // Merge, never replace. A server-confirmed snapshot is idempotent but
      // not necessarily newer than what this device has already recorded —
      // replacing outright let a yesterday's-tablet document erase a round
      // played on this phone five minutes ago. See
      // [LearningProgress.mergeWith].
      final merged = HiveService.getProgress(profileId).mergeWith(incoming);
      // Bypass LocalRepository so this hydration doesn't bounce back
      // out as a remote write.
      HiveService.saveProgress(merged);
      // Watched signs live in their own Hive key, not on the progress row, so
      // `saveProgress` does not carry them — without this the pull would drop
      // every sign the other device recorded. Merged as a union so neither
      // device's history is rolled back.
      final signedRaw = data['fsl_signed_words'] as List<dynamic>? ?? const [];
      if (signedRaw.isNotEmpty) {
        HiveService.mergeFslWordsViewed(
          profileId,
          signedRaw.map((e) => e.toString()),
        );
      }
      _changes.add(profileId);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ProgressSyncListener[$profileId] decode failed: $e\n$st');
      }
    }
  }

  /// Mirrors the deserialization in [FirestoreRepository.getProgress].
  /// Inlined here to avoid a circular dependency between the listener
  /// (in core/) and the repository (in data/).
  LearningProgress _progressFromMap(String profileId, Map<String, dynamic> r) {
    final catRaw = r['category_progress'] as Map<String, dynamic>? ?? {};
    final scoresRaw = r['recent_scores'] as List<dynamic>? ?? [];
    final wordsRaw = r['learned_word_ids'] as List<dynamic>? ?? [];
    final storyIdsRaw = r['completed_story_ids'] as List<dynamic>? ?? [];
    final storyStarsRaw = r['story_best_stars'] as Map<String, dynamic>? ?? {};
    final gameStarsRaw = r['game_best_stars'] as Map<String, dynamic>? ?? {};

    return LearningProgress(
      profileId: profileId,
      wordsLearned: (r['words_learned'] as int?) ?? 0,
      learnedWordIds: Set<String>.from(wordsRaw.map((e) => e.toString())),
      streakDays: (r['streak_days'] as int?) ?? 0,
      lastActivityDate:
          DateTime.tryParse(r['last_activity'] as String? ?? '') ??
          DateTime.now(),
      categoryProgress: catRaw.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      recentScores: scoresRaw
          .map((s) => GameScore.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      totalStars: (r['total_stars'] as int?) ?? 0,
      spentStars: (r['spent_stars'] as int?) ?? 0,
      // Absent on documents written before these lifetime counters existed;
      // the model's `effective*` getters heal the 0. Omitting them here would
      // let a cloud pull reset the high-water marks and de-level the learner —
      // the exact regression XP monotonicity exists to prevent.
      bestStreakDays: (r['best_streak_days'] as int?) ?? 0,
      gamesPlayed: (r['games_played'] as int?) ?? 0,
      playedGameTypes: gameTypesFromNames(r['played_game_types']),
      // Story and per-game records, for the same reason as the counters above:
      // `saveProgress` writes all three, so anything not read here is written
      // back empty and the pull silently erases a learner's read stories,
      // their story ★ badges and their per-game personal bests.
      completedStoryIds: Set<String>.from(storyIdsRaw.map((e) => e.toString())),
      storyBestStars: storyStarsRaw.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      gameBestStars: gameStarsRaw.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      // Deliberately not read here: `signedWordKeys` is not persisted by
      // `saveProgress`, so setting it on this model would achieve nothing.
      // `_handleSnapshot` merges it into its own Hive key instead.
    );
  }

  /// Add a single profile to the watch set after [start] has run.
  /// Safe to call any time — no-op if already subscribed.
  void watch(String profileId) {
    if (FirebaseService.isConfigured) _subscribe(profileId);
  }

  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _changes.close();
  }
}
