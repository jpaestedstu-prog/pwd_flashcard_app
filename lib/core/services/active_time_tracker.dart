import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/local/hive_service.dart';
import '../../data/models/active_time_log.dart';
import 'firebase_service.dart';

/// Foreground-minute counter for one child profile.
///
/// Increments today's [ActiveTimeLog] every minute the app is in the
/// resumed state. Persists to Hive on every tick (cheap) and pushes to
/// Firestore every 5 minutes (debounced, owner-scoped via [child_profile_id]).
///
/// Read by:
///   • [LockEnforcer] — to compare against [ChildTimeLimit.dailyLimitMinutes].
///   • Parent dashboard "X / Y min today" pill via `activeTimeProvider`.
///
/// Limitation: `Timer.periodic` only ticks while the app is in the
/// foreground. This is acceptable for the thesis demo since "screen
/// time" only matters when the child is actively using the app. Add an
/// Android foreground-service later if background tracking becomes
/// necessary.
class ActiveTimeTracker with WidgetsBindingObserver {
  ActiveTimeTracker._(this.profileId);

  /// Singleton currently in flight, if any. Tied to the active profile.
  static ActiveTimeTracker? _instance;

  final String profileId;

  Timer? _timer;
  AppLifecycleState _state = AppLifecycleState.resumed;
  DateTime? _lastFirestorePush;

  /// Latest known minutes-used-today. Re-emitted to listeners every tick
  /// so widgets can rebuild without polling Hive.
  int _minutesUsedToday = 0;
  int get minutesUsedToday => _minutesUsedToday;

  /// Listeners receive `(profileId, minutesUsedToday)` after every tick.
  /// Used by `activeTimeProvider` to keep UI live.
  static final List<void Function(String, int)> _listeners = [];

  /// Subscribe to tick callbacks. Returns an unsubscribe function.
  static void Function() addListener(void Function(String, int) cb) {
    _listeners.add(cb);
    return () => _listeners.remove(cb);
  }

  /// Start tracking [profileId]. Cancels any prior tracker.
  static Future<ActiveTimeTracker> start(String profileId) async {
    await _instance?.stop();
    final t = ActiveTimeTracker._(profileId);
    await t._init();
    _instance = t;
    return t;
  }

  /// Stop the active tracker (e.g. on profile switch / sign-out).
  static Future<void> stopActive() async {
    await _instance?.stop();
    _instance = null;
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    // Hydrate cached value so UI shows the right number on startup.
    final today = ActiveTimeLog.dayKeyFor(DateTime.now());
    _minutesUsedToday =
        HiveService.getActiveTimeLog(profileId, today).minutesUsed;
    _emit();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _state == AppLifecycleState.resumed;
    _state = state;
    // On pause/detached, push today's counter immediately so a
    // force-close doesn't drop up to 5 minutes that haven't crossed
    // the debounce yet.
    if (wasResumed &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(flushNow().catchError((Object e, StackTrace _) {
        if (kDebugMode) {
          debugPrint('ActiveTimeTracker flush-on-pause failed: $e');
        }
      }));
    }
  }

  Future<void> _tick() async {
    if (_state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final dayKey = ActiveTimeLog.dayKeyFor(now);
    final updated = await HiveService.incrementActiveTime(
      profileId: profileId,
      dayKey: dayKey,
      now: now,
    );
    _minutesUsedToday = updated.minutesUsed;
    _emit();

    // Debounced Firestore push: at most once every 5 minutes.
    final last = _lastFirestorePush;
    if (last == null || now.difference(last).inMinutes >= 5) {
      _lastFirestorePush = now;
      _pushToFirestore(updated).catchError((e) {
        if (kDebugMode) {
          debugPrint('ActiveTimeTracker push failed: $e');
        }
      });
    }
  }

  /// Force-push today's counter to Firestore right now, bypassing the
  /// 5-minute debounce. Called on `AppLifecycleState.paused` so a
  /// force-close between debounced pushes doesn't lose up to 5 minutes
  /// of recorded time. Safe to call when offline — it just no-ops if
  /// Firebase isn't configured.
  Future<void> flushNow() async {
    final now = DateTime.now();
    final dayKey = ActiveTimeLog.dayKeyFor(now);
    final current = HiveService.getActiveTimeLog(profileId, dayKey);
    _lastFirestorePush = now;
    await _pushToFirestore(current);
  }

  Future<void> _pushToFirestore(ActiveTimeLog log) async {
    if (!FirebaseService.isConfigured) return;
    final payload = log.toJson()
      ..['owner_uid'] = FirebaseService.currentUid;
    await FirebaseService.db
        .collection('active_time_logs')
        .doc(log.docId)
        .set(payload, SetOptions(merge: true));
  }

  void _emit() {
    for (final cb in _listeners) {
      try {
        cb(profileId, _minutesUsedToday);
      } catch (_) {}
    }
  }
}
