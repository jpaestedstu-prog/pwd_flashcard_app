import 'dart:async';

import 'package:flutter/material.dart';

/// Shared "is something layered over me?" plumbing for the gaze scopes.
///
/// A gaze scope drives the controls of *its* screen. The moment another route
/// covers that screen — a dialog, a bottom sheet, a pushed page — those
/// controls are neither visible nor reachable, so two things must happen:
///
/// 1. **Input stops.** A head move or blink must not activate a button the
///    learner cannot see. [gazeCovered] is a *live* read, checked at the moment
///    an action would fire, so it is never stale.
/// 2. **The affordance stops.** A highlight ring or a "Look at the screen" chip
///    left showing under a dialog tells the learner gaze is working when it is
///    inert — worse than showing nothing. [gazeCoveredForUi] is the cached
///    value `build` should use; a slow ticker refreshes it, because nothing
///    else rebuilds a scope when a route is pushed over it.
///
/// The camera is deliberately **left running** while covered: re-initialising
/// CameraX costs about a second of "Starting gaze…", and the sheets that cover
/// these screens (the viewer's "Show Me" / "Examples") are dismissed in a few
/// seconds. Standing it down on long-lived coverage is a separate change.
mixin GazeRouteGuard<T extends StatefulWidget> on State<T> {
  Timer? _coverageTimer;
  bool _coveredForUi = false;

  /// How often the cached [gazeCoveredForUi] is re-checked. Slow enough to be
  /// free, fast enough that a ring never lingers visibly under a dialog.
  static const Duration _coveragePollInterval = Duration(milliseconds: 400);

  /// Live read: another route is currently layered over this scope's screen.
  /// Gate every input path on this at event time.
  bool get gazeCovered {
    if (!mounted) return true;
    if (extraCovered) return true;
    final route = ModalRoute.of(context);
    return route != null && !route.isCurrent;
  }

  /// An additional "something is on top of me" signal, for scopes whose own
  /// [ModalRoute] cannot answer the question.
  ///
  /// The navigation shell needs this: it wraps go_router's `ShellRoute`
  /// builder, so it sits *above* the shell's inner navigator and its nearest
  /// route stays `isCurrent` even while a sheet pushed from a hub screen covers
  /// everything. Per-screen scopes are pushed as ordinary routes and their
  /// `ModalRoute` is already correct, so they leave this alone.
  bool get extraCovered => false;

  /// Cached counterpart of [gazeCovered] for `build` — see the class doc.
  bool get gazeCoveredForUi => _coveredForUi;

  /// Hook for scopes that publish state beyond their own subtree (the shell
  /// publishes its focused tile to `gazeHomeGrid`), so they can withdraw it
  /// while covered. Called after the rebuild; the default does nothing.
  void onGazeCoverageChanged(bool covered) {}

  /// Starts the ticker. Safe to call repeatedly; call only when the scope has
  /// actually armed gaze (there is nothing to hide otherwise).
  void startGazeCoverageWatch() {
    _coverageTimer ??= Timer.periodic(_coveragePollInterval, (_) {
      if (!mounted) return;
      final now = gazeCovered;
      if (now == _coveredForUi) return;
      setState(() => _coveredForUi = now);
      onGazeCoverageChanged(now);
    });
  }

  /// Stops the ticker. Call from `dispose`.
  void stopGazeCoverageWatch() {
    _coverageTimer?.cancel();
    _coverageTimer = null;
  }
}
