import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../gamepad/models/gamepad_button.dart';
import '../../gamepad/services/gamepad_service.dart';

/// **One-switch input** for Gaze Control: a press on a Bluetooth switch or
/// game controller picks the highlighted control, exactly like a blink.
///
/// Scanning lights the controls up by itself, so a learner who can press one
/// button — and nothing else — can use every screen with it. Two kinds of
/// device are heard:
///  * a **game controller** (any button), through the native gamepad bridge
///    the Game Controller feature already uses;
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

  final List<({Object token, VoidCallback onPress})> _listeners = [];
  GamepadService? _service;
  StreamSubscription<GamepadEvent>? _sub;
  bool _keyboard = false;
  DateTime? _lastPress;

  /// True while a gaze scope is listening for switch presses.
  final ValueNotifier<bool> claiming = ValueNotifier(false);

  /// Presses delivered so far (debug bridge and tests).
  int debugPresses = 0;

  /// Injectable for tests (the debounce reads it).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Starts delivering presses to [onPress] (the newest attachment wins).
  /// [service] is the app's gamepad bridge; null in tests and on platforms
  /// without one, which leaves the keyboard path.
  Object attach({required VoidCallback onPress, GamepadService? service}) {
    final token = Object();
    _listeners.add((token: token, onPress: onPress));
    _listen(service);
    _publishClaiming();
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
          if (event.pressed) press();
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
    if (event is! KeyDownEvent) return false;
    if (!_switchKeys.contains(event.logicalKey)) return false;
    press();
    return true;
  }

  /// Delivers one press to the newest attachment (also the debug bridge's
  /// way in).
  void press() {
    if (_listeners.isEmpty) return;
    final now = clock();
    final last = _lastPress;
    if (last != null && now.difference(last) < debounce) return;
    _lastPress = now;
    debugPresses++;
    _listeners.last.onPress();
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
    debugPresses = 0;
    clock = DateTime.now;
  }
}
