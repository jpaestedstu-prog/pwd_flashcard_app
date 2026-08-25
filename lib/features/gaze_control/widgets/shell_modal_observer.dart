import 'package:flutter/material.dart';

/// Tracks whether anything is stacked on the **navigation shell's own
/// navigator**, so the shell's D-pad can stand down while it is.
///
/// **The gap this closes.** `GazeRouteGuard.gazeCovered` asks
/// `ModalRoute.of(context)?.isCurrent`, which answers for the *nearest*
/// enclosing route. `NavGazeScope` wraps go_router's `ShellRoute` builder, so it
/// sits **above** the shell's inner navigator — its nearest route is the shell
/// route itself, which stays `isCurrent` forever. A bottom sheet or dialog
/// opened from a hub screen pushes onto that inner navigator and is therefore
/// completely invisible to the guard.
///
/// The result on device was not subtle: opening a game's difficulty sheet left
/// the shell's D-pad still driving the *hub grid underneath it*, announcing
/// "Spelling Bee, 1 of 2" to a learner looking at a difficulty chooser — and an
/// OK press would have opened whichever game was highlighted behind the sheet.
/// Routes pushed on the **root** navigator were always detected correctly; only
/// the shell's own stack was blind.
///
/// A plain counter rather than a route list: the only question anyone asks is
/// "is something on top?", and counting survives replaces and removals that a
/// list would have to reconcile.
class ShellModalObserver extends NavigatorObserver {
  int _depth = 0;

  /// True while at least one route is stacked above the shell's base page.
  ///
  /// The inner navigator always holds exactly one route — the current tab's
  /// page, which go_router *swaps* rather than pushes — so any depth at all
  /// means something genuinely covers the hub.
  bool get isCovering => _depth > 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The base page arrives with no previous route; everything after it is a
    // layer on top.
    if (previousRoute != null) _depth++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
  }

  /// A replace swaps one layer for another, so the depth is unchanged.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}

  /// Test seam — one test's leftover depth must not cover the next one's shell.
  @visibleForTesting
  void reset() => _depth = 0;
}

/// The single observer installed on the shell's navigator (see `app_router`).
final ShellModalObserver shellModalObserver = ShellModalObserver();
