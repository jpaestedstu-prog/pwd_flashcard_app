import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers that keep the system Back button and the back-swipe
/// gesture meaning the same thing everywhere in the app: **return to the
/// screen you came from**.
///
/// ## Why this exists
///
/// `context.go()` *replaces* the whole route stack. A screen entered with
/// `go()` therefore has nothing behind it, so system Back either closes the
/// app or (via a hard-coded fallback) drops the learner on Home — no matter
/// which screen actually launched it. That was the cause of "some features
/// always go back to Home": the games, the FSL practice modes, the flashcard
/// viewer and the deck tools were all *entered* with `go()`, and their exit
/// buttons then `go()`'d to a fixed hub.
///
/// ## The rule
///
/// * **Drill-down** (opening a feature from a screen the learner should come
///   back to) → `context.push()`.
/// * **Leaving that feature** (Close / Exit / Quit / result-dialog "Exit") →
///   [popOrGo], so it retraces the real stack.
/// * **Switching a bottom-nav tab**, or finishing an onboarding / lock /
///   profile-lifecycle step that must not be back-navigable → keep
///   `context.go()`.
///
/// Pushing a route that is nested inside the app's `ShellRoute` is safe from
/// another screen *inside* the same shell. Pushing one from *outside* the
/// shell needs `parentNavigatorKey: rootNavigatorKey` on the route — every
/// game / story activity route already carries it, which is what
/// `test/shell_route_push_nav_test.dart` guards.
/// The bottom-nav tab roots — every route built directly by the app's
/// `ShellRoute`.
///
/// These can only ever be *switched to*. Pushing one rebuilds the shell page
/// with a key that is already reserved, which trips the Navigator's
/// `!keyReservation.contains(key)` assertion, so [AppNavigation.pushOrSwitchTab]
/// routes them through `go()` instead.
const kShellTabRoutes = <String>{
  '/home',
  '/flashcards',
  '/games',
  '/stories',
  '/progress',
  '/multi-dashboard',
  '/teacher-analytics',
  '/weekly-reports',
  '/settings',
};

extension AppNavigation on BuildContext {
  /// Goes back one screen, exactly like the system Back button.
  ///
  /// Falls back to [fallbackRoute] **only** when there is genuinely nothing to
  /// pop — a notification deep-link, a lock-screen hand-off, or a flow that
  /// deliberately reset the stack. Callers should pass the hub the feature
  /// belongs to so that entry path still lands somewhere sensible.
  void popOrGo(String fallbackRoute) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }

  /// Opens [route] as a drill-down, so Back returns to the current screen —
  /// except for the bottom-nav tab roots in [kShellTabRoutes], which switch
  /// tabs instead because they cannot be pushed.
  ///
  /// For call sites that navigate to a route decided at runtime (a
  /// recommendation card, a dashboard quick action) and so can't know which
  /// kind they got.
  void pushOrSwitchTab(String route) {
    if (kShellTabRoutes.contains(Uri.parse(route).path)) {
      go(route);
    } else {
      push(route);
    }
  }
}
