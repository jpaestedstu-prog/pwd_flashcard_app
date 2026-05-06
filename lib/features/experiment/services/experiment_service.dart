import 'package:hive_flutter/hive_flutter.dart';
import '../models/experiment_models.dart';

/// Manages experiment/gamification toggle configuration per student.
class ExperimentService {
  const ExperimentService._();

  static const String _boxName = 'settings';
  static Box get _box => Hive.box(_boxName);

  /// Get experiment config for a specific student profile.
  static ExperimentConfig getConfig(String profileId) {
    final raw = _box.get('experiment_$profileId');
    if (raw == null) return const ExperimentConfig();
    return ExperimentConfig.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  /// Save experiment config for a specific student profile.
  static Future<void> saveConfig(
      String profileId, ExperimentConfig config) async {
    await _box.put('experiment_$profileId', config.toJson());
  }

  /// Quick-apply a preset to a student.
  static Future<void> applyTreatmentGroup(String profileId) async {
    await saveConfig(profileId, ExperimentConfig.treatment());
  }

  /// Quick-apply control group (all gamification off) to a student.
  static Future<void> applyControlGroup(String profileId) async {
    await saveConfig(profileId, ExperimentConfig.control());
  }

  /// Disable experiment mode for a student (restore normal mode).
  static Future<void> disableExperiment(String profileId) async {
    await saveConfig(profileId, const ExperimentConfig());
  }

  /// Check if a gamification feature is enabled for the current profile.
  static bool isFeatureEnabled(
      String profileId, GamificationFeature feature) {
    return getConfig(profileId).isFeatureEnabled(feature);
  }

  /// Batch-apply experiment group to multiple students.
  /// Uses a single Hive write instead of N individual puts.
  static Future<void> batchApply(
    List<String> profileIds,
    ExperimentConfig config,
  ) async {
    final json = config.toJson();
    final batch = <String, dynamic>{
      for (final id in profileIds) 'experiment_$id': json,
    };
    await _box.putAll(batch);
  }

  /// Get all experiment configs (for research export).
  static Map<String, ExperimentConfig> getAllConfigs() {
    final result = <String, ExperimentConfig>{};
    for (final key in _box.keys) {
      if (key is String && key.startsWith('experiment_')) {
        final profileId = key.substring('experiment_'.length);
        final raw = _box.get(key);
        if (raw != null) {
          result[profileId] = ExperimentConfig.fromJson(
            Map<String, dynamic>.from(raw as Map),
          );
        }
      }
    }
    return result;
  }
}
