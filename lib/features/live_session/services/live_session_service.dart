import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../models/live_session_models.dart';

/// Real-time classroom session backed by Firestore snapshots.
///
/// Cloud schema:
///   live_sessions/{classroomId}
///     - the session doc; status, current_activity, teacher_uid
///   live_sessions/{classroomId}/responses/{activityId}_{profileId}
///     - one response doc per (activity, student) — id collision is the
///       point: a re-submit overwrites instead of stacking.
///
/// Reads are cloud-only (no Hive cache) because the whole point is
/// real-time visibility. If the device is offline, the snapshot stream
/// stays warm via Firestore's local cache and reconciles on reconnect.
class LiveSessionService {
  const LiveSessionService();

  FirebaseFirestore get _db => FirebaseService.db;

  DocumentReference<Map<String, dynamic>> _sessionRef(String classroomId) =>
      _db.collection('live_sessions').doc(classroomId);

  CollectionReference<Map<String, dynamic>> _responsesRef(String classroomId) =>
      _sessionRef(classroomId).collection('responses');

  // ─── Teacher API ──────────────────────────────────────

  /// Start a new session (or resume the existing one). Idempotent —
  /// merges `started_at` and `status` so calling this twice in a row
  /// doesn't reset the activity.
  Future<LiveSession> startSession({
    required String classroomId,
    required String teacherProfileId,
  }) async {
    final session = LiveSession(
      classroomId: classroomId,
      teacherProfileId: teacherProfileId,
      teacherUid: FirebaseService.currentUid,
      startedAt: DateTime.now(),
    );
    await _sessionRef(classroomId).set(
      session.toJson(),
      SetOptions(merge: true),
    );
    return session;
  }

  /// Push a new activity to all subscribed students. Replaces any
  /// previous `current_activity` and bumps the doc — the snapshot fires
  /// on every connected device within ~100ms.
  Future<LiveActivity> pushFlashcard({
    required String classroomId,
    required String flashcardId,
  }) async {
    final activity = LiveActivity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: LiveActivityType.flashcard,
      payload: {'flashcard_id': flashcardId},
      pushedAt: DateTime.now(),
    );
    await _sessionRef(classroomId).set(
      {'current_activity': activity.toJson()},
      SetOptions(merge: true),
    );
    return activity;
  }

  /// Mark the session as ended and clear the current activity so any
  /// students still subscribed see "session ended" rather than the last
  /// stale activity.
  Future<void> endSession(String classroomId) async {
    await _sessionRef(classroomId).set({
      'status': LiveSessionStatus.ended.name,
      'current_activity': null,
      'ended_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Live count + per-student detail for a given activity. The teacher
  /// dashboard subscribes to this to see responses streaming in.
  Stream<List<LiveResponse>> watchResponses({
    required String classroomId,
    required String activityId,
  }) {
    return _responsesRef(classroomId)
        .where('activity_id', isEqualTo: activityId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                LiveResponse.fromJson(Map<String, dynamic>.from(d.data())))
            .toList()
          ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt)));
  }

  // ─── Student API ──────────────────────────────────────

  /// Subscribe to the session doc itself — fires whenever the teacher
  /// pushes a new activity, ends the session, or updates status.
  Stream<LiveSession?> watchSession(String classroomId) {
    return _sessionRef(classroomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return LiveSession.fromJson(Map<String, dynamic>.from(data));
    });
  }

  /// Submit (or re-submit) this student's response to the current
  /// activity. Overwrites any prior submission for the same activity.
  Future<void> submitResponse({
    required String classroomId,
    required String activityId,
    required String profileId,
    required String profileName,
    Map<String, dynamic> payload = const {},
  }) async {
    final response = LiveResponse(
      activityId: activityId,
      profileId: profileId,
      profileName: profileName,
      submittedAt: DateTime.now(),
      payload: payload,
    );
    final docId = '${activityId}_$profileId';
    await _responsesRef(classroomId).doc(docId).set({
      ...response.toJson(),
      // Required by the rule — must match the writer's auth uid.
      'owner_uid': FirebaseService.currentUid,
    }, SetOptions(merge: true));
  }
}
