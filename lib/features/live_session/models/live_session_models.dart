/// Live classroom session — the teacher (or parent) pushes one activity at a
/// time and connected learner devices render it in real time, then push their
/// responses back through Firestore snapshots. The same session also drives
/// the TV Cast display (question + raised hands + live scoreboard) and awards
/// stars to learners who answer correctly, per the educator's scoring rules.
library;

/// What kind of activity is currently on learner screens.
///
/// `flashcard` is kept first so previously-serialized activities (enum parsed
/// by name) keep deserializing. The interactive types are appended.
enum LiveActivityType {
  /// Legacy "show a flashcard, learner taps Got it!" acknowledgement.
  flashcard,

  /// A text prompt with 2–4 text options; one is correct.
  multipleChoice,

  /// A flashcard image/emoji; learner picks the matching word from options.
  pictureChoice,

  /// A statement the learner marks true or false.
  trueFalse,

  /// An FSL sign (flashcard with a video); learner picks the matching word,
  /// or — when [LiveActivity.selfReport] is true — self-reports "I got it".
  fslSign,
}

extension LiveActivityTypeX on LiveActivityType {
  /// Whether the type renders a list of tappable text options (vs. a
  /// true/false pair or a self-report button).
  bool get hasOptions =>
      this == LiveActivityType.multipleChoice ||
      this == LiveActivityType.pictureChoice ||
      this == LiveActivityType.fslSign;
}

/// One activity pushed by the educator. The full lifecycle:
///   educator pushes → all learners see it → learners respond → educator
///   ends or pushes the next one.
class LiveActivity {
  /// Stable identifier. Uses pushed-at microsecondsSinceEpoch so two quick
  /// pushes never collide on the same id.
  final String id;
  final LiveActivityType type;

  /// Type-specific data:
  ///   flashcard      → `{flashcard_id}`
  ///   multipleChoice → `{prompt, options:[String], correct_index}`
  ///   pictureChoice  → `{flashcard_id, options:[String], correct_index}`
  ///   trueFalse      → `{statement, correct_value:bool}`
  ///   fslSign        → `{flashcard_id, options:[String], correct_index,
  ///                       self_report:bool}`
  final Map<String, dynamic> payload;
  final DateTime pushedAt;

  /// Optional per-activity star override. When null, the session's
  /// [LiveScoringRules.baseStars] applies.
  final int? points;

  /// 1-based position within the pushed set, for the TV "Q 2 / 5" pill.
  /// Null for one-off pushes.
  final int? questionNumber;
  final int? totalQuestions;

  const LiveActivity({
    required this.id,
    required this.type,
    required this.payload,
    required this.pushedAt,
    this.points,
    this.questionNumber,
    this.totalQuestions,
  });

  // ─── Convenience constructors ─────────────────────────

  /// Monotonic suffix so two activities built in the same microsecond still
  /// get distinct ids (important when pushing a set rapidly).
  static int _idCounter = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  factory LiveActivity.flashcard({required String flashcardId}) => LiveActivity(
        id: _newId(),
        type: LiveActivityType.flashcard,
        payload: {'flashcard_id': flashcardId},
        pushedAt: DateTime.now(),
      );

  factory LiveActivity.multipleChoice({
    required String prompt,
    required List<String> options,
    required int correctIndex,
    int? points,
    int? questionNumber,
    int? totalQuestions,
  }) =>
      LiveActivity(
        id: _newId(),
        type: LiveActivityType.multipleChoice,
        payload: {
          'prompt': prompt,
          'options': options,
          'correct_index': correctIndex,
        },
        pushedAt: DateTime.now(),
        points: points,
        questionNumber: questionNumber,
        totalQuestions: totalQuestions,
      );

  factory LiveActivity.pictureChoice({
    required String flashcardId,
    required List<String> options,
    required int correctIndex,
    int? points,
    int? questionNumber,
    int? totalQuestions,
  }) =>
      LiveActivity(
        id: _newId(),
        type: LiveActivityType.pictureChoice,
        payload: {
          'flashcard_id': flashcardId,
          'options': options,
          'correct_index': correctIndex,
        },
        pushedAt: DateTime.now(),
        points: points,
        questionNumber: questionNumber,
        totalQuestions: totalQuestions,
      );

  factory LiveActivity.trueFalse({
    required String statement,
    required bool correctValue,
    int? points,
    int? questionNumber,
    int? totalQuestions,
  }) =>
      LiveActivity(
        id: _newId(),
        type: LiveActivityType.trueFalse,
        payload: {
          'statement': statement,
          'correct_value': correctValue,
        },
        pushedAt: DateTime.now(),
        points: points,
        questionNumber: questionNumber,
        totalQuestions: totalQuestions,
      );

  factory LiveActivity.fslSign({
    required String flashcardId,
    List<String> options = const [],
    int correctIndex = 0,
    bool selfReport = false,
    int? points,
    int? questionNumber,
    int? totalQuestions,
  }) =>
      LiveActivity(
        id: _newId(),
        type: LiveActivityType.fslSign,
        payload: {
          'flashcard_id': flashcardId,
          'options': options,
          'correct_index': correctIndex,
          'self_report': selfReport,
        },
        pushedAt: DateTime.now(),
        points: points,
        questionNumber: questionNumber,
        totalQuestions: totalQuestions,
      );

  /// A fresh, pushable copy of this activity — new id + pushedAt, with the
  /// given 1-based position stamped for the TV "Q n / t" pill. Used when
  /// pushing a saved template so each push is a distinct activity (distinct
  /// response docs).
  LiveActivity forPush({int? questionNumber, int? totalQuestions}) =>
      LiveActivity(
        id: _newId(),
        type: type,
        payload: Map<String, dynamic>.from(payload),
        pushedAt: DateTime.now(),
        points: points,
        questionNumber: questionNumber,
        totalQuestions: totalQuestions,
      );

  // ─── Typed accessors ──────────────────────────────────

  String? get flashcardId => payload['flashcard_id'] as String?;

  /// The headline text shown above the answer controls. Empty for picture /
  /// FSL activities where the prompt is the image/sign itself.
  String get prompt {
    switch (type) {
      case LiveActivityType.multipleChoice:
        return payload['prompt'] as String? ?? '';
      case LiveActivityType.trueFalse:
        return payload['statement'] as String? ?? '';
      case LiveActivityType.pictureChoice:
      case LiveActivityType.fslSign:
      case LiveActivityType.flashcard:
        return '';
    }
  }

  List<String> get options {
    final raw = payload['options'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  int get correctIndex => (payload['correct_index'] as num?)?.toInt() ?? 0;

  bool get correctValue => payload['correct_value'] as bool? ?? false;

  bool get selfReport => payload['self_report'] as bool? ?? false;

  /// Whether [answer] is the correct response for this activity.
  ///   • options-based: [answer] is the chosen option index (int).
  ///   • trueFalse: [answer] is a bool.
  ///   • fslSign self-report / flashcard: [answer] true means "I got it".
  bool isCorrectAnswer(Object? answer) {
    switch (type) {
      case LiveActivityType.multipleChoice:
      case LiveActivityType.pictureChoice:
        return answer is int && answer == correctIndex;
      case LiveActivityType.trueFalse:
        return answer is bool && answer == correctValue;
      case LiveActivityType.fslSign:
        if (selfReport) return answer == true;
        return answer is int && answer == correctIndex;
      case LiveActivityType.flashcard:
        return answer == true;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'pushed_at': pushedAt.toIso8601String(),
        if (points != null) 'points': points,
        if (questionNumber != null) 'question_number': questionNumber,
        if (totalQuestions != null) 'total_questions': totalQuestions,
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
      points: (j['points'] as num?)?.toInt(),
      questionNumber: (j['question_number'] as num?)?.toInt(),
      totalQuestions: (j['total_questions'] as num?)?.toInt(),
    );
  }
}

/// Educator-configured rules for awarding stars during a live session.
///
/// Defaults keep the legacy flashcard flow unaffected: base stars only, no
/// bonuses, no cap. All values are non-negative; [sessionCap] == 0 means
/// "no cap". Computation lives in `live_scoring.dart` so it can be unit-tested
/// and applied identically on every learner device.
class LiveScoringRules {
  /// Stars granted for any correct answer.
  final int baseStars;

  /// Maximum extra stars from the speed bonus (0 disables it). Awarded on a
  /// linear decay from full (answered instantly) to zero (answered at or
  /// after [speedWindowSec]).
  final int speedBonusMax;

  /// Window over which the speed bonus decays to zero, in seconds.
  final int speedWindowSec;

  /// Extra stars for the first learner to answer a question correctly.
  final int firstCorrectBonus;

  /// Maximum stars any learner can earn across the whole session. 0 = no cap.
  final int sessionCap;

  const LiveScoringRules({
    this.baseStars = 2,
    this.speedBonusMax = 0,
    this.speedWindowSec = 20,
    this.firstCorrectBonus = 0,
    this.sessionCap = 0,
  });

  bool get speedBonusEnabled => speedBonusMax > 0 && speedWindowSec > 0;
  bool get firstCorrectEnabled => firstCorrectBonus > 0;
  bool get hasCap => sessionCap > 0;

  LiveScoringRules copyWith({
    int? baseStars,
    int? speedBonusMax,
    int? speedWindowSec,
    int? firstCorrectBonus,
    int? sessionCap,
  }) =>
      LiveScoringRules(
        baseStars: baseStars ?? this.baseStars,
        speedBonusMax: speedBonusMax ?? this.speedBonusMax,
        speedWindowSec: speedWindowSec ?? this.speedWindowSec,
        firstCorrectBonus: firstCorrectBonus ?? this.firstCorrectBonus,
        sessionCap: sessionCap ?? this.sessionCap,
      );

  Map<String, dynamic> toJson() => {
        'base_stars': baseStars,
        'speed_bonus_max': speedBonusMax,
        'speed_window_sec': speedWindowSec,
        'first_correct_bonus': firstCorrectBonus,
        'session_cap': sessionCap,
      };

  factory LiveScoringRules.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LiveScoringRules();
    return LiveScoringRules(
      baseStars: (j['base_stars'] as num?)?.toInt() ?? 2,
      speedBonusMax: (j['speed_bonus_max'] as num?)?.toInt() ?? 0,
      speedWindowSec: (j['speed_window_sec'] as num?)?.toInt() ?? 20,
      firstCorrectBonus: (j['first_correct_bonus'] as num?)?.toInt() ?? 0,
      sessionCap: (j['session_cap'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiveScoringRules &&
      other.baseStars == baseStars &&
      other.speedBonusMax == speedBonusMax &&
      other.speedWindowSec == speedWindowSec &&
      other.firstCorrectBonus == firstCorrectBonus &&
      other.sessionCap == sessionCap;

  @override
  int get hashCode => Object.hash(
        baseStars,
        speedBonusMax,
        speedWindowSec,
        firstCorrectBonus,
        sessionCap,
      );
}

/// Who owns the live session — drives which security-rule ownership check
/// applies (classroom teacher vs. home-group parent).
enum LiveSessionOwnerKind { classroom, homeGroup }

enum LiveSessionStatus {
  active,
  ended,
}

/// The session doc itself. Lives at `live_sessions/{sessionKey}` where
/// `sessionKey` is the classroom id (teacher) or home-group id (parent).
class LiveSession {
  /// The session key — a classroom id or a home-group id. Stored under the
  /// legacy `classroom_id` field for backwards compatibility.
  final String sessionKey;
  final LiveSessionOwnerKind ownerKind;

  /// Profile id of the educator hosting the session.
  final String ownerProfileId;

  /// The educator's auth uid — duplicated here so the rule can verify
  /// without an extra `get()` on profiles/{ownerProfileId}.
  final String? ownerUid;

  final LiveSessionStatus status;

  /// Null between activities (or before the educator pushes the first).
  final LiveActivity? currentActivity;

  /// Star scoring rules the learner devices apply on a correct answer.
  final LiveScoringRules scoring;

  final DateTime startedAt;
  final DateTime? endedAt;

  const LiveSession({
    required this.sessionKey,
    this.ownerKind = LiveSessionOwnerKind.classroom,
    required this.ownerProfileId,
    this.ownerUid,
    this.status = LiveSessionStatus.active,
    this.currentActivity,
    this.scoring = const LiveScoringRules(),
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toJson() => {
        // `classroom_id` is the legacy key name; it now holds the session key
        // (classroom OR home-group id).
        'classroom_id': sessionKey,
        'owner_kind': ownerKind.name,
        'owner_profile_id': ownerProfileId,
        // Keep the legacy fields populated so older readers and the existing
        // security rule (which checks `teacher_uid`) still work.
        'teacher_profile_id': ownerProfileId,
        'teacher_uid': ownerUid,
        'owner_uid': ownerUid,
        'status': status.name,
        'current_activity': currentActivity?.toJson(),
        'scoring': scoring.toJson(),
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      };

  factory LiveSession.fromJson(Map<String, dynamic> j) {
    final statusName = j['status'] as String? ?? 'active';
    final ownerKindName = j['owner_kind'] as String? ?? 'classroom';
    final activityJson = j['current_activity'];
    return LiveSession(
      sessionKey: j['classroom_id'] as String? ?? j['session_key'] as String,
      ownerKind: LiveSessionOwnerKind.values.firstWhere(
        (k) => k.name == ownerKindName,
        orElse: () => LiveSessionOwnerKind.classroom,
      ),
      ownerProfileId: j['owner_profile_id'] as String? ??
          j['teacher_profile_id'] as String? ??
          '',
      ownerUid: j['owner_uid'] as String? ?? j['teacher_uid'] as String?,
      status: LiveSessionStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => LiveSessionStatus.active,
      ),
      currentActivity: activityJson is Map
          ? LiveActivity.fromJson(Map<String, dynamic>.from(activityJson))
          : null,
      scoring: LiveScoringRules.fromJson(
        j['scoring'] is Map
            ? Map<String, dynamic>.from(j['scoring'] as Map)
            : null,
      ),
      startedAt: DateTime.tryParse(j['started_at'] as String? ?? '') ??
          DateTime.now(),
      endedAt: j['ended_at'] != null
          ? DateTime.tryParse(j['ended_at'] as String)
          : null,
    );
  }
}

/// A reusable, educator-authored set of activities (a "quiz"). Persisted
/// locally per educator profile and pushed one activity at a time during a
/// live session. Stored in Hive (not Firestore) — it's authoring data, not
/// live state.
class LiveActivitySet {
  final String id;
  final String title;
  final List<LiveActivity> activities;
  final String createdBy;
  final DateTime createdAt;

  const LiveActivitySet({
    required this.id,
    required this.title,
    required this.activities,
    required this.createdBy,
    required this.createdAt,
  });

  LiveActivitySet copyWith({String? title, List<LiveActivity>? activities}) =>
      LiveActivitySet(
        id: id,
        title: title ?? this.title,
        activities: activities ?? this.activities,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'activities': activities.map((a) => a.toJson()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory LiveActivitySet.fromJson(Map<String, dynamic> j) {
    final rawActivities = j['activities'] as List? ?? const [];
    return LiveActivitySet(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Untitled',
      activities: rawActivities
          .whereType<Map>()
          .map((m) => LiveActivity.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      createdBy: j['created_by'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// One learner response to one activity. Stored at
/// `live_sessions/{sessionKey}/responses/{activityId}_{profileId}` so
/// re-submits are idempotent (same id overwrites).
class LiveResponse {
  final String activityId;
  final String profileId;
  final String profileName;
  final DateTime submittedAt;

  /// Whether the response was correct (evaluated on the learner device).
  final bool isCorrect;

  /// The chosen answer — an option index (int) or a bool. Stored so the
  /// educator dashboard can show what each learner picked.
  final Object? answer;

  /// Milliseconds from the activity being pushed to the learner submitting.
  /// Backs the speed bonus + a "fastest" display.
  final int elapsedMs;

  /// Stars the learner's device awarded itself for this response (for the
  /// educator's live scoreboard; the authoritative balance lives in the
  /// learner's own progress doc).
  final int starsAwarded;

  const LiveResponse({
    required this.activityId,
    required this.profileId,
    required this.profileName,
    required this.submittedAt,
    this.isCorrect = false,
    this.answer,
    this.elapsedMs = 0,
    this.starsAwarded = 0,
  });

  Map<String, dynamic> toJson() => {
        'activity_id': activityId,
        'profile_id': profileId,
        'profile_name': profileName,
        'submitted_at': submittedAt.toIso8601String(),
        'is_correct': isCorrect,
        'answer': answer,
        'elapsed_ms': elapsedMs,
        'stars_awarded': starsAwarded,
      };

  factory LiveResponse.fromJson(Map<String, dynamic> j) {
    return LiveResponse(
      activityId: j['activity_id'] as String,
      profileId: j['profile_id'] as String,
      profileName: j['profile_name'] as String? ?? 'Unknown',
      submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      isCorrect: j['is_correct'] as bool? ??
          // Legacy flashcard responses stored `{got_it:true}` in payload.
          (j['payload'] is Map &&
              (j['payload'] as Map)['got_it'] == true),
      answer: j['answer'],
      elapsedMs: (j['elapsed_ms'] as num?)?.toInt() ?? 0,
      starsAwarded: (j['stars_awarded'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A learner's raised hand. Stored at
/// `live_sessions/{sessionKey}/hands/{profileId}` so a learner has at most
/// one outstanding hand and lowering/clearing it is idempotent.
class RaisedHand {
  final String profileId;
  final String profileName;
  final DateTime raisedAt;

  /// False once the learner lowers it or the educator clears it. Kept (rather
  /// than deleted) so the toggle reads cleanly on the learner device.
  final bool active;

  const RaisedHand({
    required this.profileId,
    required this.profileName,
    required this.raisedAt,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'profile_name': profileName,
        'raised_at': raisedAt.toIso8601String(),
        'active': active,
      };

  factory RaisedHand.fromJson(Map<String, dynamic> j) {
    return RaisedHand(
      profileId: j['profile_id'] as String? ?? '',
      profileName: j['profile_name'] as String? ?? 'Unknown',
      raisedAt: DateTime.tryParse(j['raised_at'] as String? ?? '') ??
          DateTime.now(),
      active: j['active'] as bool? ?? true,
    );
  }
}

/// One row of the live scoreboard, aggregated from responses on the educator
/// device and forwarded to the TV.
class LiveScoreRow {
  final String profileId;
  final String name;
  final int stars;
  final int correct;

  const LiveScoreRow({
    required this.profileId,
    required this.name,
    required this.stars,
    required this.correct,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'stars': stars,
        'correct': correct,
      };

  @override
  bool operator ==(Object other) =>
      other is LiveScoreRow &&
      other.profileId == profileId &&
      other.name == name &&
      other.stars == stars &&
      other.correct == correct;

  @override
  int get hashCode => Object.hash(profileId, name, stars, correct);
}
