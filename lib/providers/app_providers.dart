import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'classroom_management_provider.dart';
import 'firestore_stream_helpers.dart';
import 'home_group_provider.dart';
import '../data/models/achievements.dart';
import '../data/models/models.dart';
import '../data/models/enums.dart';
import '../data/models/learning_path.dart';
import '../data/models/shop_data.dart';
import '../data/repository.dart';
import '../data/local/local_repository.dart';
import '../data/local/hive_service.dart';
import '../data/local/seed_data.dart';
import '../data/remote/firestore_repository.dart';
import '../core/services/firebase_service.dart';
import '../core/services/fsl_assets_service.dart';
import '../core/services/recovery_code_service.dart';
import '../core/services/profile_sync_listener.dart';
import '../core/services/progress_sync_listener.dart';
import '../core/services/session_tracker.dart';
import '../core/services/streak_service.dart';
import '../core/services/adaptive_difficulty_service.dart';
import '../core/services/sync_queue/sync_queue_models.dart';
import '../core/services/sync_queue/sync_queue_service.dart';
import '../core/services/sync_queue/sync_queue_storage.dart';
import '../core/utils/error_handler.dart';
import '../features/goals/models/goal_model.dart';
import '../features/goals/services/goal_service.dart';
import '../features/experiment/models/experiment_models.dart';
import '../features/experiment/services/experiment_service.dart';

// ─── Bottom Navigation Visibility ──────────────────────
/// Controls whether the bottom navigation bar is visible.
/// Automatically managed by BottomNavShell based on the current route,
/// but can also be toggled manually from any screen.
final bottomNavVisibleProvider = StateProvider<bool>((ref) => true);

// ─── Repository Provider ───────────────────────────────
/// Swap this with a FirestoreRepository to enable cloud sync.
final repositoryProvider = Provider<DataRepository>((ref) {
  return const LocalRepository();
});

// ─── FSL Asset Availability ────────────────────────────
/// Reports which FSL videos are bundled with this build, so the games and
/// the FSL category picker can hide content that isn't ready yet.
/// Memoised — the asset manifest is parsed once per app launch.
final fslAvailabilityProvider = FutureProvider<FslAvailability>((ref) {
  return FslAssetsService.load();
});

// ─── Settings / Accessibility Provider ─────────────────

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Settings are per-profile: watch the active profile's id so switching
    // profiles loads that profile's own accessibility settings. A learner's
    // auto-applied class preset is saved under their id and never affects the
    // teacher / parent (or any other) profile on a shared device.
    final profileId = ref.watch(profileProvider.select((p) => p?.id));
    return HiveService.getSettings(profileId: profileId);
  }

  /// Persist the current state under the active profile's id. Read fresh each
  /// time (rather than caching) so a save that lands right after a profile
  /// switch always targets the correct profile.
  void _save() {
    final profileId = ref.read(profileProvider)?.id;
    HiveService.saveSettings(state, profileId: profileId);
  }

  void updateFontScale(double scale) {
    state = state.copyWith(fontScale: scale);
    _save();
  }

  void toggleHighContrast() {
    state = state.copyWith(highContrastMode: !state.highContrastMode);
    _save();
  }

  void toggleTts() {
    state = state.copyWith(ttsEnabled: !state.ttsEnabled);
    _save();
  }

  void updateTtsSpeed(double speed) {
    state = state.copyWith(ttsSpeed: speed);
    _save();
  }

  void toggleReducedMotion() {
    state = state.copyWith(reducedMotion: !state.reducedMotion);
    _save();
  }

  void toggleSlowMotion() {
    state = state.copyWith(slowMotionEnabled: !state.slowMotionEnabled);
    _save();
  }

  void toggleLearningAssist() {
    state = state.copyWith(learningAssistEnabled: !state.learningAssistEnabled);
    _save();
  }

  /// Sets the Daily Mission size, clamped to the supported 3–5 range.
  void setDailyMissionSize(int size) {
    state = state.copyWith(dailyMissionSize: size.clamp(3, 5));
    _save();
  }

  void toggleSoundEffects() {
    state = state.copyWith(soundEffects: !state.soundEffects);
    _save();
  }

  void toggleSpeechToText() {
    state = state.copyWith(speechToText: !state.speechToText);
    _save();
  }

  void toggleAiCompanion() {
    state = state.copyWith(aiCompanionEnabled: !state.aiCompanionEnabled);
    _save();
  }

  void updateLocale(String locale) {
    state = state.copyWith(locale: locale);
    _save();
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
    _save();
  }

  void updateReminderTime(int hour, int minute) {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    _save();
  }

  void update(AppSettings newSettings) {
    state = newSettings;
    _save();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ─── Active Profile Provider ───────────────────────────

class ProfileNotifier extends Notifier<UserProfile?> {
  /// Stored educator profile so we can restore it after viewing a student.
  UserProfile? _savedEducatorProfile;

  @override
  UserProfile? build() {
    // Re-emit the active profile when its remote `profiles/{id}.name`
    // is hydrated by the [ProfileSyncListener]. Keeps an educator's
    // rename visible on the learner's device without a relaunch.
    ref.listen(profileRemoteChangesProvider, (_, next) {
      final updatedId = next.value;
      if (updatedId == null) return;
      final current = state;
      if (current == null || current.id != updatedId) return;
      final fresh = HiveService.getProfileById(updatedId);
      if (fresh != null) state = fresh;
    });
    return _loadActiveProfile();
  }

  UserProfile? _loadActiveProfile() {
    final activeId = HiveService.getActiveProfileId();
    if (activeId == null) return null;
    try {
      return HiveService.getProfileById(activeId);
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'ProfileNotifier');
      return null;
    }
  }

  Future<void> setProfile(UserProfile profile) async {
    // Route through LocalRepository so the profile reaches Firestore
    // with `owner_uid` stamped. Going through HiveService directly only
    // wrote locally — which broke any cloud action that depends on the
    // profile existing server-side (e.g. createClassroom's rule check).
    await const LocalRepository().saveProfile(profile);
    await HiveService.setActiveProfileId(profile.id);
    // Re-read from Hive so we pick up the auto-stamped ownerUid that
    // LocalRepository.saveProfile wrote on our behalf.
    state = HiveService.getProfileById(profile.id) ?? profile;
    // Subscribe the freshly-saved profile to the remote-name listener
    // so a teacher / parent rename pushes here without a relaunch.
    ref.read(profileSyncListenerProvider)?.watch(profile.id);
  }

  /// Temporarily switch to a student profile while preserving the
  /// educator's identity. Call [restoreEducatorProfile] to switch back.
  Future<void> viewAsStudent(UserProfile studentProfile) async {
    final current = state;
    if (current != null &&
        (current.role == UserRole.teacher || current.role == UserRole.parent)) {
      _savedEducatorProfile = current;
    }
    await setProfile(studentProfile);
  }

  /// Restore the previously saved educator profile, if any.
  ///
  /// Keeps [isViewingAsStudent] true until the profile is fully restored
  /// so that safety-net checks in the router still work during the async gap.
  Future<void> restoreEducatorProfile() async {
    final saved = _savedEducatorProfile;
    if (saved != null) {
      await setProfile(saved);
      _savedEducatorProfile = null;
    }
  }

  /// Whether we are currently viewing as a student on behalf of an educator.
  bool get isViewingAsStudent => _savedEducatorProfile != null;

  /// The saved educator profile (if viewing as student), or null.
  UserProfile? get savedEducatorProfile => _savedEducatorProfile;

  void clearProfile() {
    _savedEducatorProfile = null;
    state = null;
  }

  /// Handle the learner being removed from a classroom or home group by
  /// the educator. Clears the linkage on the local profile, signs the
  /// device out of this active profile, and lets the [MembershipEvictionGate]
  /// route to the eviction-notice screen.
  ///
  /// Idempotent — safe to call once, twice, or while there is no
  /// active profile (no-op).
  Future<void> handleEviction({required bool wasClassroom}) async {
    final p = state;
    if (p == null) return;
    final cleared = wasClassroom
        ? p.copyWith(classroomId: () => null)
        : p.copyWith(homeGroupId: () => null);
    await HiveService.saveProfile(cleared);
    await HiveService.clearActiveProfileId();
    state = null;
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

// ─── Flashcard Data Provider ───────────────────────────

final allFlashcardsProvider = Provider<List<Flashcard>>((ref) {
  final seed = SeedData.allFlashcards;
  final custom = HiveService.getCustomCards();
  return [...seed, ...custom];
});

final flashcardsByCategoryProvider =
    Provider.family<List<Flashcard>, FlashcardCategory>((ref, category) {
      final all = ref.watch(allFlashcardsProvider);
      return all.where((f) => f.category == category).toList();
    });

final decksProvider = Provider<List<FlashcardDeck>>((ref) {
  return SeedData.defaultDecks;
});

// ─── Progress Provider ─────────────────────────────────

class ProgressNotifier extends Notifier<LearningProgress> {
  late String profileId;

  @override
  LearningProgress build() {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      profileId = '';
      return LearningProgress(profileId: '', lastActivityDate: DateTime.now());
    }
    profileId = profile.id;

    // Bidirectional sync: when the listener pulls fresh progress from
    // Firestore for *this* profile, re-read Hive so dependent widgets
    // rebuild. Local writes still flow out via HiveService below; we
    // only react here to confirmed-remote updates.
    ref.listen(progressRemoteChangesProvider, (_, next) {
      if (next.value == profileId) {
        state = HiveService.getProgress(profileId);
      }
    });

    return HiveService.getProgress(profileId);
  }

  /// Re-reads the distinct-signs set from storage.
  ///
  /// `HiveService.recordFslVideoView` is a static call made from six different
  /// surfaces and does not go through this notifier, so nothing here knows a
  /// sign was watched. Without this the Signs stat on the progress screen and
  /// the sign achievements sit one view behind until something unrelated
  /// happens to rebuild progress.
  ///
  /// Deliberately not followed by `saveProgress`: `signedWordKeys` lives in its
  /// own Hive key precisely so those six writers don't have to round-trip a
  /// whole progress row, and writing it back here could clobber a view recorded
  /// elsewhere. See [LearningProgress.signedWordKeys].
  void refreshSignsWatched() {
    if (profileId.isEmpty) return;
    final signs = HiveService.fslWordsViewed(profileId);
    if (signs.length == state.signedWordKeys.length) return;
    state = state.copyWith(signedWordKeys: signs);
  }

  /// Re-reads the self-claimed and educator-confirmed sign sets from storage.
  ///
  /// Same reason as [refreshSignsWatched]: mastery is written through static
  /// `HiveService` calls (Sign It, the dictionary sheet, the educator's Sign
  /// Check screen), none of which go through this notifier, so nothing here
  /// would otherwise know a claim or a confirmation had changed — and the
  /// confirmed set feeds XP and two achievements.
  void refreshSignMastery() {
    if (profileId.isEmpty) return;
    final claimed = HiveService.fslCanSignKeys(profileId);
    final confirmed = HiveService.fslEverConfirmedKeys(profileId);
    if (claimed.length == state.canSignKeys.length &&
        confirmed.length == state.everConfirmedSignKeys.length) {
      return;
    }
    state = state.copyWith(
      canSignKeys: claimed,
      everConfirmedSignKeys: confirmed,
    );
  }

  void addWordsLearned(int count) {
    state = state.copyWith(wordsLearned: state.wordsLearned + count);
    HiveService.saveProgress(state);
  }

  /// Records flashcards answered correctly *outside* a game — currently the AI
  /// Tutor's quizzes and lessons.
  ///
  /// Mirrors how [recordGameResult] tracks vocabulary: dedupes against
  /// [LearningProgress.learnedWordIds] and derives `wordsLearned` from the set
  /// size, so a word can never be double-counted. Without this the tutor could
  /// award stars for a correct answer while the learner's Words total stayed
  /// at zero. No-op when every id is already known.
  void recordWordsLearned(Iterable<String> wordIds) {
    if (wordIds.isEmpty) return;
    final updated = Set<String>.from(state.learnedWordIds)..addAll(wordIds);
    if (updated.length == state.learnedWordIds.length) return;
    state = state.copyWith(
      learnedWordIds: updated,
      wordsLearned: updated.length,
    );
    _persistProgress();
  }

  void addStars(int stars) {
    state = state.copyWith(totalStars: state.totalStars + stars);
    HiveService.saveProgress(state);
  }

  void updateCategoryProgress(String category, double progress) {
    final updated = Map<String, double>.from(state.categoryProgress);
    updated[category] = progress.clamp(0.0, 1.0);
    state = state.copyWith(categoryProgress: updated);
    HiveService.saveProgress(state);
  }

  /// Records that the learner did *some* learning activity today (finished a
  /// game, completed the daily challenge, reviewed flashcards, …). Advances
  /// the streak using calendar-day math via [StreakService] and always bumps
  /// [lastActivityDate] so "active today" stays accurate.
  ///
  /// Streak math is gated by the experiment config: control groups with
  /// streaks disabled keep [streakDays] at 0. Re-opening the app or doing
  /// multiple activities the same day never decrements or double-counts.
  /// A redundant cloud write is skipped when nothing changed the same day.
  void recordDailyActivity() {
    final streaksEnabled = ExperimentService.getConfig(
      profileId,
    ).isFeatureEnabled(GamificationFeature.streaks);
    final now = DateTime.now();
    final newStreak = streaksEnabled
        ? StreakService.nextStreak(
            prevStreak: state.streakDays,
            lastActivity: state.lastActivityDate,
            now: now,
          )
        : state.streakDays;

    final alreadyToday = StreakService.isActiveToday(
      state.lastActivityDate,
      now: now,
    );
    final streakUnchanged = newStreak == state.streakDays;

    state = state.copyWith(
      streakDays: newStreak,
      // High-water mark: the current streak resets on a missed day, this does
      // not, so XP (and the level it drives) survives the gap.
      bestStreakDays: math.max(state.effectiveBestStreak, newStreak),
      lastActivityDate: now,
    );

    // If we already checked in today and the streak didn't move, only the
    // timestamp changed — persist locally but skip the cloud write to save
    // free-tier Firestore quota.
    if (alreadyToday && streakUnchanged) {
      HiveService.saveProgress(state);
    } else {
      _persistProgress();
    }
  }

  /// Backwards-compatible alias. Prefer [recordDailyActivity].
  void updateStreak() => recordDailyActivity();

  /// Call this after any game finishes to persist score, stars, streak, and
  /// category progress all at once.
  ///
  /// Respects experiment mode: if the student is in a control group with
  /// stars or streaks disabled, those values are zeroed out before saving.
  void recordGameResult({
    required GameType gameType,
    required int score,
    required int total,
    required int starsEarned,
    List<FlashcardCategory> categoriesPlayed = const [],
    int? durationSeconds,

    /// Word IDs correctly answered in this session (for unique tracking)
    Set<String> correctWordIds = const {},

    /// The difficulty the game was played at (for adaptive tracking).
    GameDifficulty? playedDifficulty,
  }) {
    // ─── Experiment gating ────────────────────────────
    final experimentConfig = ExperimentService.getConfig(profileId);
    final effectiveStars =
        experimentConfig.isFeatureEnabled(GamificationFeature.stars)
        ? starsEarned
        : 0;
    final newScore = GameScore(
      gameType: gameType,
      score: score,
      total: total,
      starsEarned: effectiveStars,
      date: DateTime.now(),
      durationSeconds: durationSeconds,
    );

    // Keep only last 20 scores
    final scores = [...state.recentScores, newScore];
    if (scores.length > 20) scores.removeRange(0, scores.length - 20);

    // Update category progress based on game performance
    final updated = Map<String, double>.from(state.categoryProgress);
    for (final cat in categoriesPlayed) {
      final key = cat.label;
      final current = updated[key] ?? 0.0;
      // Blend old progress with new (weighted average)
      final gameProgress = score / total;
      updated[key] = ((current * 0.7) + (gameProgress * 0.3)).clamp(0.0, 1.0);
    }

    // Update streak (gated by experiment config). Calendar-day math lives in
    // StreakService so this path stays consistent with recordDailyActivity().
    final streaksEnabled = experimentConfig.isFeatureEnabled(
      GamificationFeature.streaks,
    );
    final now = DateTime.now();
    final newStreak = streaksEnabled
        ? StreakService.nextStreak(
            prevStreak: state.streakDays,
            lastActivity: state.lastActivityDate,
            now: now,
          )
        : state.streakDays;

    // Track unique learned words
    final newLearnedIds = Set<String>.from(state.learnedWordIds)
      ..addAll(correctWordIds);
    final newWords = newLearnedIds.length - state.learnedWordIds.length;

    // Day ledger: the only record that can answer "what did I do this week?"
    // once `recentScores` has trimmed the week away.
    HiveService.addDailyActivity(
      profileId,
      games: 1,
      stars: effectiveStars,
      words: newWords,
      on: now,
    );

    state = state.copyWith(
      totalStars: state.totalStars + effectiveStars,
      wordsLearned: newLearnedIds.length,
      learnedWordIds: newLearnedIds,
      recentScores: scores,
      // Lifetime total, unlike `scores` which is trimmed to the last 20 above.
      gamesPlayed: state.effectiveGamesPlayed + 1,
      // Lifetime roster of games tried, for the same reason.
      playedGameTypes: {...state.effectivePlayedGameTypes, gameType},
      categoryProgress: updated,
      streakDays: newStreak,
      bestStreakDays: math.max(state.effectiveBestStreak, newStreak),
      lastActivityDate: now,
    );
    HiveService.saveProgress(state);

    // Cloud sync: only for classroom-linked students. Player Mode and
    // unlinked students stay 100% local.
    final activeProfile = ref.read(profileProvider);
    if (activeProfile != null &&
        !activeProfile.isGuestPlayer &&
        activeProfile.classroomId != null) {
      // Fire-and-forget — the LocalRepository enqueues for offline-first
      // replay if Firebase is configured.
      ref.read(repositoryProvider).saveProgress(state);
    }

    // Feed the adaptive difficulty engine so it can auto-adjust.
    if (playedDifficulty != null && total > 0) {
      AdaptiveDifficultyService.recordGameResult(
        profileId: profileId,
        gameType: gameType,
        category: categoriesPlayed.isNotEmpty ? categoriesPlayed.first : null,
        score: score,
        total: total,
        playedDifficulty: playedDifficulty,
        durationSeconds: durationSeconds,
      );
    }
  }

  /// Persists [state] to Hive and, for classroom-linked students, to cloud.
  /// Mirrors the offline-first sync rule used by [recordGameResult].
  void _persistProgress() {
    HiveService.saveProgress(state);
    final activeProfile = ref.read(profileProvider);
    if (activeProfile != null &&
        !activeProfile.isGuestPlayer &&
        activeProfile.classroomId != null) {
      ref.read(repositoryProvider).saveProgress(state);
    }
  }

  /// Marks a story as finished reading (learner reached the last sentence).
  /// Drives the "Read ✓" badge on story cards. No-op if already recorded.
  void recordStoryRead(String storyId) {
    // Reading a story is a learning activity — keep the streak alive even on
    // a re-read (which is otherwise a no-op below).
    recordDailyActivity();
    if (state.completedStoryIds.contains(storyId)) return;
    state = state.copyWith(
      completedStoryIds: {...state.completedStoryIds, storyId},
    );
    _persistProgress();
  }

  /// Records the best (highest) star score earned on a story's quiz.
  /// Drives the ★ badge on story cards. No-op if [stars] doesn't improve it.
  void recordStoryQuizStars(String storyId, int stars) {
    final prev = state.storyBestStars[storyId] ?? 0;
    if (stars <= prev) return;
    state = state.copyWith(
      storyBestStars: {...state.storyBestStars, storyId: stars},
    );
    _persistProgress();
  }

  /// Checks progress against all achievements, persists newly unlocked
  /// ones, and returns the list of achievements that were just earned.
  ///
  /// Returns an empty list if achievements are disabled by experiment config.
  List<Achievement> checkAchievements() {
    final config = ExperimentService.getConfig(profileId);
    if (!config.isFeatureEnabled(GamificationFeature.achievements)) {
      return [];
    }

    final previousIds = HiveService.getUnlockedAchievements(profileId);
    final newlyUnlocked = Achievements.findNewlyUnlocked(
      progress: state,
      previouslyUnlockedIds: previousIds,
    );

    // Union, never replace. This used to write `Achievements.unlockedIds` —
    // the *currently* true set — which meant any badge the live check no
    // longer reported was deleted from Hive the next time some other badge
    // unlocked, and then pushed to Firestore as the new truth. A learner could
    // lose four streak badges by being ill for a weekend.
    final durable = Achievements.durableUnlockedIds(
      progress: state,
      previouslyUnlockedIds: previousIds,
    );
    // Also writes when nothing is *newly* unlocked but the stored set is stale
    // — a legacy row that never had the badge recorded, or one holding the id
    // of an achievement since retired.
    if (!setEquals(durable, previousIds)) {
      HiveService.saveUnlockedAchievements(profileId, durable);
    }

    return newlyUnlocked;
  }

  /// Spend stars on a shop item. Returns true if successful.
  bool spendStars(int amount) {
    if (state.starBalance < amount) return false;
    state = state.copyWith(spentStars: state.spentStars + amount);
    HiveService.saveProgress(state);
    return true;
  }

  /// Purchase a shop item by ID and cost. Returns true if successful.
  bool purchaseItem(String itemId, int cost) {
    final purchased = HiveService.getPurchasedItems(profileId);
    if (purchased.contains(itemId)) return false; // already owned
    if (!spendStars(cost)) return false;
    purchased.add(itemId);
    HiveService.savePurchasedItems(profileId, purchased);
    return true;
  }

  /// Check if a shop item is owned.
  bool hasPurchased(String itemId) {
    return HiveService.getPurchasedItems(profileId).contains(itemId);
  }

  /// Get all purchased item IDs.
  Set<String> get purchasedItems => HiveService.getPurchasedItems(profileId);

  // ─── Equipped Items ──────────────────────────────────

  /// Equip a purchased shop item. The item must be owned.
  bool equipItem(String itemId, ShopItemType type) {
    if (!hasPurchased(itemId)) return false;
    final typeKey = type.name; // 'avatar', 'theme', or 'border'
    HiveService.saveEquippedItem(profileId, typeKey, itemId);
    // Trigger a state rebuild so listeners update
    state = state.copyWith();
    _syncEquippedLook();
    return true;
  }

  /// Unequip the item of a given type.
  void unequipItem(ShopItemType type) {
    final typeKey = type.name;
    HiveService.saveEquippedItem(profileId, typeKey, null);
    state = state.copyWith();
    _syncEquippedLook();
  }

  /// Pushes the profile so a newly equipped look reaches other devices, and
  /// therefore the leaderboard a classmate is looking at.
  ///
  /// Fire-and-forget and failure-tolerant on purpose: equipping is a local,
  /// instant action that must not wait on the network or break when it is
  /// absent. [FirestoreRepository.saveProfile] re-reads the equipped rows from
  /// Hive as it writes, so whatever is current at push time is what travels —
  /// which also means an equip made offline is carried by the next ordinary
  /// profile sync rather than being lost.
  void _syncEquippedLook() {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.isGuestPlayer) return;
    unawaited(() async {
      try {
        await const LocalRepository().saveProfile(profile);
      } catch (e, stack) {
        ErrorHandler.report(e, stack, 'syncEquippedLook:silent');
      }
    }());
  }

  /// Get the equipped item ID for a given type, or null if none.
  String? getEquippedItemId(ShopItemType type) {
    return HiveService.getEquippedItem(profileId, type.name);
  }

  /// Get the equipped ShopItem for a given type, or null if none.
  ShopItem? getEquippedShopItem(ShopItemType type) {
    final itemId = getEquippedItemId(type);
    if (itemId == null) return null;
    return ShopData.findById(itemId);
  }

  /// Gives back the stars spent on items that have since been withdrawn from
  /// sale, and returns the total refunded (0 when there was nothing to undo).
  ///
  /// Withdrawing an item the learner already paid for would otherwise just
  /// delete something they earned. This makes the correction whole: the item
  /// leaves their inventory, is unequipped if it was equipped, and the stars
  /// go back on the balance to spend on something that works.
  ///
  /// Safe to call on every shop visit — it is a no-op once nothing withdrawn
  /// is owned, and it never touches [LearningProgress.totalStars], so a refund
  /// cannot inflate lifetime earnings or XP (see [XpLevelService]).
  int refundWithdrawnPurchases() {
    final purchased = HiveService.getPurchasedItems(profileId);
    final toRefund = purchased.intersection(ShopData.withdrawnIds);
    if (toRefund.isEmpty) return 0;

    var refunded = 0;
    for (final id in toRefund) {
      final item = ShopData.findById(id);
      if (item == null) continue;
      refunded += item.cost;
      purchased.remove(id);
      // Drop the equip too, or the profile keeps pointing at something it no
      // longer owns.
      if (getEquippedItemId(item.type) == id) {
        HiveService.saveEquippedItem(profileId, item.type.name, null);
      }
    }
    if (refunded == 0) return 0;

    HiveService.savePurchasedItems(profileId, purchased);
    // Refund by un-spending, never by granting: spentStars is the only half of
    // the balance that may move backwards.
    state = state.copyWith(
      spentStars: (state.spentStars - refunded).clamp(0, state.spentStars),
    );
    HiveService.saveProgress(state);
    return refunded;
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, LearningProgress>(
  ProgressNotifier.new,
);

/// Every badge the active learner holds — stored union live.
///
/// The single answer for "which badges does this learner have?". The Progress
/// tab used to compute the live set itself while the Player Profile, the
/// student detail sheet, the showcase and the printed reports all read the
/// stored set, so the same learner could be shown two different badge walls on
/// two screens. See [Achievements.durableUnlockedIds].
final unlockedAchievementsProvider = Provider<Set<String>>((ref) {
  final progress = ref.watch(progressProvider);
  return Achievements.durableUnlockedIds(
    progress: progress,
    previouslyUnlockedIds: HiveService.getUnlockedAchievements(
      progress.profileId,
    ),
  );
});

// ─── All Profiles Provider (for multi-student dashboard) ────

final allProfilesWithProgressProvider =
    Provider<List<(UserProfile, LearningProgress)>>((ref) {
      // Re-evaluate when profiles or progress change so educator views stay fresh
      ref.watch(profileProvider);
      ref.watch(progressProvider);
      return HiveService.getAllProfilesWithProgress();
    });

// ─── Educator Roster Provider (Firestore-backed) ───────
//
// Aggregates every child linked to [educatorProfileId] — through both
// classroom enrollments (teacher-side) and home-group memberships
// (parent-side). Used by the educator-side Students / Analytics /
// Reports screens and the Parent Dashboard, which run on devices that
// don't have those children in their local Hive.
//
// Falls back to local Hive when Firebase isn't configured so single-device
// demos still render something.
//
// The parameter is named `educatorProfileId` because it now feeds both
// teachers and parents; the legacy `teacherId` callsites still work since
// the binding is positional.
final educatorRosterProvider =
    FutureProvider.family<List<(UserProfile, LearningProgress)>, String>((
      ref,
      educatorProfileId,
    ) async {
      if (!FirebaseService.isConfigured) {
        // Offline branch: union classroom + home-group children from local Hive.
        // We also keep the previous "all student profiles" fallback so a single-
        // device demo (no rosters set up) still shows something.
        final homeGroupChildIds =
            HiveService.getHomeGroupsByOwner(educatorProfileId)
                .expand((g) => HiveService.getHomeGroupMembers(g.id))
                .map((m) => m.profileId)
                .toSet();
        return ref
            .watch(allProfilesWithProgressProvider)
            .where(
              (p) =>
                  (p.$1.role == UserRole.student ||
                          p.$1.role == UserRole.child) &&
                      !p.$1.isGuestPlayer ||
                  homeGroupChildIds.contains(p.$1.id),
            )
            .toList();
      }
      // Re-run reactively when the classroom / home-group list or any member
      // roster changes. Mirrors the wiring on `teacherDashboardSnapshotProvider`.
      final classroomsAsync = ref.watch(
        classroomsByTeacherStreamProvider(educatorProfileId),
      );
      final homeGroupsAsync = ref.watch(
        homeGroupsByOwnerStreamProvider(educatorProfileId),
      );
      final classrooms = classroomsAsync.valueOrNull ?? const [];
      final homeGroups = homeGroupsAsync.valueOrNull ?? const [];
      for (final c in classrooms) {
        ref.watch(classroomMembersProvider(c.id));
      }
      for (final g in homeGroups) {
        ref.watch(homeGroupMembersProvider(g.id));
      }

      const remote = FirestoreRepository();
      final aggregated = <(UserProfile, LearningProgress)>[];
      final seen = <String>{};

      // Classroom-side roster (teachers)
      for (final c in classrooms) {
        final pairs = await remote.getStudentsWithProgressByClassroom(c.id);
        for (final pair in pairs) {
          // De-dup in case a child is listed under two classrooms.
          if (seen.add(pair.$1.id)) {
            aggregated.add(pair);
          }
        }
      }

      // Home-group-side roster (parents) — same de-dup set so a child who
      // appears in BOTH a classroom and a home group is counted once.
      for (final g in homeGroups) {
        final pairs = await remote.getChildrenWithProgressByHomeGroup(g.id);
        for (final pair in pairs) {
          if (seen.add(pair.$1.id)) {
            aggregated.add(pair);
          }
        }
      }

      return aggregated;
    });

// ─── Session Tracker Provider ──────────────────────────

final sessionTrackerProvider = Provider<SessionTracker?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  final tracker = SessionTracker(profileId: profile.id);
  ref.onDispose(() => tracker.dispose());
  return tracker;
});

// ─── Leaderboard ───────────────────────────────────────
//
// The global, device-local leaderboard was removed: it leaked every
// profile on the tablet across class/home-group boundaries. The board is
// now membership-scoped and online — see `onlineLeaderboardProvider` in
// online_leaderboard_provider.dart.

// ─── Learning Path Provider ────────────────────────────

class LearningPathNotifier extends Notifier<Map<String, LearningPathProgress>> {
  late String profileId;

  @override
  Map<String, LearningPathProgress> build() {
    final profile = ref.watch(profileProvider);
    profileId = profile?.id ?? '';
    final all = HiveService.getAllLearningPathProgress(profileId);
    return all.map(
      (pathId, json) => MapEntry(pathId, LearningPathProgress.fromJson(json)),
    );
  }

  LearningPathProgress? getProgress(String pathId) => state[pathId];

  /// Start a learning path if not already started.
  Future<void> startPath(String pathId) async {
    if (state.containsKey(pathId)) return;
    final progress = LearningPathProgress(
      pathId: pathId,
      startedAt: DateTime.now(),
    );
    final updated = Map<String, LearningPathProgress>.from(state);
    updated[pathId] = progress;
    state = updated;
    await HiveService.saveLearningPathProgress(
      profileId,
      pathId,
      progress.toJson(),
    );
  }

  /// Mark a step as completed with the given score.
  Future<void> completeStep(
    String pathId,
    int stepIndex,
    double score,
    int totalSteps,
  ) async {
    final current = state[pathId];
    if (current == null) return;

    final newCompleted = Set<int>.from(current.completedStepIndices)
      ..add(stepIndex);
    final newScores = Map<int, double>.from(current.bestScores);
    final existingBest = newScores[stepIndex] ?? 0.0;
    if (score > existingBest) newScores[stepIndex] = score;

    final nextStep = stepIndex + 1 < totalSteps
        ? stepIndex + 1
        : current.currentStepIndex;

    final isFullyComplete = newCompleted.length >= totalSteps;

    final updated = current.copyWith(
      completedStepIndices: newCompleted,
      currentStepIndex: nextStep,
      bestScores: newScores,
      completedAt: isFullyComplete ? DateTime.now() : null,
    );

    final newState = Map<String, LearningPathProgress>.from(state);
    newState[pathId] = updated;
    state = newState;
    await HiveService.saveLearningPathProgress(
      profileId,
      pathId,
      updated.toJson(),
    );
  }

  /// Check if a path is unlocked (prerequisite completed or initially unlocked).
  bool isPathUnlocked(LearningPath path) {
    if (path.isInitiallyUnlocked) return true;
    if (path.prerequisitePathId == null) return true;
    final prereq = state[path.prerequisitePathId!];
    return prereq?.isCompleted ?? false;
  }
}

final learningPathProvider =
    NotifierProvider<LearningPathNotifier, Map<String, LearningPathProgress>>(
      LearningPathNotifier.new,
    );

// ─── Sync Queue Providers ──────────────────────────────

/// Provides the [SyncQueueService] instance created in main.dart.
/// Returns null when Firebase is not configured.
final syncQueueServiceProvider = Provider<SyncQueueService?>((ref) {
  // Overridden at app startup via ProviderScope when Firebase is configured.
  return null;
});

// ─── Bidirectional Progress Sync ───────────────────────

/// Singleton [ProgressSyncListener] that hydrates Hive from Firestore
/// snapshots. Overridden in main.dart once the user is signed in.
final progressSyncListenerProvider = Provider<ProgressSyncListener?>((ref) {
  return null;
});

/// Stream of profileIds whose `progress` doc was just refreshed from
/// the server. [ProgressNotifier] listens to this so the UI rebuilds
/// when another device updates a student's stars/streak.
final progressRemoteChangesProvider = StreamProvider<String>((ref) {
  final listener = ref.watch(progressSyncListenerProvider);
  if (listener == null) return const Stream<String>.empty();
  return listener.changes;
});

/// Singleton [ProfileSyncListener] that hydrates Hive from Firestore
/// `profiles/{id}` snapshots — used to pick up educator-driven name
/// patches (Manage Classes > Rename, Home Group > Rename) on the
/// learner's own device. Overridden in main.dart once the user is
/// signed in.
final profileSyncListenerProvider = Provider<ProfileSyncListener?>((ref) {
  return null;
});

/// Stream of profileIds whose `profiles/{id}.name` was just refreshed
/// from the server. [ProfileNotifier] listens to this so the active
/// profile rebuilds with the new name immediately.
final profileRemoteChangesProvider = StreamProvider<String>((ref) {
  final listener = ref.watch(profileSyncListenerProvider);
  if (listener == null) return const Stream<String>.empty();
  return listener.changes;
});

/// Exposes the current [SyncQueueStatus] for the UI layer.
class SyncQueueStatusNotifier extends Notifier<SyncQueueStatus> {
  SyncQueueService? _service;
  bool _disposed = false;

  @override
  SyncQueueStatus build() {
    _service = ref.watch(syncQueueServiceProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _service?.onStatusChanged = null;
    });
    // Listen for status changes from the queue service.
    _service?.onStatusChanged = (status) {
      if (!_disposed) state = status;
    };
    return SyncQueueStorage.getQueueStatus();
  }

  /// Manually trigger queue processing.
  Future<void> sync() async {
    final service = _service;
    if (service == null) return;
    await service.processQueue();
    if (!_disposed) state = SyncQueueStorage.getQueueStatus();
  }

  /// Retry all failed operations.
  Future<void> retryFailed() async {
    final service = _service;
    if (service == null) return;
    await service.retryFailed();
    if (!_disposed) state = SyncQueueStorage.getQueueStatus();
  }

  /// Refresh status from storage (e.g. after a local write).
  void refresh() {
    if (!_disposed) state = SyncQueueStorage.getQueueStatus();
  }
}

final syncQueueStatusProvider =
    NotifierProvider<SyncQueueStatusNotifier, SyncQueueStatus>(
      SyncQueueStatusNotifier.new,
    );

// ─── Goals Provider ────────────────────────────────────

class GoalsNotifier extends Notifier<List<LearningGoal>> {
  late String profileId;

  @override
  List<LearningGoal> build() {
    final profile = ref.watch(profileProvider);
    profileId = profile?.id ?? 'default';
    final progress = ref.watch(progressProvider);
    // Update goal progress whenever learning progress changes
    final goals = GoalService.updateGoalProgress(profileId, progress);
    HiveService.saveGoals(profileId, goals);
    return goals;
  }

  Future<void> addGoal(LearningGoal goal) async {
    await GoalService.saveGoal(profileId, goal);
    state = GoalService.getGoals(profileId);
  }

  Future<void> removeGoal(String goalId) async {
    await GoalService.removeGoal(profileId, goalId);
    state = GoalService.getGoals(profileId);
  }

  List<LearningGoal> get activeGoals =>
      state.where((g) => g.status == GoalStatus.active).toList();

  List<LearningGoal> get completedGoals =>
      state.where((g) => g.status == GoalStatus.completed).toList();
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<LearningGoal>>(
  GoalsNotifier.new,
);

// ─── Recovery code (cross-device profile restoration) ────
/// Returns the latest unused recovery code metadata for [profileId], or
/// null if none has been issued. The [ShowRecoveryCodeScreen] watches
/// this to decide between "Generate a recovery code" and "Your recovery
/// code is ready" UI.
///
/// Caller `invalidate(recoveryCodeProvider(profileId))` after generating
/// a new code so the screen re-reads the freshly-created doc.
final recoveryCodeProvider = FutureProvider.autoDispose
    .family<RecoveryCodeRecord?, String>(
      (ref, profileId) => RecoveryCodeService.findActiveForProfile(profileId),
    );
