import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';

void main() {
  group('ExperimentConfig.assignedAt', () {
    test('treatment preset stamps a recent assignment time', () {
      final config = ExperimentConfig.treatment();
      expect(config.assignedAt, isNotNull);
      expect(DateTime.now().difference(config.assignedAt!).inSeconds,
          lessThan(5));
    });

    test('control preset stamps an assignment time', () {
      expect(ExperimentConfig.control().assignedAt, isNotNull);
    });

    test('default (normal mode) config has no assignment time', () {
      expect(const ExperimentConfig().assignedAt, isNull);
    });

    test('copyWith preserves assignedAt when toggling features', () {
      final original = ExperimentConfig.treatment();
      final copy = original.copyWith(
        disabledFeatures: {GamificationFeature.shop},
      );
      expect(copy.assignedAt, original.assignedAt);
    });

    test('toJson/fromJson round-trips assignedAt', () {
      final at = DateTime(2026, 6, 1, 9, 30, 15);
      final config = ExperimentConfig(enabled: true, assignedAt: at);
      final restored = ExperimentConfig.fromJson(config.toJson());
      expect(restored.assignedAt, at);
    });

    test('fromJson tolerates a missing/null assignedAt', () {
      expect(ExperimentConfig.fromJson({'enabled': true}).assignedAt, isNull);
      expect(
        ExperimentConfig.fromJson({'enabled': true, 'assignedAt': null})
            .assignedAt,
        isNull,
      );
    });
  });
}
