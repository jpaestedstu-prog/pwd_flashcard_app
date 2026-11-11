import 'package:flutter/material.dart';

/// Puts the focus on a pop-up's first control the moment it opens: a dialog,
/// a bottom sheet, a menu — and the in-screen pop-ups with no route of their
/// own, such as a game's pause card ([watchRegion]).
///
/// Flutter moves focus into a new pop-up's scope, but onto nothing inside it,
/// and of the app's sixty-odd dialogs only a handful named a control to start
/// on. So the first thing a D-pad learner pressed — a remote's OK, a switch,
/// a keyboard's Enter — fell on the empty scope and did nothing, and the
/// first arrow only landed on the first control. Both read as a press the
/// app dropped. The Daily Reward dialog that greets a learner every morning
/// was where it showed: "Collect" took two presses.
///
/// Left alone when the pop-up chose for itself (`autofocus`), when something
/// else took the focus first, and when the first control is a text field:
/// focusing one raises the on-screen keyboard over its own dialog, and on a
/// remote the arrows would then move its caret instead of leaving it.
///
/// Nothing a finger sees: a focused button shows its ring only once a D-pad
/// is in use, and on Android a screen reader's own focus does not follow it.
/// In a browser the screen reader does follow it — which is how a web dialog
/// is expected to behave.
abstract final class DpadModalFocus {
  static FocusManager? _watching;

  /// The scopes of the in-screen pop-ups that have no route of their own —
  /// a game's pause card, the level-up celebration, Home's first-visit tour
  /// (`GazeModalRegion`). They open the same way, on their scope and onto
  /// nothing: the pause card's Resume took two presses as well.
  static final Set<FocusScopeNode> _regions = {};

  /// Treats [scope] as a pop-up's own while it lives (see [_regions]).
  static void watchRegion(FocusScopeNode scope) => _regions.add(scope);

  static void forgetRegion(FocusScopeNode scope) => _regions.remove(scope);

  /// Starts watching — once, at start-up; calling again changes nothing.
  /// Tied to the focus manager itself rather than to a flag, because a
  /// widget test gets a new one for every test.
  static void install() {
    final manager = FocusManager.instance;
    if (identical(_watching, manager)) return;
    _watching = manager;
    manager.addListener(_onFocusChanged);
  }

  static void _onFocusChanged() {
    final scope = FocusManager.instance.primaryFocus;
    if (scope is! FocusScopeNode || !opensEmpty(scope)) return;
    // After a frame: the pop-up's controls have to be laid out before there
    // is a first one to find. And a frame is asked for, not waited for — on
    // a still screen the next one would come only with the learner's next
    // key, which is the very press this is here to catch.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!scope.hasPrimaryFocus) return;
        final first = firstControl(scope);
        if (first != null) first.requestFocus();
      })
      ..ensureVisualUpdate();
  }

  /// Whether [scope] is a pop-up's own scope, focused with nothing in it.
  @visibleForTesting
  static bool opensEmpty(FocusScopeNode scope) {
    if (scope.focusedChild != null) return false;
    if (_regions.contains(scope)) return true;
    final context = scope.context;
    if (context == null || !context.mounted) return false;
    final route = ModalRoute.of(context);
    if (route is! PopupRoute) return false;
    // The pop-up's outermost scope, not one nested inside it: that one's
    // enclosing scope is the navigator's, which belongs to another route
    // (or to none).
    final outer = scope.enclosingScope?.context;
    return outer == null ||
        !outer.mounted ||
        !identical(ModalRoute.of(outer), route);
  }

  /// The control a D-pad should start on in [scope], or null to leave the
  /// focus where it is (see the class comment for when).
  @visibleForTesting
  static FocusNode? firstControl(FocusScopeNode scope) {
    final context = scope.context;
    if (context == null || !context.mounted) return null;
    final policy =
        FocusTraversalGroup.maybeOf(context) ?? ReadingOrderTraversalPolicy();
    final first = policy.findFirstFocus(scope);
    if (first == null || first is FocusScopeNode || identical(first, scope)) {
      return null;
    }
    if (!first.canRequestFocus || first.skipTraversal) return null;
    final at = first.context;
    if (at == null ||
        at.findAncestorStateOfType<EditableTextState>() != null) {
      return null;
    }
    return first;
  }
}
