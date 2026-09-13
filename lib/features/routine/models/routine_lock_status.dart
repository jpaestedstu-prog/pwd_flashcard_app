import '../../../core/services/lock_enforcer.dart';
import 'routine_day_state.dart';
import 'routine_models.dart';

/// How far ahead of a locking step the learner is warned, unless the step's
/// own reminder asks for more notice.
const int kRoutineWarnMinutes = 5;

/// Where one locking step stands right now.
enum RoutineStepPhase {
  /// Its time is some way off.
  later,

  /// Its time is close enough to warn about.
  upcoming,

  /// Its time has come; the learner's device is (or will be) held on it.
  waiting,

  /// Held for longer than the routine's escalation allows.
  needsHelp,

  /// Ticked by the learner or approved by an educator.
  done,

  /// Waved past by an adult. Not done.
  excused,

  /// Its window ran out without it being done or excused.
  lapsed,
}

/// One locking step's status, with everything a screen needs to say it.
class RoutineStepLockStatus {
  final Routine routine;
  final RoutineStep step;
  final RoutineStepPhase phase;
  final DateTime dueAt;
  final DateTime now;

  /// The approval or excuse behind [RoutineStepPhase.done] or
  /// [RoutineStepPhase.excused], when an adult was involved.
  final RoutineStepMark? mark;

  final DateTime? doneAt;
  final DateTime? lockShownAt;
  final DateTime? escalatedAt;

  const RoutineStepLockStatus({
    required this.routine,
    required this.step,
    required this.phase,
    required this.dueAt,
    required this.now,
    this.mark,
    this.doneAt,
    this.lockShownAt,
    this.escalatedAt,
  });

  /// How long the step has been due; zero before its time.
  Duration get waitingFor {
    final d = now.difference(dueAt);
    return d.isNegative ? Duration.zero : d;
  }

  int get minutesWaiting => waitingFor.inMinutes;

  /// Whole minutes until the step's time, rounded up and never below 1.
  int get minutesUntil {
    final d = dueAt.difference(now);
    if (d.isNegative) return 0;
    final m = (d.inSeconds / 60).ceil();
    return m < 1 ? 1 : m;
  }

  bool get isHolding =>
      phase == RoutineStepPhase.waiting || phase == RoutineStepPhase.needsHelp;

  /// Approved by an educator rather than ticked by the learner.
  bool get wasApproved => phase == RoutineStepPhase.done && mark != null;

  /// Minutes the lock held before the step was done, when both ends are known.
  int? get minutesHeld {
    final shown = lockShownAt;
    final done = doneAt;
    if (shown == null || done == null || done.isBefore(shown)) return null;
    return done.difference(shown).inMinutes;
  }
}

/// A learner's locking steps for today, and the one that matters most.
///
/// Pure — routines, the joined day and the clock in. The educator's dashboard
/// row, the routine manager and the lock screen's escalation all read this, so
/// "is Ana waiting on something?" has one answer everywhere.
///
/// This describes the **routine**, not the tablet. A learner can be due on a
/// step while their device is off, or while a daily limit outranks the routine
/// on it; the educator is told "waiting on Brushing Teeth", and "lock showing"
/// only once the learner's device has reported the lock appearing.
class RoutineLockSummary {
  final List<RoutineStepLockStatus> steps;

  const RoutineLockSummary(this.steps);

  static const RoutineLockSummary none = RoutineLockSummary([]);

  bool get isEmpty => steps.isEmpty;

  /// The earliest step holding the device, if any.
  RoutineStepLockStatus? get current {
    for (final s in steps) {
      if (s.isHolding) return s;
    }
    return null;
  }

  /// The next step close enough to warn about.
  RoutineStepLockStatus? get upcoming {
    for (final s in steps) {
      if (s.phase == RoutineStepPhase.upcoming) return s;
    }
    return null;
  }

  bool get isHolding => current != null;

  bool get needsHelp => current?.phase == RoutineStepPhase.needsHelp;

  List<RoutineStepLockStatus> get excused =>
      steps.where((s) => s.phase == RoutineStepPhase.excused).toList();

  List<RoutineStepLockStatus> get approved =>
      steps.where((s) => s.wasApproved).toList();

  static RoutineLockSummary of({
    required List<Routine> routines,
    required RoutineDayView view,
    required DateTime now,
    Duration window = kRoutineLockWindow,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final out = <RoutineStepLockStatus>[];
    for (final routine in routines) {
      if (!routine.runsOn(today)) continue;
      for (final step in routine.lockingSteps) {
        out.add(statusFor(
          routine: routine,
          step: step,
          view: view,
          now: now,
          window: window,
        ));
      }
    }
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return RoutineLockSummary(out);
  }

  static RoutineStepLockStatus statusFor({
    required Routine routine,
    required RoutineStep step,
    required RoutineDayView view,
    required DateTime now,
    Duration window = kRoutineLockWindow,
  }) {
    final dueAt =
        DateTime(now.year, now.month, now.day, step.hour ?? 0, step.minute ?? 0);
    final id = step.id;

    RoutineStepPhase phase;
    RoutineStepMark? mark;
    if (view.isDone(id)) {
      phase = RoutineStepPhase.done;
      mark = view.isTicked(id) ? null : view.approval(id);
    } else if (view.excuse(id) != null) {
      phase = RoutineStepPhase.excused;
      mark = view.excuse(id);
    } else if (now.isBefore(dueAt)) {
      final lead = step.remindMinutesBefore > 0
          ? step.remindMinutesBefore
          : kRoutineWarnMinutes;
      phase = dueAt.difference(now) <= Duration(minutes: lead)
          ? RoutineStepPhase.upcoming
          : RoutineStepPhase.later;
    } else if (now.difference(dueAt) > window) {
      phase = RoutineStepPhase.lapsed;
    } else if (routine.escalateAfterMinutes > 0 &&
        now.difference(dueAt) >=
            Duration(minutes: routine.escalateAfterMinutes)) {
      phase = RoutineStepPhase.needsHelp;
    } else {
      phase = RoutineStepPhase.waiting;
    }

    return RoutineStepLockStatus(
      routine: routine,
      step: step,
      phase: phase,
      dueAt: dueAt,
      now: now,
      mark: mark,
      doneAt: view.doneAt(id),
      lockShownAt: view.lockShownAt(id),
      escalatedAt: view.escalatedAt(id),
    );
  }
}

/// Something that happened to a learner's routine lock on one day.
enum RoutineLockEventKind {
  lockShown,
  done,
  approved,
  approvalRevoked,
  excused,
  excuseRevoked,
  escalated,
  reset,
}

class RoutineLockEvent {
  final RoutineLockEventKind kind;
  final DateTime at;

  /// Null only for [RoutineLockEventKind.reset], which is about the whole day.
  final String? stepId;

  /// The adult involved, when there was one.
  final String byName;
  final RoutineMarkSource? source;

  /// For [RoutineLockEventKind.done]: how long the lock held first.
  final int? minutesHeld;

  const RoutineLockEvent({
    required this.kind,
    required this.at,
    this.stepId,
    this.byName = '',
    this.source,
    this.minutesHeld,
  });

  /// Every recorded event of one day, newest first.
  ///
  /// Reads the raw documents rather than [RoutineDayView], on purpose: this is
  /// the audit trail, and an excuse that was later revoked, or a morning that
  /// was later started over, still happened.
  static List<RoutineLockEvent> forDay({
    required RoutineDayLog log,
    required RoutineDayActions actions,
  }) {
    final out = <RoutineLockEvent>[];
    log.lockShownAt.forEach((id, at) {
      out.add(RoutineLockEvent(
        kind: RoutineLockEventKind.lockShown,
        at: at,
        stepId: id,
      ));
    });
    log.completedAt.forEach((id, at) {
      if (!log.completedStepIds.contains(id)) return;
      final shown = log.lockShownAt[id];
      out.add(RoutineLockEvent(
        kind: RoutineLockEventKind.done,
        at: at,
        stepId: id,
        minutesHeld: shown != null && !at.isBefore(shown)
            ? at.difference(shown).inMinutes
            : null,
      ));
    });
    log.escalatedAt.forEach((id, at) {
      out.add(RoutineLockEvent(
        kind: RoutineLockEventKind.escalated,
        at: at,
        stepId: id,
      ));
    });

    void marks(
      Map<String, RoutineStepMark> map,
      RoutineLockEventKind granted,
      RoutineLockEventKind revoked,
    ) {
      map.forEach((id, mark) {
        out.add(RoutineLockEvent(
          kind: granted,
          at: mark.at,
          stepId: id,
          byName: mark.byName,
          source: mark.source,
        ));
        final r = mark.revokedAt;
        if (r != null) {
          out.add(RoutineLockEvent(
            kind: revoked,
            at: r,
            stepId: id,
            byName: mark.revokedByName,
            source: RoutineMarkSource.educator,
          ));
        }
      });
    }

    marks(
      log.excused,
      RoutineLockEventKind.excused,
      RoutineLockEventKind.excuseRevoked,
    );
    marks(
      actions.excused,
      RoutineLockEventKind.excused,
      RoutineLockEventKind.excuseRevoked,
    );
    marks(
      actions.approved,
      RoutineLockEventKind.approved,
      RoutineLockEventKind.approvalRevoked,
    );

    final reset = actions.resetAt ?? log.resetAt;
    if (reset != null) {
      out.add(RoutineLockEvent(
        kind: RoutineLockEventKind.reset,
        at: reset,
        byName: actions.resetAt != null ? actions.resetByName : '',
      ));
    }

    // Taking back an excuse the tablet granted writes that same mark, now
    // revoked, into the educator's document — so it is in both. It happened
    // once, and the log says so once.
    final seen = <String>{};
    out.retainWhere(
      (e) => seen.add('${e.kind.name}|${e.stepId}|${e.at.toIso8601String()}'),
    );

    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}
