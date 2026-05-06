import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/survey/models/survey_models.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';

void main() {
  group('SusSurveyResult — SUS score calculation', () {
    test('perfect positive scores calculate to 100', () {
      // All responses = 5 (strongly agree)
      // Odd Qs (0,2,4,6,8): 5-1 = 4 each → 5 × 4 = 20
      // Even Qs (1,3,5,7,9): 5-5 = 0 each → 5 × 0 = 0
      // Total = 20 × 2.5 = 50 — NOT 100, because even Qs disagree
      // For max score: odd Qs = 5, even Qs = 1
      final result = SusSurveyResult(
        id: 'test1',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [5, 1, 5, 1, 5, 1, 5, 1, 5, 1],
      );
      expect(result.susScore, 100.0);
    });

    test('worst possible scores calculate to 0', () {
      // Odd Qs = 1, Even Qs = 5 → all contributions = 0
      final result = SusSurveyResult(
        id: 'test2',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [1, 5, 1, 5, 1, 5, 1, 5, 1, 5],
      );
      expect(result.susScore, 0.0);
    });

    test('neutral responses (all 3s) calculate to 50', () {
      // Odd Qs: 3-1 = 2 each → 5 × 2 = 10
      // Even Qs: 5-3 = 2 each → 5 × 2 = 10
      // Total = 20 × 2.5 = 50
      final result = SusSurveyResult(
        id: 'test3',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
      );
      expect(result.susScore, 50.0);
    });

    test('empty responses return 0', () {
      final result = SusSurveyResult(
        id: 'test4',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [],
      );
      expect(result.susScore, 0.0);
    });

    test('wrong length responses return 0', () {
      final result = SusSurveyResult(
        id: 'test5',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [5, 5, 5],
      );
      expect(result.susScore, 0.0);
    });
  });

  group('SusSurveyResult — grade labels', () {
    test('score >= 85 is Excellent', () {
      final r = SusSurveyResult(
        id: 't', profileId: 'p', completedAt: DateTime(2025),
        responses: [5, 1, 5, 1, 5, 1, 5, 1, 5, 1], // 100
      );
      expect(r.gradeLabel, 'Excellent');
    });

    test('score 72 is Good', () {
      // Need score = 72.5 → sum = 29 → contributions = 29
      // Let's use specific values: odd=[5,5,5,4,4] even=[1,1,1,2,2]
      // Odd: 4+4+4+3+3 = 18, Even: 4+4+4+3+3 = 18 → 36×2.5 = 90 (too high)
      // Simpler: just test grade label with a known score
      final r = SusSurveyResult(
        id: 't', profileId: 'p', completedAt: DateTime(2025),
        responses: [4, 2, 4, 2, 4, 2, 4, 2, 4, 2], // each contrib = 3, sum = 30, × 2.5 = 75
      );
      expect(r.gradeLabel, 'Good');
    });

    test('score 52–71 is OK', () {
      // Need score >= 52 and < 72
      // Odd (0,2,4,6,8): responses [4,_,4,_,3,_,3,_,3] → 3+3+2+2+2 = 12
      // Even (1,3,5,7,9): responses [_,2,_,3,_,3,_,3,_,3] → 3+2+2+2+2 = 11
      // Total = 23 × 2.5 = 57.5
      final r = SusSurveyResult(
        id: 't', profileId: 'p', completedAt: DateTime(2025),
        responses: [4, 2, 4, 3, 3, 3, 3, 3, 3, 3],
      );
      expect(r.susScore, 57.5);
      expect(r.gradeLabel, 'OK');
    });

    test('score 38–51 is Poor', () {
      final r = SusSurveyResult(
        id: 't', profileId: 'p', completedAt: DateTime(2025),
        responses: [2, 3, 2, 3, 3, 3, 3, 3, 2, 3], // calc below
      );
      // Odd (0,2,4,6,8): 2-1 + 2-1 + 3-1 + 3-1 + 2-1 = 1+1+2+2+1 = 7
      // Even (1,3,5,7,9): 5-3 + 5-3 + 5-3 + 5-3 + 5-3 = 2×5 = 10
      // Total = 17 × 2.5 = 42.5
      expect(r.susScore, 42.5);
      expect(r.gradeLabel, 'Poor');
    });
  });

  group('SusSurveyResult — serialization', () {
    test('roundtrip toJson/fromJson preserves all fields', () {
      final original = SusSurveyResult(
        id: 'abc-123',
        profileId: 'prof-1',
        completedAt: DateTime(2025, 6, 15, 10, 30),
        responses: [5, 1, 4, 2, 3, 3, 4, 2, 5, 1],
        feedback: 'Great app!',
      );

      final json = original.toJson();
      final restored = SusSurveyResult.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.profileId, original.profileId);
      expect(restored.completedAt, original.completedAt);
      expect(restored.responses, original.responses);
      expect(restored.feedback, original.feedback);
      expect(restored.susScore, original.susScore);
    });

    test('fromJson clamps responses to 1-5', () {
      final json = {
        'id': 'x',
        'profileId': 'p',
        'completedAt': '2025-01-01T00:00:00.000',
        'responses': [0, 6, -1, 10, 3, 3, 3, 3, 3, 3],
      };
      final result = SusSurveyResult.fromJson(json);
      expect(result.responses[0], 1); // 0 clamped to 1
      expect(result.responses[1], 5); // 6 clamped to 5
      expect(result.responses[2], 1); // -1 clamped to 1
      expect(result.responses[3], 5); // 10 clamped to 5
    });

    test('fromJson handles null feedback', () {
      final json = {
        'id': 'x',
        'profileId': 'p',
        'completedAt': '2025-01-01T00:00:00.000',
        'responses': [3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
      };
      final result = SusSurveyResult.fromJson(json);
      expect(result.feedback, isNull);
    });
  });

  group('SusSurveyResult — copyWith', () {
    test('copyWith preserves fields when none specified', () {
      final original = SusSurveyResult(
        id: 'id1',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [1, 2, 3, 4, 5, 1, 2, 3, 4, 5],
        feedback: 'hello',
      );
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.feedback, 'hello');
    });

    test('copyWith can set feedback to null', () {
      final original = SusSurveyResult(
        id: 'id1',
        profileId: 'p1',
        completedAt: DateTime(2025),
        responses: [3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
        feedback: 'hello',
      );
      final copy = original.copyWith(feedback: () => null);
      expect(copy.feedback, isNull);
    });
  });

  group('SusQuestions', () {
    test('has 10 English questions', () {
      expect(SusQuestions.english.length, 10);
    });

    test('has 10 Filipino questions', () {
      expect(SusQuestions.filipino.length, 10);
    });

    test('has 5 Likert labels in English', () {
      expect(SusQuestions.scaleLabelsEnglish.length, 5);
    });

    test('has 5 Likert labels in Filipino', () {
      expect(SusQuestions.scaleLabelsFilipino.length, 5);
    });
  });

  // ─── Experiment Models ────────────────────────────────

  group('ExperimentConfig — defaults', () {
    test('default config has experiment disabled', () {
      const config = ExperimentConfig();
      expect(config.enabled, false);
      expect(config.groupLabel, 'treatment');
      expect(config.disabledFeatures, isEmpty);
    });

    test('default config allows all features', () {
      const config = ExperimentConfig();
      for (final f in GamificationFeature.values) {
        expect(config.isFeatureEnabled(f), true,
            reason: '${f.name} should be enabled by default');
      }
    });
  });

  group('ExperimentConfig — presets', () {
    test('treatment preset enables all features', () {
      final config = ExperimentConfig.treatment();
      expect(config.enabled, true);
      expect(config.groupLabel, 'treatment');
      for (final f in GamificationFeature.values) {
        expect(config.isFeatureEnabled(f), true);
      }
    });

    test('control preset disables all features', () {
      final config = ExperimentConfig.control();
      expect(config.enabled, true);
      expect(config.groupLabel, 'control');
      for (final f in GamificationFeature.values) {
        expect(config.isFeatureEnabled(f), false,
            reason: '${f.name} should be disabled in control group');
      }
    });
  });

  group('ExperimentConfig — isFeatureEnabled logic', () {
    test('experiment disabled = all features on regardless of disabled set', () {
      const config = ExperimentConfig(
        disabledFeatures: {GamificationFeature.stars, GamificationFeature.shop},
      );
      // When experiment is off, all features are always enabled
      expect(config.isFeatureEnabled(GamificationFeature.stars), true);
      expect(config.isFeatureEnabled(GamificationFeature.shop), true);
    });

    test('experiment enabled with specific features disabled', () {
      const config = ExperimentConfig(
        enabled: true,
        disabledFeatures: {
          GamificationFeature.leaderboard,
          GamificationFeature.celebrations,
        },
      );
      expect(config.isFeatureEnabled(GamificationFeature.stars), true);
      expect(config.isFeatureEnabled(GamificationFeature.leaderboard), false);
      expect(config.isFeatureEnabled(GamificationFeature.celebrations), false);
      expect(config.isFeatureEnabled(GamificationFeature.achievements), true);
    });
  });

  group('ExperimentConfig — serialization', () {
    test('roundtrip toJson/fromJson preserves all fields', () {
      const original = ExperimentConfig(
        enabled: true,
        groupLabel: 'control',
        disabledFeatures: {
          GamificationFeature.stars,
          GamificationFeature.streaks,
          GamificationFeature.shop,
        },
      );

      final json = original.toJson();
      final restored = ExperimentConfig.fromJson(json);

      expect(restored.enabled, true);
      expect(restored.groupLabel, 'control');
      expect(restored.disabledFeatures, contains(GamificationFeature.stars));
      expect(restored.disabledFeatures, contains(GamificationFeature.streaks));
      expect(restored.disabledFeatures, contains(GamificationFeature.shop));
      expect(restored.disabledFeatures.length, 3);
    });

    test('fromJson handles missing fields with defaults', () {
      final config = ExperimentConfig.fromJson({});
      expect(config.enabled, false);
      expect(config.groupLabel, 'treatment');
      expect(config.disabledFeatures, isEmpty);
    });

    test('fromJson ignores out-of-range feature indices', () {
      final config = ExperimentConfig.fromJson({
        'enabled': true,
        'groupLabel': 'test',
        'disabledFeatures': [0, 999, -1, 2],
      });
      // Only valid indices (0 = stars, 2 = leaderboard) should survive
      expect(config.disabledFeatures.length, 2);
      expect(config.disabledFeatures, contains(GamificationFeature.stars));
      expect(config.disabledFeatures, contains(GamificationFeature.leaderboard));
    });

    test('treatment preset roundtrip', () {
      final original = ExperimentConfig.treatment();
      final restored = ExperimentConfig.fromJson(original.toJson());
      expect(restored.enabled, true);
      expect(restored.groupLabel, 'treatment');
      expect(restored.disabledFeatures, isEmpty);
    });

    test('control preset roundtrip', () {
      final original = ExperimentConfig.control();
      final restored = ExperimentConfig.fromJson(original.toJson());
      expect(restored.enabled, true);
      expect(restored.groupLabel, 'control');
      expect(restored.disabledFeatures.length,
          GamificationFeature.values.length);
    });
  });

  group('ExperimentConfig — copyWith', () {
    test('copyWith preserves unspecified fields', () {
      const original = ExperimentConfig(
        enabled: true,
        groupLabel: 'custom',
        disabledFeatures: {GamificationFeature.shop},
      );
      final copy = original.copyWith(groupLabel: 'updated');
      expect(copy.enabled, true);
      expect(copy.groupLabel, 'updated');
      expect(copy.disabledFeatures, contains(GamificationFeature.shop));
    });

    test('copyWith can change disabled features', () {
      final original = ExperimentConfig.treatment();
      final copy = original.copyWith(
        disabledFeatures: {GamificationFeature.dailyChallenge},
      );
      expect(copy.isFeatureEnabled(GamificationFeature.stars), true);
      expect(copy.isFeatureEnabled(GamificationFeature.dailyChallenge), false);
    });
  });

  group('GamificationFeature — extensions', () {
    test('all features have labels', () {
      for (final f in GamificationFeature.values) {
        expect(f.label, isNotEmpty, reason: '${f.name} should have a label');
      }
    });

    test('all features have Filipino labels', () {
      for (final f in GamificationFeature.values) {
        expect(f.labelFilipino, isNotEmpty,
            reason: '${f.name} should have a Filipino label');
      }
    });

    test('all features have descriptions', () {
      for (final f in GamificationFeature.values) {
        expect(f.description, isNotEmpty,
            reason: '${f.name} should have a description');
      }
    });

    test('feature count is 9', () {
      expect(GamificationFeature.values.length, 9);
    });
  });
}
