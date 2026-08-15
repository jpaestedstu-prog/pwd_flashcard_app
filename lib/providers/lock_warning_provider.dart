import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/lock_warning.dart';
import 'active_time_provider.dart';
import 'child_alarm_provider.dart';
import 'child_time_limit_provider.dart';
import 'child_unlock_override_provider.dart';
import 'pin_unlock_grace_provider.dart';
import 'wall_clock_provider.dart';

/// Live "a lock is coming soon" signal for one child profile.
///
/// Sibling of `lockStateProvider`, watching the same inputs so the two
/// always agree about which rule is closest. Returns null when there is
/// nothing to warn about — including while an unlock override or PIN
/// grace is active, since no lock is coming during those.
final lockWarningProvider = Provider.family<LockWarning?, String>((
  ref,
  childProfileId,
) {
  // 10-second tick, same as the lock state. The value is unused; watching
  // it is what re-evaluates as the clock advances.
  ref.watch(wallClockTickerProvider);

  final now = DateTime.now();

  // An active grace/override means the learner is explicitly allowed to
  // keep going, so there is no impending lock to warn about.
  final localGrace = ref.watch(pinUnlockGraceProvider(childProfileId));
  if (localGrace != null && localGrace.isAfter(now)) return null;

  final override = ref
      .watch(childUnlockOverrideProvider(childProfileId))
      .valueOrNull;
  if (override != null && override.isActiveAt(now)) return null;

  final limit = ref.watch(childTimeLimitProvider(childProfileId)).valueOrNull;
  final alarms =
      ref.watch(childAlarmListProvider(childProfileId)).valueOrNull ?? const [];
  final used = ref.watch(activeTimeProvider(childProfileId));

  return LockWarningEvaluator.evaluate(
    limit: limit,
    minutesUsedToday: used,
    alarms: alarms,
    now: now,
  );
});

/// Remembers which impending locks have already been announced, so the
/// warning fires once per approaching lock instead of once per 10-second
/// tick.
///
/// Keyed by `LockWarning.eventKey`, which deliberately ignores the minute
/// count — "5 minutes left" and "4 minutes left" describe the same lock and
/// must not both interrupt the learner.
///
/// In-memory only, and cleared whenever the warning lapses (the lock landed,
/// an educator granted more time, or the day rolled over), which re-arms it
/// for the next genuine approach. Not persisted: a relaunch re-warning is
/// harmless and arguably correct, since the learner may have missed it.
class LockWarningSeenNotifier extends FamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String childProfileId) => <String>{};

  /// Marks [key] as announced. Returns false when it already was, so the
  /// caller can skip re-announcing.
  bool markShown(String key) {
    if (state.contains(key)) return false;
    state = {...state, key};
    return true;
  }

  /// Re-arms [key] once the warning window has passed.
  void clear(String key) {
    if (!state.contains(key)) return;
    state = state.where((k) => k != key).toSet();
  }
}

final lockWarningSeenProvider =
    NotifierProvider.family<LockWarningSeenNotifier, Set<String>, String>(
      LockWarningSeenNotifier.new,
    );
