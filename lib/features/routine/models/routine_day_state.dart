import 'routine_models.dart';

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

  /// The educator's "start today over", when there has been one.
  final DateTime? resetAt;
  final String resetByName;

  final DateTime updatedAt;

  const RoutineDayActions({
    required this.childProfileId,
    required this.day,
    this.excused = const <String, RoutineStepMark>{},
    this.approved = const <String, RoutineStepMark>{},
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

  bool get isEmpty => excused.isEmpty && approved.isEmpty && resetAt == null;

  RoutineDayActions _copy({
    Map<String, RoutineStepMark>? excused,
    Map<String, RoutineStepMark>? approved,
    DateTime? resetAt,
    String? resetByName,
    required DateTime updatedAt,
  }) =>
      RoutineDayActions(
        childProfileId: childProfileId,
        day: day,
        excused: excused ?? this.excused,
        approved: approved ?? this.approved,
        resetAt: resetAt ?? this.resetAt,
        resetByName: resetByName ?? this.resetByName,
        updatedAt: updatedAt,
      );

  RoutineDayActions withExcuse(String stepId, RoutineStepMark mark) =>
      _copy(excused: {...excused, stepId: mark}, updatedAt: mark.lastChanged);

  RoutineDayActions withApproval(String stepId, RoutineStepMark mark) =>
      _copy(approved: {...approved, stepId: mark}, updatedAt: mark.lastChanged);

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
