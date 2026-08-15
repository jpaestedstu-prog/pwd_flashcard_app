import 'package:flutter/material.dart';

/// Types of items available in the star shop
enum ShopItemType { avatar, theme, border, title, soundPack, celebration }

/// A purchasable item in the star shop
class ShopItem {
  final String id;
  final String name;
  final String description;

  /// Filipino name and description.
  ///
  /// Item text lives in the catalogue rather than the ARB files, matching how
  /// the rest of the app's bilingual *data* works (`labelFilipino` on the
  /// category and game enums). The alternative — 50 ARB keys reached through a
  /// switch on item id — puts the translation a long way from the thing it
  /// names and makes adding an item a two-file job.
  ///
  /// Use [localizedName] / [localizedDescription] rather than reading these
  /// directly, so an untranslated item falls back to English instead of blank.
  final String nameFilipino;
  final String descriptionFilipino;

  final int cost;
  final ShopItemType type;
  final String emoji;
  final Color color;

  /// Whether this item can currently be sold.
  ///
  /// An item whose effect is not implemented yet must not be on the shelf: a
  /// learner who saves up for it gets nothing back for their stars. Setting
  /// this to `false` hides the item (and its whole tab, if it empties) and
  /// makes [ProgressNotifier.refundWithdrawnPurchases] return the stars to
  /// anyone who already bought it. Flip it back to `true` on the day the
  /// effect lands and the item returns to sale untouched.
  final bool available;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.emoji,
    required this.color,
    this.nameFilipino = '',
    this.descriptionFilipino = '',
    this.available = true,
  });

  /// The item's name for [isFilipino], falling back to English when no
  /// translation has been written yet.
  String localizedName(bool isFilipino) =>
      isFilipino && nameFilipino.isNotEmpty ? nameFilipino : name;

  /// The item's description for [isFilipino], falling back to English.
  String localizedDescription(bool isFilipino) =>
      isFilipino && descriptionFilipino.isNotEmpty
          ? descriptionFilipino
          : description;
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
      nameFilipino: 'Unicorn',
      descriptionFilipino: 'Isang mahiwagang unicorn avatar!',
      cost: 15,
      type: ShopItemType.avatar,
      emoji: '🦄',
      color: Color(0xFFE1BEE7),
    ),
    ShopItem(
      id: 'avatar_dragon',
      name: 'Dragon',
      description: 'A powerful dragon avatar!',
      nameFilipino: 'Dragon',
      descriptionFilipino: 'Isang makapangyarihang dragon avatar!',
      cost: 25,
      type: ShopItemType.avatar,
      emoji: '🐉',
      color: Color(0xFFFFCDD2),
    ),
    ShopItem(
      id: 'avatar_shark',
      name: 'Shark',
      description: 'A cool shark avatar!',
      nameFilipino: 'Pating',
      descriptionFilipino: 'Isang astig na avatar ng pating!',
      cost: 20,
      type: ShopItemType.avatar,
      emoji: '🦈',
      color: Color(0xFFBBDEFB),
    ),
    ShopItem(
      id: 'avatar_flamingo',
      name: 'Flamingo',
      description: 'An elegant flamingo avatar!',
      nameFilipino: 'Flamingo',
      descriptionFilipino: 'Isang eleganteng flamingo avatar!',
      cost: 20,
      type: ShopItemType.avatar,
      emoji: '🦩',
      color: Color(0xFFF8BBD0),
    ),
    ShopItem(
      id: 'avatar_bee',
      name: 'Bee',
      description: 'A busy bee avatar!',
      nameFilipino: 'Bubuyog',
      descriptionFilipino: 'Isang masipag na bubuyog avatar!',
      cost: 10,
      type: ShopItemType.avatar,
      emoji: '🐝',
      color: Color(0xFFFFF9C4),
    ),
    ShopItem(
      id: 'avatar_octopus',
      name: 'Octopus',
      description: 'A clever octopus avatar!',
      nameFilipino: 'Pugita',
      descriptionFilipino: 'Isang matalinong pugita avatar!',
      cost: 30,
      type: ShopItemType.avatar,
      emoji: '🐙',
      color: Color(0xFFD1C4E9),
    ),
    ShopItem(
      id: 'avatar_robot',
      name: 'Robot',
      description: 'A friendly robot avatar!',
      nameFilipino: 'Robot',
      descriptionFilipino: 'Isang palakaibigang robot avatar!',
      cost: 35,
      type: ShopItemType.avatar,
      emoji: '🤖',
      color: Color(0xFFB0BEC5),
    ),
    ShopItem(
      id: 'avatar_alien',
      name: 'Alien',
      description: 'An out-of-this-world avatar!',
      nameFilipino: 'Alien',
      descriptionFilipino: 'Isang avatar na hindi taga-Mundo!',
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
      nameFilipino: 'Temang Karagatan',
      descriptionFilipino: 'Malamig na asul na karagatan',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌊',
      color: Color(0xFF81D4FA),
    ),
    ShopItem(
      id: 'theme_sunset',
      name: 'Sunset Theme',
      description: 'Warm sunset colors',
      nameFilipino: 'Temang Paglubog ng Araw',
      descriptionFilipino: 'Mainit na kulay ng paglubog ng araw',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌅',
      color: Color(0xFFFFCC80),
    ),
    ShopItem(
      id: 'theme_forest',
      name: 'Forest Theme',
      description: 'Natural green forest vibes',
      nameFilipino: 'Temang Kagubatan',
      descriptionFilipino: 'Natural na berdeng kagubatan',
      cost: 30,
      type: ShopItemType.theme,
      emoji: '🌲',
      color: Color(0xFFA5D6A7),
    ),
    ShopItem(
      id: 'theme_galaxy',
      name: 'Galaxy Theme',
      description: 'Cosmic purple galaxy vibes',
      nameFilipino: 'Temang Galaksiya',
      descriptionFilipino: 'Kosmikong lilang galaksiya',
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
      nameFilipino: 'Border na Bahaghari',
      descriptionFilipino: 'Makulay na bahaghari sa profile',
      cost: 20,
      type: ShopItemType.border,
      emoji: '🌈',
      color: Color(0xFFFFAB91),
    ),
    ShopItem(
      id: 'border_sparkle',
      name: 'Sparkle Border',
      description: 'A sparkling profile frame',
      nameFilipino: 'Border na Kislap',
      descriptionFilipino: 'Kumikislap na frame ng profile',
      cost: 25,
      type: ShopItemType.border,
      emoji: '✨',
      color: Color(0xFFFFD54F),
    ),
    ShopItem(
      id: 'border_crown',
      name: 'Crown Border',
      description: 'A royal crown profile frame',
      nameFilipino: 'Border na Korona',
      descriptionFilipino: 'Makaharing korona sa profile',
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
      nameFilipino: 'Bituing Mag-aaral',
      descriptionFilipino: 'Ipakita mong ikaw ay kumikinang',
      cost: 15,
      type: ShopItemType.title,
      emoji: '🌟',
      color: Color(0xFFFFF176),
    ),
    ShopItem(
      id: 'title_word_wizard',
      name: 'Word Wizard',
      description: 'A master of vocabulary',
      nameFilipino: 'Salamangkero ng Salita',
      descriptionFilipino: 'Dalubhasa sa talasalitaan',
      cost: 25,
      type: ShopItemType.title,
      emoji: '🧙',
      color: Color(0xFFCE93D8),
    ),
    ShopItem(
      id: 'title_speed_learner',
      name: 'Speed Learner',
      description: 'Learn faster than anyone',
      nameFilipino: 'Mabilis Matuto',
      descriptionFilipino: 'Matuto nang mas mabilis kaysa kanino man',
      cost: 30,
      type: ShopItemType.title,
      emoji: '⚡',
      color: Color(0xFFFFD54F),
    ),
    ShopItem(
      id: 'title_bookworm',
      name: 'Bookworm',
      description: 'Always reading and learning',
      nameFilipino: 'Palabasa',
      descriptionFilipino: 'Laging nagbabasa at natututo',
      cost: 20,
      type: ShopItemType.title,
      emoji: '📚',
      color: Color(0xFFA5D6A7),
    ),

    // ─── Sound Packs ────────────────────────────────
    // Withdrawn from sale: `assets/sounds/` holds one set of effects and no
    // per-pack variants, so equipping any of these changed nothing an ear
    // could detect. They stay in the catalogue (rather than being deleted) so
    // owners can be refunded by id and so adding the audio is a one-word
    // change here — set `available: true` once the files exist.
    ShopItem(
      id: 'sound_chiptune',
      name: 'Chiptune Pack',
      description: 'Retro 8-bit sound effects',
      nameFilipino: 'Chiptune Pack',
      descriptionFilipino: 'Retro na 8-bit na tunog',
      cost: 20,
      type: ShopItemType.soundPack,
      emoji: '🎮',
      color: Color(0xFF80DEEA),
      available: false,
    ),
    ShopItem(
      id: 'sound_nature',
      name: 'Nature Pack',
      description: 'Calming nature sounds',
      nameFilipino: 'Pack ng Kalikasan',
      descriptionFilipino: 'Mga nakakakalmang tunog ng kalikasan',
      cost: 20,
      type: ShopItemType.soundPack,
      emoji: '🌿',
      color: Color(0xFFC5E1A5),
      available: false,
    ),
    ShopItem(
      id: 'sound_space',
      name: 'Space Pack',
      description: 'Futuristic space sounds',
      nameFilipino: 'Pack ng Kalawakan',
      descriptionFilipino: 'Makabagong tunog ng kalawakan',
      cost: 30,
      type: ShopItemType.soundPack,
      emoji: '🚀',
      color: Color(0xFFB39DDB),
      available: false,
    ),

    // ─── Celebration Animations ─────────────────────
    ShopItem(
      id: 'celebration_fireworks',
      name: 'Fireworks',
      description: 'Explosive fireworks celebration',
      nameFilipino: 'Paputok',
      descriptionFilipino: 'Pagdiriwang na may paputok',
      cost: 25,
      type: ShopItemType.celebration,
      emoji: '🎆',
      color: Color(0xFFEF9A9A),
    ),
    ShopItem(
      id: 'celebration_rainbow',
      name: 'Rainbow Burst',
      description: 'A rainbow celebration effect',
      nameFilipino: 'Sabog na Bahaghari',
      descriptionFilipino: 'Epektong pagdiriwang na bahaghari',
      cost: 25,
      type: ShopItemType.celebration,
      emoji: '🌈',
      color: Color(0xFFF48FB1),
    ),
    ShopItem(
      id: 'celebration_snow',
      name: 'Snowfall',
      description: 'Gentle snowflake animation',
      nameFilipino: 'Pag-ulan ng Niyebe',
      descriptionFilipino: 'Marahang animation ng niyebe',
      cost: 35,
      type: ShopItemType.celebration,
      emoji: '❄️',
      color: Color(0xFFB3E5FC),
    ),
  ];

  /// Every item of [type], sold or withdrawn. Use [sellableByType] for
  /// anything the learner is shown.
  static List<ShopItem> byType(ShopItemType type) =>
      allItems.where((item) => item.type == type).toList();

  /// The items of [type] that are actually on sale.
  static List<ShopItem> sellableByType(ShopItemType type) =>
      allItems.where((item) => item.type == type && item.available).toList();

  /// Categories with at least one item on sale — the tabs the shop shows.
  /// A category whose items are all withdrawn disappears rather than
  /// presenting an empty shelf.
  static List<ShopItemType> get sellableTypes => ShopItemType.values
      .where((type) => sellableByType(type).isNotEmpty)
      .toList();

  /// Ids of items no longer on sale. Anyone holding one gets refunded.
  static Set<String> get withdrawnIds =>
      allItems.where((item) => !item.available).map((item) => item.id).toSet();

  static ShopItem? findById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
