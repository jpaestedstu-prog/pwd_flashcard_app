import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/analytics_service.dart';

/// Centralized error handling service for FlashLearn PWD.
///
/// Catches all uncaught exceptions (Flutter framework errors, async errors,
/// and platform errors), logs them locally to a Hive box, and exposes
/// a stream so the UI layer can show user-friendly feedback.
class ErrorHandler {
  ErrorHandler._();

  static const String _boxName = 'error_logs';
  static const int _maxLogEntries = 200;

  /// Sources whose errors must be logged (Hive + console) but **not**
  /// surfaced to [errorStream] — the user-facing snackbar shouldn't fire
  /// for known-noisy paths such as the post-join lifecycle wiring or the
  /// alarm scheduler's plugin init. Genuine user-actionable errors keep
  /// raising inline failures (per-feature snackbars, the join failure
  /// banner) so we don't lose visibility on real problems.
  static const Set<String> _silentSources = {
    'applyLifecycle:silent',
    'AlarmScheduler:silent',
    'completeJoin:setProfileSilent',
    'ChildTimeLimitStream:silent',
    'ChildAlarmStream:silent',
    'ChildUnlockOverrideStream:silent',
    'LockEnforcerGate:silent',
    'OnAlarmFired:silent',
    'PinUnlockGrace:silent',
    'OverflowSilent',
  };

  static final _errorStreamController =
      StreamController<AppError>.broadcast();

  /// Stream of errors for the UI to listen to (e.g. show a snackbar).
  static Stream<AppError> get errorStream => _errorStreamController.stream;

  /// Initialize global error handling. Call this in main() BEFORE runApp().
  static void init() {
    // 1. Catch Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      // Layout overflow errors ("A RenderFlex overflowed by …") are
      // recoverable incidents, not crashes. Suppress the yellow/black
      // striped banner in release so end-users never see it; still print
      // it in debug so the developer fixes the source.
      final exception = details.exception;
      final isOverflow = exception is FlutterError &&
          exception.message.contains('overflowed by');
      if (!isOverflow || kDebugMode) {
        FlutterError.presentError(details);
      }
      _handleError(
        details.exception,
        details.stack,
        source: isOverflow ? 'OverflowSilent' : 'FlutterError',
        context: details.context?.toString(),
      );
      // Forward to Crashlytics with full FlutterErrorDetails so the
      // remote report keeps the framework's context (widget tree, build
      // phase). Internally gated by AnalyticsService.isOptIn — no-op
      // until an educator explicitly enables telemetry.
      if (!isOverflow) {
        AnalyticsService.recordFlutterError(details);
      }
    };

    // 2. Catch platform dispatcher errors (e.g. codec failures)
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(error, stack, source: 'PlatformDispatcher');
      return true; // Prevent the error from propagating
    };
  }

  /// Wrap [runApp] inside [runZonedGuarded] to catch async errors that
  /// escape try/catch blocks.
  static void runGuarded(void Function() appRunner) {
    runZonedGuarded(
      appRunner,
      (error, stack) {
        _handleError(error, stack, source: 'Zone');
      },
    );
  }

  /// Manually report an error from anywhere in the codebase.
  /// Use this instead of silently swallowing with `catch (_) {}`.
  static void report(
    Object error, [
    StackTrace? stack,
    String? source,
  ]) {
    _handleError(error, stack, source: source ?? 'Manual');
  }

  /// Core handler — logs + broadcasts.
  static void _handleError(
    Object error,
    StackTrace? stack, {
    String source = 'Unknown',
    String? context,
  }) {
    // Suppress asset-loading errors — they are handled locally by
    // Image.asset's errorBuilder and should not trigger user-facing
    // error SnackBars.
    final errorStr = error.toString();
    if (errorStr.contains('Unable to load asset') ||
        errorStr.contains('AssetImage') ||
        (context != null && context.contains('image'))) {
      if (kDebugMode) {
        debugPrint('│ [ErrorHandler] Suppressed asset error: $errorStr');
      }
      return;
    }

    final appError = AppError(
      message: errorStr,
      source: source,
      context: context,
      timestamp: DateTime.now(),
      stackTrace: stack?.toString(),
    );

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('┌── ERROR [$source] ──────────────────────');
      if (context != null) debugPrint('│ Context: $context');
      debugPrint('│ $error');
      if (stack != null) {
        debugPrint('│ ${stack.toString().split('\n').take(5).join('\n│ ')}');
      }
      debugPrint('└─────────────────────────────────────────');
    }

    // Persist to Hive — keep diagnostics intact even for silent sources.
    _persistError(appError);

    // Forward to Crashlytics. Internally a no-op when the user has not
    // opted in (which is the default), so this is privacy-safe. Silent
    // sources still go to Crashlytics because they represent real
    // problems we want to triage remotely — they're only silent for
    // the user-facing snackbar.
    AnalyticsService.recordError(
      error,
      stack,
      source: source,
      context: context,
    );

    // Silent sources: logged but never surfaced to the global snackbar.
    // See [_silentSources] for the rationale.
    if (_silentSources.contains(source)) return;

    // Broadcast to any listening UI
    if (!_errorStreamController.isClosed) {
      _errorStreamController.add(appError);
    }
  }

  /// Save error to local Hive box for diagnostics / crash log export.
  static Future<void> _persistError(AppError error) async {
    try {
      final box = Hive.box(_boxName);
      final logs = List<Map<String, dynamic>>.from(
        (box.get('logs', defaultValue: <dynamic>[]) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      logs.add(error.toJson());

      // Trim old entries
      while (logs.length > _maxLogEntries) {
        logs.removeAt(0);
      }

      await box.put('logs', logs);
    } catch (_) {
      // If Hive itself fails, we can only print
      debugPrint('Failed to persist error log: ${error.message}');
    }
  }

  /// Retrieve all stored error logs (newest first).
  static List<AppError> getErrorLogs() {
    try {
      final box = Hive.box(_boxName);
      final logs = List<Map<String, dynamic>>.from(
        (box.get('logs', defaultValue: <dynamic>[]) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      return logs.reversed.map((e) => AppError.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear all stored error logs.
  static Future<void> clearLogs() async {
    try {
      final box = Hive.box(_boxName);
      await box.put('logs', <dynamic>[]);
    } catch (_) {
      // silent
    }
  }

  /// Clean up resources.
  static void dispose() {
    _errorStreamController.close();
  }
}

/// A structured error record for logging and display.
class AppError {
  final String message;
  final String source;
  final String? context;
  final DateTime timestamp;
  final String? stackTrace;

  const AppError({
    required this.message,
    required this.source,
    this.context,
    required this.timestamp,
    this.stackTrace,
  });

  /// User-friendly message (strips internal details).
  String get userMessage {
    if (message.contains('SocketException') ||
        message.contains('NetworkException')) {
      return 'Network error. Please check your connection.';
    }
    if (message.contains('FormatException')) {
      return 'Data format error. Some data may be corrupted.';
    }
    if (message.contains('TimeoutException')) {
      return 'Operation timed out. Please try again.';
    }
    return 'Something went wrong. The app will continue working.';
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'source': source,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
        'stackTrace': stackTrace,
      };

  factory AppError.fromJson(Map<String, dynamic> json) => AppError(
        message: json['message'] as String? ?? 'Unknown error',
        source: json['source'] as String? ?? 'Unknown',
        context: json['context'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        stackTrace: json['stackTrace'] as String?,
      );
}
