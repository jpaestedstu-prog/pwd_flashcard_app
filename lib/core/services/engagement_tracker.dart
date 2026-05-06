import 'package:flutter/material.dart';
import '../../data/local/hive_service.dart';

/// Tracks screen-level navigation events and feature usage within a session.
///
/// Works alongside [SessionTracker] to provide deeper engagement analytics:
/// - Which screens were visited and for how long
/// - Which features/games were used most
/// - Return frequency (days between sessions)
class EngagementTracker extends NavigatorObserver {
  final String profileId;
  final List<_ScreenVisit> _visits = [];
  final Map<String, int> _featureUsage = {};
  DateTime? _lastScreenEntered;
  String? _currentScreen;

  EngagementTracker({required this.profileId});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _recordScreenExit();
    _currentScreen = route.settings.name ?? 'unknown';
    _lastScreenEntered = DateTime.now();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _recordScreenExit();
    _currentScreen = previousRoute?.settings.name;
    _lastScreenEntered = DateTime.now();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _recordScreenExit();
    _currentScreen = newRoute?.settings.name ?? 'unknown';
    _lastScreenEntered = DateTime.now();
  }

  void _recordScreenExit() {
    if (_currentScreen != null && _lastScreenEntered != null) {
      final duration =
          DateTime.now().difference(_lastScreenEntered!).inSeconds;
      if (duration >= 1) {
        // Only record visits > 1 second
        _visits.add(_ScreenVisit(
          screenName: _currentScreen!,
          durationSeconds: duration,
          timestamp: _lastScreenEntered!,
        ));
      }
    }
  }

  /// Track usage of a named feature (e.g., 'shop_visit', 'leaderboard_view').
  void trackFeatureUsage(String featureName) {
    _featureUsage[featureName] = (_featureUsage[featureName] ?? 0) + 1;
  }

  /// Flush all collected data to Hive storage.
  Future<void> flush() async {
    _recordScreenExit(); // Capture the last screen

    if (_visits.isEmpty && _featureUsage.isEmpty) return;

    final data = <String, dynamic>{
      'date': DateTime.now().toIso8601String(),
      'screenVisits': _visits
          .map((v) => {
                'screen': v.screenName,
                'duration': v.durationSeconds,
                'time': v.timestamp.toIso8601String(),
              })
          .toList(),
      'featureUsage': _featureUsage,
    };

    HiveService.addEngagementLog(profileId, data);
    _visits.clear();
    _featureUsage.clear();
  }

  // ─── Static Analytics Queries ──────────────────────

  /// Get all engagement logs for a profile.
  static List<Map<String, dynamic>> getLogs(String profileId) {
    return HiveService.getEngagementLogs(profileId);
  }

  /// Get the most visited screens (top N) in the last N days.
  static Map<String, int> topScreens(String profileId,
      {int days = 30, int limit = 10}) {
    final logs = getLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final screenCounts = <String, int>{};

    for (final log in logs) {
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null || date.isBefore(cutoff)) continue;

      final visits = log['screenVisits'] as List? ?? [];
      for (final visit in visits) {
        final map = Map<String, dynamic>.from(visit as Map);
        final screen = map['screen'] as String? ?? 'unknown';
        screenCounts[screen] = (screenCounts[screen] ?? 0) + 1;
      }
    }

    final sorted = screenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(limit));
  }

  /// Get total time per screen (in seconds) in the last N days.
  static Map<String, int> screenDurations(String profileId,
      {int days = 30}) {
    final logs = getLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final durations = <String, int>{};

    for (final log in logs) {
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null || date.isBefore(cutoff)) continue;

      final visits = log['screenVisits'] as List? ?? [];
      for (final visit in visits) {
        final map = Map<String, dynamic>.from(visit as Map);
        final screen = map['screen'] as String? ?? 'unknown';
        final dur = map['duration'] as int? ?? 0;
        durations[screen] = (durations[screen] ?? 0) + dur;
      }
    }
    return durations;
  }

  /// Get feature usage counts in the last N days.
  static Map<String, int> featureUsageSummary(String profileId,
      {int days = 30}) {
    final logs = getLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final usage = <String, int>{};

    for (final log in logs) {
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null || date.isBefore(cutoff)) continue;

      final featureMap = log['featureUsage'] as Map? ?? {};
      for (final entry in featureMap.entries) {
        final key = entry.key.toString();
        usage[key] = (usage[key] ?? 0) + (entry.value as int? ?? 0);
      }
    }
    return usage;
  }

  /// Calculate return frequency: average days between sessions.
  static double returnFrequency(String profileId, {int days = 30}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final dates = sessions
        .map((s) => DateTime.tryParse(s['date'] as String? ?? ''))
        .where((d) => d != null && d.isAfter(cutoff))
        .map((d) => d!)
        .toList()
      ..sort();

    if (dates.length < 2) return 0;

    // Get unique session days
    final uniqueDays = <String>{};
    for (final d in dates) {
      uniqueDays.add(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    final sortedDays = uniqueDays.toList()..sort();
    if (sortedDays.length < 2) return 0;

    // Average gap between session days
    double totalGap = 0;
    for (int i = 1; i < sortedDays.length; i++) {
      final prev = DateTime.parse(sortedDays[i - 1]);
      final curr = DateTime.parse(sortedDays[i]);
      totalGap += curr.difference(prev).inDays;
    }
    return totalGap / (sortedDays.length - 1);
  }

  /// Get unique active days in the last N days.
  static int activeDays(String profileId, {int days = 30}) {
    final sessions = HiveService.getSessionLogs(profileId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final uniqueDays = <String>{};

    for (final s in sessions) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      if (date != null && date.isAfter(cutoff)) {
        uniqueDays.add(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
      }
    }
    return uniqueDays.length;
  }
}

class _ScreenVisit {
  final String screenName;
  final int durationSeconds;
  final DateTime timestamp;

  const _ScreenVisit({
    required this.screenName,
    required this.durationSeconds,
    required this.timestamp,
  });
}
