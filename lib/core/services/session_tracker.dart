import 'package:flutter/widgets.dart';
import '../../data/local/hive_service.dart';

/// Tracks app sessions — start/end time, games played, cards reviewed.
///
/// Uses [WidgetsBindingObserver] to detect when the app goes to
/// background (pause) and returns (resume).
class SessionTracker with WidgetsBindingObserver {
  final String profileId;
  DateTime _sessionStart;
  int _gamesPlayed = 0;
  int _cardsReviewed = 0;

  SessionTracker({required this.profileId})
      : _sessionStart = DateTime.now() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Record that a game was played in this session.
  void recordGamePlayed() => _gamesPlayed++;

  /// Record that N cards were reviewed in this session.
  void recordCardsReviewed(int count) => _cardsReviewed += count;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _endSession();
    } else if (state == AppLifecycleState.resumed) {
      _startNewSession();
    }
  }

  void _startNewSession() {
    _sessionStart = DateTime.now();
    _gamesPlayed = 0;
    _cardsReviewed = 0;
  }

  void _endSession() {
    final duration = DateTime.now().difference(_sessionStart);
    // Only log sessions > 5 seconds (ignore accidental opens)
    if (duration.inSeconds < 5) return;

    HiveService.addSessionLog(profileId, {
      'date': _sessionStart.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'gamesPlayed': _gamesPlayed,
      'cardsReviewed': _cardsReviewed,
    });
  }

  /// Manually end the current session (e.g. on profile switch).
  void endCurrentSession() => _endSession();

  /// Remove this observer when no longer needed.
  void dispose() {
    _endSession();
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
