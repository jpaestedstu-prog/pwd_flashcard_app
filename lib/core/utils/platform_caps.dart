import 'package:flutter/foundation.dart';

/// Whether this is the browser version, for the screens that tell a learner
/// what only the Android app can do (see `AndroidAppNotice`).
///
/// [kIsWeb] itself is a constant, so a widget test can never see the browser
/// version's screens; [debugWeb] lets one. Code that would call `dart:io` in
/// a browser keeps testing [kIsWeb] directly: a test only flips the screens.
abstract final class PlatformCaps {
  /// Set by a test to show the browser version's screens; null otherwise.
  @visibleForTesting
  static bool? debugWeb;

  /// True in the browser version.
  static bool get isWeb => debugWeb ?? kIsWeb;
}
