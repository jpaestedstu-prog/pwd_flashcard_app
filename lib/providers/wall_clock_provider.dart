import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current wall-clock time once every 10 seconds, **and the instant
/// the app is resumed**.
///
/// Watched by [lockStateProvider] so the alarm-window, daily-limit and
/// "My Day" step checks re-evaluate without waiting for the active-time minute
/// tick or a Firestore stream emission. Without this, an alarm that fires
/// while the user is idle on a single screen wouldn't surface the lock
/// until the next [ActiveTimeTracker] tick (up to 60 s away) or until
/// the user navigates.
///
/// The resume tick is what makes a lock feel automatic rather than delayed.
/// Android throttles timers in the background, so a learner who put the
/// tablet down at 6:44 and picked it up at 6:46 would otherwise sit on Home
/// for up to ten seconds before their routine step took over — long enough to
/// start something else, which is exactly what the lock exists to prevent.
final wallClockTickerProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  void tick() {
    if (!controller.isClosed) controller.add(DateTime.now());
  }

  final timer = Timer.periodic(const Duration(seconds: 10), (_) => tick());
  // Guarded: a pure `test()` with no binding has no lifecycle to listen to,
  // and the periodic tick alone is a correct (just slower) clock.
  AppLifecycleListener? lifecycle;
  try {
    lifecycle = AppLifecycleListener(onResume: tick);
  } catch (_) {
    lifecycle = null;
  }
  ref.onDispose(() {
    timer.cancel();
    lifecycle?.dispose();
    controller.close();
  });
  return controller.stream;
});
