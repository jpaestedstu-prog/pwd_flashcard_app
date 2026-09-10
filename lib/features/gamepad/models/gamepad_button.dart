/// Every physical control on a Bluetooth gamepad the app understands.
///
/// The names are the **wire format** shared with the native Android bridge
/// (`GamepadBridge.kt`), so they must stay in sync with the `BUTTON_*`
/// constants there. Keeping them as an enum on the Dart side lets the mapping
/// from control → app action be a pure, exhaustively-switched function that is
/// unit-testable without a device.
///
/// ### Why sticks and triggers appear here as *buttons*
/// The X3 (`GamePadPlus V3`) reports its D-pad as a **hat switch**
/// (`ABS_HAT0X/Y`), its thumbsticks as `ABS_X/Y` + `ABS_Z/RZ`, and L2/R2 as
/// `ABS_GAS/BRAKE` — i.e. as analogue *motion*, not key presses. Android
/// delivers those as `MotionEvent`s on `SOURCE_JOYSTICK`, which Flutter does
/// **not** forward to Dart at all. The native bridge therefore converts each
/// axis into discrete directional presses (with a dead zone and edge
/// detection) so the whole controller arrives here as one uniform stream.
enum GamepadButton {
  // ── D-pad (hat switch on the X3) ────────────────────────────────────────
  dpadLeft,
  dpadUp,
  dpadRight,
  dpadDown,

  // ── Face buttons, in the physical diamond ───────────────────────────────
  /// Bottom of the diamond.
  a,

  /// Right of the diamond.
  b,

  /// Left of the diamond.
  x,

  /// Top of the diamond.
  y,

  // ── Shoulders and triggers ──────────────────────────────────────────────
  l1,
  l2,
  r1,
  r2,

  // ── Centre buttons ──────────────────────────────────────────────────────
  select,
  start,

  // ── Thumbstick clicks (BTN_THUMBL / BTN_THUMBR) ─────────────────────────
  leftStickClick,
  rightStickClick,

  // ── Left thumbstick pushed past the dead zone ───────────────────────────
  leftStickLeft,
  leftStickUp,
  leftStickRight,
  leftStickDown,

  // ── Right thumbstick pushed past the dead zone ──────────────────────────
  rightStickLeft,
  rightStickUp,
  rightStickRight,
  rightStickDown,

  /// The vendor "mode"/home button (`BTN_MODE`). Deliberately unmapped — on
  /// most controllers it switches the pad's own HID profile, and reacting to
  /// it would fight the hardware.
  mode;

  /// Parses a wire name from the native bridge, or null when the bridge sends
  /// something this build doesn't know (forward compatibility: an unknown
  /// control is ignored rather than crashing the input loop).
  static GamepadButton? fromWire(String name) {
    for (final b in GamepadButton.values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// A single press or release arriving from the controller.
class GamepadEvent {
  final GamepadButton button;

  /// True for a press, false for a release. Releases are delivered so the
  /// bridge can be trusted to balance its synthetic axis presses, but the
  /// navigation layer acts on presses only.
  final bool pressed;

  /// Android's `deviceId`, so a second controller can be told apart.
  final int deviceId;

  const GamepadEvent({
    required this.button,
    required this.pressed,
    this.deviceId = 0,
  });

  @override
  String toString() =>
      'GamepadEvent(${button.name}, ${pressed ? "down" : "up"}, dev $deviceId)';
}

/// A controller appearing or disappearing.
class GamepadConnectionEvent {
  final int deviceId;
  final String name;
  final bool connected;

  const GamepadConnectionEvent({
    required this.deviceId,
    required this.name,
    required this.connected,
  });
}
