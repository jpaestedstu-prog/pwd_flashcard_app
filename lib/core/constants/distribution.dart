import 'package:flutter/foundation.dart';

/// How this copy of the app reached the device.
///
/// It decides one thing today: whether the app may point people at the
/// project website for a newer version. A website APK has nothing else to tell
/// it about updates, so it asks the site's `version.json`. A store copy must
/// not: Google Play and the App Store both forbid an app that updates itself
/// from anywhere but the store, and the store already updates it.
enum Distribution {
  /// An APK downloaded from the project website — every Android build unless
  /// told otherwise. Keeps the original application id, so the tablets that
  /// installed one keep accepting updates.
  website,

  /// The Google Play build:
  /// `flutter build appbundle --dart-define=FLASHLEARN_DISTRIBUTION=play`.
  /// The same define gives it its own application id (see
  /// `android/app/build.gradle.kts`).
  play,

  /// Every iOS build — the App Store, TestFlight, or a test install.
  appStore;

  /// The `--dart-define` a Play build is made with.
  static const String _define = String.fromEnvironment(
    'FLASHLEARN_DISTRIBUTION',
    defaultValue: 'website',
  );

  /// This build's channel. iOS is always [appStore]: there is no other way
  /// onto an iPhone or iPad.
  static Distribution get current => resolve(
        platform: defaultTargetPlatform,
        define: _define,
      );

  /// The rule behind [current] — pure, so it is tested.
  @visibleForTesting
  static Distribution resolve({
    required TargetPlatform platform,
    required String define,
  }) {
    if (platform == TargetPlatform.iOS) return appStore;
    return define == 'play' ? play : website;
  }

  /// Whether to ask the website for a newer APK and show "Check for updates".
  bool get checksWebsiteForUpdates => this == website;
}
