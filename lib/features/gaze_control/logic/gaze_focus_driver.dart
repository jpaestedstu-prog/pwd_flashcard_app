import 'package:flutter/material.dart';

/// Drives Flutter's **built-in directional focus traversal** from gaze input.
///
/// The published-grid D-pad ([gazeHomeGrid] / `GazeDpadScope`) only reaches
/// cells a screen has explicitly registered. That covers the hubs and a handful
/// of adopters — but a dialog, a bottom sheet or any of the ~15 pushed screens
/// the hub tiles can open registers nothing, so a hands-free learner could open
/// them and then not operate or leave them. The Daily Reward dialog that greets
/// a learner on login was exactly this: touch-only.
///
/// Rather than hand-wiring every one of those screens, this drives the focus
/// traversal Flutter already implements for keyboards and Android TV D-pads.
/// Material's buttons, list tiles, text fields and dialog actions are focusable
/// out of the box, so the covering route becomes navigable for free — including
/// its back button, which is what gives a learner the way out.
///
/// Pure static helpers over [FocusManager]: no camera, no widgets, so the
/// mapping is unit-testable with plain `Focus` nodes.
abstract final class GazeFocusDriver {
  /// The node gaze should act on: whatever currently holds focus. When a route
  /// is pushed, Flutter moves focus into that route's own [FocusScopeNode], so
  /// this naturally follows the topmost screen and traversal stays inside it.
  static FocusNode? get focused {
    final node = FocusManager.instance.primaryFocus;
    // A node with no context can't be traversed from or activated.
    return node?.context == null ? null : node;
  }

  /// Moves focus one step in [direction]. Returns whether focus actually moved,
  /// so the caller can fall back (e.g. keep a scroll gesture) when the route has
  /// nothing focusable that way.
  static bool move(TraversalDirection direction) {
    final node = focused;
    if (node == null) return false;
    if (!node.focusInDirection(direction)) return false;
    _revealFocused();
    return true;
  }

  /// Scrolls the newly focused control into view.
  ///
  /// Traversal will happily focus a widget below the fold — on a long pushed
  /// screen that leaves the learner steering something they cannot see, with
  /// the ring off-screen too. The published-grid path already does this
  /// (`GazeFocusable._ensureVisible`); this keeps the fallback honest on
  /// exactly the long screens it exists for.
  ///
  /// Deferred to the next frame: Flutter applies a focus change asynchronously,
  /// so reading [focused] immediately after [move] still returns the *previous*
  /// node — which would scroll the control the learner just left.
  static void _revealFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = focused?.context;
      if (context == null || !context.mounted) return;
      if (Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5, // centre it, like the tile grid does
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Activates the focused control — the same path a keyboard Enter or an
  /// Android TV D-pad centre press takes, so a widget that responds to those
  /// responds to a blink with no extra wiring.
  ///
  /// Returns false when nothing actionable is focused (e.g. the route's bare
  /// scope node), letting the caller try [moveFirst] instead of doing nothing.
  ///
  /// Success is decided by *finding an enabled action*, not by its return
  /// value: Material's activate action runs the button's `onPressed` and
  /// returns null, so treating null as failure would report every successful
  /// press as a miss.
  static bool activate() {
    final node = focused;
    final context = node?.context;
    if (context == null) return false;
    const intent = ActivateIntent();
    final action = Actions.maybeFind<ActivateIntent>(context, intent: intent);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(context, intent);
    return true;
  }

  /// Pulls focus onto the first focusable control of the current scope. Used
  /// when a route has just appeared and focus is still resting on its scope
  /// node, so the learner's first head move lands somewhere visible instead of
  /// being swallowed.
  static bool moveFirst() {
    final node = focused;
    if (node == null) return false;
    // Down then right covers both column- and row-shaped layouts; whichever
    // finds a node first wins.
    return node.focusInDirection(TraversalDirection.down) ||
        node.focusInDirection(TraversalDirection.right);
  }

  /// Global-coordinate rectangle of the focused control, for drawing a
  /// highlight the learner can actually see. Null when nothing real is focused
  /// or it has not been laid out.
  static Rect? get focusedRect {
    final node = focused;
    if (node == null) return null;
    final renderObject = node.context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    if (!renderObject.attached) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }
}
