import 'routine_models.dart';

/// One calendar day of a learner's routine, scored.
class RoutineDaySummary {
  final DateTime day;

  /// Steps the routines scheduled for this day.
  final int scheduled;

  /// Steps the learner ticked off.
  final int done;

  const RoutineDaySummary({
    required this.day,
    required this.scheduled,
    required this.done,
  });

  /// A day with nothing scheduled is a **rest day**, not a failure.
  ///
  /// This distinction is the whole reason the type exists: a Mon/Wed/Fri
  /// routine leaves four blank days a week, and averaging those in as zeroes
  /// would tell an educator their learner is failing when they are doing
  /// exactly what was asked.
  bool get isRestDay => scheduled == 0;

  bool get isComplete => scheduled > 0 && done >= scheduled;

  /// 0.0–1.0, or null on a rest day — null rather than zero so callers are
  /// forced to decide what a rest day means rather than silently averaging it.
  double? get fraction => scheduled == 0 ? null : done / scheduled;
}

/// How reliably one step gets done.
class RoutineStepReliability {
  final String stepId;
  final String title;
  final String emoji;

  /// Days this step was scheduled, and days it was ticked.
  final int scheduled;
  final int done;

  const RoutineStepReliability({
    required this.stepId,
    required this.title,
    required this.emoji,
    required this.scheduled,
    required this.done,
  });

  int get missed => scheduled - done;

  double get rate => scheduled == 0 ? 0 : done / scheduled;
}

/// A learner's routine history, scored over a window of days.
///
/// Pure — it takes the logs and the routines and returns numbers, so the
/// arithmetic that an educator will act on ("bath time is where it stalls")
/// is testable without Hive, Firestore or a clock.
///
/// **Known limitation, stated rather than hidden:** past days are scored
/// against the routines as they are *today*. There is no snapshot of what was
/// scheduled on a Tuesday three weeks ago, so editing a routine re-scores its
/// history. That is the honest trade for not writing a schedule snapshot on
/// every day the learner never opened the app; the screen says the window is
/// "based on the current routine" so nobody reads it as a permanent record.
class RoutineHistory {
  final List<RoutineDaySummary> days;
  final List<RoutineStepReliability> steps;

  const RoutineHistory({required this.days, required this.steps});

  /// Days that actually had a routine, newest first.
  List<RoutineDaySummary> get activeDays =>
      days.where((d) => !d.isRestDay).toList();

  /// Share of scheduled steps completed across the window, 0.0–1.0.
  /// Rest days are excluded; a window of only rest days returns null.
  double? get completionRate {
    final active = activeDays;
    if (active.isEmpty) return null;
    final scheduled = active.fold<int>(0, (s, d) => s + d.scheduled);
    if (scheduled == 0) return null;
    final done = active.fold<int>(0, (s, d) => s + d.done);
    return done / scheduled;
  }

  /// Days where every scheduled step was ticked.
  int get completeDays => days.where((d) => d.isComplete).length;

  /// Consecutive fully-complete days ending at the most recent active day.
  ///
  /// Rest days are **skipped, not broken** — a Mon/Wed/Fri routine should not
  /// lose its streak every Tuesday for doing exactly what was asked. Today is
  /// skipped too when it is still incomplete: a streak should not evaporate at
  /// 9am because the day is not finished yet.
  int streak({DateTime? now}) {
    final today = now ?? DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    var count = 0;
    for (final d in days) {
      if (d.isRestDay) continue;
      final isToday = d.day == todayKey;
      if (d.isComplete) {
        count++;
        continue;
      }
      if (isToday) continue; // still in progress
      break;
    }
    return count;
  }

  /// The steps that stall most often, worst first. Only steps that were
  /// actually missed, so an educator reads a short list of real problems
  /// rather than a full roster sorted by luck.
  List<RoutineStepReliability> get stalls {
    final out = steps.where((s) => s.missed > 0).toList()
      ..sort((a, b) {
        final byMissed = b.missed.compareTo(a.missed);
        if (byMissed != 0) return byMissed;
        return a.rate.compareTo(b.rate);
      });
    return out;
  }

  bool get isEmpty => activeDays.isEmpty;

  /// Scores [logs] against [routines].
  ///
  /// [logs] should be newest-first (as `HiveService.getRoutineHistory`
  /// returns them); the result preserves that order.
  factory RoutineHistory.from({
    required List<Routine> routines,
    required List<RoutineDayLog> logs,
    required String Function(RoutineStep step) titleOf,
    required String Function(RoutineStep step) emojiOf,
  }) {
    final live = routines.where((r) => r.enabled).toList();

    final days = <RoutineDaySummary>[];
    final scheduledCount = <String, int>{};
    final doneCount = <String, int>{};
    final stepById = <String, RoutineStep>{};

    for (final log in logs) {
      var scheduled = 0;
      var done = 0;
      for (final routine in live) {
        if (!routine.runsOn(log.day)) continue;
        for (final step in routine.orderedSteps) {
          scheduled++;
          stepById[step.id] = step;
          scheduledCount[step.id] = (scheduledCount[step.id] ?? 0) + 1;
          if (log.completedStepIds.contains(step.id)) {
            done++;
            doneCount[step.id] = (doneCount[step.id] ?? 0) + 1;
          }
        }
      }
      days.add(
        RoutineDaySummary(day: log.day, scheduled: scheduled, done: done),
      );
    }

    final steps = <RoutineStepReliability>[];
    for (final entry in scheduledCount.entries) {
      final step = stepById[entry.key]!;
      steps.add(
        RoutineStepReliability(
          stepId: entry.key,
          title: titleOf(step),
          emoji: emojiOf(step),
          scheduled: entry.value,
          done: doneCount[entry.key] ?? 0,
        ),
      );
    }

    return RoutineHistory(days: days, steps: steps);
  }
}
