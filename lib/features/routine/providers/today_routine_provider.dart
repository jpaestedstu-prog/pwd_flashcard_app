import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../models/routine_catalog.dart';
import '../models/routine_history.dart';
import '../models/routine_models.dart';

/// Everything the signed-in learner's day amounts to, in one value.
///
/// The Home card, the Child home card and the "My Day" screen were each
/// re-deriving this from three providers and getting subtly different answers:
/// which routines run today, which steps are live, which are ticked, what is
/// next, whether the next one is late. Computing it once means the card and
/// the screen can never disagree about whether the day is finished — and the
/// disagreement would be visible, because the card sits directly above the
/// button that opens the screen.
class TodayRoutine {
  const TodayRoutine({
    required this.steps,
    required this.log,
    required this.streak,
    required this.hasEducator,
  });

  /// Every live step scheduled for today, in display order.
  final List<RoutineStep> steps;

  /// Today's completion log, or null before it has loaded.
  final RoutineDayLog? log;

  /// Consecutive fully-complete days, rest days skipped. See
  /// [RoutineHistory.streak].
  final int streak;

  /// Whether an adult is in a position to set a routine for this learner.
  ///
  /// Drives the difference between "ask your teacher" and a Player profile,
  /// who has nobody to ask and should not be told to go and ask them.
  final bool hasEducator;

  static const TodayRoutine none = TodayRoutine(
    steps: <RoutineStep>[],
    log: null,
    streak: 0,
    hasEducator: false,
  );

  bool get isEmpty => steps.isEmpty;

  int get total => steps.length;

  int get done =>
      steps.where((s) => log?.isDone(s.id) ?? false).length;

  /// 0–1, or null when nothing is scheduled — null rather than zero so a rest
  /// day never renders as a failed one.
  double? get fraction => steps.isEmpty ? null : done / steps.length;

  bool get allDone => steps.isNotEmpty && done >= steps.length;

  /// The first step not yet ticked, or null when the day is done or empty.
  RoutineStep? get nextStep {
    for (final s in steps) {
      if (!(log?.isDone(s.id) ?? false)) return s;
    }
    return null;
  }

  /// Whether [nextStep] was due before [now] — it has a clock time and that
  /// time has passed. An unscheduled step is never overdue: "after breakfast"
  /// cannot be late.
  bool isOverdue(DateTime now) {
    final step = nextStep;
    if (step == null || !step.isScheduled) return false;
    final due = DateTime(now.year, now.month, now.day, step.hour!, step.minute!);
    return now.isAfter(due);
  }
}

/// The signed-in learner's day, live.
///
/// Rebuilds when a routine changes, when a step is ticked, and — through
/// [wallClockTickerProvider] in the widgets that need it — when a step falls
/// overdue. Degrades to [TodayRoutine.none] for a learner with no profile,
/// which is the right answer rather than an error.
final todayRoutineProvider = Provider<TodayRoutine>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return TodayRoutine.none;

  final today = DateTime.now();
  // `valueOrNull` throughout: no routine, a mirror that has not opened, and a
  // cloud read that failed all mean "nothing to show", and none of them is a
  // reason to break the top of Home.
  final routines =
      ref.watch(myRoutinesProvider).valueOrNull ?? const <Routine>[];
  final log = ref
      .watch(routineDayLogProvider(routineDayKey(profile.id, today)))
      .valueOrNull;

  final steps = <RoutineStep>[
    for (final r in routines)
      if (r.enabled && r.runsOn(today)) ...r.orderedSteps,
  ];

  final filipino = ref.watch(settingsProvider).locale == 'fil';
  final history = RoutineHistory.from(
    routines: routines,
    logs: ref.watch(routineHistoryProvider(profile.id)),
    titleOf: (s) => RoutineCatalog.titleFor(s, filipino: filipino),
    emojiOf: RoutineCatalog.emojiFor,
  );

  return TodayRoutine(
    steps: steps,
    log: log,
    streak: history.streak(now: today),
    // A learner who belongs to a class or a family group has someone whose
    // job this is. A Player profile does not, and telling them to ask their
    // teacher would be pointing at nobody.
    hasEducator: !profile.isGuestPlayer &&
        (profile.classroomId != null || profile.homeGroupId != null),
  );
});
