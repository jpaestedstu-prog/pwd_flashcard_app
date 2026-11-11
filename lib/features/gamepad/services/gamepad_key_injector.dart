import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/input_trace.dart';

/// How a controller's arrow press went ([GamepadKeyInjector.sendArrow]).
enum ArrowDelivery {
  /// It could not be sent at all.
  failed,

  /// Sent, and nothing in the app took it.
  ignored,

  /// Sent, and something acted on it: a move, a slider's turn.
  taken,
}

/// Sends a real arrow key into Flutter, so the focused control adjusts itself.
///
/// ## Why this rather than a per-widget callback
/// A slider has to be *nudged*, not pressed, and the app has sliders in half a
/// dozen places (speech speed, daily mission size, the gamepad's own tuning).
/// Wiring an "adjust" callback through every one of them would be a lot of
/// call sites and a standing invitation to drift — a slider added later would
/// silently be unadjustable again.
///
/// Flutter's [Slider] already knows how to move itself by one division when it
/// has focus and receives ← or →, because that is what a keyboard user does.
/// Handing it exactly that event reuses the behaviour instead of duplicating
/// it, and it works for anything else that handles arrows — dropdowns, tab
/// bars, a custom control added next year — with no further work.
///
/// ## Why not the semantics route
/// `SemanticsAction.increase` is what TalkBack uses on a slider, and it would
/// be the tidier API. But Flutter only *builds* a semantics tree while an
/// accessibility service is bound, and the learner this feature exists for
/// drives the app with a controller **instead of** TalkBack — so on their
/// device there would be no semantics node to act on.
abstract final class GamepadKeyInjector {
  /// Delivers one ←/→/↑/↓ press-and-release to whatever holds focus.
  ///
  /// Says how it went. [ArrowDelivery.failed] means the caller should say so
  /// rather than leaving the learner pressing a control that quietly does
  /// nothing; [ArrowDelivery.ignored], that the caller should do the move
  /// itself.
  static ArrowDelivery sendArrow(TraversalDirection direction) {
    final key = switch (direction) {
      TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
      TraversalDirection.right => LogicalKeyboardKey.arrowRight,
      TraversalDirection.up => LogicalKeyboardKey.arrowUp,
      TraversalDirection.down => LogicalKeyboardKey.arrowDown,
    };
    final physical = switch (direction) {
      TraversalDirection.left => PhysicalKeyboardKey.arrowLeft,
      TraversalDirection.right => PhysicalKeyboardKey.arrowRight,
      TraversalDirection.up => PhysicalKeyboardKey.arrowUp,
      TraversalDirection.down => PhysicalKeyboardKey.arrowDown,
    };

    // The handler the focus system installs — the same one a real key press
    // from the engine goes through, so Shortcuts and Actions see this exactly
    // as they would a keyboard.
    //
    // `keyMessageHandler` is deprecated in favour of listening on
    // `HardwareKeyboard`, but that replacement is for *observing* keys; there
    // is no supported API for *injecting* one outside the test harness. If a
    // future Flutter removes this, the analyzer will fail here rather than the
    // feature failing silently, and the fallback below already covers a null
    // handler.
    // ignore: deprecated_member_use
    final handler = ServicesBinding.instance.keyEventManager.keyMessageHandler;
    if (handler == null) {
      if (kDebugMode) debugPrint('GamepadAdjust: no key handler installed');
      return ArrowDelivery.failed;
    }

    _letGoOfModifiers();
    final down = KeyDownEvent(
      physicalKey: physical,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
    final up = KeyUpEvent(
      physicalKey: physical,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
    try {
      // ignore: deprecated_member_use
      final taken = handler(KeyMessage([down], null));
      // ignore: deprecated_member_use
      handler(KeyMessage([up], null));
      return taken ? ArrowDelivery.taken : ArrowDelivery.ignored;
    } catch (e) {
      // Never let a synthetic key take the controller down with it.
      if (kDebugMode) debugPrint('GamepadAdjust: injection failed: $e');
      return ArrowDelivery.failed;
    }
  }

  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  /// Lets go of any keyboard modifier Flutter still believes is held.
  ///
  /// A shortcut for a plain arrow does not match while Alt, Shift, Control or
  /// Meta is down, and Flutter can believe one is down for good. TalkBack's own
  /// keys are Alt + arrow: it keeps the arrow for itself, and it can keep the
  /// release of Alt too. Flutter hears otherwise only from the keyboard's next
  /// key, and a controller's presses never pass that way. So after a keyboard
  /// session every arrow from the controller went nowhere: "Nothing more that
  /// way. Still on Unnamed item" (on the tablet, 29 Oct and 4 Nov), while L2
  /// and R2, which send no key, carried on working. Someone pressing the
  /// controller is not also holding Alt on a keyboard for it.
  static void _letGoOfModifiers() {
    final keyboard = HardwareKeyboard.instance;
    for (final physical in keyboard.physicalKeysPressed.toList()) {
      final logical = keyboard.lookUpLayout(physical);
      if (logical == null || !_modifiers.contains(logical)) continue;
      InputTrace.log('GamepadAdjust: let go of ${logical.debugName}');
      keyboard.handleKeyEvent(
        KeyUpEvent(
          physicalKey: physical,
          logicalKey: logical,
          timeStamp: Duration.zero,
        ),
      );
    }
  }
}
