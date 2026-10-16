import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../constants/distribution.dart';

/// Firebase App Check: proof that a request reaching Firestore comes from a
/// genuine copy of FlashLearn, not a script that copied the project's public
/// API key. Every install signs in anonymously, so without it the security
/// rules are the only defence (see firestore.rules and docs/security.md).
///
/// App Check itself is free, but the attestation that makes it mean anything
/// is not, and one channel can never have it:
///
///  * **Google Play** builds attest with Play Integrity, which needs the app in
///    a Google Play Console account (a one-time registration fee);
///  * **iPhone and iPad** builds attest with App Attest (falling back to
///    DeviceCheck), which needs the Apple Developer Program (yearly fee);
///  * **website APKs** are installed outside any store, so nothing can vouch
///    for them. App Check could never be *enforced* for them without locking
///    every such tablet out of its own data.
///
/// So it is compiled in and **off**: a store build made with
/// `--dart-define=FLASHLEARN_APP_CHECK=true` turns it on once those accounts
/// exist. Until the project is switched to *enforce* in the Firebase console,
/// tokens are only reported (the console's App Check metrics), never
/// required, so turning it on cannot cut anyone off.
class AppCheckService {
  AppCheckService._();

  /// `--dart-define=FLASHLEARN_APP_CHECK=true`.
  static const bool requested = bool.fromEnvironment('FLASHLEARN_APP_CHECK');

  /// Whether this build attests at all — pure, so it is tested. A website
  /// APK never does in release (no store to vouch for it); in a debug build
  /// the debug provider lets a developer try the flow on any channel. The web
  /// app never does: it would need a reCAPTCHA key, and none is registered.
  @visibleForTesting
  static bool shouldActivate({
    required bool requested,
    required Distribution distribution,
    required bool debugBuild,
  }) =>
      requested &&
      distribution != Distribution.web &&
      (distribution != Distribution.website || debugBuild);

  /// Must run right after `Firebase.initializeApp`, before Firestore or Auth
  /// make their first request. Never throws: App Check failing to start must
  /// not stop the app from starting.
  static Future<void> activate() async {
    if (!shouldActivate(
      requested: requested,
      distribution: Distribution.current,
      debugBuild: kDebugMode,
    )) {
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      if (kDebugMode) debugPrint('AppCheck: activated');
    } catch (e) {
      if (kDebugMode) debugPrint('AppCheck: could not activate: $e');
    }
  }
}
