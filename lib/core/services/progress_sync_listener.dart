import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
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
      // Player-mode profiles never reach the cloud.
      if ((raw['isGuestPlayer'] as bool?) ?? false) continue;
      _subscribe(id);
    }
  }

  void _subscribe(String profileId) {
    if (_subs.containsKey(profileId)) return;
    final ref = _db.collection('progress').doc(profileId);
    _subs[profileId] = ref.snapshots(includeMetadataChanges: false).listen(
      (snap) => _handleSnapshot(profileId, snap),
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('ProgressSyncListener[$profileId] error: $e');
        }
      },
    );
  }

  void _handleSnapshot(
      String profileId, DocumentSnapshot<Map<String, dynamic>> snap) {
    // Skip echoes of our own pending writes — those will fire again
    // once confirmed by the server.
    if (snap.metadata.hasPendingWrites) return;
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;

    try {
      final progress = _progressFromMap(profileId, data);
      // Bypass LocalRepository so this hydration doesn't bounce back
      // out as a remote write.
      HiveService.saveProgress(progress);
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
  LearningProgress _progressFromMap(
      String profileId, Map<String, dynamic> r) {
    final catRaw = r['category_progress'] as Map<String, dynamic>? ?? {};
    final scoresRaw = r['recent_scores'] as List<dynamic>? ?? [];
    final wordsRaw = r['learned_word_ids'] as List<dynamic>? ?? [];

    return LearningProgress(
      profileId: profileId,
      wordsLearned: (r['words_learned'] as int?) ?? 0,
      learnedWordIds: Set<String>.from(wordsRaw.map((e) => e.toString())),
      streakDays: (r['streak_days'] as int?) ?? 0,
      lastActivityDate:
          DateTime.tryParse(r['last_activity'] as String? ?? '') ??
              DateTime.now(),
      categoryProgress:
          catRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      recentScores: scoresRaw
          .map((s) =>
              GameScore.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      totalStars: (r['total_stars'] as int?) ?? 0,
      spentStars: (r['spent_stars'] as int?) ?? 0,
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
