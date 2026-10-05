import 'package:flutter/widgets.dart';

import '../logic/gaze_focus_driver.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../services/gaze_metrics.dart';
import 'gaze_focus_overlay.dart';
import 'gaze_keyboard.dart';

/// The **focus-traversal fallback**, shared by every gaze scope.
///
/// A scope drives the controls *it* knows about — the shell's tab bar and hub
/// tiles, the flashcard viewer's action bar, a game's edge targets. The moment
/// something it does not know about is in front of them (a dialog, a bottom
/// sheet, a pushed page, a game's pause card) those controls are hidden, and
/// gaze has to steer whatever is showing instead. This hands the learner's
/// head moves, blinks, scan steps and spoken commands to Flutter's own focus
/// traversal — the same machinery a keyboard or a TV remote uses — so any
/// Material control on the covering surface becomes reachable with no
/// per-screen wiring, and a bright ring above every route shows where it is.
///
/// Only the navigation shell had this at first. A sheet opened from the
/// flashcard viewer ("Show Me", "Examples", the FSL clip) or a game's pause
/// card therefore left a hands-free learner with no way to press anything
/// or to leave: the viewer's scope correctly stopped driving its hidden
/// action bar, and nothing took over.
///
/// **Every surface has a way out.** Many sheets have no close button at all —
/// a touch user taps the dimmed area or presses Back — so traversal alone
/// could reach everything on them except the exit. A "Back" pill sits
/// top-left whenever traversal is live: looking ▲ (or ◀) from the first
/// control lands on it, scanning visits it after the last control, and a
/// blink there closes the dialog, sheet or page — the same rule as the Back
/// pill on the D-pad screens.
class GazeTraversal {
  GazeTraversal({
    required this.onMoved,
    required this.onPressed,
    this.onLeft,
    this.onScanned,
  });

  /// A focus move happened (haptic tick, measurement, spoken name…).
  final VoidCallback onMoved;

  /// A scanning step moved the focus; [onMoved] when not given.
  final VoidCallback? onScanned;

  /// A control was pressed, and what pressed it.
  final void Function(GazeSelectBy by) onPressed;

  /// The learner took the Back pill / said "go back".
  final VoidCallback? onLeft;

  final GazeFocusOverlay _ring = GazeFocusOverlay();
  BuildContext? _ringContext;
  String? _hint;

  /// The highlight is on the Back pill rather than on a control.
  bool _onExit = false;

  /// Whether the traversal ring is currently drawn.
  bool get ringShowing => _ring.isShowing;

  /// Whether the highlight is resting on the Back pill.
  bool get onExit => _onExit;

  /// Shows the ring while [wanted], hides it otherwise. Idempotent.
  void syncRing(
    BuildContext context, {
    required bool wanted,
    String? hint,
  }) {
    if (!wanted) {
      _onExit = false;
      _ring.hide();
      return;
    }
    _ringContext = context;
    _hint = hint;
    _ring.show(context, hint: hint, exitFocused: _onExit);
  }

  /// Removes the ring (scope teardown).
  void hideRing() {
    _onExit = false;
    _ring.hide();
  }

  void _setExit(bool value) {
    if (_onExit == value) return;
    _onExit = value;
    final context = _ringContext;
    if (_ring.isShowing && context != null) {
      _ring.show(context, hint: _hint, exitFocused: value);
    }
  }

  /// One step in [direction]. When the surface has nothing focusable that way
  /// the focus is probably still on its bare scope node, so pull it onto the
  /// first control and the next gesture has somewhere to go. Backwards from
  /// the first control — or anywhere, on a surface with no controls — is the
  /// Back pill.
  bool move(TraversalDirection direction) {
    final backward =
        direction == TraversalDirection.up ||
        direction == TraversalDirection.left;
    // Checked first: on a surface with nothing focusable (a "Show Me" clip
    // sheet is just a video) Flutter's directional traversal re-focuses the
    // bare scope and reports success, so every gesture looked handled while
    // nothing happened at all.
    if (!GazeFocusDriver.hasFocusable()) {
      // Nothing to press here: Back is the only place to go.
      _setExit(true);
      onMoved();
      return true;
    }
    if (_onExit) {
      if (backward) return false;
      // Off the Back pill: the first control — not the one below it, which is
      // where a step from the (still focused) first control used to land.
      if (GazeFocusDriver.moveToStart()) {
        _setExit(false);
        onMoved();
        return true;
      }
      return false;
    }
    if (backward && GazeFocusDriver.isFirst()) {
      _setExit(true);
      onMoved();
      return true;
    }
    final moved =
        GazeFocusDriver.move(direction) || GazeFocusDriver.moveFirst();
    if (moved) {
      onMoved();
      _keepSystemKeyboardDown();
    }
    return moved;
  }

  /// Focus landing on a text field raises the system keyboard by itself —
  /// half the screen, none of it reachable by gaze. Put it away; a blink on
  /// the field opens the gaze keyboard instead.
  void _keepSystemKeyboardDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = GazeFocusDriver.focused?.context;
      if (context != null && GazeKeyboard.editableFor(context) != null) {
        GazeKeyboard.hideSystemKeyboard();
      }
    });
  }

  /// Presses whatever the ring is on. A freshly opened dialog often still has
  /// focus on its scope node with nothing to press, so pull focus onto its
  /// first control instead and the learner's first blink is never swallowed.
  /// On the Back pill, closes the surface.
  bool commit({GazeSelectBy by = GazeSelectBy.blink}) {
    if (_onExit) {
      _setExit(false);
      onLeft?.call();
      return GazeFocusDriver.popTop();
    }
    if (!GazeFocusDriver.hasFocusable()) {
      // A surface with nothing on it but its way out: the first blink lights
      // Back, the next one takes it — the same two blinks as everywhere else.
      _setExit(true);
      onMoved();
      return true;
    }
    // A text field: the gaze keyboard, since nothing else can type into it.
    if (GazeKeyboard.openForFocus()) {
      onPressed(by);
      return true;
    }
    if (GazeFocusDriver.activate()) {
      onPressed(by);
      return true;
    }
    if (GazeFocusDriver.moveFirst()) {
      onMoved();
      return true;
    }
    return false;
  }

  /// A completed head hold. Look-up doubles as "press it" when nothing else
  /// picks ([GazeSettings.lookUpSelects]), mirroring the D-pad's rule so a
  /// head-only learner always has a way to press; ▼ still reaches everything,
  /// so nothing is stranded.
  void zone(GazeZone zone, {required bool lookUpSelects}) {
    switch (zone) {
      case GazeZone.left:
        move(TraversalDirection.left);
      case GazeZone.right:
        move(TraversalDirection.right);
      case GazeZone.up:
        lookUpSelects
            ? commit(by: GazeSelectBy.headHold)
            : move(TraversalDirection.up);
      case GazeZone.down:
        move(TraversalDirection.down);
      case GazeZone.none:
        break;
    }
  }

  /// Scanning mode: the next control in reading order lights up, and after
  /// the last one, the Back pill.
  bool scanStep() {
    final stepped = onScanned ?? onMoved;
    if (!GazeFocusDriver.hasFocusable()) {
      // Only the way out to offer: keep it lit.
      _setExit(true);
      return true;
    }
    if (_onExit) {
      // Round again from the top of the page.
      final moved = GazeFocusDriver.moveToStart();
      _setExit(false);
      if (moved) stepped();
      return moved;
    }
    if (GazeFocusDriver.isLast()) {
      _setExit(true);
      stepped();
      return true;
    }
    final moved = GazeFocusDriver.scanNext();
    if (moved) stepped();
    return moved;
  }

  /// A spoken phrase while traversing. Movement, select and "go back" are
  /// handled here — "go back" closes the surface holding the focus, which is
  /// right even for a sheet on the shell's own navigator. The returned intent
  /// tells the scope whether there is a scroll for it to perform (it owns the
  /// scroll gesture). Resolved against an empty grid, so only the global
  /// intents can match — a dialog publishes no cells to address by name.
  DpadVoiceIntent voice(String text) {
    final intent = resolveDpadVoiceCommand(text, const []).intent;
    switch (intent) {
      case DpadVoiceIntent.moveLeft:
        move(TraversalDirection.left);
      case DpadVoiceIntent.moveRight:
        move(TraversalDirection.right);
      case DpadVoiceIntent.moveUp:
        move(TraversalDirection.up);
      case DpadVoiceIntent.moveDown:
        move(TraversalDirection.down);
      case DpadVoiceIntent.select:
      case DpadVoiceIntent.activate:
        commit(by: GazeSelectBy.voice);
      case DpadVoiceIntent.goBack:
        _setExit(false);
        onLeft?.call();
        GazeFocusDriver.popTop();
      case DpadVoiceIntent.scrollUp:
      case DpadVoiceIntent.scrollDown:
      case DpadVoiceIntent.none:
        break;
    }
    return intent;
  }
}
