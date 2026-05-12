import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/child_unlock_override.dart';
import '../features/parent/services/child_unlock_override_service.dart';

/// Live stream of the per-child unlock-override document.
///
/// Watched by [lockStateProvider] so a fresh "Unlock Now" from a teacher
/// or parent (or a successful PIN entry on the lock screen, which also
/// writes a 30-minute grace) propagates to the child within seconds.
///
/// Emits `null` when no override exists or when the document fails to
/// parse — the lock-state provider treats `null` as "no grace, evaluate
/// the underlying time-limit/alarm/schedule rules normally".
final childUnlockOverrideProvider =
    StreamProvider.family<ChildUnlockOverride?, String>(
  (ref, childProfileId) {
    return const ChildUnlockOverrideService().watchForChild(childProfileId);
  },
);
