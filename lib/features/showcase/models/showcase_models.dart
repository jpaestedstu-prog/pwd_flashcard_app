import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';

/// The type of showcase item in the student's portfolio
enum ShowcaseItemType {
  achievement,
  highScore,
  categoryMastery,
  learningPathComplete,
  streakMilestone,
  assessmentResult,
  customNote,
}

extension ShowcaseItemTypeX on ShowcaseItemType {
  String get label => switch (this) {
    ShowcaseItemType.achievement => 'Achievement',
    ShowcaseItemType.highScore => 'High Score',
    ShowcaseItemType.categoryMastery => 'Category Mastery',
    ShowcaseItemType.learningPathComplete => 'Learning Path',
    ShowcaseItemType.streakMilestone => 'Streak Milestone',
    ShowcaseItemType.assessmentResult => 'Assessment',
    ShowcaseItemType.customNote => 'Note',
  };

  String get emoji => switch (this) {
    ShowcaseItemType.achievement => '🏆',
    ShowcaseItemType.highScore => '🌟',
    ShowcaseItemType.categoryMastery => '📚',
    ShowcaseItemType.learningPathComplete => '🗺️',
    ShowcaseItemType.streakMilestone => '🔥',
    ShowcaseItemType.assessmentResult => '📝',
    ShowcaseItemType.customNote => '📌',
  };

  IconData get icon => switch (this) {
    ShowcaseItemType.achievement => Icons.emoji_events_rounded,
    ShowcaseItemType.highScore => Icons.star_rounded,
    ShowcaseItemType.categoryMastery => Icons.school_rounded,
    ShowcaseItemType.learningPathComplete => Icons.map_rounded,
    ShowcaseItemType.streakMilestone => Icons.local_fire_department_rounded,
    ShowcaseItemType.assessmentResult => Icons.assignment_turned_in_rounded,
    ShowcaseItemType.customNote => Icons.sticky_note_2_rounded,
  };

  Color get color => switch (this) {
    ShowcaseItemType.achievement => const Color(0xFFFFD700),
    ShowcaseItemType.highScore => const Color(0xFFFF9800),
    ShowcaseItemType.categoryMastery => const Color(0xFF4CAF50),
    ShowcaseItemType.learningPathComplete => const Color(0xFF7E57C2),
    ShowcaseItemType.streakMilestone => const Color(0xFFF44336),
    ShowcaseItemType.assessmentResult => const Color(0xFF00ACC1),
    ShowcaseItemType.customNote => const Color(0xFF78909C),
  };

  Color get lightColor => switch (this) {
    ShowcaseItemType.achievement => AppColors.background,
    ShowcaseItemType.highScore => const Color(0xFFFFF3E0),
    ShowcaseItemType.categoryMastery => const Color(0xFFE8F5E9),
    ShowcaseItemType.learningPathComplete => const Color(0xFFF3E5F5),
    ShowcaseItemType.streakMilestone => const Color(0xFFFFEBEE),
    ShowcaseItemType.assessmentResult => const Color(0xFFE0F7FA),
    ShowcaseItemType.customNote => const Color(0xFFECEFF1),
  };
}

/// A single item in the student's showcase portfolio
class ShowcaseItem {
  final String id;
  final ShowcaseItemType type;
  final String title;
  final String description;
  final DateTime earnedAt;
  final bool isPinned;

  // Optional metadata depending on type
  final String? achievementId;
  final GameType? gameType;
  final int? score;
  final int? total;
  final FlashcardCategory? category;
  final double? masteryPercent;
  final String? learningPathId;
  final String? customNote;

  const ShowcaseItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.earnedAt,
    this.isPinned = false,
    this.achievementId,
    this.gameType,
    this.score,
    this.total,
    this.category,
    this.masteryPercent,
    this.learningPathId,
    this.customNote,
  });

  ShowcaseItem copyWith({
    String? id,
    ShowcaseItemType? type,
    String? title,
    String? description,
    DateTime? earnedAt,
    bool? isPinned,
    String? achievementId,
    GameType? gameType,
    int? score,
    int? total,
    FlashcardCategory? category,
    double? masteryPercent,
    String? learningPathId,
    String? customNote,
  }) {
    return ShowcaseItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      earnedAt: earnedAt ?? this.earnedAt,
      isPinned: isPinned ?? this.isPinned,
      achievementId: achievementId ?? this.achievementId,
      gameType: gameType ?? this.gameType,
      score: score ?? this.score,
      total: total ?? this.total,
      category: category ?? this.category,
      masteryPercent: masteryPercent ?? this.masteryPercent,
      learningPathId: learningPathId ?? this.learningPathId,
      customNote: customNote ?? this.customNote,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'description': description,
    'earnedAt': earnedAt.toIso8601String(),
    'isPinned': isPinned,
    'achievementId': achievementId,
    'gameType': gameType?.index,
    'score': score,
    'total': total,
    'category': category?.index,
    'masteryPercent': masteryPercent,
    'learningPathId': learningPathId,
    'customNote': customNote,
  };

  factory ShowcaseItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    final gameTypeIndex = json['gameType'] as int?;
    final catIndex = json['category'] as int?;
    return ShowcaseItem(
      id: json['id'] as String,
      type: (typeIndex >= 0 && typeIndex < ShowcaseItemType.values.length)
          ? ShowcaseItemType.values[typeIndex]
          : ShowcaseItemType.customNote,
      title: json['title'] as String,
      description: json['description'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      achievementId: json['achievementId'] as String?,
      gameType: (gameTypeIndex != null &&
              gameTypeIndex >= 0 &&
              gameTypeIndex < GameType.values.length)
          ? GameType.values[gameTypeIndex]
          : null,
      score: json['score'] as int?,
      total: json['total'] as int?,
      category: (catIndex != null &&
              catIndex >= 0 &&
              catIndex < FlashcardCategory.values.length)
          ? FlashcardCategory.values[catIndex]
          : null,
      masteryPercent: (json['masteryPercent'] as num?)?.toDouble(),
      learningPathId: json['learningPathId'] as String?,
      customNote: json['customNote'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowcaseItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A student's complete portfolio
class ShowcasePortfolio {
  final String profileId;
  final String profileName;
  final List<ShowcaseItem> items;
  final DateTime lastUpdated;

  const ShowcasePortfolio({
    required this.profileId,
    required this.profileName,
    this.items = const [],
    required this.lastUpdated,
  });

  /// Items sorted: pinned first, then by date (newest first)
  List<ShowcaseItem> get sortedItems {
    final sorted = List<ShowcaseItem>.from(items);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.earnedAt.compareTo(a.earnedAt);
    });
    return sorted;
  }

  /// Count by type
  Map<ShowcaseItemType, int> get typeCounts {
    final counts = <ShowcaseItemType, int>{};
    for (final item in items) {
      counts[item.type] = (counts[item.type] ?? 0) + 1;
    }
    return counts;
  }

  int get pinnedCount => items.where((i) => i.isPinned).length;

  ShowcasePortfolio copyWith({
    String? profileId,
    String? profileName,
    List<ShowcaseItem>? items,
    DateTime? lastUpdated,
  }) {
    return ShowcasePortfolio(
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      items: items ?? this.items,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
