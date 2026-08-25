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

/// A learner's sticker shelf: what they own, when they earned it, and how
/// much of it they have actually been shown.
///
/// The state used to be a bare `Set<String>`, which could answer "do I own
/// this?" and nothing else — so a sticker earned mid-game appeared silently
/// the next time the album happened to be opened, with no way for the app to
/// know it had never been celebrated.
class StickerCollection {
  /// Every sticker id the learner has earned.
  final Set<String> owned;

  /// When each was earned. Stickers earned before unlock dates were recorded
  /// are absent here; see [unseen].
  final Map<String, DateTime> unlockedAt;

  /// The last time the album was opened.
  final DateTime? lastSeenAt;

  const StickerCollection({
    this.owned = const {},
    this.unlockedAt = const {},
    this.lastSeenAt,
  });

  bool contains(String id) => owned.contains(id);

  int get ownedCount => owned.length;

  int get totalCount => StickerData.allStickers.length;

  /// Earned but never shown to the learner.
  ///
  /// A sticker with no recorded date was earned by an older build; it counts
  /// as seen. Announcing a year-old sticker as "New!" would be worse than
  /// staying quiet, and the alternative — dropping it — would take away
  /// something already earned.
  Set<String> get unseen {
    final seenAt = lastSeenAt;
    return owned.where((id) {
      final at = unlockedAt[id];
      if (at == null) return false;
      return seenAt == null || at.isAfter(seenAt);
    }).toSet();
  }

  bool isUnseen(String id) => unseen.contains(id);

  int get unseenCount => unseen.length;

  StickerCollection copyWith({
    Set<String>? owned,
    Map<String, DateTime>? unlockedAt,
    DateTime? lastSeenAt,
  }) {
    return StickerCollection(
      owned: owned ?? this.owned,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class StickerNotifier extends StateNotifier<StickerCollection> {
  final String profileId;

  StickerNotifier(this.profileId) : super(const StickerCollection()) {
    _load();
  }

  void _load() {
    // Same reasoning as MoodNotifier: the unseen-sticker badge is read from
    // the home screens, and a decorative count must never be able to break
    // one. An empty shelf is the degraded state — nothing on disk is touched,
    // so the real collection comes back on the next successful load.
    try {
      state = StickerCollection(
        owned: HiveService.getOwnedStickers(profileId),
        unlockedAt: HiveService.getStickerUnlockDates(profileId),
        lastSeenAt: HiveService.getStickersSeenAt(profileId),
      );
    } catch (_) {
      state = const StickerCollection();
    }
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
        ownedStickers: state.ownedCount,
      );
      if (unlocked) {
        newlyUnlocked.add(sticker);
      }
    }
    if (newlyUnlocked.isNotEmpty) {
      final now = DateTime.now();
      final owned = Set<String>.from(state.owned);
      final dates = Map<String, DateTime>.from(state.unlockedAt);
      for (final s in newlyUnlocked) {
        owned.add(s.id);
        dates[s.id] = now;
      }
      state = state.copyWith(owned: owned, unlockedAt: dates);
      // Best-effort persistence. A failed write is self-healing: the unlock
      // conditions are pure functions of progress, which never goes
      // backwards, so the next sweep re-awards exactly the same stickers.
      try {
        HiveService.saveOwnedStickers(profileId, owned);
        HiveService.saveStickerUnlockDates(profileId, dates);
      } catch (_) {
        // Kept in memory for this session; re-derived next launch.
      }
    }
    return newlyUnlocked;
  }

  /// Mark everything currently earned as shown to the learner.
  ///
  /// Called once the album has actually rendered the new stickers and their
  /// celebration has been dismissed — not merely on navigation, or a learner
  /// who bounced off the screen would lose the announcement.
  Future<void> markAllSeen() async {
    final now = DateTime.now();
    state = state.copyWith(lastSeenAt: now);
    await HiveService.setStickersSeenAt(profileId, now);
  }

  /// Check if a specific sticker is owned.
  bool isOwned(String stickerId) => state.contains(stickerId);

  /// Total owned stickers count.
  int get ownedCount => state.ownedCount;

  /// Total stickers available.
  int get totalCount => state.totalCount;
}

final stickerProvider =
    StateNotifierProvider<StickerNotifier, StickerCollection>((ref) {
  final profile = ref.watch(profileProvider);
  return StickerNotifier(profile?.id ?? '');
});

/// How many earned stickers the learner has not been shown yet.
///
/// Drives the badge on the home tile: the whole point of a reward is that you
/// find out you got it, and before this the album was the only place that
/// even knew.
final unseenStickerCountProvider = Provider<int>((ref) {
  return ref.watch(stickerProvider).unseenCount;
});
