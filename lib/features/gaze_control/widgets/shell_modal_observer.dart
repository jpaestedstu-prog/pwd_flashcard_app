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

  /// [isCovering] for widgets that must redraw when it changes — the AI
  /// Tutor bubble floats above every navigator and would otherwise sit on top
  /// of a game's difficulty sheet.
  ///
  /// Updated after the frame: navigator callbacks can arrive while a
  /// declarative page change is being built, where notifying listeners that
  /// call setState would throw.
  final ValueNotifier<bool> covering = ValueNotifier<bool>(false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The base page arrives with no previous route; everything after it is a
    // layer on top.
    if (previousRoute != null) {
      _depth++;
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) {
      _depth--;
      _sync();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) {
      _depth--;
      _sync();
    }
  }

  /// A replace swaps one layer for another, so the depth is unchanged.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      covering.value = isCovering;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Test seam — one test's leftover depth must not cover the next one's shell.
  @visibleForTesting
  void reset() {
    _depth = 0;
    covering.value = false;
  }
}

/// Counts only dialogs and sheets on the **root** navigator. Full pages there
/// (games, the full AI Tutor) already take the bubble away by location; a
/// dialog or a root-level sheet over a hub does not change the location, so
/// without this the bubble floated over the Daily Reward and achievement
/// dialogs.
class PopupObserver extends ShellModalObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _depth++;
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && _depth > 0) {
      _depth--;
      _sync();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && _depth > 0) {
      _depth--;
      _sync();
    }
  }
}

/// The single observer installed on the shell's navigator (see `app_router`).
final ShellModalObserver shellModalObserver = ShellModalObserver();

/// The single popup observer installed on the root navigator (see `app_router`).
final ShellModalObserver rootPopupObserver = PopupObserver();
