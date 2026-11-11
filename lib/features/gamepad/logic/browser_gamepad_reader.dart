import '../models/gamepad_button.dart';

/// Turns what a web browser reports of a game controller into the presses and
/// releases the Android bridge sends (`GamepadBridge.kt`), so the web app's
/// controller goes through the very same host, actions and speech.
///
/// A browser has no events for a controller's buttons: the Gamepad API gives
/// a snapshot — every button's value from 0 to 1, every stick's position from
/// -1 to 1 — and a page reads it many times a second. This compares each
/// snapshot with the last one and reports only what changed, the way the
/// bridge turns Android's axis motion into edges. A stick or a trigger counts
/// as pressed past [press] and as let go below [release], so one held near
/// the line does not chatter, as on Android.
///
/// The layout is the browser's "standard" one, which Chrome gives the X3 and
/// any common controller: buttons 0–3 the face diamond (bottom, right, left,
/// top), 4/5 L1/R1, 6/7 L2/R2, 8/9 Select/Start, 10/11 the stick clicks,
/// 12–15 the D-pad (up, down, left, right), 16 the home button; axes 0/1 the
/// left stick, 2/3 the right one.
///
/// Pure: snapshots in, events out, so every case is unit-testable without a
/// browser.
class BrowserGamepadReader {
  BrowserGamepadReader({this.press = 0.6, this.release = 0.4})
      : assert(release < press);

  /// How far a trigger or a stick must go to count as pressed.
  final double press;

  /// How far it must come back before it counts as let go.
  final double release;

  /// The standard layout's buttons, by index.
  static const standardButtons = <GamepadButton>[
    GamepadButton.a,
    GamepadButton.b,
    GamepadButton.x,
    GamepadButton.y,
    GamepadButton.l1,
    GamepadButton.r1,
    GamepadButton.l2,
    GamepadButton.r2,
    GamepadButton.select,
    GamepadButton.start,
    GamepadButton.leftStickClick,
    GamepadButton.rightStickClick,
    GamepadButton.dpadUp,
    GamepadButton.dpadDown,
    GamepadButton.dpadLeft,
    GamepadButton.dpadRight,
    GamepadButton.mode,
  ];

  /// What each controller held at its last snapshot.
  final Map<int, Set<GamepadButton>> _held = {};

  /// The controllers seen so far, by their browser index.
  Iterable<int> get devices => _held.keys;

  /// The presses and releases since controller [deviceId]'s last snapshot.
  ///
  /// [buttons] are the buttons' values (0 to 1; a plain button is 0 or 1),
  /// [axes] the sticks' positions. A browser that does not use the standard
  /// layout ([standard] false) still has its first sixteen buttons read the
  /// same way: the face buttons and the D-pad are where most controllers put
  /// them, and a wrong guess there is better than a dead controller.
  List<GamepadEvent> read(
    int deviceId, {
    required List<double> buttons,
    required List<double> axes,
    bool standard = true,
  }) {
    final before = _held[deviceId] ?? const <GamepadButton>{};
    final now = <GamepadButton>{};
    final count = buttons.length < standardButtons.length
        ? buttons.length
        : standardButtons.length;
    for (var i = 0; i < count; i++) {
      final button = standardButtons[i];
      if (_isDown(buttons[i], before.contains(button))) now.add(button);
    }
    _stick(now, before, axes, 0, GamepadButton.leftStickLeft,
        GamepadButton.leftStickRight);
    _stick(now, before, axes, 1, GamepadButton.leftStickUp,
        GamepadButton.leftStickDown);
    _stick(now, before, axes, 2, GamepadButton.rightStickLeft,
        GamepadButton.rightStickRight);
    _stick(now, before, axes, 3, GamepadButton.rightStickUp,
        GamepadButton.rightStickDown);
    _held[deviceId] = now;

    return [
      // Releases first: a stick swung from left to right lets go of left
      // before it presses right, as the bridge reports it.
      for (final b in GamepadButton.values)
        if (before.contains(b) && !now.contains(b))
          GamepadEvent(button: b, pressed: false, deviceId: deviceId),
      for (final b in GamepadButton.values)
        if (now.contains(b) && !before.contains(b))
          GamepadEvent(button: b, pressed: true, deviceId: deviceId),
    ];
  }

  /// Controller [deviceId] is gone: a release for everything it held, so no
  /// button stays "held" for good (the host's repeat would run on).
  List<GamepadEvent> forget(int deviceId) {
    final held = _held.remove(deviceId) ?? const <GamepadButton>{};
    return [
      for (final b in GamepadButton.values)
        if (held.contains(b))
          GamepadEvent(button: b, pressed: false, deviceId: deviceId),
    ];
  }

  bool _isDown(double value, bool wasDown) =>
      wasDown ? value > release : value >= press;

  void _stick(
    Set<GamepadButton> now,
    Set<GamepadButton> before,
    List<double> axes,
    int axis,
    GamepadButton negative,
    GamepadButton positive,
  ) {
    if (axis >= axes.length) return;
    final v = axes[axis];
    if (v.isNaN) return;
    if (_isDown(-v, before.contains(negative))) {
      now.add(negative);
    } else if (_isDown(v, before.contains(positive))) {
      now.add(positive);
    }
  }
}

/// A browser's name for a controller ("Xbox 360 Controller (XInput STANDARD
/// GAMEPAD)", "GamePadPlus V3 (STANDARD GAMEPAD Vendor: 1949 Product: 0402)")
/// without the browser's own words in brackets.
String browserGamepadName(String id) {
  final cut = id.indexOf(' (');
  final name = (cut > 0 ? id.substring(0, cut) : id).trim();
  return name.isEmpty ? 'Gamepad' : name;
}
