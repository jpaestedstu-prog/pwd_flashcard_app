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
    // Geometry first: for a D-pad, "the control below this one" is what the
    // learner means.
    if (node.focusInDirection(direction)) {
      _revealFocused();
      return true;
    }
    // Geometry can legitimately fail while there is still somewhere to go.
    // Directional traversal will not cross a scroll boundary into a pinned
    // footer, so on the game category picker a learner reached the last
    // category and then simply stopped — the "Start" button underneath was
    // unreachable and the screen was a dead end. Reading order has no such
    // blind spot, so fall back to it rather than stranding them.
    final forward =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    if (forward ? node.nextFocus() : node.previousFocus()) {
      _revealFocused();
      return true;
    }
    return false;
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

  /// Scanning mode's step over a covering route: moves focus to the next
  /// control in reading order, wrapping from the last back to the first, so a
  /// blink-only learner sees each control of a dialog or pushed page light up
  /// in turn. From a bare scope node (a route that has only just appeared)
  /// this lands on its first control.
  static bool scanNext() {
    final node = focused;
    if (node == null) return false;
    if (node.nextFocus()) {
      _revealFocused();
      return true;
    }
    return false;
  }

  /// The controls focus can move among on the focused surface, in reading
  /// order (top to bottom, then left to right within a row).
  static List<FocusNode> _readingOrder(FocusNode node) {
    final scope = node.nearestScope;
    if (scope == null) return const [];
    final nodes = <({FocusNode node, Rect rect})>[];
    for (final n in scope.traversalDescendants) {
      if (n is FocusScopeNode || n.context == null) continue;
      try {
        nodes.add((node: n, rect: n.rect));
      } catch (_) {
        // Not laid out yet — not somewhere the learner can be.
      }
    }
    nodes.sort((a, b) {
      final dy = a.rect.center.dy - b.rect.center.dy;
      // Controls whose centres are this close share a row.
      if (dy.abs() > 8) return dy < 0 ? -1 : 1;
      return a.rect.center.dx.compareTo(b.rect.center.dx);
    });
    return [for (final n in nodes) n.node];
  }

  /// Whether the focused control is the first one on its surface — the place
  /// from which looking up reaches the surface's way out.
  static bool isFirst() {
    final node = focused;
    if (node == null || node is FocusScopeNode) return false;
    final order = _readingOrder(node);
    return order.isNotEmpty && identical(order.first, node);
  }

  /// Whether the focused control is the last one on its surface.
  static bool isLast() {
    final node = focused;
    if (node == null || node is FocusScopeNode) return false;
    final order = _readingOrder(node);
    return order.isNotEmpty && identical(order.last, node);
  }

  /// Whether the focused surface has any control to move to at all.
  static bool hasFocusable() {
    final node = focused;
    return node != null && _readingOrder(node).isNotEmpty;
  }

  /// Closes whatever holds the focus — the dialog, the sheet or the page —
  /// exactly as the system Back button would. It asks the navigator the
  /// focused control lives in, so a sheet opened on the navigation shell's own
  /// navigator closes too (the gaze scope's own navigator is a different one).
  static bool popTop() {
    final context = focused?.context;
    if (context == null) return false;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return false;
    navigator.maybePop();
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
