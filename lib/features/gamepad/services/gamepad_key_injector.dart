import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  /// Returns whether the key could be delivered at all. False means the
  /// caller should say so rather than leaving the learner pressing a control
  /// that quietly does nothing.
  static bool sendArrow(TraversalDirection direction) {
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
      return false;
    }

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
      handler(KeyMessage([down], null));
      // ignore: deprecated_member_use
      handler(KeyMessage([up], null));
      return true;
    } catch (e) {
      // Never let a synthetic key take the controller down with it.
      if (kDebugMode) debugPrint('GamepadAdjust: injection failed: $e');
      return false;
    }
  }
}
