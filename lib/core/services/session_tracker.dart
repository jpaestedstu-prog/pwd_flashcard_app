import 'dart:async';

import 'package:flutter/widgets.dart';
import '../../data/local/hive_service.dart';

/// Bumped after every session write.
///
/// Study-time summaries are derived from the session log, but the log is
/// written by a plain service on a timer — nothing in Riverpod changes when a
/// checkpoint lands. Without this signal a cached summary sat on the figure it
/// held when *progress* last changed, so "This Week → Minutes" drifted behind
/// the same number on Detailed Analytics, which reads the log directly. Two
/// study-time readouts disagreeing is the exact defect this whole area was
/// fixed for, so the summary listens here instead.
final ValueNotifier<int> sessionLogRevision = ValueNotifier<int>(0);

/// Tracks app sessions — start/end time, games played, cards reviewed.
///
/// Uses [WidgetsBindingObserver] to detect when the app goes to
/// background (pause) and returns (resume).
class SessionTracker with WidgetsBindingObserver {
  final String profileId;
  DateTime _sessionStart;
  int _gamesPlayed = 0;
  int _cardsReviewed = 0;

  /// Identity of the sitting being written, so each checkpoint overwrites the
  /// previous one instead of appending a new row. See
  /// [HiveService.upsertSessionLog].
  late String _sessionId;

  Timer? _checkpoint;
  AppLifecycleState _state = AppLifecycleState.resumed;

  /// How often an in-progress sitting is written to disk. Matches
  /// [ActiveTimeTracker]'s cadence — the two count the same wall clock, and a
  /// minute is fine-grained enough for every report that reads either.
  static const Duration checkpointInterval = Duration(minutes: 1);

  /// The tracker for the profile that is signed in, if any.
  ///
  /// Exists so the code that *knows* a game finished — `ProgressNotifier` —
  /// can say so without every caller having to reach through Riverpod for a
  /// service that may legitimately not exist (no profile, or a test).
  static SessionTracker? _active;
  static SessionTracker? get active => _active;

  SessionTracker({required this.profileId})
      : _sessionStart = DateTime.now() {
    _sessionId = _sessionStart.toIso8601String();
    WidgetsBinding.instance.addObserver(this);
    _checkpoint = Timer.periodic(checkpointInterval, (_) => _write());
    _active = this;
  }

  /// Record that a game was played in this session.
  void recordGamePlayed() => _gamesPlayed++;

  /// Record that N cards were reviewed in this session.
  void recordCardsReviewed(int count) => _cardsReviewed += count;

  /// Seconds the current sitting has been running. Zero once it has ended.
  int get elapsedSeconds => DateTime.now().difference(_sessionStart).inSeconds;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _state == AppLifecycleState.resumed;
    _state = state;
    if (wasResumed &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _endSession();
    } else if (state == AppLifecycleState.resumed && !wasResumed) {
      _startNewSession();
    }
  }

  void _startNewSession() {
    _sessionStart = DateTime.now();
    _sessionId = _sessionStart.toIso8601String();
    _gamesPlayed = 0;
    _cardsReviewed = 0;
  }

  /// Persists the sitting as it stands. Safe to call repeatedly — the write is
  /// keyed by [_sessionId], so it replaces rather than accumulates.
  void _write({bool force = false}) {
    if (!force && _state != AppLifecycleState.resumed) return;
    final duration = DateTime.now().difference(_sessionStart);
    // Only log sessions > 5 seconds (ignore accidental opens)
    if (duration.inSeconds < 5) return;

    HiveService.upsertSessionLog(profileId, {
      'id': _sessionId,
      'date': _sessionStart.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'gamesPlayed': _gamesPlayed,
      'cardsReviewed': _cardsReviewed,
    });
    sessionLogRevision.value++;
  }

  /// Final write for the sitting. Forced, because the thing that triggers it —
  /// the app leaving `resumed`, or the profile being switched out — has already
  /// moved the lifecycle state past the point [_write] would accept.
  void _endSession() => _write(force: true);

  /// Manually end the current session (e.g. on profile switch).
  void endCurrentSession() => _endSession();

  /// Test seam: pretend this sitting began [ago] earlier.
  ///
  /// A sitting under five seconds is deliberately not logged, so without this
  /// every test of the write path would have to wait out real wall-clock time.
  @visibleForTesting
  void debugBackdateStart(Duration ago) {
    _sessionStart = DateTime.now().subtract(ago);
    // Deliberately *not* re-deriving `_sessionId` — the id identifies the
    // sitting, and backdating is meant to age the one already in flight.
  }

  /// Test seam: run one checkpoint now instead of waiting for the timer.
  @visibleForTesting
  void debugCheckpoint() => _write();

  /// Remove this observer when no longer needed.
  void dispose() {
    _endSession();
    _checkpoint?.cancel();
    _checkpoint = null;
    if (identical(_active, this)) _active = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  // ─── Analytics Queries ─────────────────────────────

  /// Get total study time in minutes for the last N days.
  /// [now] exists so a caller can ask about a fixed point in time — the same
  /// seam `WeeklySummary.forProfile` already had. Without it the two could
  /// not be compared against one dataset: a test pinning a date here silently
  /// drifted out of its own window as the real clock moved on.
  static int totalStudyMinutes(String profileId,
      {int days = 30, DateTime? now}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    int totalSeconds = 0;
    for (final s in sessions) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      if (date != null && date.isAfter(cutoff)) {
        totalSeconds += (s['durationSeconds'] as int?) ?? 0;
      }
    }
    return (totalSeconds / 60).round();
  }

  /// Get average session length in minutes.
  static double averageSessionMinutes(String profileId,
      {int days = 30, DateTime? now}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final filtered = sessions.where((s) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      return date != null && date.isAfter(cutoff);
    }).toList();
    if (filtered.isEmpty) return 0;
    int totalSeconds = 0;
    for (final s in filtered) {
      totalSeconds += (s['durationSeconds'] as int?) ?? 0;
    }
    return totalSeconds / 60 / filtered.length;
  }

  /// Get total number of sessions in the last N days.
  static int totalSessions(String profileId, {int days = 30}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return sessions.where((s) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      return date != null && date.isAfter(cutoff);
    }).length;
  }

  /// Get total games played in the last N days.
  ///
  /// Reads the day ledger, not the session logs. The session log's own
  /// `gamesPlayed` field is fed by [recordGamePlayed], which nothing in the app
  /// has ever called — so every session is logged with zero, and this method
  /// returned a flat 0 no matter how much the learner played. The ledger is
  /// written by `ProgressNotifier.recordGameResult`, i.e. by the thing that
  /// actually knows a game finished.
  static int totalGamesPlayed(String profileId,
      {int days = 30, DateTime? now}) {
    final ledger = HiveService.getDailyActivity(profileId);
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    var total = 0;
    ledger.forEach((key, row) {
      final date = DateTime.tryParse(key);
      if (date != null && date.isAfter(cutoff)) {
        total += row['games'] ?? 0;
      }
    });
    return total;
  }

  /// Get daily study minutes for the last N days (for charts).
  /// Returns a map of date string (yyyy-MM-dd) -> minutes.
  static Map<String, int> dailyStudyMinutes(
      String profileId, {int days = 7, DateTime? now}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final result = <String, int>{};

    // Pre-fill with zeros for all days (oldest first for chronological order)
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result[key] = 0;
    }

    for (final s in sessions) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      if (date != null && date.isAfter(cutoff)) {
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final minutes = ((s['durationSeconds'] as int?) ?? 0) ~/ 60;
        result[key] = (result[key] ?? 0) + minutes;
      }
    }

    return result;
  }
}
