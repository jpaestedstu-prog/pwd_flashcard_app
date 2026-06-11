import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
import 'firebase_service.dart';

/// Opt-in telemetry wrapper around Firebase Crashlytics + Analytics.
///
/// **Free-tier compatible:** Both products are unlimited on Spark — no
/// Blaze plan or billing setup required.
///
/// **Privacy posture:** Default OFF. The toggle is parent-gated in
/// settings (visible only to teacher/parent profiles) because the user
/// base includes children and PWD users. No telemetry leaves the device
/// until an educator explicitly opts in.
///
/// **Storage:** The opt-in flag lives in a dedicated Hive key
/// (`telemetry_opt_in`) outside of [AppSettings] so it doesn't get
/// replicated to Firestore through the sync queue — opt-in is a per-device
/// consent, not a per-account preference.
class AnalyticsService {
  AnalyticsService._();

  /// Hive key for the opt-in flag.
  static const String _optInKey = 'telemetry_opt_in';

  /// In-memory cache of the opt-in flag, refreshed by [_loadOptIn].
  /// Avoids hitting Hive on every log call.
  static bool _optIn = false;

  /// Whether [initialize] has run successfully. When false, every method
  /// becomes a no-op — safe to call from any platform (web stub, missing
  /// google-services.json, etc.).
  static bool _ready = false;

  /// Whether the user has opted in to telemetry. Read by the settings UI
  /// to render the toggle's current value.
  static bool get isOptIn => _optIn;

  /// Initialise Crashlytics + Analytics and apply the persisted opt-in
  /// flag. Call this after [FirebaseService.init] succeeds.
  ///
  /// Non-throwing — failures are logged in debug mode and leave the
  /// service in a no-op state so the rest of the app keeps working.
  static Future<void> initialize() async {
    if (!FirebaseService.isConfigured) return;
    try {
      _optIn = await _loadOptIn();
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(_optIn);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(_optIn);
      _ready = true;
      if (kDebugMode) {
        debugPrint('✓ AnalyticsService: ready (opt-in=$_optIn)');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('✗ AnalyticsService.initialize failed: $e\n$stack');
      }
      _ready = false;
    }
  }

  /// Toggle the opt-in flag. Persists to Hive AND flips the live
  /// collection-enabled state on both Crashlytics and Analytics so the
  /// change takes effect immediately (no app restart needed).
  ///
  /// Idempotent. Safe to call before [initialize] — the flag persists
  /// and is picked up on next launch.
  static Future<void> setOptIn(bool enabled) async {
    _optIn = enabled;
    await HiveService.saveSetting(_optInKey, enabled);
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(enabled);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('✗ AnalyticsService.setOptIn failed: $e\n$stack');
      }
    }
  }

  /// Record a non-fatal error to Crashlytics. No-op when opt-in is off.
  ///
  /// Used by [ErrorHandler.report] so the existing centralised error
  /// pipeline transparently fans out to the cloud when the user has
  /// consented.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? source,
    String? context,
  }) async {
    if (!_ready || !_optIn) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context ?? source,
        information: [
          if (source != null) 'source: $source',
          if (context != null) 'context: $context',
        ],
      );
    } catch (_) {
      // Swallow — telemetry must never break the app.
    }
  }

  /// Record a Flutter framework error (build/layout/etc.) with full
  /// FlutterErrorDetails context. No-op when opt-in is off.
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_ready || !_optIn) return;
    try {
      await FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {
      // Swallow.
    }
  }

  /// Log a custom Analytics event. No-op when opt-in is off.
  ///
  /// Use sparingly — limit to lifecycle milestones (`deck_completed`,
  /// `fsl_video_played`, `classroom_joined`, etc.) rather than every
  /// keypress. Spark plan is unlimited but event volume still costs
  /// device bandwidth.
  ///
  /// Parameter values must be String or num (Firebase Analytics limit).
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_ready || !_optIn) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Swallow.
    }
  }

  /// Read the persisted opt-in flag. Defaults to `false` (Privacy by
  /// default — the user must affirmatively opt in).
  static Future<bool> _loadOptIn() async {
    try {
      final raw = HiveService.getSetting(_optInKey);
      if (raw is bool) return raw;
    } catch (_) {
      // Hive may not be open yet on early call paths.
    }
    return false;
  }
}
