import 'package:flutter/foundation.dart';
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
  const SingleActivator(LogicalKeyboardKey.escape): const DpadBackIntent(),
};

/// The app-level actions: Flutter's own, with the arrows' move taken over by
/// [DpadDirectionalFocusAction], Escape made Back ([DpadBackAction]), and
/// up and down able to leave a one-line text field ([DpadFieldExits]).
Map<Type, Action<Intent>> get dpadActions => <Type, Action<Intent>>{
  ...WidgetsApp.defaultActions,
  ScrollIntent: ScrollAction(),
  DirectionalFocusIntent: DpadDirectionalFocusAction(),
  DpadBackIntent: DpadBackAction(),
  DpadLeaveFieldIntent: DpadLeaveFieldAction(),
};

/// Escape, as Back.
class DpadBackIntent extends Intent {
  const DpadBackIntent();
}

/// Escape is Back: the step back the system Back button takes on Android —
/// out of a dialog or a sheet, back a screen, a game to its pause menu — and,
/// like it, nothing at the very start of the app. It never closes the app.
///
/// A web keyboard, a TV remote in a browser and a switch box set to Escape
/// had no way back but steering to the on-screen arrow, and a pushed screen
/// in the web app is one the browser's own Back does not know about. A
/// dialog that may be dismissed, or an open menu, still closes the way Escape
/// always closed it; this takes the rest, as Back does.
///
/// Its own intent, not Flutter's [DismissIntent]: every page route answers
/// that one with a dismiss that is switched off for pages, and Flutter stops
/// at the nearest answer, switched off or not — so on a page, Escape never
/// got past it.
///
/// In a text field Escape only leaves the field, as Back first closes the
/// keyboard: a learner halfway through a message keeps the screen.
class DpadBackAction extends Action<DpadBackIntent> {
  @override
  Object? invoke(DpadBackIntent intent) {
    final node = FocusManager.instance.primaryFocus;
    final context = node?.context;
    if (node == null || context == null || !context.mounted) return null;
    if (isInTextField(node)) {
      leaveTextField(node);
      return null;
    }
    if (dpadDismiss(context)) return null;
    Router.maybeOf(context)?.backButtonDispatcher?.invokeCallback(
      SynchronousFuture<bool>(false),
    );
    return null;
  }
}

/// Closes what [context] sits in when that answers a dismiss: a dialog that
/// may be dismissed, an open menu, the AI Buddy's panel. Returns whether it
/// did — a page does not answer, and Back then goes back.
///
/// Shared by Escape and the controller's B, which had only the router's
/// back: the AI Buddy's panel is no route, so B said "nothing to go back
/// to" and the panel stayed (found on the tablet, 29 Oct).
bool dpadDismiss(BuildContext context) {
  const dismiss = DismissIntent();
  final closes = Actions.maybeFind<DismissIntent>(context, intent: dismiss);
  if (closes == null) return false;
  final (enabled, _) = Actions.of(
    context,
  ).invokeActionIfEnabled(closes, dismiss, context);
  return enabled;
}

/// Whether [node] is a text field's own focus — where Escape, and the
/// controller's B, leave the field rather than the screen.
bool isInTextField(FocusNode node) =>
    node.context?.findAncestorStateOfType<EditableTextState>() != null;

/// Leaves the text field [node] for the control the learner came to it from.
///
/// A plain unfocus left the focus on the page itself, so the next arrow
/// started again from the top of the screen — a learner who stepped out of
/// a search box at the bottom of a list was thrown back to its first item.
void leaveTextField(FocusNode node) =>
    node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

/// Up or down, asked of a one-line text field: leave it.
class DpadLeaveFieldIntent extends Intent {
  const DpadLeaveFieldIntent(this.direction);

  final TraversalDirection direction;
}

/// Lets up and down leave a one-line text field, as they leave a button.
///
/// Flutter's text shortcuts give a one-line field up and down too — they jump
/// the caret to the start or the end — so a learner with a remote or a
/// switch box who arrowed into a search box or the Messages field could
/// never arrow out of it again. A field of several lines keeps them: there
/// they move between its lines. Sits below Flutter's text shortcuts (in
/// `MaterialApp.builder`), so it is asked first.
class DpadFieldExits extends StatelessWidget {
  const DpadFieldExits({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp):
          DpadLeaveFieldIntent(TraversalDirection.up),
      SingleActivator(LogicalKeyboardKey.arrowDown):
          DpadLeaveFieldIntent(TraversalDirection.down),
    },
    child: child,
  );
}

/// See [DpadFieldExits]. Enabled only in a one-line field; anywhere else the
/// key goes on to whatever handled it before.
class DpadLeaveFieldAction extends Action<DpadLeaveFieldIntent> {
  @override
  bool isEnabled(DpadLeaveFieldIntent intent, [BuildContext? context]) {
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    return field != null && field.widget.maxLines == 1;
  }

  @override
  Object? invoke(DpadLeaveFieldIntent intent) {
    DpadDirectionalFocusAction().invoke(
      DirectionalFocusIntent(intent.direction),
    );
    return null;
  }
}

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
    // A focus with no place on the screen — scrolled away under a finger or
    // a screen reader, or let go to its scope — starts again from what is on
    // screen; the edge checks below cannot measure from it.
    if (GazeFocusDriver.startOnScreen(forward: forward)) return;
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
      if (!GazeFocusDriver.countsAhead(node, other)) continue;
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
  const DpadSliderScope({super.key, this.name, required this.child});

  /// What the slider sets ("Voice Speed"), joined to the slider so a screen
  /// reader says name and value as one stop: "Slow, Voice Speed, slider".
  ///
  /// Flutter's [Slider] gives a screen reader its value bubble
  /// ([Slider.label]) as its name, so a slider showing "60%" was named "60%"
  /// and said nothing of what it set. And swiped up or down, TalkBack reads
  /// the value it moves to from [Slider.semanticFormatterCallback] at once,
  /// before the screen rebuilds — beside the old bubble ("65%, 60%"). So a
  /// named slider has no bubble: its formatter says the value, the value
  /// shows in its row, and the words in that row stay out of the a11y tree.
  final String? name;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scoped = MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(navigationMode: NavigationMode.directional),
      child: child,
    );
    final name = this.name;
    if (name == null) return scoped;
    return MergeSemantics(child: Semantics(label: name, child: scoped));
  }
}
