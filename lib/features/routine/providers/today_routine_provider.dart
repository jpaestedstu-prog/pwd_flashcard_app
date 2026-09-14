import '../../../providers/lock_state_provider.dart' show canBeLockedByRoutine;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
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
    this.excusedIds = const <String>{},
  });

  /// Steps an adult waved past for today. Not done — the card still counts
  /// them as outstanding — but never offered as the next thing to do.
  final Set<String> excusedIds;

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
      if (!(log?.isDone(s.id) ?? false) && !excusedIds.contains(s.id)) {
        return s;
      }
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

  /// The step whose time is running right now — started, not yet ended, and
  /// neither finished nor excused — or null.
  RoutineStep? currentStep(DateTime now) {
    for (final s in steps) {
      final start = s.startsOn(now);
      final end = s.endsOn(now);
      if (start == null || end == null) continue;
      if (log?.isDone(s.id) ?? false) continue;
      if (excusedIds.contains(s.id)) continue;
      if (!now.isBefore(start) && now.isBefore(end)) return s;
    }
    return null;
  }
}

/// Whether "My Day" applies to the signed-in profile at all.
///
/// The one place the two halves of this feature are told apart:
///
///  * A **Student or Child** always has it. Their routine is a Teacher's or a
///    Parent's instrument — it can hold the device at each step — so there is
///    deliberately no learner-facing switch to turn it off. Turning it off is
///    the educator's job, in the routine itself.
///  * A **Player (With Progress)** has it when they say so:
///    `AppSettings.routineEnabled`, on their own Settings screen. Nobody sets
///    a routine for a Player, nothing locks, and a checklist they did not ask
///    for is just clutter on their home.
///  * A **guest Player** never has it. Nothing a guest does is persisted past
///    the session and their home is one button, so there is no day to plan and
///    nowhere to show it.
///  * An **educator** does not have a My Day of their own. Previewing a
///    learner's is a different thing and goes straight to
///    `routineListProvider` — see `RoutineScreen`, which never consults this.
final routineFeatureProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return false;
  if (profile.isGuestPlayer) return false;
  if (profile.role == UserRole.player) {
    return ref.watch(settingsProvider.select((s) => s.routineEnabled));
  }
  return profile.role.isEnrollableLearner;
});

/// The signed-in learner's day, live.
///
/// Rebuilds when a routine changes, when a step is ticked, when the calendar
/// day changes ([currentDayProvider]), and — through [wallClockTickerProvider]
/// in the widgets that need it — when a step falls overdue. Degrades to [TodayRoutine.none] for a learner with no profile,
/// which is the right answer rather than an error.
final todayRoutineProvider = Provider<TodayRoutine>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return TodayRoutine.none;
  // A Player who turned My Day off has an empty day, not a hidden one: every
  // surface that reads this — the Home card, the screen, the notification tap
  // handler — then agrees there is nothing to show, without each of them
  // having to remember the setting.
  if (!ref.watch(routineFeatureProvider)) return TodayRoutine.none;

  // Watched, not read: a running app must move to the new day at midnight.
  final today = ref.watch(currentDayProvider);
  // `valueOrNull` throughout: no routine, a mirror that has not opened, and a
  // cloud read that failed all mean "nothing to show", and none of them is a
  // reason to break the top of Home.
  final routines =
      ref.watch(myRoutinesProvider).valueOrNull ?? const <Routine>[];
  final key = routineDayKey(profile.id, today);
  // The joined day: an educator's approval shows as done on Home, their
  // excuse stops the step being offered as next, and their reset clears the
  // card. Null until the learner's own log has loaded, as before.
  final view = ref.watch(routineDayViewProvider(key));
  final log =
      ref.watch(routineDayLogProvider(key)).hasValue ? view.effectiveLog : null;

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
    excusedIds: view.excusedIds,
    streak: history.streak(now: today),
    // A learner who belongs to a class or a family group has someone whose
    // job this is. A Player profile does not, and telling them to ask their
    // teacher would be pointing at nobody.
    hasEducator: !profile.isGuestPlayer &&
        (profile.classroomId != null || profile.homeGroupId != null),
  );
});

/// Whether the signed-in learner's routine runs on the clock rather than on
/// their own ticks.
///
/// A **Student or Child** never marks a step done, never says "I did it!"
/// and never asks their own way out of a lock: a step is finished when its
/// time ends, or when their Teacher or Parent finishes it early. Every learner
/// surface — My Day, the step screen, the pop-up, the Home card — reads this
/// one answer. A **Player** keeps the checklist they tick themselves.
final routineRunsOnClockProvider = Provider<bool>((ref) {
  return canBeLockedByRoutine(ref.watch(profileProvider)?.role);
});
