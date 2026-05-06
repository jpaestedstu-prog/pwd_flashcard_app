import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../features/assessment/services/assessment_service.dart';
import '../../../features/assessment/models/assessment_models.dart';
import '../models/showcase_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _uuid = Uuid();

/// Service that manages showcase portfolio persistence.
class ShowcaseService {
  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  /// Get all showcase items for a profile
  static List<ShowcaseItem> getItems(String profileId) {
    final raw = _box.get('showcase_$profileId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) =>
            ShowcaseItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save all showcase items for a profile
  static Future<void> saveItems(
      String profileId, List<ShowcaseItem> items) async {
    await _box.put(
      'showcase_$profileId',
      items.map((i) => i.toJson()).toList(),
    );
  }

  /// Add a single showcase item
  static Future<void> addItem(
      String profileId, ShowcaseItem item) async {
    final items = getItems(profileId);
    // Avoid duplicates by checking ID
    items.removeWhere((i) => i.id == item.id);
    items.add(item);
    await saveItems(profileId, items);
  }

  /// Remove a showcase item
  static Future<void> removeItem(
      String profileId, String itemId) async {
    final items = getItems(profileId);
    items.removeWhere((i) => i.id == itemId);
    await saveItems(profileId, items);
  }

  /// Toggle pin status
  static Future<void> togglePin(
      String profileId, String itemId) async {
    final items = getItems(profileId);
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    items[idx] = items[idx].copyWith(isPinned: !items[idx].isPinned);
    await saveItems(profileId, items);
  }
}

/// Manages the student's showcase portfolio state
class ShowcaseNotifier extends StateNotifier<ShowcasePortfolio> {
  final String profileId;
  final String profileName;

  ShowcaseNotifier({
    required this.profileId,
    required this.profileName,
  }) : super(ShowcasePortfolio(
          profileId: profileId,
          profileName: profileName,
          items: ShowcaseService.getItems(profileId),
          lastUpdated: DateTime.now(),
        ));

  /// Refresh items from storage
  void refresh() {
    state = state.copyWith(
      items: ShowcaseService.getItems(profileId),
      lastUpdated: DateTime.now(),
    );
  }

  /// Add an item to the portfolio
  Future<void> addItem(ShowcaseItem item) async {
    await ShowcaseService.addItem(profileId, item);
    refresh();
  }

  /// Remove an item from the portfolio
  Future<void> removeItem(String itemId) async {
    await ShowcaseService.removeItem(profileId, itemId);
    refresh();
  }

  /// Toggle pin status of an item
  Future<void> togglePin(String itemId) async {
    await ShowcaseService.togglePin(profileId, itemId);
    refresh();
  }

  /// Add a custom note to the portfolio
  Future<void> addNote(String title, String note) async {
    final item = ShowcaseItem(
      id: _uuid.v4(),
      type: ShowcaseItemType.customNote,
      title: title,
      description: note,
      earnedAt: DateTime.now(),
      customNote: note,
    );
    await addItem(item);
  }

  /// Auto-curate: scan achievements, scores, mastery and add noteworthy items
  Future<List<ShowcaseItem>> autoPopulate(LearningProgress progress) async {
    final existingIds = state.items.map((i) => i.achievementId ?? i.id).toSet();
    final newItems = <ShowcaseItem>[];

    // 1) Add unlocked achievements
    final unlockedIds = HiveService.getUnlockedAchievements(profileId);
    for (final achievementId in unlockedIds) {
      if (existingIds.contains(achievementId)) continue;
      final achievement = Achievements.all.where((a) => a.id == achievementId);
      if (achievement.isEmpty) continue;
      final a = achievement.first;
      final item = ShowcaseItem(
        id: _uuid.v4(),
        type: ShowcaseItemType.achievement,
        title: a.title,
        description: a.description,
        earnedAt: DateTime.now(),
        achievementId: a.id,
      );
      newItems.add(item);
      existingIds.add(achievementId);
    }

    // 2) Add high scores (best game results with 3 stars)
    for (final score in progress.recentScores) {
      if (score.starsEarned >= 3 && score.total > 0) {
        final key = '${score.gameType.name}_${score.date.toIso8601String()}';
        if (existingIds.contains(key)) continue;
        final pct = ((score.score / score.total) * 100).round();
        final item = ShowcaseItem(
          id: _uuid.v4(),
          type: ShowcaseItemType.highScore,
          title: '${score.gameType.label} — $pct%',
          description:
              'Scored ${score.score}/${score.total} and earned ${score.starsEarned} stars!',
          earnedAt: score.date,
          gameType: score.gameType,
          score: score.score,
          total: score.total,
        );
        newItems.add(item);
        existingIds.add(key);
      }
    }

    // 3) Add mastered categories (>= 80%)
    for (final cat in FlashcardCategory.values) {
      final mastery = progress.categoryProgress[cat.label] ?? 0.0;
      if (mastery >= 0.8) {
        final key = 'mastery_${cat.name}';
        if (existingIds.contains(key)) continue;
        final item = ShowcaseItem(
          id: 'mastery_${cat.name}',
          type: ShowcaseItemType.categoryMastery,
          title: '${cat.label} Mastered!',
          description:
              'Achieved ${(mastery * 100).round()}% mastery in ${cat.label}',
          earnedAt: DateTime.now(),
          category: cat,
          masteryPercent: mastery,
        );
        newItems.add(item);
        existingIds.add(key);
      }
    }

    // 4) Add streak milestones
    final streakMilestones = [3, 7, 14, 30, 60, 100];
    for (final milestone in streakMilestones) {
      if (progress.streakDays >= milestone) {
        final key = 'streak_$milestone';
        if (existingIds.contains(key)) continue;
        final item = ShowcaseItem(
          id: 'streak_$milestone',
          type: ShowcaseItemType.streakMilestone,
          title: '$milestone-Day Streak!',
          description:
              'Maintained a learning streak of $milestone days in a row!',
          earnedAt: DateTime.now(),
        );
        newItems.add(item);
        existingIds.add(key);
      }
    }

    // 5) Add assessment results (pre/post test completions)
    final assessmentResults = AssessmentService.getResults(profileId);
    for (final result in assessmentResults) {
      final key = 'assessment_${result.id}';
      if (existingIds.contains(key)) continue;
      final pct = (result.percentage * 100).round();
      final item = ShowcaseItem(
        id: key,
        type: ShowcaseItemType.assessmentResult,
        title: '${result.type.label} — $pct%',
        description:
            'Scored ${result.score}/${result.totalQuestions} on ${result.type.label}',
        earnedAt: result.completedAt,
        score: result.score,
        total: result.totalQuestions,
        masteryPercent: result.percentage,
      );
      newItems.add(item);
      existingIds.add(key);
    }

    // Save all new items
    for (final item in newItems) {
      await ShowcaseService.addItem(profileId, item);
    }

    refresh();
    return newItems;
  }
}

final showcaseProvider =
    StateNotifierProvider<ShowcaseNotifier, ShowcasePortfolio>((ref) {
  final profile = ref.watch(profileProvider);
  return ShowcaseNotifier(
    profileId: profile?.id ?? '',
    profileName: profile?.name ?? 'Learner',
  );
});
