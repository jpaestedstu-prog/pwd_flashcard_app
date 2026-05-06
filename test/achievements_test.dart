import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

void main() {
  group('Achievements', () {
    test('all achievements have unique IDs', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(ids.length, Achievements.all.length);
    });

    test('all achievements have non-empty fields', () {
      for (final a in Achievements.all) {
        expect(a.title, isNotEmpty, reason: '${a.id} missing title');
        expect(a.description, isNotEmpty,
            reason: '${a.id} missing description');
        expect(a.icon, isNotNull, reason: '${a.id} missing icon');
      }
    });

    test('first_word unlocks at wordsLearned >= 1', () {
      final progress = LearningProgress(
        profileId: 'test',
        wordsLearned: 1,
        lastActivityDate: DateTime.now(),
      );

      final unlocked = Achievements.unlockedIds(progress);
      expect(unlocked.contains('first_word'), true);
    });

    test('half_way unlocks at 72+ words', () {
      final progress = LearningProgress(
        profileId: 'test',
        wordsLearned: 72,
        lastActivityDate: DateTime.now(),
      );

      final unlocked = Achievements.unlockedIds(progress);
      expect(unlocked.contains('half_way'), true);
    });

    test('week_streak does NOT unlock at 3-day streak', () {
      final progress = LearningProgress(
        profileId: 'test',
        streakDays: 3,
        lastActivityDate: DateTime.now(),
      );

      final unlocked = Achievements.unlockedIds(progress);
      expect(unlocked.contains('week_streak'), false);
    });

    test('week_streak unlocks at 7+ day streak', () {
      final progress = LearningProgress(
        profileId: 'test',
        streakDays: 7,
        lastActivityDate: DateTime.now(),
      );

      final unlocked = Achievements.unlockedIds(progress);
      expect(unlocked.contains('week_streak'), true);
    });

    test('findNewlyUnlocked returns only new achievements', () {
      final progress = LearningProgress(
        profileId: 'test',
        wordsLearned: 72,
        lastActivityDate: DateTime.now(),
      );

      // Both first_word and half_way should unlock (wordsLearned=72 >= 1 and >= 72)
      final allUnlocked = Achievements.unlockedIds(progress);
      expect(allUnlocked.contains('first_word'), true);
      expect(allUnlocked.contains('half_way'), true);

      // Simulate that first_word was already unlocked
      final newOnes = Achievements.findNewlyUnlocked(
        progress: progress,
        previouslyUnlockedIds: {'first_word'},
      );

      // half_way should be newly unlocked, but not first_word
      expect(newOnes.any((a) => a.id == 'half_way'), true);
      expect(newOnes.any((a) => a.id == 'first_word'), false);
    });
  });
}
