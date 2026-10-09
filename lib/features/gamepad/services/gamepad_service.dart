import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/gamepad_button.dart';

/// Dart end of the native gamepad bridge (`GamepadBridge.kt`).
///
/// Exposes two broadcast streams — button presses and connect/disconnect — and
/// one switch ([setCaptureEnabled]) that tells the native side whether to
/// swallow controller keys or let them fall through to Flutter's own focus
/// traversal.
///
/// Everything here is best-effort: on a platform with no bridge (iOS, web,
/// desktop, and every widget test) the channels simply never produce events and
/// the app behaves exactly as it did before. Nothing about this service is
/// allowed to throw into the app.
class GamepadService {
  static const _events = EventChannel('flashlearn/gamepad/events');
  static const _methods = MethodChannel('flashlearn/gamepad');

  final _buttons = StreamController<GamepadEvent>.broadcast();
  final _connections = StreamController<GamepadConnectionEvent>.broadcast();

  StreamSubscription<dynamic>? _sub;
  bool _started = false;

  /// Controllers the native side has told us about, by device id. Kept so a
  /// removal event — which arrives with no name, because the device is already
  /// gone — can still be reported with the name it connected under.
  final Map<int, String> _known = {};

  /// Presses and releases from every connected controller.
  Stream<GamepadEvent> get buttons => _buttons.stream;

  /// Controllers appearing and disappearing.
  Stream<GamepadConnectionEvent> get connections => _connections.stream;

  /// Names of the controllers currently connected.
  List<String> get connectedNames => _known.values.toList(growable: false);

  /// Android device ids currently connected.
  ///
  /// [connections] is a broadcast stream, so it does **not** replay: anything
  /// that starts listening after a controller connected would never hear about
  /// it. This roster is the catch-up path for those late subscribers.
  List<int> get connectedIds => _known.keys.toList(growable: false);

  bool get hasController => _known.isNotEmpty;

  /// Whether this platform has the bridge at all: `GamepadBridge.kt` is
  /// Android only. Elsewhere the event channel has no listener, and listening
  /// to it is not a quiet no-op: Flutter reports the MissingPluginException
  /// through FlutterError, which put "Something went wrong" over every screen
  /// of the iPhone and iPad app.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Begins listening. Safe to call repeatedly; does nothing where there is
  /// no bridge ([isSupported]).
  void start() {
    if (_started) return;
    _started = true;
    if (!isSupported) return;
    try {
      _sub = _events.receiveBroadcastStream().listen(
            _onEvent,
            onError: (Object error) {
              // A missing-plugin error on an unsupported platform is expected,
              // not a fault worth surfacing to a learner.
              if (kDebugMode) debugPrint('Gamepad channel error: $error');
            },
            cancelOnError: false,
          );
    } catch (e) {
      if (kDebugMode) debugPrint('Gamepad channel unavailable: $e');
    }
    // Ask outright what is attached, rather than trusting the event stream's
    // opening burst. That burst is emitted the moment the native side is
    // listened to, and whether any given subscriber exists yet depends on
    // build order — which made "is a controller connected?" answer differently
    // between launches, and the hubs published their tile grid only sometimes.
    // A method call has no such race: it always answers.
    refreshDevices();
  }

  /// Re-reads the attached controllers from the platform and emits a
  /// connection event for any this service had not already recorded.
  Future<void> refreshDevices() async {
    try {
      final raw = await _methods.invokeListMethod<dynamic>('devices');
      if (raw == null) return;
      for (final entry in raw) {
        if (entry is! Map) continue;
        final id = entry['id'];
        if (id is! int || _known.containsKey(id)) continue;
        final name = (entry['name'] as String?)?.trim();
        final label = (name == null || name.isEmpty) ? 'Gamepad' : name;
        _known[id] = label;
        if (_connections.isClosed) return;
        _connections.add(
          GamepadConnectionEvent(deviceId: id, name: label, connected: true),
        );
      }
    } catch (_) {
      // No bridge on this platform — nothing attached, nothing to report.
    }
  }

  Future<void> stop() async {
    _started = false;
    await _sub?.cancel();
    _sub = null;
    _known.clear();
    await setCaptureEnabled(false);
  }

  /// Tells the native bridge whether to consume controller keys.
  ///
  /// Off means the pad keeps working as a stock Android controller (Flutter's
  /// built-in focus traversal), which is the right behaviour when the learner
  /// has switched gamepad support off.
  Future<void> setCaptureEnabled(bool enabled) async {
    try {
      await _methods.invokeMethod<bool>('setCaptureEnabled', {
        'enabled': enabled,
      });
    } catch (_) {
      // No bridge on this platform — nothing to enable.
    }
  }

  /// Controllers Android currently reports, independent of the event stream.
  Future<List<String>> queryDevices() async {
    try {
      final raw = await _methods.invokeListMethod<dynamic>('devices');
      if (raw == null) return const [];
      return [
        for (final entry in raw)
          if (entry is Map) (entry['name'] as String?) ?? 'Gamepad',
      ];
    } catch (_) {
      return const [];
    }
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    switch (raw['type']) {
      case 'button':
        final name = raw['button'];
        if (name is! String) return;
        final button = GamepadButton.fromWire(name);
        // An unknown control from a newer bridge is ignored rather than
        // crashing the input loop.
        if (button == null) return;
        _buttons.add(
          GamepadEvent(
            button: button,
            pressed: raw['pressed'] == true,
            deviceId: raw['deviceId'] is int ? raw['deviceId'] as int : 0,
          ),
        );
      case 'connection':
        final id = raw['deviceId'] is int ? raw['deviceId'] as int : 0;
        final connected = raw['connected'] == true;
        final name = (raw['name'] as String?)?.trim();
        if (connected) {
          final label = (name == null || name.isEmpty) ? 'Gamepad' : name;
          // Android re-reports a device that is already known when it wakes
          // from sleep; only a genuinely new id is a connection.
          if (_known.containsKey(id)) return;
          _known[id] = label;
          _connections.add(
            GamepadConnectionEvent(
              deviceId: id,
              name: label,
              connected: true,
            ),
          );
        } else {
          final label = _known.remove(id);
          if (label == null) return; // Never knew about it; nothing to report.
          _connections.add(
            GamepadConnectionEvent(
              deviceId: id,
              name: label,
              connected: false,
            ),
          );
        }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _buttons.close();
    await _connections.close();
  }
}
