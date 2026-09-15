import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/lock_state_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../models/routine_models.dart';
import '../models/routine_popup_schedule.dart';
import '../models/routine_presentation.dart';
import '../providers/today_routine_provider.dart';
import '../services/routine_step_action.dart';
import '../services/routine_time_finisher.dart';
import 'routine_mood_prompt.dart';
import 'routine_now_popup.dart';

/// A step the learner asked for by tapping its notification, waiting for the
/// watcher to show it. Holds a step id; cleared once shown.
final pendingRoutinePopupProvider = StateProvider<String?>((ref) => null);

/// Raises the "My Day" pop-up when a scheduled step comes due while the
/// learner is in the app — "It is lunch time.", and then "how do you feel?".
///
/// The OS notification (see `RoutineReminderScheduler`) fires at the step's
/// time whether or not the app is open. This is the in-app half: a learner
/// already using the app at 12:00 should not have to notice a banner in the
/// status bar to be told it is lunch time — the step comes to them.
///
/// For a **Student or Child** the day runs on the clock
/// ([routineRunsOnClockProvider]), and this is also where it moves forward:
///
///  * a step whose time has ended is recorded as finished on the learner's own
///    device ([RoutineTimeFinisher]) — nobody ticks it;
///  * the pop-up only says what is happening and until when, with a single OK;
///  * a step the educator marked "ask how they feel" asks once its time is
///    over, rather than after a tap that no longer exists.
///
/// Mounted once in the learner shell, renders nothing, and does nothing at all
/// unless today's routine actually contains a step with a time on it — so it
/// adds no clock, no lock check and no rebuilds to a learner without one.
///
/// It interrupts only where interrupting is fair
/// ([RoutinePopupSchedule.isCalmLocation]) and never over the time's-up lock
/// screen; a step that comes due mid-game waits and is raised when the learner
/// is back on a hub.
class RoutinePopupWatcher extends ConsumerStatefulWidget {
  const RoutinePopupWatcher({super.key, required this.location});

  /// The router's current location, from the shell. Decides whether this is
  /// a calm moment to interrupt.
  final String location;

  @override
  ConsumerState<RoutinePopupWatcher> createState() =>
      _RoutinePopupWatcherState();
}

class _RoutinePopupWatcherState extends ConsumerState<RoutinePopupWatcher> {
  /// Step id → do not raise again before this time ("Later", or — on the
  /// clock — the end of a step the learner has already seen).
  final Map<String, DateTime> _snoozedUntil = {};

  /// Steps already asked "how do you feel?" about since their time ended.
  final Set<String> _askedAfter = {};

  /// Whose snoozes these are, and for which day — a profile switch or
  /// midnight wipes them, so one learner's "later" never silences another's
  /// step and yesterday's never silences today's.
  String? _snoozeKey;

  bool _showing = false;

  /// One "time is over" write at a time.
  bool _finishing = false;

  /// The time as of the last build, from the same ticker the due check reads.
  /// "Later" is measured from this rather than from `DateTime.now()`, so the
  /// snooze and the check it silences can never disagree about what time it
  /// is.
  DateTime? _lastNow;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null ||
        profile.role.isEducator ||
        // A Player who turned My Day off, and a guest Player, who never had
        // one. `routineFeatureProvider` is the single answer to "does this
        // profile have a routine at all" — reading it here rather than
        // re-deriving the rule keeps the pop-up and the Home card from ever
        // disagreeing about whether the feature exists.
        !ref.watch(routineFeatureProvider) ||
        // An educator peeking at a learner's account is not the person whose
        // lunch time it is.
        ref.read(profileProvider.notifier).isViewingAsStudent) {
      return const SizedBox.shrink();
    }

    final today = ref.watch(todayRoutineProvider);
    final request = ref.watch(pendingRoutinePopupProvider);
    final hasScheduled = today.steps.any((s) => s.isScheduled);
    if (!hasScheduled) return const SizedBox.shrink();

    // Only now does the clock matter: re-evaluate every 10 s so the pop-up
    // arrives at 12:00 on its own rather than on the learner's next tap.
    //
    // No `?? DateTime.now()` fallback. The ticker delivers its first value one
    // microtask after this first build, so falling back read the device clock
    // for exactly one frame — invisible in the app, and in tests it meant the
    // *real* time decided whether a fixture's step was due: the suite passed
    // when run before 9am and failed after it. Skipping that one frame costs
    // nothing and makes the clock the only clock.
    final now = ref.watch(wallClockTickerProvider).valueOrNull;
    if (now == null) return const SizedBox.shrink();
    _lastNow = now;

    final key = '${profile.id}|${now.year}-${now.month}-${now.day}';
    if (_snoozeKey != key) {
      _snoozeKey = key;
      _snoozedUntil.clear();
      _askedAfter.clear();
    }

    final clock = ref.watch(routineRunsOnClockProvider);
    if (clock) _finishEnded(profile.id, today, now);

    var due = RoutinePopupSchedule.due(
      todaysSteps: today.steps,
      log: today.log,
      now: now,
      snoozedUntil: _snoozedUntil,
      // A step an adult excused on the routine lock is excused here too, and
      // so is one an adult paused: nothing is announced until they resume it.
      skippedStepIds: {...today.excusedIds, ...today.pausedIds},
      // …and a device an adult unlocked is left alone until the unlock ends.
      unlockedUntil: ref.watch(deviceUnlockedUntilProvider(profile.id)),
      requestedStepId: request,
    );
    // On the clock a step whose time is over is finished, not due: it is never
    // announced after the fact (it is recorded a moment later).
    if (clock && due != null && _isOver(today, due, now)) due = null;
    final shown = due;
    final askAfter = clock && shown == null ? _moodDueAfter(today, now) : null;
    if ((shown == null && askAfter == null) || _showing) {
      return const SizedBox.shrink();
    }
    if (!RoutinePopupSchedule.isCalmLocation(widget.location)) {
      return const SizedBox.shrink();
    }
    // Never on top of something the learner already has open. Two checks,
    // because the router's location alone cannot see either: a question sheet
    // ("How do you feel after brushing your teeth?") sits on the shell's own
    // navigator under `/routine`, and a dialog such as the daily reward sits
    // on the root navigator above the shell. Both re-evaluate on the next
    // tick, so the pop-up is raised moments after they close.
    if (isMoodQuestionOpen) return const SizedBox.shrink();
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return const SizedBox.shrink();
    // Never over a lock screen — the time's-up one or My Day's own. The child
    // cannot dismiss either, and a dialog on top would be one more thing they
    // cannot get past. (The routine lock is already showing the step this
    // pop-up would announce, so there is nothing to lose by waiting.)
    if (ref.watch(lockStateProvider(profile.id)) != null) {
      return const SizedBox.shrink();
    }

    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shown != null) {
        _raise(shown, today.steps, profile.id, clock: clock);
      } else if (askAfter != null) {
        _askAbout(askAfter);
      }
    });
    return const SizedBox.shrink();
  }

  /// Whether [step]'s time is over — its end as it stands today, after any
  /// time an adult added. A paused step's clock is stopped, so it never is.
  static bool _isOver(TodayRoutine today, RoutineStep step, DateTime now) {
    if (today.isPaused(step.id)) return false;
    final end = today.endOf(step, now);
    return end != null && !now.isBefore(end);
  }

  /// Records the steps whose time is over as finished, on the learner's own
  /// device. At most one write in flight, and none when nothing has ended —
  /// or before the day log has loaded, when "not finished" is not yet known.
  void _finishEnded(String profileId, TodayRoutine today, DateTime now) {
    final log = today.log;
    if (_finishing || log == null) return;
    final ended = [
      for (final s in today.steps)
        if (_isOver(today, s, now) &&
            !log.isDone(s.id) &&
            !today.excusedIds.contains(s.id))
          s,
    ];
    if (ended.isEmpty) return;
    _finishing = true;
    final day = DateTime(now.year, now.month, now.day);
    final finisher = ref.read(routineTimeFinisherProvider);
    unawaited(() async {
      try {
        final wrote = await finisher.finish(profileId, day, ended, now: now);
        if (wrote && mounted) {
          ref.invalidate(routineDayLogProvider(routineDayKey(profileId, day)));
        }
      } finally {
        _finishing = false;
      }
    }());
  }

  /// A finished step the educator marked "ask how they feel", finished within
  /// the last hour and not asked about yet — the clock's version of asking
  /// after a tick.
  RoutineStep? _moodDueAfter(TodayRoutine today, DateTime now) {
    final log = today.log;
    if (log == null) return null;
    for (final s in today.steps) {
      if (!s.asksMoodAfter || !log.isDone(s.id)) continue;
      if (_askedAfter.contains(s.id)) continue;
      final finishedAt = log.completedAt[s.id] ?? today.endOf(s, now);
      if (finishedAt == null ||
          now.difference(finishedAt) > RoutinePopupSchedule.taskFreshness) {
        continue;
      }
      return s;
    }
    return null;
  }

  Future<void> _askAbout(RoutineStep step) async {
    if (!mounted) return;
    _askedAfter.add(step.id);
    // Asks nothing when the learner already answered about this step today.
    await askAboutStep(context, ref, step);
    if (mounted) setState(() => _showing = false);
  }

  Future<void> _raise(
    RoutineStep step,
    List<RoutineStep> todaysSteps,
    String profileId, {
    required bool clock,
  }) async {
    if (!mounted) return;
    // The request is being honoured; clear it so it is not honoured twice.
    ref.read(pendingRoutinePopupProvider.notifier).state = null;

    final did = await showRoutineNowPopup(
      context,
      ref,
      step,
      canTick: !clock,
    );
    if (!mounted) return;

    final at = _lastNow ?? DateTime.now();
    if (clock) {
      // Seen, which is all the pop-up asks of a Student or Child: not raised
      // again before the step's time is over. A check-in's answer, if given,
      // is already recorded.
      _snoozedUntil[step.id] = ref.read(todayRoutineProvider).endOf(step, at) ??
          at.add(RoutinePopupSchedule.snoozeFor);
    } else if (did) {
      await RoutineStepAction.toggle(
        ref: ref,
        profileId: profileId,
        day: DateTime.now(),
        step: step,
        todaysSteps: todaysSteps,
        presentation: ref.read(routinePresentationProvider),
        filipino: ref.read(settingsProvider).locale == 'fil',
      );
    } else {
      _snoozedUntil[step.id] = at.add(RoutinePopupSchedule.snoozeFor);
    }
    if (mounted) setState(() => _showing = false);
  }
}
