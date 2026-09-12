import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/lock_state_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../models/routine_models.dart';
import '../models/routine_popup_schedule.dart';
import '../models/routine_presentation.dart';
import '../providers/today_routine_provider.dart';
import '../services/routine_step_action.dart';
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
  /// Step id → do not raise again before this time ("Later").
  final Map<String, DateTime> _snoozedUntil = {};

  /// Whose snoozes these are, and for which day — a profile switch or
  /// midnight wipes them, so one learner's "later" never silences another's
  /// step and yesterday's never silences today's.
  String? _snoozeKey;

  bool _showing = false;

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
        profile.isGuestPlayer ||
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
    }

    final due = RoutinePopupSchedule.due(
      todaysSteps: today.steps,
      log: today.log,
      now: now,
      snoozedUntil: _snoozedUntil,
      requestedStepId: request,
    );
    if (due == null || _showing) return const SizedBox.shrink();
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
    // Never over the time's-up lock: the child cannot dismiss that screen,
    // and a dialog on top of it would be one more thing they cannot get past.
    if (ref.watch(lockStateProvider(profile.id)) != null) {
      return const SizedBox.shrink();
    }

    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _raise(due, today.steps, profile.id),
    );
    return const SizedBox.shrink();
  }

  Future<void> _raise(
    RoutineStep step,
    List<RoutineStep> todaysSteps,
    String profileId,
  ) async {
    if (!mounted) return;
    // The request is being honoured; clear it so it is not honoured twice.
    ref.read(pendingRoutinePopupProvider.notifier).state = null;

    final did = await showRoutineNowPopup(context, ref, step);
    if (!mounted) return;

    if (did) {
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
      _snoozedUntil[step.id] = (_lastNow ?? DateTime.now()).add(
        RoutinePopupSchedule.snoozeFor,
      );
    }
    if (mounted) setState(() => _showing = false);
  }
}
