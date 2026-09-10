import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_service.dart';
import '../features/routine/models/routine_models.dart';
import '../features/routine/services/routine_service.dart';
import 'app_providers.dart';

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
  return HiveService.getRoutineHistory(profileId);
});
