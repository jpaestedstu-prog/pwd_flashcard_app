import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/alert_models.dart';

/// Service that checks student data and generates alerts for parents/teachers.
///
/// Persists alert config and alert history in Hive.
class AlertService {
  static const _configKey = 'alert_config';
  static const _alertsKey = 'alert_history';

  // ─── Config Management ──────────────────────────────

  /// Get the current alert configuration.
  static AlertConfig getConfig() {
    final data = HiveService.getSetting(_configKey);
    if (data == null) return const AlertConfig();
    return AlertConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Save the alert configuration.
  static Future<void> saveConfig(AlertConfig config) async {
    await HiveService.saveSetting(_configKey, config.toJson());
  }

  // ─── Alert History ──────────────────────────────────

  /// Get all alerts, newest first.
  static List<AlertEntry> getAlerts() {
    final data = HiveService.getSetting(_alertsKey);
    if (data == null) return [];
    final list = List<dynamic>.from(data as List);
    final alerts = list
        .map((e) => AlertEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  /// Get unread alert count.
  static int get unreadCount =>
      getAlerts().where((a) => !a.isRead).length;

  /// Mark a single alert as read.
  static Future<void> markRead(String alertId) async {
    final alerts = getAlerts();
    final updated = alerts
        .map((a) => a.id == alertId ? a.markRead() : a)
        .toList();
    await _saveAlerts(updated);
  }

  /// Mark all alerts as read.
  static Future<void> markAllRead() async {
    final alerts = getAlerts();
    final updated = alerts.map((a) => a.markRead()).toList();
    await _saveAlerts(updated);
  }

  /// Clear all alert history.
  static Future<void> clearAlerts() async {
    await HiveService.saveSetting(_alertsKey, <dynamic>[]);
  }

  // ─── Alert Generation ──────────────────────────────

  /// Scan all student profiles and generate any new alerts.
  /// Call this periodically (e.g., on parent/teacher dashboard load).
  static Future<List<AlertEntry>> checkAndGenerateAlerts() async {
    final config = getConfig();
    if (!config.enabled) return [];

    final existingAlerts = getAlerts();
    final newAlerts = <AlertEntry>[];

    // Get all student profiles with progress
    final profilesWithProgress = HiveService.getAllProfilesWithProgress();
    final students =
        profilesWithProgress.where((p) => p.$1.role == UserRole.student);

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    for (final (profile, progress) in students) {
      // ─── Low Accuracy Check ─────────
      if (config.enabledTypes.contains(AlertType.lowAccuracy) &&
          progress.recentScores.isNotEmpty) {
        final recentAccuracy = _recentAccuracy(progress);
        if (recentAccuracy < config.accuracyThreshold) {
          final alertKey =
              'lowAccuracy_${profile.id}_$todayKey';
          if (!_alertExists(existingAlerts, alertKey)) {
            newAlerts.add(AlertEntry(
              id: alertKey,
              type: AlertType.lowAccuracy,
              studentProfileId: profile.id,
              studentName: profile.name,
              message:
                  '${profile.name}\'s accuracy is ${(recentAccuracy * 100).round()}% '
                  '(below ${(config.accuracyThreshold * 100).round()}% threshold)',
              timestamp: now,
            ));
          }
        }
      }

      // ─── Inactivity Check ──────────
      if (config.enabledTypes.contains(AlertType.inactivity)) {
        final daysSinceActive =
            now.difference(progress.lastActivityDate).inDays;
        if (daysSinceActive >= config.inactivityDays) {
          final alertKey =
              'inactivity_${profile.id}_$todayKey';
          if (!_alertExists(existingAlerts, alertKey)) {
            newAlerts.add(AlertEntry(
              id: alertKey,
              type: AlertType.inactivity,
              studentProfileId: profile.id,
              studentName: profile.name,
              message:
                  '${profile.name} has been inactive for $daysSinceActive days',
              timestamp: now,
            ));
          }
        }
      }

      // ─── Streak Broken Check ───────
      if (config.enabledTypes.contains(AlertType.streakBroken)) {
        final daysSinceActive =
            now.difference(progress.lastActivityDate).inDays;
        // Streak is considered broken if they had a streak and missed a day
        if (daysSinceActive >= 2 && progress.streakDays == 0) {
          final alertKey =
              'streakBroken_${profile.id}_$todayKey';
          if (!_alertExists(existingAlerts, alertKey)) {
            newAlerts.add(AlertEntry(
              id: alertKey,
              type: AlertType.streakBroken,
              studentProfileId: profile.id,
              studentName: profile.name,
              message: '${profile.name}\'s streak was broken',
              timestamp: now,
            ));
          }
        }
      }
    }

    // Save new alerts
    if (newAlerts.isNotEmpty) {
      final all = [...newAlerts, ...existingAlerts];
      // Keep only last 100 alerts to prevent unbounded growth
      final trimmed = all.take(100).toList();
      await _saveAlerts(trimmed);
    }

    return newAlerts;
  }

  // ─── Helpers ────────────────────────────────────────

  static double _recentAccuracy(LearningProgress progress) {
    final last5 = progress.recentScores.reversed.take(5).toList();
    if (last5.isEmpty) return 0;
    final sum = last5.fold<double>(
      0,
      (s, score) => s + (score.total > 0 ? score.score / score.total : 0),
    );
    return sum / last5.length;
  }

  static bool _alertExists(List<AlertEntry> alerts, String id) {
    return alerts.any((a) => a.id == id);
  }

  static Future<void> _saveAlerts(List<AlertEntry> alerts) async {
    await HiveService.saveSetting(
      _alertsKey,
      alerts.map((a) => a.toJson()).toList(),
    );
  }
}
