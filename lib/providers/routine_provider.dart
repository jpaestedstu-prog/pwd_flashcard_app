import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_service.dart';
import '../features/routine/models/routine_day_state.dart';
import '../features/routine/models/routine_lock_status.dart';
import '../features/routine/models/routine_models.dart';
import '../features/routine/services/routine_service.dart';
import 'app_providers.dart';
import 'wall_clock_provider.dart';

/// Live stream of every routine targeting one learner.
///
/// Watched by both sides of the feature: the educator's editor
/// (`RoutineEditorScreen`) and the learner's own day (`RoutineScreen`). The
/// service seeds it from the Hive mirror, so the first frame is never empty
/// for a learner who already has a routine.
final routineListProvider =
    StreamProvider.family<List<Routine>, String>((ref, childProfileId) {
  return const RoutineService().watchForChild(childProfileId);
});

/// Every routine authored by one educator, for a "routines I've set"
/// overview.
final routinesBySetterProvider =
    FutureProvider.family<List<Routine>, String>((ref, setterProfileId) {
  return const RoutineService().listForSetter(setterProfileId);
});

/// The signed-in learner's own routines. Null profile yields an empty list
/// rather than an error — a Player or a signed-out device has no routine and
/// that is not a failure.
final myRoutinesProvider = StreamProvider<List<Routine>>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return Stream.value(const <Routine>[]);
  return const RoutineService().watchForChild(profile.id);
});

/// Identifies one learner's calendar day. A record rather than two `family`
/// providers, because every consumer needs both halves together and a
/// `family` key must be a single value.
typedef RoutineDayKey = ({String profileId, DateTime day});

/// Live completion log for one learner on one day.
///
/// [RoutineDayKey.day] must be date-only — build it with
/// [routineDayKey], which strips the time. A key carrying a wall-clock time
/// would mint a fresh provider every rebuild and re-subscribe forever.
final routineDayLogProvider =
    StreamProvider.family<RoutineDayLog, RoutineDayKey>((ref, key) {
  return const RoutineService().watchDayLog(key.profileId, key.day);
});

/// Builds a [RoutineDayKey] with the time component stripped.
RoutineDayKey routineDayKey(String profileId, DateTime day) =>
    (profileId: profileId, day: DateTime(day.year, day.month, day.day));

/// The last two weeks of completion for [profileId], newest first, read from
/// the local mirror.
///
/// Backs the educator's history strip and the learner's streak. It re-reads
/// whenever today's log changes, which is what keeps the strip live while an
/// educator is watching a learner work through their morning.
final routineHistoryProvider =
    Provider.family<List<RoutineDayLog>, String>((ref, profileId) {
  ref.watch(routineDayLogProvider(routineDayKey(profileId, DateTime.now())));
  // Tolerates storage not being ready. An empty history is the right degraded
  // answer — the streak reads 0 and nothing else changes — and this is watched
  // from the top of Home now, where throwing would take the whole page with it
  // rather than one number.
  try {
    return HiveService.getRoutineHistory(profileId);
  } catch (_) {
    return const <RoutineDayLog>[];
  }
});

/// Live educator actions on one learner's day — approvals, excuses, resets
/// made from a Teacher's or Parent's own device.
final routineDayActionsProvider =
    StreamProvider.family<RoutineDayActions, RoutineDayKey>((ref, key) {
  return const RoutineService().watchDayActions(key.profileId, key.day);
});

/// One learner's day as it actually stands: their log joined with any
/// educator actions. What screens should ask "is this step done?".
final routineDayViewProvider =
    Provider.family<RoutineDayView, RoutineDayKey>((ref, key) {
  return RoutineDayView.of(
    profileId: key.profileId,
    day: key.day,
    log: ref.watch(routineDayLogProvider(key)).valueOrNull,
    actions: ref.watch(routineDayActionsProvider(key)).valueOrNull,
  );
});

/// The last two weeks of educator actions for [profileId], newest first,
/// from the local mirror. Re-reads when today's actions change.
final routineActionsHistoryProvider =
    Provider.family<List<RoutineDayActions>, String>((ref, profileId) {
  ref.watch(
    routineDayActionsProvider(routineDayKey(profileId, DateTime.now())),
  );
  try {
    return HiveService.getRoutineActionsHistory(profileId);
  } catch (_) {
    return const <RoutineDayActions>[];
  }
});

/// Pulls a learner's recent days from the cloud into this device's mirror,
/// then refreshes the history that reads it. Watched by the history screen,
/// which on an educator's device would otherwise only know the days it had
/// open.
final routineRecentDaysSyncProvider =
    FutureProvider.autoDispose.family<void, String>((ref, profileId) async {
  await const RoutineService().fetchRecentDays(profileId);
  ref.invalidate(routineHistoryProvider(profileId));
  ref.invalidate(routineActionsHistoryProvider(profileId));
});

/// One learner's locking steps for today, live on the wall clock — what the
/// educator's dashboard alerts from.
final routineLockSummaryProvider =
    Provider.family<RoutineLockSummary, String>((ref, profileId) {
  final now = ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();
  final routines =
      ref.watch(routineListProvider(profileId)).valueOrNull ?? const <Routine>[];
  if (!routines.any((r) => r.enabled && r.lockEnabled)) {
    return RoutineLockSummary.none;
  }
  final view = ref.watch(routineDayViewProvider(routineDayKey(profileId, now)));
  return RoutineLockSummary.of(routines: routines, view: view, now: now);
});
