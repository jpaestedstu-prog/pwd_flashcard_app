import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../features/experiment/models/experiment_models.dart';
import '../features/experiment/services/experiment_service.dart';

// ─── Experiment / Gamification Toggle Provider ─────────

class ExperimentNotifier extends Notifier<ExperimentConfig> {
  @override
  ExperimentConfig build() {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const ExperimentConfig();
    return ExperimentService.getConfig(profile.id);
  }

  Future<void> setConfig(ExperimentConfig config) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await ExperimentService.saveConfig(profile.id, config);
    state = config;
  }

  Future<void> applyTreatment() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await ExperimentService.applyTreatmentGroup(profile.id);
    state = ExperimentConfig.treatment();
  }

  Future<void> applyControl() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await ExperimentService.applyControlGroup(profile.id);
    state = ExperimentConfig.control();
  }

  Future<void> disable() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await ExperimentService.disableExperiment(profile.id);
    state = const ExperimentConfig();
  }

  Future<void> toggleFeature(GamificationFeature feature) async {
    final current = Set<GamificationFeature>.from(state.disabledFeatures);
    if (current.contains(feature)) {
      current.remove(feature);
    } else {
      current.add(feature);
    }
    await setConfig(state.copyWith(disabledFeatures: current));
  }

  /// Check if a gamification feature should be visible.
  bool isFeatureVisible(GamificationFeature feature) {
    return state.isFeatureEnabled(feature);
  }
}

final experimentProvider =
    NotifierProvider<ExperimentNotifier, ExperimentConfig>(
  ExperimentNotifier.new,
);

/// Convenience provider to check if a specific gamification feature
/// is enabled for the current profile.
final gamificationFeatureProvider =
    Provider.family<bool, GamificationFeature>((ref, feature) {
  final config = ref.watch(experimentProvider);
  return config.isFeatureEnabled(feature);
});
