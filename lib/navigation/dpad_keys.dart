import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/gaze_control/logic/gaze_focus_driver.dart';
import '../features/gaze_control/widgets/gaze_focus_overlay.dart' show DpadFocusRing;

/// The arrow keys as a D-pad, on Android and in the web app alike: a
/// keyboard, a TV-style remote or a switch box set to send arrows.
///
/// Flutter's default on Android moves focus with the arrows, but in a browser
/// it scrolls the page instead — there a keyboard could not reach a single
/// tab or tile. These replace the app-level defaults only (they sit above the
/// text-editing shortcuts), so a focused text field still moves its caret and
/// a focused slider still slides: their own shortcuts are nearer the focus and
/// are asked first.
Map<ShortcutActivator, Intent> get dpadShortcuts => <ShortcutActivator, Intent>{
  ...WidgetsApp.defaultShortcuts,
  const SingleActivator(LogicalKeyboardKey.arrowUp):
      const DirectionalFocusIntent(TraversalDirection.up),
  const SingleActivator(LogicalKeyboardKey.arrowDown):
      const DirectionalFocusIntent(TraversalDirection.down),
  const SingleActivator(LogicalKeyboardKey.arrowLeft):
      const DirectionalFocusIntent(TraversalDirection.left),
  const SingleActivator(LogicalKeyboardKey.arrowRight):
      const DirectionalFocusIntent(TraversalDirection.right),
};

/// The app-level actions: Flutter's own, with the arrows' move taken over by
/// [DpadDirectionalFocusAction].
Map<Type, Action<Intent>> get dpadActions => <Type, Action<Intent>>{
  ...WidgetsApp.defaultActions,
  ScrollIntent: ScrollAction(),
  DirectionalFocusIntent: DpadDirectionalFocusAction(),
};

/// Moves the focus for an arrow key the way gaze's and the game controller's
/// traversal already do ([GazeFocusDriver.move]), so all three D-pads step
/// through a screen in the same order — including the fixes that driver
/// carries for rows Flutter would skip and footers it would not cross.
///
/// Two additions, both about edges:
///  * a page's information is not all controls. Progress ends in charts and
///    badges, a story in its text, and stepping past the last control used to
///    wrap straight back to the top without them ever coming into view. At the
///    first or last control, with more page beyond it, the page scrolls first;
///  * up or down with nothing at all that way (the tab bar is the bottom of
///    every hub) stays put, as a remote does at the edge of a TV screen. The
///    driver's reading-order fallback is for controls geometry cannot find —
///    a pinned footer below a list — and from the tab bar it jumped back up
///    into the page.
class DpadDirectionalFocusAction extends DirectionalFocusAction {
  @override
  void invoke(DirectionalFocusIntent intent) {
    // The ring shows from the first press, whatever device sent it.
    DpadFocusRing.arrowKeysMoved();
    final direction = intent.direction;
    final vertical = direction == TraversalDirection.up ||
        direction == TraversalDirection.down;
    final forward = direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    if (vertical &&
        (forward ? GazeFocusDriver.isLast() : GazeFocusDriver.isFirst()) &&
        scrollPage(forward: forward)) {
      return;
    }
    if (vertical && _atOuterEdge(down: forward)) {
      scrollPage(forward: forward);
      return;
    }
    if (GazeFocusDriver.move(direction)) return;
    if (vertical) scrollPage(forward: forward);
  }

  /// Whether nothing focusable lies below (or above) the focused control at
  /// all — in its own surface or, for a page inside the navigation shell, the
  /// shell around it.
  static bool _atOuterEdge({required bool down}) {
    final node = GazeFocusDriver.focused;
    if (node == null || node is FocusScopeNode) return false;
    final Rect from;
    try {
      from = node.rect;
    } catch (_) {
      return false;
    }
    final scope = GazeFocusDriver.reachableScope(node);
    if (scope == null) return false;
    for (final other in scope.traversalDescendants) {
      if (identical(other, node) || other is FocusScopeNode) continue;
      final Rect r;
      try {
        r = other.rect;
      } catch (_) {
        continue;
      }
      // Centres, as Flutter's own search compares them: a guest's floating
      // Home button sits over the lower corner of the last deck, and judged
      // against the deck's bottom edge it was "not below", so down never
      // reached it. Within a row's slack is level, not below: the AI Buddy
      // sits 4 px higher than that Home button beside it, and down from it
      // went round to the top of the page.
      if (down
          ? r.center.dy > from.center.dy + GazeFocusDriver.rowSlack
          : r.center.dy < from.center.dy - GazeFocusDriver.rowSlack) {
        return false;
      }
    }
    return true;
  }

  /// Scrolls the page holding the focus most of a screen up or down. Returns
  /// whether there was any page left to show that way.
  static bool scrollPage({required bool forward}) {
    final position = _pageUnderFocus();
    if (position == null) return false;
    final step = position.viewportDimension * 0.8;
    final target = (position.pixels + (forward ? step : -step)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) return false;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  /// The vertical scroll view around the focused control — or, while nothing
  /// is focused yet (the page's own scope holds focus), the first one inside
  /// the page that can scroll.
  static ScrollPosition? _pageUnderFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return null;
    final around = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (around != null) return around.position;
    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final position = state.position;
        if (axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
            position.hasContentDimensions &&
            position.maxScrollExtent > position.minScrollExtent) {
          found = position;
          return;
        }
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }
}

/// The focus node a control floating above the router attaches under, so
/// the D-pad's traversal can reach it: the navigation shell's own scope while
/// a shell is showing, else null.
///
/// The AI Buddy launcher is drawn in `MaterialApp.builder`, beside the
/// router rather than inside it, so in the focus tree it belonged to no page
/// and arrows from the hub never found it. The shell publishes its scope
/// here; the launcher hangs its focus node from it.
final ValueNotifier<FocusNode?> dpadFloatingParent = ValueNotifier(null);

/// Up and down leave a focused slider rather than nudge it; left and right
/// still change its value.
///
/// Flutter's slider takes all four arrows unless the app says it is being
/// driven by a D-pad ([NavigationMode.directional]), and a D-pad has no Tab
/// key — so a learner who arrowed onto a slider could never arrow off it.
/// Scoped to the slider alone: app-wide, directional mode would also make
/// every disabled button a stop. The game controller's adjust mode only ever
/// sends left and right, so it is unaffected.
class DpadSliderScope extends StatelessWidget {
  const DpadSliderScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(navigationMode: NavigationMode.directional),
    child: child,
  );
}
