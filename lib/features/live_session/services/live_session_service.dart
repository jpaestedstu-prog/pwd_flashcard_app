import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../models/live_session_models.dart';

/// Real-time classroom / home-group session backed by Firestore snapshots.
///
/// Cloud schema:
///   live_sessions/{sessionKey}
///     - the session doc; status, current_activity, scoring, owner_uid.
///       `sessionKey` is a classroom id (teacher) or home-group id (parent).
///   live_sessions/{sessionKey}/responses/{activityId}_{profileId}
///     - one response doc per (activity, learner) — id collision is the
///       point: a re-submit overwrites instead of stacking.
///   live_sessions/{sessionKey}/hands/{profileId}
///     - one raised-hand doc per learner; `active` toggles on raise/lower.
///
/// Reads are cloud-only (no Hive cache) because the whole point is real-time
/// visibility. If the device is offline, the snapshot stream stays warm via
/// Firestore's local cache and reconciles on reconnect.
///
/// **Free-tier:** a 30-learner classroom answering ~30 questions per session
/// is ≈900 response writes + 30 hand writes — a rounding error against the
/// Spark plan's 20K/day write quota.
class LiveSessionService {
  const LiveSessionService();

  FirebaseFirestore get _db => FirebaseService.db;

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionKey) =>
      _db.collection('live_sessions').doc(sessionKey);

  CollectionReference<Map<String, dynamic>> _responsesRef(String sessionKey) =>
      _sessionRef(sessionKey).collection('responses');

  CollectionReference<Map<String, dynamic>> _handsRef(String sessionKey) =>
      _sessionRef(sessionKey).collection('hands');

  // ─── Educator API ─────────────────────────────────────

  /// Start a new session (or resume the existing one). Idempotent — merges
  /// so calling this twice doesn't reset the current activity. Updates the
  /// scoring rules each call so the educator can tweak them mid-session.
  Future<LiveSession> startSession({
    required String sessionKey,
    required String ownerProfileId,
    LiveSessionOwnerKind ownerKind = LiveSessionOwnerKind.classroom,
    LiveScoringRules scoring = const LiveScoringRules(),
  }) async {
    final session = LiveSession(
      sessionKey: sessionKey,
      ownerKind: ownerKind,
      ownerProfileId: ownerProfileId,
      ownerUid: FirebaseService.currentUid,
      scoring: scoring,
      startedAt: DateTime.now(),
    );
    // Merge so resuming doesn't clobber an in-flight `current_activity`. We
    // deliberately omit that key from the patch (rather than null it) so a
    // resume keeps whatever question is already on screen.
    await _sessionRef(sessionKey).set(
      {
        'classroom_id': sessionKey,
        'owner_kind': ownerKind.name,
        'owner_profile_id': ownerProfileId,
        'teacher_profile_id': ownerProfileId,
        'teacher_uid': FirebaseService.currentUid,
        'owner_uid': FirebaseService.currentUid,
        'status': LiveSessionStatus.active.name,
        'scoring': scoring.toJson(),
        'started_at': session.startedAt.toIso8601String(),
        'ended_at': null,
      },
      SetOptions(merge: true),
    );
    return session;
  }

  /// Update just the scoring rules on an existing session.
  Future<void> updateScoring({
    required String sessionKey,
    required LiveScoringRules scoring,
  }) async {
    await _sessionRef(sessionKey).set(
      {'scoring': scoring.toJson()},
      SetOptions(merge: true),
    );
  }

  /// Push an activity to all subscribed learners. Replaces any previous
  /// `current_activity` and bumps the doc — the snapshot fires on every
  /// connected device within ~100 ms.
  Future<LiveActivity> pushActivity({
    required String sessionKey,
    required LiveActivity activity,
  }) async {
    await _sessionRef(sessionKey).set(
      {'current_activity': activity.toJson()},
      SetOptions(merge: true),
    );
    return activity;
  }

  /// Back-compat helper for the legacy flashcard push.
  Future<LiveActivity> pushFlashcard({
    required String sessionKey,
    required String flashcardId,
  }) =>
      pushActivity(
        sessionKey: sessionKey,
        activity: LiveActivity.flashcard(flashcardId: flashcardId),
      );

  /// Clear the current activity without ending the session (so learners see
  /// "waiting for the next question" rather than a stale one).
  Future<void> clearActivity(String sessionKey) async {
    await _sessionRef(sessionKey).set(
      {'current_activity': null},
      SetOptions(merge: true),
    );
  }

  /// Mark the session ended and clear the current activity.
  Future<void> endSession(String sessionKey) async {
    await _sessionRef(sessionKey).set({
      'status': LiveSessionStatus.ended.name,
      'current_activity': null,
      'ended_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Live responses for a single activity. The educator dashboard subscribes
  /// to this to see responses streaming in for the current question.
  Stream<List<LiveResponse>> watchResponses({
    required String sessionKey,
    required String activityId,
  }) {
    return _responsesRef(sessionKey)
        .where('activity_id', isEqualTo: activityId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                LiveResponse.fromJson(Map<String, dynamic>.from(d.data())))
            .toList()
          ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt)));
  }

  /// Every response in the session, across all activities. Used to build the
  /// running scoreboard on the educator device.
  Stream<List<LiveResponse>> watchAllResponses(String sessionKey) {
    return _responsesRef(sessionKey).snapshots().map((snap) => snap.docs
        .map((d) => LiveResponse.fromJson(Map<String, dynamic>.from(d.data())))
        .toList());
  }

  // ─── Learner API ──────────────────────────────────────

  /// Subscribe to the session doc — fires whenever the educator pushes a new
  /// activity, changes scoring, or ends the session.
  Stream<LiveSession?> watchSession(String sessionKey) {
    return _sessionRef(sessionKey).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return LiveSession.fromJson(Map<String, dynamic>.from(data));
    });
  }

  /// Submit (or re-submit) this learner's response to the current activity.
  /// Overwrites any prior submission for the same activity.
  Future<void> submitResponse({
    required String sessionKey,
    required String activityId,
    required String profileId,
    required String profileName,
    required bool isCorrect,
    Object? answer,
    int elapsedMs = 0,
    int starsAwarded = 0,
  }) async {
    final response = LiveResponse(
      activityId: activityId,
      profileId: profileId,
      profileName: profileName,
      submittedAt: DateTime.now(),
      isCorrect: isCorrect,
      answer: answer,
      elapsedMs: elapsedMs,
      starsAwarded: starsAwarded,
    );
    final docId = '${activityId}_$profileId';
    await _responsesRef(sessionKey).doc(docId).set({
      ...response.toJson(),
      // Required by the rule — must match the writer's auth uid.
      'owner_uid': FirebaseService.currentUid,
    }, SetOptions(merge: true));
  }

  /// Patch the stars a learner ended up awarding itself (e.g. after the
  /// first-correct bonus resolves). Keeps the educator scoreboard accurate.
  Future<void> updateResponseStars({
    required String sessionKey,
    required String activityId,
    required String profileId,
    required int starsAwarded,
  }) async {
    final docId = '${activityId}_$profileId';
    await _responsesRef(sessionKey).doc(docId).set(
      {'stars_awarded': starsAwarded},
      SetOptions(merge: true),
    );
  }

  // ─── Raise-hand API ───────────────────────────────────

  /// Raise this learner's hand. Idempotent — the doc id is the profile id.
  Future<void> raiseHand({
    required String sessionKey,
    required String profileId,
    required String profileName,
  }) async {
    final hand = RaisedHand(
      profileId: profileId,
      profileName: profileName,
      raisedAt: DateTime.now(),
    );
    await _handsRef(sessionKey).doc(profileId).set({
      ...hand.toJson(),
      'owner_uid': FirebaseService.currentUid,
    }, SetOptions(merge: true));
  }

  /// Lower this learner's own hand (or — when called by the educator — clear
  /// it). Keeps the doc so the learner toggle reads cleanly; just flips
  /// `active` to false.
  Future<void> lowerHand({
    required String sessionKey,
    required String profileId,
  }) async {
    await _handsRef(sessionKey).doc(profileId).set(
      {'active': false},
      SetOptions(merge: true),
    );
  }

  /// Live list of currently-raised hands, newest last. The educator dashboard
  /// and the TV both render from this.
  Stream<List<RaisedHand>> watchHands(String sessionKey) {
    return _handsRef(sessionKey).snapshots().map((snap) => snap.docs
        .map((d) => RaisedHand.fromJson(Map<String, dynamic>.from(d.data())))
        .where((h) => h.active)
        .toList()
      ..sort((a, b) => a.raisedAt.compareTo(b.raisedAt)));
  }

  // ─── Aggregation (pure) ───────────────────────────────

  /// Collapse a flat list of responses into a per-learner scoreboard, sorted
  /// by stars desc then correct desc. Pure — unit-testable, no I/O.
  static List<LiveScoreRow> aggregateScoreboard(List<LiveResponse> responses) {
    final byProfile = <String, LiveScoreRow>{};
    for (final r in responses) {
      final existing = byProfile[r.profileId];
      byProfile[r.profileId] = LiveScoreRow(
        profileId: r.profileId,
        name: r.profileName,
        stars: (existing?.stars ?? 0) + r.starsAwarded,
        correct: (existing?.correct ?? 0) + (r.isCorrect ? 1 : 0),
      );
    }
    final rows = byProfile.values.toList()
      ..sort((a, b) {
        final byStars = b.stars.compareTo(a.stars);
        if (byStars != 0) return byStars;
        return b.correct.compareTo(a.correct);
      });
    return rows;
  }
}
