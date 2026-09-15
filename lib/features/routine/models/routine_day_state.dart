import 'routine_models.dart';

/// Most time an adult may add to one step in a day. A step stretched past two
/// extra hours is a different plan, and belongs in the routine itself.
const int kRoutineMaxAddedMinutes = 120;

/// An adult's change to how long one step lasts today — minutes added to it,
/// and a pause that stops its clock.
///
/// A pause lifts the lock and freezes the countdown: while [pausedAt] is set
/// the step's end moves later second by second, so the learner comes back to
/// exactly the time they had left. Resuming folds the pause into
/// [pausedSeconds] and the clock runs again.
///
/// Only a Teacher or Parent writes one, from their own dashboard, so it lives
/// in the educator's [RoutineDayActions] document. A merge keeps whichever
/// copy changed last — the whole adjustment, not a sum, because two devices
/// adding "10 minutes" to their own copies must not add twenty.
class RoutineStepAdjustment {
  final int addedMinutes;
  final int pausedSeconds;
  final DateTime? pausedAt;
  final DateTime changedAt;
  final String byProfileId;
  final String byName;

  const RoutineStepAdjustment({
    this.addedMinutes = 0,
    this.pausedSeconds = 0,
    this.pausedAt,
    required this.changedAt,
    this.byProfileId = '',
    this.byName = '',
  });

  bool get isPaused => pausedAt != null;

  /// How far the step's end has moved as of [now].
  Duration shiftAt(DateTime now) {
    var shift =
        Duration(minutes: addedMinutes) + Duration(seconds: pausedSeconds);
    final p = pausedAt;
    if (p != null && now.isAfter(p)) shift += now.difference(p);
    return shift;
  }

  RoutineStepAdjustment _next({
    int? addedMinutes,
    int? pausedSeconds,
    DateTime? pausedAt,
    bool clearPause = false,
    required DateTime at,
    required String byProfileId,
    required String byName,
  }) =>
      RoutineStepAdjustment(
        addedMinutes: addedMinutes ?? this.addedMinutes,
        pausedSeconds: pausedSeconds ?? this.pausedSeconds,
        pausedAt: clearPause ? null : (pausedAt ?? this.pausedAt),
        changedAt: at,
        byProfileId: byProfileId,
        byName: byName,
      );

  /// [minutes] more, capped at [kRoutineMaxAddedMinutes] in total.
  RoutineStepAdjustment withAddedMinutes(
    int minutes, {
    required DateTime at,
    String byProfileId = '',
    String byName = '',
  }) =>
      _next(
        addedMinutes:
            (addedMinutes + minutes).clamp(0, kRoutineMaxAddedMinutes),
        at: at,
        byProfileId: byProfileId,
        byName: byName,
      );

  /// Stops the clock at [at]. Pausing a paused step changes nothing.
  RoutineStepAdjustment paused({
    required DateTime at,
    String byProfileId = '',
    String byName = '',
  }) {
    if (isPaused) return this;
    return _next(
      pausedAt: at,
      at: at,
      byProfileId: byProfileId,
      byName: byName,
    );
  }

  /// Starts the clock again at [at], keeping the time the pause lasted.
  RoutineStepAdjustment resumed({
    required DateTime at,
    String byProfileId = '',
    String byName = '',
  }) {
    final p = pausedAt;
    if (p == null) return this;
    final held = at.isAfter(p) ? at.difference(p).inSeconds : 0;
    return _next(
      pausedSeconds: pausedSeconds + held,
      clearPause: true,
      at: at,
      byProfileId: byProfileId,
      byName: byName,
    );
  }

  Map<String, dynamic> toJson() => {
        'added_minutes': addedMinutes,
        'paused_seconds': pausedSeconds,
        'paused_at': pausedAt?.toIso8601String(),
        'changed_at': changedAt.toIso8601String(),
        'by_profile_id': byProfileId,
        'by_name': byName,
      };

  static RoutineStepAdjustment? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final changed = raw['changed_at'] is String
        ? DateTime.tryParse(raw['changed_at'] as String)
        : null;
    if (changed == null) return null;
    int whole(Object? v, int max) => v is int ? v.clamp(0, max) : 0;
    return RoutineStepAdjustment(
      addedMinutes: whole(raw['added_minutes'], kRoutineMaxAddedMinutes),
      // A day has 86,400 seconds; a longer pause is a corrupt row.
      pausedSeconds: whole(raw['paused_seconds'], 86400),
      pausedAt: raw['paused_at'] is String
          ? DateTime.tryParse(raw['paused_at'] as String)
          : null,
      changedAt: changed,
      byProfileId: (raw['by_profile_id'] as String?) ?? '',
      byName: (raw['by_name'] as String?) ?? '',
    );
  }

  static Map<String, RoutineStepAdjustment> mapFromJson(Object? raw) {
    final out = <String, RoutineStepAdjustment>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final a = tryFromJson(value);
      if (key is String && a != null) out[key] = a;
    });
    return out;
  }

  static Map<String, dynamic> mapToJson(
    Map<String, RoutineStepAdjustment> map,
  ) =>
      {for (final e in map.entries) e.key: e.value.toJson()};

  /// Per step, whichever copy changed last. Ties keep [a], the local copy.
  static Map<String, RoutineStepAdjustment> mergeMaps(
    Map<String, RoutineStepAdjustment> a,
    Map<String, RoutineStepAdjustment> b,
  ) {
    final out = <String, RoutineStepAdjustment>{};
    for (final key in {...a.keys, ...b.keys}) {
      final x = a[key];
      final y = b[key];
      out[key] = x == null
          ? y!
          : (y == null || !y.changedAt.isAfter(x.changedAt) ? x : y);
    }
    return out;
  }
}

/// What an educator did to a learner's day from their own device.
///
/// Lives in its own Firestore document, `routine_actions/{child}_{yyyy-mm-dd}`,
/// rather than inside the learner's `routine_logs` row, for the same reason
/// `child_unlock_overrides` does: the security rules let only the learner's
/// owning device write the learner's log, and a Teacher's phone is a different
/// device with a different account. Keeping the educator's writes in a
/// document the educator owns means remote "excuse" and "mark done" work
/// between two devices without loosening the rules on the learner's record.
///
/// The learner's device watches this document the way it watches an unlock
/// override, and [RoutineDayView] joins the two into the one answer every
/// screen needs.
class RoutineDayActions {
  final String childProfileId;

  /// Date-only.
  final DateTime day;

  /// Steps an educator excused for today — the lock lifts, the step stays
  /// not done.
  final Map<String, RoutineStepMark> excused;

  /// Steps an educator marked done on the learner's behalf — "I watched them
  /// brush their teeth", from across the room or across town.
  final Map<String, RoutineStepMark> approved;

  /// Time an educator added to a step, and pauses they started — see
  /// [RoutineStepAdjustment].
  final Map<String, RoutineStepAdjustment> adjustments;

  /// The educator's "start today over", when there has been one.
  final DateTime? resetAt;
  final String resetByName;

  final DateTime updatedAt;

  const RoutineDayActions({
    required this.childProfileId,
    required this.day,
    this.excused = const <String, RoutineStepMark>{},
    this.approved = const <String, RoutineStepMark>{},
    this.adjustments = const <String, RoutineStepAdjustment>{},
    this.resetAt,
    this.resetByName = '',
    required this.updatedAt,
  });

  factory RoutineDayActions.empty(String childProfileId, DateTime day) =>
      RoutineDayActions(
        childProfileId: childProfileId,
        day: DateTime(day.year, day.month, day.day),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  String get key => dayKeyFor(childProfileId, day);

  bool get isEmpty =>
      excused.isEmpty &&
      approved.isEmpty &&
      adjustments.isEmpty &&
      resetAt == null;

  RoutineDayActions _copy({
    Map<String, RoutineStepMark>? excused,
    Map<String, RoutineStepMark>? approved,
    Map<String, RoutineStepAdjustment>? adjustments,
    DateTime? resetAt,
    String? resetByName,
    required DateTime updatedAt,
  }) =>
      RoutineDayActions(
        childProfileId: childProfileId,
        day: day,
        excused: excused ?? this.excused,
        approved: approved ?? this.approved,
        adjustments: adjustments ?? this.adjustments,
        resetAt: resetAt ?? this.resetAt,
        resetByName: resetByName ?? this.resetByName,
        updatedAt: updatedAt,
      );

  RoutineDayActions withExcuse(String stepId, RoutineStepMark mark) =>
      _copy(excused: {...excused, stepId: mark}, updatedAt: mark.lastChanged);

  RoutineDayActions withApproval(String stepId, RoutineStepMark mark) =>
      _copy(approved: {...approved, stepId: mark}, updatedAt: mark.lastChanged);

  RoutineDayActions withAdjustment(
    String stepId,
    RoutineStepAdjustment adjustment,
  ) =>
      _copy(
        adjustments: {...adjustments, stepId: adjustment},
        updatedAt: adjustment.changedAt,
      );

  RoutineDayActions withReset({required DateTime at, String byName = ''}) =>
      _copy(resetAt: at, resetByName: byName, updatedAt: at);

  /// Per-step latest mark on each side, and the latest reset.
  static RoutineDayActions merge(
    RoutineDayActions local,
    RoutineDayActions remote,
  ) {
    final a = local.resetAt;
    final b = remote.resetAt;
    final remoteResetWins = b != null && (a == null || b.isAfter(a));
    return RoutineDayActions(
      childProfileId: local.childProfileId.isEmpty
          ? remote.childProfileId
          : local.childProfileId,
      day: local.day,
      excused: RoutineStepMark.mergeMaps(local.excused, remote.excused),
      approved: RoutineStepMark.mergeMaps(local.approved, remote.approved),
      adjustments: RoutineStepAdjustment.mergeMaps(
        local.adjustments,
        remote.adjustments,
      ),
      resetAt: remoteResetWins ? b : a,
      resetByName: remoteResetWins ? remote.resetByName : local.resetByName,
      updatedAt: local.updatedAt.isAfter(remote.updatedAt)
          ? local.updatedAt
          : remote.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'child_profile_id': childProfileId,
        'day': dayStampOf(day),
        'excused': RoutineStepMark.mapToJson(excused),
        'approved': RoutineStepMark.mapToJson(approved),
        'adjustments': RoutineStepAdjustment.mapToJson(adjustments),
        'reset_at': resetAt?.toIso8601String(),
        'reset_by_name': resetByName,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RoutineDayActions.fromJson(Map<String, dynamic> json) {
    final dayRaw = json['day'] as String?;
    final parsed = dayRaw == null ? null : DateTime.tryParse(dayRaw);
    final day = parsed ?? DateTime.now();
    final updated = json['updated_at'] is String
        ? DateTime.tryParse(json['updated_at'] as String)
        : null;
    return RoutineDayActions(
      childProfileId: (json['child_profile_id'] as String?) ?? '',
      day: DateTime(day.year, day.month, day.day),
      excused: RoutineStepMark.mapFromJson(json['excused']),
      approved: RoutineStepMark.mapFromJson(json['approved']),
      // Absent on every day written before pause and add-time existed.
      adjustments: RoutineStepAdjustment.mapFromJson(json['adjustments']),
      resetAt: json['reset_at'] is String
          ? DateTime.tryParse(json['reset_at'] as String)
          : null,
      resetByName: (json['reset_by_name'] as String?) ?? '',
      updatedAt: updated ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// A learner's day as it actually stands: their own log, and whatever an
/// educator did to it, joined.
///
/// **Every screen that asks "is this step done?" should ask this**, not the
/// raw log. The log alone cannot see an educator's approval or excuse, and it
/// cannot see an educator's reset — a learner's device would keep showing a
/// morning the teacher had just started over.
///
/// Pure: two documents in, answers out.
class RoutineDayView {
  final RoutineDayLog log;
  final RoutineDayActions actions;

  const RoutineDayView._(this.log, this.actions);

  factory RoutineDayView.of({
    required String profileId,
    required DateTime day,
    RoutineDayLog? log,
    RoutineDayActions? actions,
  }) =>
      RoutineDayView._(
        log ?? RoutineDayLog.empty(profileId, day),
        actions ?? RoutineDayActions.empty(profileId, day),
      );

  /// The most recent "start today over" from either side.
  DateTime? get resetAt {
    final a = log.resetAt;
    final b = actions.resetAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  bool _counts(DateTime? t) {
    final reset = resetAt;
    if (reset == null) return true;
    return t != null && t.isAfter(reset);
  }

  /// The learner ticked it, since the last reset.
  bool isTicked(String stepId) =>
      log.completedStepIds.contains(stepId) &&
      (resetAt == null || _counts(log.completedAt[stepId]));

  /// An educator marked it done, since the last reset, and has not taken it
  /// back.
  RoutineStepMark? approval(String stepId) {
    final mark = actions.approved[stepId];
    if (mark == null || !mark.isActive || !_counts(mark.lastChanged)) {
      return null;
    }
    return mark;
  }

  /// The standing excuse for [stepId], from whichever side changed last.
  ///
  /// Latest-wins across both documents is what lets an educator revoke an
  /// excuse that was granted on the learner's device: the revocation is newer.
  RoutineStepMark? excuse(String stepId) {
    final mark = RoutineStepMark.latest(
      log.excused[stepId],
      actions.excused[stepId],
    );
    if (mark == null || !mark.isActive || !_counts(mark.lastChanged)) {
      return null;
    }
    return mark;
  }

  bool isDone(String stepId) => isTicked(stepId) || approval(stepId) != null;

  /// Excused and not done. A step the learner went on to do anyway is done.
  bool isExcused(String stepId) => !isDone(stepId) && excuse(stepId) != null;

  /// Nothing more is being asked of the learner for this step today.
  bool isSettled(String stepId) => isDone(stepId) || excuse(stepId) != null;

  DateTime? doneAt(String stepId) {
    if (isTicked(stepId)) return log.completedAt[stepId];
    return approval(stepId)?.at;
  }

  DateTime? lockShownAt(String stepId) {
    final t = log.lockShownAt[stepId];
    return _counts(t) ? t : null;
  }

  DateTime? escalatedAt(String stepId) {
    final t = log.escalatedAt[stepId];
    return _counts(t) ? t : null;
  }

  /// An adult's added time or pause on [stepId] since the last reset.
  RoutineStepAdjustment? adjustment(String stepId) {
    final a = actions.adjustments[stepId];
    if (a == null || !_counts(a.changedAt)) return null;
    return a;
  }

  /// Paused by an adult, and not settled since.
  bool isPaused(String stepId) =>
      !isSettled(stepId) && (adjustment(stepId)?.isPaused ?? false);

  /// When [step]'s time ends today as of [now]: its planned end, moved by any
  /// time an adult added and any pause. Null for an unscheduled step.
  ///
  /// While a step is paused this moves later with [now], which is exactly
  /// what keeps its countdown frozen.
  DateTime? endOf(RoutineStep step, DateTime now) {
    final planned = step.endsOn(now);
    if (planned == null) return null;
    final a = adjustment(step.id);
    return a == null ? planned : planned.add(a.shiftAt(now));
  }

  /// Every step whose end an adult moved, with its end as of [now] — the
  /// shape the lock enforcer takes.
  Map<String, DateTime> movedEnds(Iterable<RoutineStep> steps, DateTime now) {
    final out = <String, DateTime>{};
    for (final s in steps) {
      if (adjustment(s.id) == null) continue;
      final end = endOf(s, now);
      if (end != null) out[s.id] = end;
    }
    return out;
  }

  Set<String> get pausedIds => {
        for (final id in actions.adjustments.keys)
          if (isPaused(id)) id,
      };

  Iterable<String> get _knownIds => {
        ...log.completedStepIds,
        ...log.excused.keys,
        ...actions.approved.keys,
        ...actions.excused.keys,
      };

  Set<String> get doneIds => {
        for (final id in _knownIds)
          if (isDone(id)) id,
      };

  Set<String> get excusedIds => {
        for (final id in _knownIds)
          if (isExcused(id)) id,
      };

  /// The learner's log with its ticks replaced by what counts — for the many
  /// widgets that take a [RoutineDayLog] and only ever ask it
  /// `completedStepIds`. Approvals show as done, pre-reset ticks do not.
  RoutineDayLog get effectiveLog => RoutineDayLog(
        profileId: log.profileId,
        day: log.day,
        completedStepIds: doneIds,
        completedAt: {
          for (final id in doneIds)
            if (doneAt(id) != null) id: doneAt(id)!,
        },
        excused: log.excused,
        lockShownAt: log.lockShownAt,
        escalatedAt: log.escalatedAt,
        resetAt: resetAt,
        scheduled: log.scheduled,
        snapshotAt: log.snapshotAt,
        updatedAt: log.updatedAt,
      );
}
