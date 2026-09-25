import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/lock_enforcer.dart';
import '../data/models/enums.dart';
import '../features/routine/models/routine_models.dart';
import 'active_time_provider.dart';
import 'child_alarm_provider.dart';
import 'child_time_limit_provider.dart';
import 'child_unlock_override_provider.dart';
import 'pin_unlock_grace_provider.dart';
import 'profile_role_provider.dart';
import 'routine_provider.dart';
import 'wall_clock_provider.dart';

/// Live `LockReason?` for one child profile.
///
/// Re-evaluates whenever any of its inputs change — the time-limit
/// stream, the alarm list stream, the active-time minute counter, the
/// unlock-override stream, the local PIN-grace value, or the 10-second
/// wall-clock ticker. Returning null means "not locked"; the
/// [LockEnforcerGate] widget watches this and routes to `/time-up-lock`
/// whenever it flips non-null, and the lock screen itself routes home
/// when it flips back to null.
///
/// Order of precedence:
///   1. **Local PIN unlock grace** — written by the lock screen on a
///      successful on-device PIN entry. Authoritative because the child's
///      device cannot persist an educator-setter override (the Firestore
///      rule rejects that write). A timer self-invalidates the provider
///      when the grace expires so the lock re-arms without a relaunch.
///   2. **Remote unlock override** — written by the Teacher/Parent
///      dashboard "Unlock Now". Same timer trick for the expiry edge.
///   3. Otherwise, delegate to the pure [LockEnforcer.evaluate]. Watching
///      [wallClockTickerProvider] forces this branch to recompute every
///      10 s so an alarm fire or daily-limit crossing surfaces without
///      waiting for the active-time minute tick or a Firestore push.
///
/// The fourth input is "My Day": a routine a Teacher or Parent switched to
/// locking holds the device at each step's time until the learner marks it
/// done ([RoutineStepDue]). Only Students and Children can be held this way —
/// a Player runs the same routines as a plain checklist, which is the whole
/// difference between the two surfaces.
final lockStateProvider =
    Provider.family<LockReason?, String>((ref, childProfileId) {
  // 10-second wall-clock tick: watching it is what forces re-evaluation on a
  // sub-minute cadence, and its value *is* the clock every rule below reads.
  // Ten seconds of staleness is nothing against windows measured in minutes
  // and hours, and taking the time from one place means a test can pin it —
  // the ticker has no value on the very first build (it arrives a microtask
  // later), which is the only case that falls back to the device clock.
  final now = ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();

  // 1. Local PIN grace.
  final localGrace = ref.watch(pinUnlockGraceProvider(childProfileId));
  if (localGrace != null && localGrace.isAfter(now)) {
    final remaining = localGrace.difference(now);
    // Avoid scheduling a zero/negative timer — the wall-clock ticker will
    // catch the expiry on its next tick. Same-frame self-invalidate
    // would also risk a rebuild loop.
    if (remaining > Duration.zero) {
      final timer = Timer(remaining, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
    return null;
  }

  // 2. Remote unlock override.
  final override =
      ref.watch(childUnlockOverrideProvider(childProfileId)).valueOrNull;
  if (override != null && override.isActiveAt(now)) {
    final remaining = override.unlockedUntil.difference(now);
    if (remaining > Duration.zero) {
      final timer = Timer(remaining, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
    return null;
  }

  // 3. Underlying time-limit / alarm / schedule rules.
  final limit = ref.watch(childTimeLimitProvider(childProfileId)).valueOrNull;
  final alarms =
      ref.watch(childAlarmListProvider(childProfileId)).valueOrNull ??
          const [];
  final used = ref.watch(activeTimeProvider(childProfileId));

  // 4. "My Day" steps that hold the device. Read only for a supervised
  //    learner: a Player has no educator to set one and must never be locked
  //    out of a device they own, so their routine stream is not even opened.
  var routineSteps = const <RoutineStep>[];
  var completed = const <String>{};
  var skipped = const <String>{};
  var ends = const <String, DateTime>{};
  var paused = const <String>{};
  if (canBeLockedByRoutine(ref.watch(profileRoleProvider(childProfileId)))) {
    final today = DateTime(now.year, now.month, now.day);
    final routines =
        ref.watch(routineListProvider(childProfileId)).valueOrNull ??
            const <Routine>[];
    routineSteps = [
      for (final r in routines)
        if (r.runsOn(today)) ...r.lockingStepsOn(today),
    ];
    // Nothing locks today — do not subscribe to the day log or the skips for
    // it. A learner whose routines are all plain checklists costs this
    // provider exactly one list comprehension.
    if (routineSteps.isNotEmpty) {
      final key = routineDayKey(childProfileId, today);
      // Nothing locks until both halves of the day have loaded. Deciding from
      // an empty day for the moment before the learner's log arrives would
      // flash the lock for a step they finished an hour ago: the gate routes
      // on any non-null reason, and the lock screen would bounce straight
      // back to Home.
      final logLoaded = ref.watch(routineDayLogProvider(key)).hasValue;
      final actionsLoaded = ref.watch(routineDayActionsProvider(key)).hasValue;
      if (!logLoaded || !actionsLoaded) {
        routineSteps = const <RoutineStep>[];
      } else {
        // The joined day, not the raw log: an educator's "mark done" or
        // "excuse" from their own phone has to lift the lock, and their
        // "start today over" has to re-arm it.
        final view = ref.watch(routineDayViewProvider(key));
        completed = view.doneIds;
        skipped = view.excusedIds;
        // An adult's pause lifts the lock; time they added keeps it longer.
        ends = view.movedEnds(routineSteps, now);
        paused = view.pausedIds;
      }
    }
  }

  return LockEnforcer.evaluate(
    limit: limit,
    minutesUsedToday: used,
    alarms: alarms,
    now: now,
    routineSteps: routineSteps,
    completedStepIds: completed,
    skippedStepIds: skipped,
    routineStepEnds: ends,
    pausedStepIds: paused,
  );
});

/// Until when an adult has unlocked this profile's device, or null.
///
/// The same two sources [lockStateProvider] short-circuits on — the on-device
/// PIN grace and an educator's remote unlock — as one moment, the later of the
/// two. Raw values with no clock: whether the moment has passed is for the
/// reader to decide against its own `now`, so a reader on the wall-clock
/// ticker and this provider can never disagree about the time.
///
/// "My Day" reads it so an unlocked device is left alone by the pop-up as well
/// as by the lock.
final deviceUnlockedUntilProvider =
    Provider.family<DateTime?, String>((ref, childProfileId) {
  final grace = ref.watch(pinUnlockGraceProvider(childProfileId));
  final remote = ref
      .watch(childUnlockOverrideProvider(childProfileId))
      .valueOrNull
      ?.unlockedUntil;
  if (grace == null) return remote;
  if (remote == null) return grace;
  return grace.isAfter(remote) ? grace : remote;
});

/// Whether a profile in [role] can be held by a routine step.
///
/// Students and Children only. Parents and Teachers set the routines; Players
/// (with progress or guest) run them as a checklist and are never locked —
/// their My Day is a learning-and-awareness feature, not a supervision one.
bool canBeLockedByRoutine(UserRole? role) =>
    role == UserRole.student || role == UserRole.child;
