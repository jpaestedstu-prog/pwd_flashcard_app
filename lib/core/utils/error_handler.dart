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
  ///
  /// Non-critical *feedback* services (sound effects, celebration sound +
  /// haptics) also belong here: their own contracts promise "log but never
  /// interrupt UX", so a missing/clipped sound asset or a harmless audio
  /// plugin race must never raise the generic "Something went wrong"
  /// snackbar at a PWD learner — most visibly on the very first sound after
  /// launch (e.g. profile-creation success chime).
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
    // Cosmetic mirror push. Best-effort by design: the equip already happened
    // locally, and a learner should never see an error because their new hat
    // has not reached the leaderboard yet.
    'syncEquippedLook:silent',
    // The public messaging directory. Both of these are background mirrors of
    // data already saved locally: `upsert` republishes the username entry on
    // every profile save (so it fires on a plain sign-in), and `_refreshCache`
    // tops up a cached display name. Offline they time out and used to put
    // "Operation timed out. Please try again." in front of a teacher who had
    // asked for nothing and could do nothing about it — `_refreshCache`'s own
    // doc comment already promised it "never throws". The user-initiated
    // lookups are deliberately NOT here: if someone searches for a username,
    // a failure is theirs to see.
    'ProfileDirectoryService.upsert',
    // Tidy-up after a profile delete: the profile is already gone, and a
    // failed handle removal is not something the user can act on.
    'ProfileDirectoryService.remove',
    'ProfileDirectoryService._refreshCache',
    // Recoverable Flutter framework assertions (overflow, ListTile ink-hidden,
    // duplicate GlobalKey, hero conflicts, setState-during-build, …). Logged
    // for the developer but never surfaced as the user-facing snackbar — see
    // the FlutterError.onError handler in [init].
    'FrameworkDiagnostic:silent',
    'SoundService',
    'CelebrationService',
    // The lock screen's alarm chime + spoken hand-off. A missing codec,
    // a TTS engine that isn't installed, or an audio-focus loss must
    // never stack a generic error snackbar on top of a lock screen the
    // child already can't dismiss — the caption and FSL clip still carry
    // the message.
    'LockAnnouncer:silent',
    // The blocked-peers listener. `blocks` is a newer collection than some
    // deployed rule sets, so an app built ahead of a Firestore deploy gets
    // PERMISSION_DENIED here on every Messages open. Blocking still works
    // from the Hive cache, and a learner must never be shown an error banner
    // for a safeguarding feature quietly running in the background.
    'FriendService.watchBlocked:silent',
    // Classmate suggestions in the Add Friend dialog. A convenience list on
    // top of the username field: offline or refused, the learner can still
    // type a username, so a failure here is never theirs to see.
    'FriendService.suggestClassmates:silent',
    // The unfriend inside a block. Often there is no friendship left to
    // delete (the peer already unfriended you, or you are re-blocking after
    // an unblock), and the rules refuse to delete a missing doc — while the
    // block itself, the part that matters, has already succeeded.
    'FriendService.blockUnfriend:silent',
    // Finishing a friendship every parent approved runs in the background on
    // whichever learner's device sees it first. The other device's attempt
    // can be refused (the friendship is already there), which is expected.
    'FriendService.finishApproved:silent',
    // Every routine path. All twelve already name themselves ":silent" but
    // none was registered, so the suffix was a claim the set never honoured —
    // see silent_source_convention_test.dart, which now enforces the two
    // agreeing.
    //
    // The reads are background mirrors that fall back to the Hive cache
    // (`watchForChild` re-emits the local list on a stream error), so there is
    // nothing for a learner to do about them. The *writes* look user-initiated
    // — an educator did press Save — but `RoutineService.save` returns a
    // `CloudSyncOutcome` precisely so `reportRoutineSync` can say the specific
    // true thing ("saved here, not sent yet" / "this device no longer syncs
    // this profile"). The generic banner landed on top of that, and in the
    // not-owner case flatly contradicted it.
    //
    // Seen on the tablet: opening "My Day" as a learner whose educator profile
    // had been restored onto another device produced
    // "Something went wrong. The app will continue working." over a routine
    // that had in fact saved locally and was showing correctly.
    'RoutineSave:silent',
    'RoutineDelete:silent',
    'RoutineList:silent',
    'RoutineSetterList:silent',
    'RoutineStream:silent',
    'RoutineDayLog:silent',
    'RoutineDayLogStream:silent',
    'RoutineRecordSchedule:silent',
    'RoutineResetDay:silent',
    'RoutineToggle:silent',
    // Notification plumbing, exactly like `AlarmScheduler:silent` above: a
    // reminder that fails to schedule must not interrupt the learner, who was
    // not the one asking for it.
    'RoutineReminderScheduler:silent',
    'OnRoutineReminder:silent',
    // Same class again: starting or tearing down the routine reminder
    // scheduler on a profile switch or a My Day toggle is background work the
    // learner did not ask for, and a plugin hiccup in it must not become a
    // snackbar over whatever they were doing.
    'applyRoutineLifecycle:silent',
    // Routine lock records and educator actions: all written locally first,
    // so a refused or offline cloud write is a sync gap the educator's UI
    // reports on its own terms — never a snackbar over a learner's lock.
    'RoutineLockRecord:silent',
    'RoutineActions:silent',
    'RoutineActionsStream:silent',
    // One document of a profile delete that could not be removed — reported,
    // never shown: the delete carries on, and the one refusal that matters
    // (the profile itself) is rethrown for a retry.
    'FirestoreRepository.deleteProfile:silent',
    'RoutineRecentDays:silent',
    // Deferred startup work (main.dart), the same class as
    // `applyLifecycle:silent`: nobody asked for it and nothing is blocked on
    // it, so it must not greet a learner at launch.
    'startupBackground:silent',
  };

  /// Whether [source] is suppressed from the global snackbar.
  ///
  /// Exposed for tests because the failure mode of [_silentSources] is a typo:
  /// a string no call site ever passes silences nothing, the snackbar keeps
  /// appearing, and the entry sitting in the set above makes it look handled.
  @visibleForTesting
  static bool isSilentSource(String source) => _silentSources.contains(source);

  static final _errorStreamController = StreamController<AppError>.broadcast();

  /// Stream of errors for the UI to listen to (e.g. show a snackbar).
  static Stream<AppError> get errorStream => _errorStreamController.stream;

  /// Initialize global error handling. Call this in main() BEFORE runApp().
  static void init() {
    // 1. Catch Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      // Framework *diagnostics* — layout overflow ("A RenderFlex overflowed
      // by …"), the ListTile ink/background-hidden warning, duplicate
      // GlobalKey, hero conflicts, "setState() during build", etc. — surface
      // here as `FlutterError` instances. They are recoverable, developer-
      // facing assertions: the app keeps running and most are compiled out of
      // release builds entirely. They must be logged for the developer but
      // must NEVER raise the user-facing "Something went wrong" snackbar at a
      // PWD learner (e.g. the ListTile warning that fires on the student home
      // right after joining a class). Genuine runtime exceptions thrown in
      // build/layout/paint arrive as their original type (e.g. _TypeError,
      // StateError, NoSuchMethodError) and DO still surface to the user.
      final isFrameworkDiagnostic = exception is FlutterError;
      final isOverflow =
          isFrameworkDiagnostic && exception.message.contains('overflowed by');
      // Suppress the yellow/black overflow banner in release; otherwise print
      // so the developer still sees and fixes the source.
      if (!isOverflow || kDebugMode) {
        FlutterError.presentError(details);
      }
      _handleError(
        details.exception,
        details.stack,
        source: isFrameworkDiagnostic
            ? 'FrameworkDiagnostic:silent'
            : 'FlutterError',
        context: details.context?.toString(),
      );
      // Forward to Crashlytics with full FlutterErrorDetails so the
      // remote report keeps the framework's context (widget tree, build
      // phase). Skip the layout-overflow spam. Internally gated by
      // AnalyticsService.isOptIn — no-op until an educator enables telemetry.
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
    runZonedGuarded(appRunner, (error, stack) {
      _handleError(error, stack, source: 'Zone');
    });
  }

  /// Manually report an error from anywhere in the codebase.
  /// Use this instead of silently swallowing with `catch (_) {}`.
  static void report(Object error, [StackTrace? stack, String? source]) {
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
    if (isSilentSource(source)) return;

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
        (box.get('logs', defaultValue: <dynamic>[]) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
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
        (box.get('logs', defaultValue: <dynamic>[]) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
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
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    stackTrace: json['stackTrace'] as String?,
  );
}
