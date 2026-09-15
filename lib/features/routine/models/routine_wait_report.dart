import 'routine_day_state.dart';
import 'routine_models.dart';

/// One locked step on one day, as the weekly report counts it.
class RoutineWaitEntry {
  final DateTime day;
  final RoutineStep step;

  /// Whether the learner's device showed the lock at all. A tablet that was
  /// switched off never did, and its learner waited for nothing.
  final bool lockShown;

  /// Minutes the lock was on screen before it let go — its time ending, or an
  /// adult ending or excusing it. Time an adult paused it does not count.
  final int minutesWaited;

  /// An adult finished the step before its time ended.
  final bool endedEarly;

  /// Who ended it early: a Teacher's or Parent's name, or empty when it was
  /// done on the learner's tablet through the adult check.
  final String endedEarlyBy;

  /// An adult excused the step for the day.
  final bool excused;
  final String excusedBy;

  /// Minutes an adult added to the step.
  final int addedMinutes;

  /// Whether an adult paused the step at some point.
  final bool paused;

  const RoutineWaitEntry({
    required this.day,
    required this.step,
    required this.lockShown,
    required this.minutesWaited,
    this.endedEarly = false,
    this.endedEarlyBy = '',
    this.excused = false,
    this.excusedBy = '',
    this.addedMinutes = 0,
    this.paused = false,
  });
}

/// One step's week, summed.
class RoutineWaitStepSummary {
  final RoutineStep step;

  /// Days the lock for this step actually appeared.
  final int locksShown;
  final int minutesWaited;
  final int endedEarly;
  final int excused;
  final int addedMinutes;

  const RoutineWaitStepSummary({
    required this.step,
    required this.locksShown,
    required this.minutesWaited,
    required this.endedEarly,
    required this.excused,
    required this.addedMinutes,
  });
}

/// A learner's last week of routine locks: how long they waited, and how
/// often an adult stepped in — ended a step early, excused it, or gave it more
/// time.
///
/// Pure, like [RoutineLockSummary]: logs, educator actions, routines and the
/// clock in, numbers out. The educator's history screen shows it; the tests
/// pin the arithmetic without Hive or a clock.
///
/// **Days are read as they were planned.** A day whose schedule was frozen
/// with its times ([RoutineDayStep.hasTiming]) is scored against that; an
/// older day falls back to the routine as it is now, the same trade the
/// history strip makes.
class RoutineWaitReport {
  final List<RoutineWaitEntry> entries;

  /// The first and last calendar day the report covers.
  final DateTime from;
  final DateTime to;

  const RoutineWaitReport({
    required this.entries,
    required this.from,
    required this.to,
  });

  bool get isEmpty => entries.isEmpty;

  int get locksShown => entries.where((e) => e.lockShown).length;

  int get minutesWaited =>
      entries.fold<int>(0, (sum, e) => sum + e.minutesWaited);

  int get endedEarly => entries.where((e) => e.endedEarly).length;

  int get excused => entries.where((e) => e.excused).length;

  int get addedMinutes =>
      entries.fold<int>(0, (sum, e) => sum + e.addedMinutes);

  int get pauses => entries.where((e) => e.paused).length;

  /// Average minutes per lock that appeared, or null when none did.
  int? get averageWait =>
      locksShown == 0 ? null : (minutesWaited / locksShown).round();

  /// How many steps each adult ended early. The empty name is the learner's
  /// tablet (the adult check), which identifies nobody.
  Map<String, int> get endedEarlyBy {
    final out = <String, int>{};
    for (final e in entries) {
      if (!e.endedEarly) continue;
      out[e.endedEarlyBy] = (out[e.endedEarlyBy] ?? 0) + 1;
    }
    return out;
  }

  /// Per step, longest total wait first.
  List<RoutineWaitStepSummary> get steps {
    final byId = <String, List<RoutineWaitEntry>>{};
    for (final e in entries) {
      (byId[e.step.id] ??= []).add(e);
    }
    final out = [
      for (final list in byId.values)
        RoutineWaitStepSummary(
          step: list.first.step,
          locksShown: list.where((e) => e.lockShown).length,
          minutesWaited: list.fold<int>(0, (s, e) => s + e.minutesWaited),
          endedEarly: list.where((e) => e.endedEarly).length,
          excused: list.where((e) => e.excused).length,
          addedMinutes: list.fold<int>(0, (s, e) => s + e.addedMinutes),
        ),
    ]..sort((a, b) {
        final byWait = b.minutesWaited.compareTo(a.minutesWaited);
        if (byWait != 0) return byWait;
        return b.endedEarly.compareTo(a.endedEarly);
      });
    return out;
  }

  /// An ended-early finish has to beat the step's end by more than this, so
  /// the clock's own finish — stamped at the end itself — never counts.
  static const Duration earlySlack = Duration(minutes: 1);

  /// Scores the [days] calendar days ending today.
  ///
  /// [logs] and [actions] may be in any order and may miss days.
  factory RoutineWaitReport.from({
    required String profileId,
    required List<Routine> routines,
    required List<RoutineDayLog> logs,
    required List<RoutineDayActions> actions,
    required DateTime now,
    int days = 7,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(Duration(days: days - 1));
    final logsByDay = {for (final l in logs) dayStampOf(l.day): l};
    final actsByDay = {for (final a in actions) dayStampOf(a.day): a};

    final entries = <RoutineWaitEntry>[];
    for (var i = 0; i < days; i++) {
      final day = first.add(Duration(days: i));
      final stamp = dayStampOf(day);
      final log = logsByDay[stamp];
      final acts = actsByDay[stamp];
      final view = RoutineDayView.of(
        profileId: profileId,
        day: day,
        log: log,
        actions: acts,
      );
      // The latest moment anything on this day can have happened.
      final dayOver = day.add(const Duration(days: 1));
      final clock = now.isBefore(dayOver) ? now : dayOver;

      for (final step in _lockingStepsOn(day, log, routines)) {
        final start = step.startsOn(day);
        final planned = step.endsOn(day);
        if (start == null || planned == null || clock.isBefore(start)) {
          continue;
        }
        final adj = view.adjustment(step.id);
        final end = adj == null ? planned : planned.add(adj.shiftAt(clock));

        final shown = view.lockShownAt(step.id);
        final approval = view.approval(step.id);
        final excuse = view.excuse(step.id);
        final doneAt = view.doneAt(step.id);

        // When the lock let go: an adult's finish or excuse before the end,
        // or the end itself — never later than now.
        var letGo = end;
        for (final t in [doneAt, excuse?.at]) {
          if (t != null && t.isBefore(letGo)) letGo = t;
        }
        if (clock.isBefore(letGo)) letGo = clock;

        var waited = 0;
        if (shown != null) {
          final begin = shown.isAfter(start) ? shown : start;
          var seconds = letGo.difference(begin).inSeconds;
          if (adj != null) {
            // The lock was lifted while paused.
            var pausedFor = adj.pausedSeconds;
            final p = adj.pausedAt;
            if (p != null && letGo.isAfter(p)) {
              pausedFor += letGo.difference(p).inSeconds;
            }
            seconds -= pausedFor;
          }
          waited = seconds <= 0 ? 0 : (seconds / 60).round();
        }

        final early = doneAt != null && doneAt.isBefore(end.subtract(earlySlack));
        final byName = approval != null && early ? approval.byName : '';

        final happened = shown != null ||
            early ||
            excuse != null ||
            adj != null;
        if (!happened) continue;

        entries.add(RoutineWaitEntry(
          day: day,
          step: step,
          lockShown: shown != null,
          minutesWaited: waited,
          endedEarly: early,
          endedEarlyBy: byName,
          excused: excuse != null && !view.isDone(step.id),
          excusedBy: excuse == null ||
                  excuse.source == RoutineMarkSource.learnerDevice
              ? ''
              : excuse.byName,
          addedMinutes: adj?.addedMinutes ?? 0,
          paused: adj != null && (adj.pausedSeconds > 0 || adj.isPaused),
        ));
      }
    }
    return RoutineWaitReport(entries: entries, from: first, to: today);
  }

  /// The steps that could lock on [day]: from its frozen schedule when that
  /// was frozen with times, otherwise from the routines as they are now.
  static List<RoutineStep> _lockingStepsOn(
    DateTime day,
    RoutineDayLog? log,
    List<Routine> routines,
  ) {
    if (log != null &&
        log.scheduled.isNotEmpty &&
        log.scheduled.every((s) => s.hasTiming)) {
      return [
        for (final s in log.scheduled)
          if (s.locks) s.toStep(),
      ];
    }
    return [
      for (final r in routines)
        if (r.runsOn(day)) ...r.lockingSteps,
    ];
  }
}
