import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routine_service.dart';

/// What the learner's device reports about its own routine lock: that the
/// lock appeared.
///
/// A provider seam rather than a direct service call, because the lock screen
/// makes this report from `build`. Every widget test that pumps the lock would
/// otherwise perform a real Hive write inside the fake-async zone, which hangs
/// the whole test file at teardown (see the project's Hive-hang notes). Tests
/// override this with a recorder that remembers instead of writing.
///
/// There is no "needs help" report any more: a step's lock lets go by itself
/// when its time ends, so a Student or Child is never stuck waiting on one.
class RoutineLockRecorder {
  const RoutineLockRecorder();

  Future<void> lockShown(String profileId, String stepId) =>
      const RoutineService().markLockShown(profileId, DateTime.now(), stepId);
}

final routineLockRecorderProvider = Provider<RoutineLockRecorder>(
  (ref) => const RoutineLockRecorder(),
);
