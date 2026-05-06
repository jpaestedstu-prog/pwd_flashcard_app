import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Sticker rarity levels
enum StickerRarity { common, rare, epic, legendary }

extension StickerRarityX on StickerRarity {
  String get label => switch (this) {
        StickerRarity.common => 'Common',
        StickerRarity.rare => 'Rare',
        StickerRarity.epic => 'Epic',
        StickerRarity.legendary => 'Legendary',
      };

  String get labelFilipino => switch (this) {
        StickerRarity.common => 'Karaniwan',
        StickerRarity.rare => 'Bihira',
        StickerRarity.epic => 'Epiko',
        StickerRarity.legendary => 'Alamat',
      };

  Color get color => switch (this) {
        StickerRarity.common => const Color(0xFF78909C),
        StickerRarity.rare => const Color(0xFF42A5F5),
        StickerRarity.epic => const Color(0xFFAB47BC),
        StickerRarity.legendary => const Color(0xFFFFB300),
      };

  Color get bgColor => switch (this) {
        StickerRarity.common => const Color(0xFFECEFF1),
        StickerRarity.rare => const Color(0xFFE3F2FD),
        StickerRarity.epic => const Color(0xFFF3E5F5),
        StickerRarity.legendary => AppColors.background,
      };

  int get stars => switch (this) {
        StickerRarity.common => 1,
        StickerRarity.rare => 2,
        StickerRarity.epic => 3,
        StickerRarity.legendary => 4,
      };
}

/// Sticker categories
enum StickerCategory {
  animals,
  stars,
  badges,
  school,
  nature,
  special,
}

extension StickerCategoryX on StickerCategory {
  String get label => switch (this) {
        StickerCategory.animals => 'Animals',
        StickerCategory.stars => 'Stars & Sparkles',
        StickerCategory.badges => 'Badges',
        StickerCategory.school => 'School',
        StickerCategory.nature => 'Nature',
        StickerCategory.special => 'Special',
      };

  String get emoji => switch (this) {
        StickerCategory.animals => '🐾',
        StickerCategory.stars => '⭐',
        StickerCategory.badges => '🏅',
        StickerCategory.school => '📚',
        StickerCategory.nature => '🌿',
        StickerCategory.special => '✨',
      };

  IconData get icon => switch (this) {
        StickerCategory.animals => Icons.pets_rounded,
        StickerCategory.stars => Icons.star_rounded,
        StickerCategory.badges => Icons.military_tech_rounded,
        StickerCategory.school => Icons.school_rounded,
        StickerCategory.nature => Icons.eco_rounded,
        StickerCategory.special => Icons.auto_awesome_rounded,
      };
}

/// A single collectible sticker
class Sticker {
  final String id;
  final String name;
  final String nameFilipino;
  final String emoji;
  final StickerCategory category;
  final StickerRarity rarity;
  final String unlockDescription;
  final String unlockDescriptionFilipino;

  /// Function ID used to check unlock condition against progress.
  /// Matches keys in [StickerUnlockChecker].
  final String unlockConditionId;

  const Sticker({
    required this.id,
    required this.name,
    required this.nameFilipino,
    required this.emoji,
    required this.category,
    required this.rarity,
    required this.unlockDescription,
    required this.unlockDescriptionFilipino,
    required this.unlockConditionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sticker && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Seed data for all stickers
class StickerData {
  StickerData._();

  static const List<Sticker> allStickers = [
    // ─── Animals (Common) ──────────────────────
    Sticker(
      id: 'stk_puppy',
      name: 'Happy Puppy',
      nameFilipino: 'Masayang Tuta',
      emoji: '🐶',
      category: StickerCategory.animals,
      rarity: StickerRarity.common,
      unlockDescription: 'Learn 5 words',
      unlockDescriptionFilipino: 'Matuto ng 5 salita',
      unlockConditionId: 'words_5',
    ),
    Sticker(
      id: 'stk_kitten',
      name: 'Cute Kitten',
      nameFilipino: 'Cute na Kuting',
      emoji: '🐱',
      category: StickerCategory.animals,
      rarity: StickerRarity.common,
      unlockDescription: 'Learn 10 words',
      unlockDescriptionFilipino: 'Matuto ng 10 salita',
      unlockConditionId: 'words_10',
    ),
    Sticker(
      id: 'stk_bunny',
      name: 'Fluffy Bunny',
      nameFilipino: 'Malambot na Kuneho',
      emoji: '🐰',
      category: StickerCategory.animals,
      rarity: StickerRarity.rare,
      unlockDescription: 'Learn 25 words',
      unlockDescriptionFilipino: 'Matuto ng 25 salita',
      unlockConditionId: 'words_25',
    ),
    Sticker(
      id: 'stk_dolphin',
      name: 'Smart Dolphin',
      nameFilipino: 'Matalinong Dolphin',
      emoji: '🐬',
      category: StickerCategory.animals,
      rarity: StickerRarity.epic,
      unlockDescription: 'Learn 50 words',
      unlockDescriptionFilipino: 'Matuto ng 50 salita',
      unlockConditionId: 'words_50',
    ),
    Sticker(
      id: 'stk_unicorn',
      name: 'Magic Unicorn',
      nameFilipino: 'Mahiwagang Unicorn',
      emoji: '🦄',
      category: StickerCategory.animals,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Learn 100 words',
      unlockDescriptionFilipino: 'Matuto ng 100 salita',
      unlockConditionId: 'words_100',
    ),

    // ─── Stars & Sparkles ──────────────────────
    Sticker(
      id: 'stk_first_star',
      name: 'First Star',
      nameFilipino: 'Unang Bituin',
      emoji: '⭐',
      category: StickerCategory.stars,
      rarity: StickerRarity.common,
      unlockDescription: 'Earn 10 stars',
      unlockDescriptionFilipino: 'Kumita ng 10 bituin',
      unlockConditionId: 'stars_10',
    ),
    Sticker(
      id: 'stk_sparkle',
      name: 'Sparkle Power',
      nameFilipino: 'Sparkle Power',
      emoji: '✨',
      category: StickerCategory.stars,
      rarity: StickerRarity.rare,
      unlockDescription: 'Earn 50 stars',
      unlockDescriptionFilipino: 'Kumita ng 50 bituin',
      unlockConditionId: 'stars_50',
    ),
    Sticker(
      id: 'stk_shooting_star',
      name: 'Shooting Star',
      nameFilipino: 'Bulalakaw',
      emoji: '🌠',
      category: StickerCategory.stars,
      rarity: StickerRarity.epic,
      unlockDescription: 'Earn 100 stars',
      unlockDescriptionFilipino: 'Kumita ng 100 bituin',
      unlockConditionId: 'stars_100',
    ),
    Sticker(
      id: 'stk_galaxy',
      name: 'Galaxy Explorer',
      nameFilipino: 'Galaxy Explorer',
      emoji: '🌌',
      category: StickerCategory.stars,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Earn 500 stars',
      unlockDescriptionFilipino: 'Kumita ng 500 bituin',
      unlockConditionId: 'stars_500',
    ),

    // ─── Badges ──────────────────────
    Sticker(
      id: 'stk_first_game',
      name: 'Game Starter',
      nameFilipino: 'Nagsimula sa Laro',
      emoji: '🎮',
      category: StickerCategory.badges,
      rarity: StickerRarity.common,
      unlockDescription: 'Play your first game',
      unlockDescriptionFilipino: 'Maglaro ng unang laro',
      unlockConditionId: 'games_1',
    ),
    Sticker(
      id: 'stk_gamer',
      name: 'Pro Gamer',
      nameFilipino: 'Pro Gamer',
      emoji: '🕹️',
      category: StickerCategory.badges,
      rarity: StickerRarity.rare,
      unlockDescription: 'Play 10 games',
      unlockDescriptionFilipino: 'Maglaro ng 10 laro',
      unlockConditionId: 'games_10',
    ),
    Sticker(
      id: 'stk_champion',
      name: 'Champion',
      nameFilipino: 'Kampeon',
      emoji: '🏆',
      category: StickerCategory.badges,
      rarity: StickerRarity.epic,
      unlockDescription: 'Get a perfect score in any game',
      unlockDescriptionFilipino: 'Makakuha ng perfect score sa kahit anong laro',
      unlockConditionId: 'perfect_score',
    ),
    Sticker(
      id: 'stk_legend',
      name: 'Legend',
      nameFilipino: 'Alamat',
      emoji: '👑',
      category: StickerCategory.badges,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Get 5 perfect scores',
      unlockDescriptionFilipino: 'Makakuha ng 5 perfect scores',
      unlockConditionId: 'perfect_5',
    ),

    // ─── School ──────────────────────
    Sticker(
      id: 'stk_bookworm',
      name: 'Bookworm',
      nameFilipino: 'Bookworm',
      emoji: '📖',
      category: StickerCategory.school,
      rarity: StickerRarity.common,
      unlockDescription: 'Read your first story',
      unlockDescriptionFilipino: 'Basahin ang unang kwento',
      unlockConditionId: 'stories_1',
    ),
    Sticker(
      id: 'stk_scholar',
      name: 'Scholar',
      nameFilipino: 'Iskolar',
      emoji: '🎓',
      category: StickerCategory.school,
      rarity: StickerRarity.rare,
      unlockDescription: 'Complete a learning path',
      unlockDescriptionFilipino: 'Kumpletuhin ang isang learning path',
      unlockConditionId: 'path_complete_1',
    ),
    Sticker(
      id: 'stk_teacher_pet',
      name: 'Super Student',
      nameFilipino: 'Super Estudyante',
      emoji: '🌟',
      category: StickerCategory.school,
      rarity: StickerRarity.epic,
      unlockDescription: 'Master 3 categories',
      unlockDescriptionFilipino: 'I-master ang 3 kategorya',
      unlockConditionId: 'categories_3',
    ),
    Sticker(
      id: 'stk_genius',
      name: 'Little Genius',
      nameFilipino: 'Munting Henyo',
      emoji: '🧠',
      category: StickerCategory.school,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Master all 12 categories',
      unlockDescriptionFilipino: 'I-master lahat ng 12 kategorya',
      unlockConditionId: 'categories_12',
    ),

    // ─── Nature ──────────────────────
    Sticker(
      id: 'stk_seedling',
      name: 'Seedling',
      nameFilipino: 'Binhi',
      emoji: '🌱',
      category: StickerCategory.nature,
      rarity: StickerRarity.common,
      unlockDescription: 'Start a 3-day streak',
      unlockDescriptionFilipino: 'Magsimula ng 3-araw na streak',
      unlockConditionId: 'streak_3',
    ),
    Sticker(
      id: 'stk_flower',
      name: 'Blooming Flower',
      nameFilipino: 'Namumulaklak na Bulaklak',
      emoji: '🌸',
      category: StickerCategory.nature,
      rarity: StickerRarity.rare,
      unlockDescription: 'Reach a 7-day streak',
      unlockDescriptionFilipino: 'Maabot ang 7-araw na streak',
      unlockConditionId: 'streak_7',
    ),
    Sticker(
      id: 'stk_tree',
      name: 'Growing Tree',
      nameFilipino: 'Lumalaking Puno',
      emoji: '🌳',
      category: StickerCategory.nature,
      rarity: StickerRarity.epic,
      unlockDescription: 'Reach a 14-day streak',
      unlockDescriptionFilipino: 'Maabot ang 14-araw na streak',
      unlockConditionId: 'streak_14',
    ),
    Sticker(
      id: 'stk_rainbow',
      name: 'Rainbow',
      nameFilipino: 'Bahaghari',
      emoji: '🌈',
      category: StickerCategory.nature,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Reach a 30-day streak',
      unlockDescriptionFilipino: 'Maabot ang 30-araw na streak',
      unlockConditionId: 'streak_30',
    ),

    // ─── Special ──────────────────────
    Sticker(
      id: 'stk_rocket',
      name: 'Rocket Launch',
      nameFilipino: 'Rocket Launch',
      emoji: '🚀',
      category: StickerCategory.special,
      rarity: StickerRarity.rare,
      unlockDescription: 'Complete 5 daily challenges',
      unlockDescriptionFilipino: 'Kumpletuhin ang 5 daily challenges',
      unlockConditionId: 'daily_5',
    ),
    Sticker(
      id: 'stk_fire',
      name: 'On Fire',
      nameFilipino: 'On Fire',
      emoji: '🔥',
      category: StickerCategory.special,
      rarity: StickerRarity.epic,
      unlockDescription: 'Complete 20 daily challenges',
      unlockDescriptionFilipino: 'Kumpletuhin ng 20 daily challenges',
      unlockConditionId: 'daily_20',
    ),
    Sticker(
      id: 'stk_crown',
      name: 'Royal Crown',
      nameFilipino: 'Royal Crown',
      emoji: '👸',
      category: StickerCategory.special,
      rarity: StickerRarity.legendary,
      unlockDescription: 'Collect 20 other stickers',
      unlockDescriptionFilipino: 'Kolektahin ang 20 ibang stickers',
      unlockConditionId: 'stickers_20',
    ),
  ];

  static List<Sticker> byCategory(StickerCategory category) =>
      allStickers.where((s) => s.category == category).toList();

  static Sticker? findById(String id) =>
      allStickers.where((s) => s.id == id).firstOrNull;
}
