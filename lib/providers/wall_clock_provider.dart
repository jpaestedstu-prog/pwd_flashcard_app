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

/// Today's date (midnight) — what anything keyed by the day should watch:
/// "My Day", its history, the day log a screen follows.
///
/// Reading `DateTime.now()` once inside a provider keys it to the day it was
/// first built on: with the app left running past midnight, Home kept
/// yesterday's "All done" (found on the emulator after a date change).
///
/// It reads the date rather than watching [wallClockTickerProvider] itself,
/// which would start a ten-second periodic timer in every widget test that
/// mounts a learner's day. The app shell advances it instead — see
/// [isNewDay] and its listener in `main.dart` — so dependents recompute
/// exactly once when the date changes.
final currentDayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Whether [now] falls on a different calendar day from [currentDay] — later
/// (midnight passed) or earlier (the clock was set back). Pure.
bool isNewDay(DateTime currentDay, DateTime now) =>
    now.year != currentDay.year ||
    now.month != currentDay.month ||
    now.day != currentDay.day;
