import 'package:flutter/services.dart';

/// The status and navigation bars as the app shows them everywhere but its
/// full-screen pages: edge to edge, both bars on show (see main.dart).
abstract final class SystemBars {
  /// Shows both bars again after a full-screen page (the sign player, the My
  /// Day lock, the time's-up lock) and goes back to edge to edge.
  ///
  /// Edge to edge alone is not enough: since Flutter 3.44 that mode only lays
  /// the app out under the bars, and leaves in place the flags a full-screen
  /// (immersive) page set to hide them. On the Honor (Android 16) the clock
  /// and battery stayed hidden for the rest of the session after one visit to
  /// the full-screen sign player. Naming both bars rewrites those flags; edge
  /// to edge then lays the app under the bars again.
  static Future<void> restore() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
