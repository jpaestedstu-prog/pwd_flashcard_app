import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/active_time_tracker.dart';
import '../data/local/hive_service.dart';
import '../data/models/active_time_log.dart';

/// Live "minutes used today" for one profile.
///
/// On the child's device this updates every minute via the tracker's
/// listener callback. On other devices (parent/teacher's), it falls
/// back to whatever Hive has cached locally — eventually consistent
/// once the next Firestore sync lands.
class ActiveTimeNotifier extends FamilyNotifier<int, String> {
  void Function()? _unsubscribe;

  @override
  int build(String profileId) {
    final today = ActiveTimeLog.dayKeyFor(DateTime.now());
    final initial =
        HiveService.getActiveTimeLog(profileId, today).minutesUsed;
    _unsubscribe = ActiveTimeTracker.addListener((id, minutes) {
      if (id == profileId) {
        state = minutes;
      }
    });
    ref.onDispose(() {
      _unsubscribe?.call();
    });
    return initial;
  }
}

final activeTimeProvider =
    NotifierProvider.family<ActiveTimeNotifier, int, String>(
  ActiveTimeNotifier.new,
);
