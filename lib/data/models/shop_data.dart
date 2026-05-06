import 'package:flutter/material.dart';

/// Types of items available in the star shop
enum ShopItemType { avatar, theme, border, title, soundPack, celebration }

/// A purchasable item in the star shop
class ShopItem {
  final String id;
  final String name;
  final String description;
  final int cost;
  final ShopItemType type;
  final String emoji;
  final Color color;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.emoji,
    required this.color,
  });
}

/// All purchasable shop items
class ShopData {
  ShopData._();

  static const List<ShopItem> allItems = [
    // ─── Premium Avatars ────────────────────────────
    ShopItem(
      id: 'avatar_unicorn',
      name: 'Unicorn',
      description: 'A magical unicorn avatar!',
      cost: 15,
      type: ShopItemType.avatar,
      emoji: '🦄',
      color: Color(0xFFE1BEE7),
    ),
    ShopItem(
      id: 'avatar_dragon',
      name: 'Dragon',
      description: 'A powerful dragon avatar!',
      cost: 25,
      type: ShopItemType.avatar,
      emoji: '🐉',
      color: Color(0xFFFFCDD2),
    ),
    ShopItem(
      id: 'avatar_shark',
      name: 'Shark',
      description: 'A cool shark avatar!',
      cost: 20,
      type: ShopItemType.avatar,
      emoji: '🦈',
      color: Color(0xFFBBDEFB),
    ),
    ShopItem(
      id: 'avatar_flamingo',
      name: 'Flamingo',
      description: 'An elegant flamingo avatar!',
      cost: 20,
      type: ShopItemType.avatar,
      emoji: '🦩',
      color: Color(0xFFF8BBD0),
    ),
    ShopItem(
      id: 'avatar_bee',
      name: 'Bee',
      description: 'A busy bee avatar!',
      cost: 10,
      type: ShopItemType.avatar,
      emoji: '🐝',
      color: Color(0xFFFFF9C4),
    ),
    ShopItem(
      id: 'avatar_octopus',
      name: 'Octopus',
      description: 'A clever octopus avatar!',
      cost: 30,
      type: ShopItemType.avatar,
      emoji: '🐙',
      color: Color(0xFFD1C4E9),
    ),
    ShopItem(
      id: 'avatar_robot',
      name: 'Robot',
      description: 'A friendly robot avatar!',
      cost: 35,
      type: ShopItemType.avatar,
      emoji: '🤖',
      color: Color(0xFFB0BEC5),
    ),
    ShopItem(
      id: 'avatar_alien',
      name: 'Alien',
      description: 'An out-of-this-world avatar!',
      cost: 40,
      type: ShopItemType.avatar,
      emoji: '👽',
      color: Color(0xFFC8E6C9),
    ),

    // ─── Themes ─────────────────────────────────────
    ShopItem(
      id: 'theme_ocean',
      name: 'Ocean Theme',
      description: 'Cool blue ocean vibes',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌊',
      color: Color(0xFF81D4FA),
    ),
    ShopItem(
      id: 'theme_sunset',
      name: 'Sunset Theme',
      description: 'Warm sunset colors',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌅',
      color: Color(0xFFFFCC80),
    ),
    ShopItem(
      id: 'theme_forest',
      name: 'Forest Theme',
      description: 'Natural green forest vibes',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌲',
      color: Color(0xFFA5D6A7),
    ),
    ShopItem(
      id: 'theme_galaxy',
      name: 'Galaxy Theme',
      description: 'Cosmic purple galaxy vibes',
      cost: 50,
      type: ShopItemType.theme,
      emoji: '🌌',
      color: Color(0xFFB39DDB),
    ),

    // ─── Profile Borders ────────────────────────────
    ShopItem(
      id: 'border_rainbow',
      name: 'Rainbow Border',
      description: 'A colorful rainbow profile frame',
      cost: 20,
      type: ShopItemType.border,
      emoji: '🌈',
      color: Color(0xFFFFAB91),
    ),
    ShopItem(
      id: 'border_sparkle',
      name: 'Sparkle Border',
      description: 'A sparkling profile frame',
      cost: 25,
      type: ShopItemType.border,
      emoji: '✨',
      color: Color(0xFFFFD54F),
    ),
    ShopItem(
      id: 'border_crown',
      name: 'Crown Border',
      description: 'A royal crown profile frame',
      cost: 45,
      type: ShopItemType.border,
      emoji: '👑',
      color: Color(0xFFFFE082),
    ),

    // ─── Profile Titles ─────────────────────────────
    ShopItem(
      id: 'title_star_student',
      name: 'Star Student',
      description: 'Show everyone you shine bright',
      cost: 15,
      type: ShopItemType.title,
      emoji: '🌟',
      color: Color(0xFFFFF176),
    ),
    ShopItem(
      id: 'title_word_wizard',
      name: 'Word Wizard',
      description: 'A master of vocabulary',
      cost: 25,
      type: ShopItemType.title,
      emoji: '🧙',
      color: Color(0xFFCE93D8),
    ),
    ShopItem(
      id: 'title_speed_learner',
      name: 'Speed Learner',
      description: 'Learn faster than anyone',
      cost: 30,
      type: ShopItemType.title,
      emoji: '⚡',
      color: Color(0xFFFFD54F),
    ),
    ShopItem(
      id: 'title_bookworm',
      name: 'Bookworm',
      description: 'Always reading and learning',
      cost: 20,
      type: ShopItemType.title,
      emoji: '📚',
      color: Color(0xFFA5D6A7),
    ),

    // ─── Sound Packs ────────────────────────────────
    ShopItem(
      id: 'sound_chiptune',
      name: 'Chiptune Pack',
      description: 'Retro 8-bit sound effects',
      cost: 20,
      type: ShopItemType.soundPack,
      emoji: '🎮',
      color: Color(0xFF80DEEA),
    ),
    ShopItem(
      id: 'sound_nature',
      name: 'Nature Pack',
      description: 'Calming nature sounds',
      cost: 20,
      type: ShopItemType.soundPack,
      emoji: '🌿',
      color: Color(0xFFC5E1A5),
    ),
    ShopItem(
      id: 'sound_space',
      name: 'Space Pack',
      description: 'Futuristic space sounds',
      cost: 30,
      type: ShopItemType.soundPack,
      emoji: '🚀',
      color: Color(0xFFB39DDB),
    ),

    // ─── Celebration Animations ─────────────────────
    ShopItem(
      id: 'celebration_fireworks',
      name: 'Fireworks',
      description: 'Explosive fireworks celebration',
      cost: 25,
      type: ShopItemType.celebration,
      emoji: '🎆',
      color: Color(0xFFEF9A9A),
    ),
    ShopItem(
      id: 'celebration_rainbow',
      name: 'Rainbow Burst',
      description: 'A rainbow celebration effect',
      cost: 25,
      type: ShopItemType.celebration,
      emoji: '🌈',
      color: Color(0xFFF48FB1),
    ),
    ShopItem(
      id: 'celebration_snow',
      name: 'Snowfall',
      description: 'Gentle snowflake animation',
      cost: 35,
      type: ShopItemType.celebration,
      emoji: '❄️',
      color: Color(0xFFB3E5FC),
    ),
  ];

  static List<ShopItem> byType(ShopItemType type) =>
      allItems.where((item) => item.type == type).toList();

  static ShopItem? findById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
