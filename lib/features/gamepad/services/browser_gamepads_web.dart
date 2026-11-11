import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import '../logic/browser_gamepad_reader.dart';
import '../models/gamepad_button.dart';

/// A game controller in the browser, through the Gamepad API.
///
/// The API has no events for buttons, only `gamepadconnected` and
/// `gamepaddisconnected`: a page reads `navigator.getGamepads()` itself, many
/// times a second. This reads it every frame (60 times a second) while a
/// controller is connected, and not at all otherwise, and hands each change to
/// [onButton] as the Android bridge would ([BrowserGamepadReader]).
///
/// A browser makes a controller known to a page only once one of its buttons
/// is pressed while the page is open; until then it is not "connected".
class BrowserGamepads {
  BrowserGamepads({required this.onButton, required this.onConnection});

  final void Function(GamepadEvent event) onButton;
  final void Function(GamepadConnectionEvent event) onConnection;

  static const _every = Duration(milliseconds: 16);

  final _reader = BrowserGamepadReader();
  final Map<int, String> _connected = {};
  Timer? _poll;
  JSFunction? _onConnected;
  JSFunction? _onDisconnected;

  /// Whether this browser has the Gamepad API (every current one does, on a
  /// page served over https or from this computer).
  static bool get available {
    try {
      return web.window.navigator.has('getGamepads');
    } catch (_) {
      return false;
    }
  }

  Map<int, String> get connected => Map.unmodifiable(_connected);

  void start() {
    if (_onConnected != null || !available) return;
    _onConnected = ((web.Event _) => scan()).toJS;
    _onDisconnected = ((web.Event _) => scan()).toJS;
    web.window.addEventListener('gamepadconnected', _onConnected);
    web.window.addEventListener('gamepaddisconnected', _onDisconnected);
    // A controller already known to the browser (pressed on an earlier page)
    // is there without a new event.
    scan();
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    if (_onConnected != null) {
      web.window.removeEventListener('gamepadconnected', _onConnected);
      web.window.removeEventListener('gamepaddisconnected', _onDisconnected);
    }
    _onConnected = null;
    _onDisconnected = null;
    for (final index in _connected.keys.toList()) {
      _drop(index);
    }
  }

  /// Reads every controller once, and keeps reading while one is connected.
  void scan() {
    final seen = <int>{};
    try {
      final pads = web.window.navigator.getGamepads().toDart;
      for (final pad in pads) {
        if (pad == null || !pad.connected) continue;
        final index = pad.index;
        seen.add(index);
        if (!_connected.containsKey(index)) {
          final name = browserGamepadName(pad.id);
          _connected[index] = name;
          onConnection(
            GamepadConnectionEvent(deviceId: index, name: name, connected: true),
          );
        }
        final buttons = <double>[
          for (final b in pad.buttons.toDart) b.pressed ? 1.0 : b.value,
        ];
        final axes = <double>[for (final a in pad.axes.toDart) a.toDartDouble];
        for (final event in _reader.read(
          index,
          buttons: buttons,
          axes: axes,
          standard: pad.mapping == 'standard',
        )) {
          onButton(event);
        }
      }
    } catch (e) {
      // A browser that refuses (a page not served over https) has no
      // controller to offer: say so once in the console, never to a learner.
      debugPrint('BrowserGamepads: $e');
    }
    for (final index in _connected.keys.toList()) {
      if (!seen.contains(index)) _drop(index);
    }
    if (_connected.isEmpty) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(_every, (_) => scan());
    }
  }

  void _drop(int index) {
    for (final event in _reader.forget(index)) {
      onButton(event);
    }
    final name = _connected.remove(index);
    if (name != null) {
      onConnection(
        GamepadConnectionEvent(deviceId: index, name: name, connected: false),
      );
    }
  }
}
