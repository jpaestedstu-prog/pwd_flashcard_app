import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/child_time_limit.dart';
import '../features/parent/services/child_time_limit_service.dart';

/// Live stream of the per-child time-limit document.
///
/// Watched by both the parent's editor (so the toggle reflects what's
/// actually in Firestore) and the child's [LockEnforcer] (so an edit
/// from another device propagates within seconds).
///
/// Emits `null` when no document exists for the child — the enforcer
/// short-circuits in that case.
final childTimeLimitProvider =
    StreamProvider.family<ChildTimeLimit?, String>(
  (ref, childProfileId) {
    return const ChildTimeLimitService().watchForChild(childProfileId);
  },
);
