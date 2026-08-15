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

  // ─────────────────────────────────────────────────────────────────────
  // Word Hunt badges
  // ─────────────────────────────────────────────────────────────────────
  //
  // These read the Word Hunt discovery log rather than [LearningProgress], so
  // they are the one family of achievements that touches Hive. This suite never
  // opens a box — which is exactly the case the service's guarded accessors
  // exist for, and asserting it here keeps that guard from being removed.
  group('Word Hunt achievements', () {
    LearningProgress progress() => LearningProgress(
          profileId: 'p-hunt',
          lastActivityDate: DateTime(2026),
        );

    test('are part of the badge set', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          'hunt_first_find',
          'hunt_spotter',
          'hunt_collector',
          'hunt_daily_streak',
        ]),
      );
    });

    test('stay locked, not crashing, when Hive is not up', () {
      final unlocked = Achievements.unlockedIds(progress());
      expect(unlocked.contains('hunt_first_find'), isFalse);
      expect(unlocked.contains('hunt_daily_streak'), isFalse);
    });

    test('their titles come from the shared milestone ladder', () {
      // One source of truth: the "N more to unlock X" nudge on My Finds reads
      // the same list, so the two can never disagree about the badge name.
      expect(Achievements.huntFirstFind.title, huntFindMilestones[0].title);
      expect(Achievements.huntSpotter.title, huntFindMilestones[1].title);
      expect(Achievements.huntCollector.title, huntFindMilestones[2].title);
    });
  });

  group('nextHuntMilestone', () {
    test('points at the next rung up', () {
      expect(nextHuntMilestone(0)!.finds, huntFindMilestones[0].finds);
      expect(nextHuntMilestone(1)!.finds, huntFindMilestones[1].finds);
      expect(nextHuntMilestone(9)!.finds, huntFindMilestones[1].finds);
      expect(nextHuntMilestone(10)!.finds, huntFindMilestones[2].finds);
    });

    test('is null once the ladder is topped out', () {
      expect(nextHuntMilestone(huntFindMilestones.last.finds), isNull);
      expect(nextHuntMilestone(999), isNull);
    });

    test('the ladder ascends', () {
      final finds = huntFindMilestones.map((m) => m.finds).toList();
      expect(finds, orderedEquals([...finds]..sort()));
      expect(finds.toSet(), hasLength(finds.length));
    });
  });
}
