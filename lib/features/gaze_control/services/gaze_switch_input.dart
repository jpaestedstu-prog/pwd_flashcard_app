import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../gamepad/models/gamepad_button.dart';
import '../../gamepad/services/gamepad_service.dart';
import '../models/gaze_models.dart';

/// **One-switch input** for Gaze Control: a press on a Bluetooth switch or
/// game controller picks the highlighted control, exactly like a blink.
///
/// Scanning lights the controls up by itself, so a learner who can press one
/// button — and nothing else — can use every screen with it. Two kinds of
/// device are heard:
///  * a **game controller**, through the native gamepad bridge the Game
///    Controller feature already uses. Any *button* picks; the D-pad and the
///    sticks steer the scanning highlight the way they are pushed instead —
///    they used to pick too, so a thumb resting on a stick, or a learner
///    steering with it as anyone holding a controller would, chose whatever
///    happened to be lit;
///  * a **switch interface** that types a key — most send Space or Enter —
///    through the hardware keyboard.
///
/// Gaze scopes that pick by switch [attach] while they are the scope the
/// learner is using and [detach] when they stand down; the newest attachment
/// receives the presses. While anyone is attached, [claiming] is true and the
/// Game Controller's own navigation leaves presses alone — one press must never
/// both pick a scanned item and move the controller's own cursor.
class GazeSwitchInput {
  GazeSwitchInput._();

  /// The single, app-wide switch input.
  static final GazeSwitchInput instance = GazeSwitchInput._();

  /// A bouncy switch can report one press as two; ignore a second press this
  /// soon after the first.
  static const Duration debounce = Duration(milliseconds: 300);

  /// A diagonal push on a stick or D-pad arrives as two directions a few
  /// milliseconds apart (15-60 ms on the tablet's controller) and moved the
  /// highlight twice; a second direction this soon after the first is the
  /// same push.
  static const Duration stepDebounce = Duration(milliseconds: 120);
  DateTime? _lastStep;

  final List<
    ({
      Object token,
      VoidCallback onPress,
      void Function(GazeZone direction)? onSteer,
    })
  >
  _listeners = [];
  GamepadService? _service;
  StreamSubscription<GamepadEvent>? _sub;
  bool _keyboard = false;
  DateTime? _lastPress;

  /// True while a gaze scope is listening for switch presses.
  final ValueNotifier<bool> claiming = ValueNotifier(false);

  /// Keeps the window out of the system keyboard's reach while the learner
  /// at the tablet picks with a switch (see `MainActivity.IME_CHANNEL`): with
  /// a text field focused, the keyboard took a switch interface's Space before
  /// the app saw it — the press typed a space instead of choosing, and on a
  /// code field nothing at all happened.
  ///
  /// Set from the learner's settings ([gazeKeyboardBypassProvider]), not from
  /// whichever surface holds the switch at the moment: the switch passes from
  /// a screen to the gaze keyboard over it and back, and the window flag
  /// flipping at every hand-over re-laid the window out under the learner.
  static const MethodChannel _ime = MethodChannel('flashlearn/ime');
  bool _imeBypass = false;

  /// Whether the system keyboard is kept away (debug bridge and tests).
  bool get keyboardBypassed => _imeBypass;

  void setKeyboardBypass(bool on) {
    if (_imeBypass == on) return;
    _imeBypass = on;
    _ime
        .invokeMethod<bool>('setBypass', {'on': on})
        .catchError((Object _) => false);
  }

  /// Presses delivered so far (debug bridge and tests).
  int debugPresses = 0;

  /// Every key event the keyboard handler saw, and the last one — so a press
  /// that never arrives can be told from one that arrived and was dropped.
  int debugKeyEvents = 0;
  String debugLastKey = '';

  /// How many surfaces hold the switch right now.
  int get debugListeners => _listeners.length;

  /// Steps delivered so far (debug bridge and tests).
  int debugSteps = 0;

  /// The latest inputs and what became of each, newest last (debug and
  /// profile builds) — so a press a learner says "did nothing" can be told
  /// apart from one that never arrived, was a bounce, or had no taker.
  final List<String> debugHistory = [];

  void _note(String source, String outcome) {
    if (kReleaseMode) return;
    final t = DateTime.now().toIso8601String();
    debugHistory.add('${t.substring(11, 23)} $source $outcome');
    if (debugHistory.length > 40) debugHistory.removeAt(0);
  }

  /// Injectable for tests (the debounce reads it).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Starts delivering presses to [onPress] (the newest attachment wins), and
  /// a controller's stick and arrows to [onSteer]. [service] is the app's
  /// gamepad bridge; null in tests and on platforms without one, which leaves
  /// the keyboard path.
  Object attach({
    required VoidCallback onPress,
    void Function(GazeZone direction)? onSteer,
    GamepadService? service,
  }) {
    final token = Object();
    _listeners.add((token: token, onPress: onPress, onSteer: onSteer));
    _listen(service);
    _publishClaiming();
    // A screen takes the switch: make sure Android will hand its keys over
    // (see MainActivity.focusFlutterView — the first Space after a touch was
    // otherwise spent on focus).
    if (_imeBypass) {
      _ime.invokeMethod<bool>('focus').catchError((Object _) => false);
    }
    return token;
  }

  /// Stops delivering presses for [token]. [gamepadFeatureOn] says whether the
  /// Game Controller feature still wants the bridge capturing its keys once
  /// gaze lets go.
  void detach(Object token, {bool gamepadFeatureOn = false}) {
    _listeners.removeWhere((l) => identical(l.token, token));
    if (_listeners.isEmpty) {
      _sub?.cancel();
      _sub = null;
      try {
        _service?.setCaptureEnabled(gamepadFeatureOn);
      } catch (_) {}
      _service = null;
      if (_keyboard) {
        HardwareKeyboard.instance.removeHandler(_onKey);
        _keyboard = false;
      }
    }
    _publishClaiming();
  }

  void _listen(GamepadService? service) {
    if (service != null && _sub == null) {
      _service = service;
      try {
        service.start();
        // Swallow the controller's keys natively, so Flutter's own focus
        // traversal does not also react to the press.
        service.setCaptureEnabled(true);
        _sub = service.buttons.listen((event) {
          if (!event.pressed) return;
          final button = event.button;
          final direction = directionOf(button);
          if (direction != null) {
            steer(direction, source: button.name);
          } else if (picksWith(button)) {
            press(source: button.name);
          } else {
            _note(button.name, 'not a switch');
          }
        });
      } catch (_) {
        _sub = null;
      }
    }
    if (!_keyboard) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _keyboard = true;
    }
  }

  /// Keys that count as a switch press: what switch interfaces type (Space,
  /// Enter), and a controller's face and shoulder buttons when they reach
  /// Flutter as keys (the native capture is not running). Anything else —
  /// the arrows, Back — is left for the app.
  static final Set<LogicalKeyboardKey> _switchKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.gameButtonB,
    LogicalKeyboardKey.gameButtonX,
    LogicalKeyboardKey.gameButtonY,
    LogicalKeyboardKey.gameButtonLeft1,
    LogicalKeyboardKey.gameButtonRight1,
    LogicalKeyboardKey.gameButtonStart,
    LogicalKeyboardKey.gameButtonSelect,
  };

  bool _onKey(KeyEvent event) {
    if (!kReleaseMode) {
      debugKeyEvents++;
      debugLastKey = '${event.runtimeType}:${event.logicalKey.keyLabel}';
    }
    if (event is! KeyDownEvent) return false;
    if (!_switchKeys.contains(event.logicalKey)) return false;
    press(source: event.logicalKey.keyLabel);
    return true;
  }

  /// Which way a controller input steers the highlight — the D-pad and both
  /// sticks; null for everything that is not a direction.
  static GazeZone? directionOf(GamepadButton button) => switch (button) {
    GamepadButton.dpadUp ||
    GamepadButton.leftStickUp ||
    GamepadButton.rightStickUp => GazeZone.up,
    GamepadButton.dpadDown ||
    GamepadButton.leftStickDown ||
    GamepadButton.rightStickDown => GazeZone.down,
    GamepadButton.dpadLeft ||
    GamepadButton.leftStickLeft ||
    GamepadButton.rightStickLeft => GazeZone.left,
    GamepadButton.dpadRight ||
    GamepadButton.leftStickRight ||
    GamepadButton.rightStickRight => GazeZone.right,
    _ => null,
  };

  /// Whether a controller input picks: every button — not a direction, and
  /// not the vendor "mode" button, which switches the pad's own profile.
  static bool picksWith(GamepadButton button) =>
      directionOf(button) == null && button != GamepadButton.mode;

  /// Delivers one press to the newest attachment (also the debug bridge's
  /// way in).
  void press({String source = 'bridge'}) {
    if (_listeners.isEmpty) {
      _note(source, 'no taker');
      return;
    }
    final now = clock();
    final last = _lastPress;
    if (last != null && now.difference(last) < debounce) {
      _note(source, 'bounce');
      return;
    }
    _lastPress = now;
    debugPresses++;
    _note(source, 'press');
    _listeners.last.onPress();
  }

  /// Steers the newest attachment's scanning highlight [direction] (also the
  /// debug bridge's way in). Ignored by a surface that is not scanning.
  void steer(GazeZone direction, {String source = 'bridge'}) {
    if (direction == GazeZone.none) return;
    if (_listeners.isEmpty) {
      _note(source, 'no taker');
      return;
    }
    final onSteer = _listeners.last.onSteer;
    if (onSteer == null) {
      _note(source, 'no steering here');
      return;
    }
    final now = clock();
    final last = _lastStep;
    if (last != null && now.difference(last) < stepDebounce) {
      _note(source, 'same push');
      return;
    }
    _lastStep = now;
    debugSteps++;
    _note(source, 'steer ${direction.name}');
    onSteer(direction);
  }

  void _publishClaiming() {
    // Listeners rebuild widgets; attach/detach run from initState/dispose.
    scheduleMicrotask(() => claiming.value = _listeners.isNotEmpty);
  }

  /// Test seam: forget every attachment.
  @visibleForTesting
  void reset() {
    for (final l in List.of(_listeners)) {
      detach(l.token);
    }
    _lastPress = null;
    _lastStep = null;
    debugPresses = 0;
    debugSteps = 0;
    debugHistory.clear();
    clock = DateTime.now;
    _imeBypass = false;
  }
}
