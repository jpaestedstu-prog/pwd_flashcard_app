import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/lock_enforcer.dart';
import 'active_time_provider.dart';
import 'child_alarm_provider.dart';
import 'child_time_limit_provider.dart';
import 'child_unlock_override_provider.dart';
import 'pin_unlock_grace_provider.dart';
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
final lockStateProvider =
    Provider.family<LockReason?, String>((ref, childProfileId) {
  // 10-second wall-clock tick. We don't use the emitted value — watching
  // it is what forces re-evaluation on a sub-minute cadence.
  ref.watch(wallClockTickerProvider);

  final now = DateTime.now();

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
  return LockEnforcer.evaluate(
    limit: limit,
    minutesUsedToday: used,
    alarms: alarms,
    now: now,
  );
});
