import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gamepad_service.dart';

/// The app-wide [GamepadService].
///
/// A provider rather than a plain singleton so widget tests can override it
/// with a fake and drive the whole navigation layer without a device.
final gamepadServiceProvider = Provider<GamepadService>((ref) {
  final service = GamepadService();
  ref.onDispose(service.dispose);
  return service;
});

/// Which controllers are connected right now.
class GamepadStatus {
  final bool connected;

  /// Name Android reports for the controller — "GamePadPlus V3" for the X3.
  final String? name;

  /// True once a controller has connected at least once this session, so a
  /// later connection can be announced as a *re*-connection.
  final bool everConnected;

  const GamepadStatus({
    this.connected = false,
    this.name,
    this.everConnected = false,
  });

  GamepadStatus copyWith({bool? connected, String? name, bool? everConnected}) =>
      GamepadStatus(
        connected: connected ?? this.connected,
        name: name ?? this.name,
        everConnected: everConnected ?? this.everConnected,
      );
}

/// Tracks controller connection state for the whole app.
///
/// Separate from the host widget so anything can watch it — the hubs use it to
/// decide whether to publish their tile grid, and the settings screen uses it
/// to show a live "connected" badge.
class GamepadStatusNotifier extends Notifier<GamepadStatus> {
  StreamSubscription<dynamic>? _sub;

  @override
  GamepadStatus build() {
    final service = ref.watch(gamepadServiceProvider);
    _sub = service.connections.listen((event) {
      if (event.connected) {
        state = state.copyWith(
          connected: true,
          name: event.name,
          everConnected: true,
        );
      } else {
        // Another pad may still be attached — trust the service's own roster
        // rather than assuming a single controller.
        state = GamepadStatus(
          connected: service.hasController,
          name: service.hasController ? service.connectedNames.first : null,
          everConnected: true,
        );
      }
    });
    ref.onDispose(() => _sub?.cancel());

    // Seed from what the service already knows.
    //
    // This provider is created lazily — the first hub to watch
    // `tileGridActiveProvider` builds it — which is typically *long after* the
    // controller connected, because the native bridge reports already-paired
    // pads the instant it is listened to, back on the splash screen. A
    // subscription alone therefore only ever hears about pads that connect
    // from now on, leaving a controller that was switched on before the app
    // launched permanently invisible: the hubs never published their tiles and
    // every item press fell through to the focus-traversal fallback.
    final connected = service.hasController;
    return GamepadStatus(
      connected: connected,
      name: connected ? service.connectedNames.first : null,
      everConnected: connected,
    );
  }
}

final gamepadStatusProvider =
    NotifierProvider<GamepadStatusNotifier, GamepadStatus>(
  GamepadStatusNotifier.new,
);
