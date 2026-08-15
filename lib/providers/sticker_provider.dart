import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/hive_service.dart';
import '../data/models/models.dart';
import '../data/models/enums.dart';
import '../features/stickers/models/sticker_models.dart';
import 'app_providers.dart';

/// Checks unlock conditions for stickers against user progress.
class StickerUnlockChecker {
  StickerUnlockChecker._();

  static bool isUnlocked(
    String conditionId,
    LearningProgress progress, {
    int completedPaths = 0,
    int dailyChallenges = 0,
    int ownedStickers = 0,
  }) {
    return switch (conditionId) {
      // Word milestones
      'words_5' => progress.wordsLearned >= 5,
      'words_10' => progress.wordsLearned >= 10,
      'words_25' => progress.wordsLearned >= 25,
      'words_50' => progress.wordsLearned >= 50,
      'words_100' => progress.wordsLearned >= 100,
      // Star milestones
      'stars_10' => progress.totalStars >= 10,
      'stars_50' => progress.totalStars >= 50,
      'stars_100' => progress.totalStars >= 100,
      'stars_500' => progress.totalStars >= 500,
      // Game milestones. Lifetime counts — `recentScores` is trimmed to the
      // last 20, and is empty on a profile restored from the cloud before any
      // game is played on this device, which would strip an earned sticker.
      'games_1' => progress.effectiveGamesPlayed >= 1,
      'games_10' => progress.effectiveGamesPlayed >= 10,
      'perfect_score' => progress.recentScores.any(
        (s) => s.score == s.total && s.total > 0,
      ),
      'perfect_5' =>
        progress.recentScores
                .where((s) => s.score == s.total && s.total > 0)
                .length >=
            5,
      // Story milestones — check if any story quiz was played
      'stories_1' => progress.recentScores.any(
        (s) => s.gameType == GameType.storyQuiz,
      ),
      // Learning path
      'path_complete_1' => completedPaths >= 1,
      // Category accuracy >= 0.8. Deliberately still keyed off
      // `categoryProgress` (a rolling accuracy average) rather than the true
      // coverage measure the certificates and exports moved to: these are
      // rewards a learner already holds, and re-scoring them against a stricter
      // rule would silently take stickers back off the shelf. Measurement
      // surfaces owe accuracy; the sticker book owes durability.
      'categories_3' =>
        progress.categoryProgress.values.where((v) => v >= 0.8).length >= 3,
      'categories_12' =>
        progress.categoryProgress.values.where((v) => v >= 0.8).length >= 12,
      // Streak milestones
      'streak_3' => progress.streakDays >= 3,
      'streak_7' => progress.streakDays >= 7,
      'streak_14' => progress.streakDays >= 14,
      'streak_30' => progress.streakDays >= 30,
      // Daily challenge milestones
      'daily_5' => dailyChallenges >= 5,
      'daily_20' => dailyChallenges >= 20,
      // Meta: collecting stickers
      'stickers_20' => ownedStickers >= 20,
      _ => false,
    };
  }
}

class StickerNotifier extends StateNotifier<Set<String>> {
  final String profileId;

  StickerNotifier(this.profileId) : super({}) {
    _load();
  }

  void _load() {
    state = HiveService.getOwnedStickers(profileId);
  }

  /// Check all stickers for newly unlocked ones.
  /// Returns the list of stickers that were *just* unlocked this call.
  List<Sticker> checkNewStickers(
    LearningProgress progress, {
    int completedPaths = 0,
    int dailyChallenges = 0,
  }) {
    final newlyUnlocked = <Sticker>[];
    for (final sticker in StickerData.allStickers) {
      if (state.contains(sticker.id)) continue;
      final unlocked = StickerUnlockChecker.isUnlocked(
        sticker.unlockConditionId,
        progress,
        completedPaths: completedPaths,
        dailyChallenges: dailyChallenges,
        ownedStickers: state.length,
      );
      if (unlocked) {
        newlyUnlocked.add(sticker);
      }
    }
    if (newlyUnlocked.isNotEmpty) {
      final updated = Set<String>.from(state);
      for (final s in newlyUnlocked) {
        updated.add(s.id);
      }
      state = updated;
      HiveService.saveOwnedStickers(profileId, state);
    }
    return newlyUnlocked;
  }

  /// Check if a specific sticker is owned.
  bool isOwned(String stickerId) => state.contains(stickerId);

  /// Total owned stickers count.
  int get ownedCount => state.length;

  /// Total stickers available.
  int get totalCount => StickerData.allStickers.length;
}

final stickerProvider = StateNotifierProvider<StickerNotifier, Set<String>>((
  ref,
) {
  final profile = ref.watch(profileProvider);
  return StickerNotifier(profile?.id ?? '');
});
