import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../models/routine_models.dart';

/// Hive key, namespaced per profile by [HiveService.saveProfileSetting].
const String kRoutineLockSkipKey = 'routineLockSkips';

/// The routine steps an adult has waved past for one calendar day.
///
/// A routine lock is cleared by *doing* the step, which is the whole point —
/// but a child can be ill, away from the bathroom, or simply somewhere the
/// step cannot happen, and a learner who physically cannot clear the lock
/// would otherwise be shut out of their own tablet for the hour. The adult
/// gate (`requireAdult`) opens this door and nothing else does.
///
/// Deliberately **not** a tick: the step is skipped, not completed. The day
/// log keeps saying it was not done, so the history, the streak and the
/// educator's dashboard all tell the truth about the morning.
class RoutineLockSkips {
  const RoutineLockSkips({required this.dayStamp, required this.stepIds});

  /// `yyyy-mm-dd` these skips belong to. A skip is worth exactly one day:
  /// tomorrow's brushing teeth is a different brushing teeth.
  final String dayStamp;

  final Set<String> stepIds;

  static const RoutineLockSkips none = RoutineLockSkips(
    dayStamp: '',
    stepIds: <String>{},
  );

  /// The skips that apply on [day] — empty once the date has rolled, without
  /// needing anything to have run at midnight.
  Set<String> on(DateTime day) =>
      dayStamp == dayStampOf(day) ? stepIds : const <String>{};

  /// `2026-09-12|id-a,id-b`, the stored form. One string rather than a map so
  /// it round-trips through the plain settings box the rest of the per-profile
  /// preferences use.
  String encode() => '$dayStamp|${(stepIds.toList()..sort()).join(',')}';

  static RoutineLockSkips decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return none;
    final cut = raw.indexOf('|');
    if (cut <= 0) return none;
    final ids = raw
        .substring(cut + 1)
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    return RoutineLockSkips(dayStamp: raw.substring(0, cut), stepIds: ids);
  }
}

/// Per-learner routine-lock skips, persisted so a restart does not re-trap the
/// learner behind a step an adult already excused.
///
/// Persisted, unlike [adultGateGraceProvider], and for the opposite reason: the
/// adult gate is a speed bump that should reset the moment the app does, while
/// this is a decision an adult made about today. Making them re-enter a PIN
/// because the tablet ran out of battery would punish the wrong person.
class RoutineLockSkipNotifier extends FamilyNotifier<RoutineLockSkips, String> {
  @override
  RoutineLockSkips build(String profileId) {
    try {
      return RoutineLockSkips.decode(
        HiveService.getProfileSetting(kRoutineLockSkipKey, profileId: profileId),
      );
    } catch (_) {
      // Storage not open yet (tests, early boot). No skips is the safe answer:
      // the lock stands, and an adult can excuse it again.
      return RoutineLockSkips.none;
    }
  }

  /// Excuse [stepId] for [day]. Replaces the whole record when the stored one
  /// is from an earlier day, so yesterday's excuses never carry over.
  Future<void> skip(String stepId, {DateTime? day}) async {
    final stamp = dayStampOf(day ?? DateTime.now());
    final current = state.dayStamp == stamp ? state.stepIds : const <String>{};
    final next = RoutineLockSkips(
      dayStamp: stamp,
      stepIds: {...current, stepId},
    );
    state = next;
    try {
      await HiveService.saveProfileSetting(
        kRoutineLockSkipKey,
        next.encode(),
        profileId: arg,
      );
    } catch (_) {
      // In-memory is enough to release the learner now; the worst a failed
      // write costs is one more PIN after a restart.
    }
  }

  /// Drop every skip (educator "start today over", sign-out, tests).
  Future<void> clear() async {
    state = RoutineLockSkips.none;
    try {
      await HiveService.saveProfileSetting(
        kRoutineLockSkipKey,
        '',
        profileId: arg,
      );
    } catch (_) {}
  }
}

final routineLockSkipProvider =
    NotifierProvider.family<RoutineLockSkipNotifier, RoutineLockSkips, String>(
  RoutineLockSkipNotifier.new,
);
