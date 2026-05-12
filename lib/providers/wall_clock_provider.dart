import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current wall-clock time once every 10 seconds.
///
/// Watched by [lockStateProvider] so the alarm-window and daily-limit
/// checks re-evaluate without waiting for the active-time minute tick
/// or a Firestore stream emission. Without this, an alarm that fires
/// while the user is idle on a single screen wouldn't surface the lock
/// until the next [ActiveTimeTracker] tick (up to 60 s away) or until
/// the user navigates.
final wallClockTickerProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(
    const Duration(seconds: 10),
    (_) => controller.add(DateTime.now()),
  );
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
