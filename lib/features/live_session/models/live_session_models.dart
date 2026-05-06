/// Live classroom session — the teacher pushes one activity at a time
/// and connected student devices render it in real time, then push their
/// responses back through Firestore snapshots.
library;

/// What kind of activity is currently on student screens. Kept small on
/// purpose — only flashcard for v1; spelling/quiz can be added later by
/// extending this enum and the [LiveActivity.payload] schema.
enum LiveActivityType {
  flashcard,
}

/// One activity pushed by the teacher. The full lifecycle:
///   teacher pushes → all students see it → students respond → teacher
///   ends or pushes the next one.
class LiveActivity {
  /// Stable identifier. Uses pushed-at millisecondsSinceEpoch so the
  /// teacher's "push" UX maps cleanly to a unique id.
  final String id;
  final LiveActivityType type;
  /// Type-specific data. For [LiveActivityType.flashcard]: `flashcard_id`.
  final Map<String, dynamic> payload;
  final DateTime pushedAt;

  const LiveActivity({
    required this.id,
    required this.type,
    required this.payload,
    required this.pushedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'pushed_at': pushedAt.toIso8601String(),
      };

  factory LiveActivity.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String? ?? 'flashcard';
    return LiveActivity(
      id: j['id'] as String,
      type: LiveActivityType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => LiveActivityType.flashcard,
      ),
      payload: Map<String, dynamic>.from(j['payload'] as Map? ?? const {}),
      pushedAt: DateTime.tryParse(j['pushed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum LiveSessionStatus {
  active,
  ended,
}

/// The session doc itself. Lives at `live_sessions/{classroomId}`.
class LiveSession {
  final String classroomId;
  final String teacherProfileId;
  /// The teacher's auth uid — duplicated here so the rule can verify
  /// without an extra `get()` on profiles/{teacherProfileId}.
  final String? teacherUid;
  final LiveSessionStatus status;
  /// Null between activities (or before the teacher pushes the first).
  final LiveActivity? currentActivity;
  final DateTime startedAt;
  final DateTime? endedAt;

  const LiveSession({
    required this.classroomId,
    required this.teacherProfileId,
    this.teacherUid,
    this.status = LiveSessionStatus.active,
    this.currentActivity,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toJson() => {
        'classroom_id': classroomId,
        'teacher_profile_id': teacherProfileId,
        'teacher_uid': teacherUid,
        'status': status.name,
        'current_activity': currentActivity?.toJson(),
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      };

  factory LiveSession.fromJson(Map<String, dynamic> j) {
    final statusName = j['status'] as String? ?? 'active';
    final activityJson = j['current_activity'];
    return LiveSession(
      classroomId: j['classroom_id'] as String,
      teacherProfileId: j['teacher_profile_id'] as String,
      teacherUid: j['teacher_uid'] as String?,
      status: LiveSessionStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => LiveSessionStatus.active,
      ),
      currentActivity: activityJson is Map
          ? LiveActivity.fromJson(Map<String, dynamic>.from(activityJson))
          : null,
      startedAt: DateTime.tryParse(j['started_at'] as String? ?? '') ??
          DateTime.now(),
      endedAt: j['ended_at'] != null
          ? DateTime.tryParse(j['ended_at'] as String)
          : null,
    );
  }
}

/// One student response to one activity. Stored at
/// `live_sessions/{classroomId}/responses/{activityId}_{profileId}` so
/// re-submits are idempotent (same id overwrites).
class LiveResponse {
  final String activityId;
  final String profileId;
  final String profileName;
  final DateTime submittedAt;
  /// Free-form payload. For flashcard: `{got_it: true}`. Future activity
  /// types can put answer text, score, etc. here.
  final Map<String, dynamic> payload;

  const LiveResponse({
    required this.activityId,
    required this.profileId,
    required this.profileName,
    required this.submittedAt,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'activity_id': activityId,
        'profile_id': profileId,
        'profile_name': profileName,
        'submitted_at': submittedAt.toIso8601String(),
        'payload': payload,
      };

  factory LiveResponse.fromJson(Map<String, dynamic> j) {
    return LiveResponse(
      activityId: j['activity_id'] as String,
      profileId: j['profile_id'] as String,
      profileName: j['profile_name'] as String? ?? 'Unknown',
      submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      payload: Map<String, dynamic>.from(j['payload'] as Map? ?? const {}),
    );
  }
}
