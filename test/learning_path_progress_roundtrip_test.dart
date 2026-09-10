import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/learning_path.dart';

/// Pins the Hive round-trip that used to crash a learner's second session.
///
/// `LearningPathProgress.fromJson` cast `bestScores` to `Map<String, dynamic>`.
/// That holds for a map this code built itself, and fails for the same map read
/// back out of Hive, which hands nested maps back as `Map<dynamic, dynamic>`.
/// `HiveService.getAllLearningPathProgress` converts only the *top* level, so
/// the nested one arrived dynamic-keyed and the cast threw — on the provider
/// every learning-path screen watches.
///
/// Nothing caught it because nothing had ever read a *stored* progress record
/// back: the round trip only happens on the learner's next launch.
void main() {
  group('LearningPathProgress.fromJson', () {
    test('accepts the map shape Hive returns', () {
      // Exactly what Hive hands back: dynamic keys all the way down.
      final fromHive = <String, dynamic>{
        'pathId': 'path-1',
        'completedStepIndices': <dynamic>[0, 1],
        'currentStepIndex': 2,
        'startedAt': DateTime(2026, 9, 2).toIso8601String(),
        'bestScores': <dynamic, dynamic>{'0': 0.8, '1': 0.95},
      };

      final progress = LearningPathProgress.fromJson(fromHive);

      expect(progress.pathId, 'path-1');
      expect(progress.currentStepIndex, 2);
      expect(progress.completedStepIndices, {0, 1});
      expect(progress.bestScores[0], closeTo(0.8, 1e-9));
      expect(progress.bestScores[1], closeTo(0.95, 1e-9));
    });

    test('still accepts its own toJson output', () {
      final original = LearningPathProgress(
        pathId: 'path-2',
        startedAt: DateTime(2026, 9, 2),
        currentStepIndex: 1,
        completedStepIndices: {0},
        bestScores: const {0: 0.6},
      );

      final restored = LearningPathProgress.fromJson(original.toJson());

      expect(restored.pathId, 'path-2');
      expect(restored.bestScores[0], closeTo(0.6, 1e-9));
      expect(restored.completedStepIndices, {0});
    });

    test('treats a missing bestScores as empty rather than throwing', () {
      final progress = LearningPathProgress.fromJson(<String, dynamic>{
        'pathId': 'path-3',
        'completedStepIndices': <dynamic>[],
        'currentStepIndex': 0,
        'startedAt': DateTime(2026, 9, 2).toIso8601String(),
      });

      expect(progress.bestScores, isEmpty);
    });
  });
}
