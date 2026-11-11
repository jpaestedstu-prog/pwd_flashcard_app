import '../models/gamepad_button.dart';

/// No browser here: no Gamepad API (see `browser_gamepads_web.dart`).
class BrowserGamepads {
  BrowserGamepads({required this.onButton, required this.onConnection});

  final void Function(GamepadEvent event) onButton;
  final void Function(GamepadConnectionEvent event) onConnection;

  static bool get available => false;

  /// The controllers connected now, by index, with their names.
  Map<int, String> get connected => const {};

  void start() {}

  void scan() {}

  void stop() {}
}
