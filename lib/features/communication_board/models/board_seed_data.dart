import 'board_models.dart';

/// Seed data for the AAC Communication Board.
/// Provides a curated set of commonly-used tiles appropriate for
/// PWD students learning English/Filipino in a classroom setting.
class BoardSeedData {
  BoardSeedData._();

  static const List<BoardTile> allTiles = [
    // ─── Greetings ──────────────────────────────────
    BoardTile(id: 'g01', label: 'Hello',        labelFil: 'Kamusta',       emoji: '👋', category: BoardTileCategory.greetings),
    BoardTile(id: 'g02', label: 'Good morning',  labelFil: 'Magandang umaga', emoji: '🌅', category: BoardTileCategory.greetings),
    BoardTile(id: 'g03', label: 'Good afternoon', labelFil: 'Magandang hapon', emoji: '☀️', category: BoardTileCategory.greetings),
    BoardTile(id: 'g04', label: 'Goodbye',       labelFil: 'Paalam',       emoji: '👋', category: BoardTileCategory.greetings),
    BoardTile(id: 'g05', label: 'Thank you',     labelFil: 'Salamat',      emoji: '🙏', category: BoardTileCategory.greetings),
    BoardTile(id: 'g06', label: 'Please',        labelFil: 'Pakiusap',     emoji: '🤲', category: BoardTileCategory.greetings),

    // ─── Needs ──────────────────────────────────────
    BoardTile(id: 'n01', label: 'I need help',   labelFil: 'Kailangan ko ng tulong', emoji: '🆘', category: BoardTileCategory.needs),
    BoardTile(id: 'n02', label: 'I am hungry',   labelFil: 'Gutom ako',    emoji: '🍽️', category: BoardTileCategory.needs),
    BoardTile(id: 'n03', label: 'I am thirsty',  labelFil: 'Nauuhaw ako',  emoji: '💧', category: BoardTileCategory.needs),
    BoardTile(id: 'n04', label: 'I want to rest', labelFil: 'Gusto kong magpahinga', emoji: '😴', category: BoardTileCategory.needs),
    BoardTile(id: 'n05', label: 'Bathroom',      labelFil: 'Banyo',        emoji: '🚻', category: BoardTileCategory.needs),
    BoardTile(id: 'n06', label: 'I am sick',     labelFil: 'May sakit ako', emoji: '🤒', category: BoardTileCategory.needs),
    BoardTile(id: 'n07', label: 'I am hurt',     labelFil: 'Masakit',      emoji: '🩹', category: BoardTileCategory.needs),
    BoardTile(id: 'n08', label: 'I need water',  labelFil: 'Kailangan ko ng tubig', emoji: '🥤', category: BoardTileCategory.needs),

    // ─── Feelings ───────────────────────────────────
    BoardTile(id: 'f01', label: 'I am happy',    labelFil: 'Masaya ako',   emoji: '😊', category: BoardTileCategory.feelings),
    BoardTile(id: 'f02', label: 'I am sad',      labelFil: 'Malungkot ako', emoji: '😢', category: BoardTileCategory.feelings),
    BoardTile(id: 'f03', label: 'I am scared',   labelFil: 'Takot ako',    emoji: '😨', category: BoardTileCategory.feelings),
    BoardTile(id: 'f04', label: 'I am angry',    labelFil: 'Galit ako',    emoji: '😠', category: BoardTileCategory.feelings),
    BoardTile(id: 'f05', label: 'I am tired',    labelFil: 'Pagod ako',    emoji: '😫', category: BoardTileCategory.feelings),
    BoardTile(id: 'f06', label: 'I am excited',  labelFil: 'Nasasabik ako', emoji: '🤩', category: BoardTileCategory.feelings),
    BoardTile(id: 'f07', label: 'I am confused',  labelFil: 'Nalilito ako', emoji: '😕', category: BoardTileCategory.feelings),
    BoardTile(id: 'f08', label: 'I feel good',   labelFil: 'Ayos lang ako', emoji: '👍', category: BoardTileCategory.feelings),

    // ─── Actions ────────────────────────────────────
    BoardTile(id: 'a01', label: 'I want to play', labelFil: 'Gusto kong maglaro', emoji: '🎮', category: BoardTileCategory.actions),
    BoardTile(id: 'a02', label: 'I want to read', labelFil: 'Gusto kong magbasa', emoji: '📖', category: BoardTileCategory.actions),
    BoardTile(id: 'a03', label: 'I want to eat',  labelFil: 'Gusto kong kumain', emoji: '🍴', category: BoardTileCategory.actions),
    BoardTile(id: 'a04', label: 'I want to drink', labelFil: 'Gusto kong uminom', emoji: '🥛', category: BoardTileCategory.actions),
    BoardTile(id: 'a05', label: 'I want to go',  labelFil: 'Gusto kong pumunta', emoji: '🚶', category: BoardTileCategory.actions),
    BoardTile(id: 'a06', label: 'I want to learn', labelFil: 'Gusto kong matuto', emoji: '📝', category: BoardTileCategory.actions),
    BoardTile(id: 'a07', label: 'I want to sing', labelFil: 'Gusto kong kumanta', emoji: '🎵', category: BoardTileCategory.actions),
    BoardTile(id: 'a08', label: 'I want to draw', labelFil: 'Gusto kong gumuhit', emoji: '🎨', category: BoardTileCategory.actions),

    // ─── People ─────────────────────────────────────
    BoardTile(id: 'p01', label: 'Teacher',       labelFil: 'Guro',         emoji: '👩‍🏫', category: BoardTileCategory.people),
    BoardTile(id: 'p02', label: 'Friend',        labelFil: 'Kaibigan',     emoji: '🧑‍🤝‍🧑', category: BoardTileCategory.people),
    BoardTile(id: 'p03', label: 'Mom',           labelFil: 'Nanay',        emoji: '👩', category: BoardTileCategory.people),
    BoardTile(id: 'p04', label: 'Dad',           labelFil: 'Tatay',        emoji: '👨', category: BoardTileCategory.people),
    BoardTile(id: 'p05', label: 'Brother',       labelFil: 'Kuya',         emoji: '👦', category: BoardTileCategory.people),
    BoardTile(id: 'p06', label: 'Sister',        labelFil: 'Ate',          emoji: '👧', category: BoardTileCategory.people),

    // ─── Places ─────────────────────────────────────
    BoardTile(id: 'l01', label: 'School',        labelFil: 'Paaralan',     emoji: '🏫', category: BoardTileCategory.places),
    BoardTile(id: 'l02', label: 'Home',          labelFil: 'Bahay',        emoji: '🏠', category: BoardTileCategory.places),
    BoardTile(id: 'l03', label: 'Playground',    labelFil: 'Palaruan',     emoji: '🛝', category: BoardTileCategory.places),
    BoardTile(id: 'l04', label: 'Hospital',      labelFil: 'Ospital',      emoji: '🏥', category: BoardTileCategory.places),
    BoardTile(id: 'l05', label: 'Store',         labelFil: 'Tindahan',     emoji: '🏪', category: BoardTileCategory.places),
    BoardTile(id: 'l06', label: 'Church',        labelFil: 'Simbahan',     emoji: '⛪', category: BoardTileCategory.places),

    // ─── Food ───────────────────────────────────────
    BoardTile(id: 'd01', label: 'Rice',          labelFil: 'Kanin',        emoji: '🍚', category: BoardTileCategory.food),
    BoardTile(id: 'd02', label: 'Bread',         labelFil: 'Tinapay',      emoji: '🍞', category: BoardTileCategory.food),
    BoardTile(id: 'd03', label: 'Milk',          labelFil: 'Gatas',        emoji: '🥛', category: BoardTileCategory.food),
    BoardTile(id: 'd04', label: 'Fruit',         labelFil: 'Prutas',       emoji: '🍎', category: BoardTileCategory.food),
    BoardTile(id: 'd05', label: 'Water',         labelFil: 'Tubig',        emoji: '💧', category: BoardTileCategory.food),
    BoardTile(id: 'd06', label: 'Juice',         labelFil: 'Juice',        emoji: '🧃', category: BoardTileCategory.food),

    // ─── Responses ──────────────────────────────────
    BoardTile(id: 'r01', label: 'Yes',           labelFil: 'Oo',           emoji: '✅', category: BoardTileCategory.responses),
    BoardTile(id: 'r02', label: 'No',            labelFil: 'Hindi',        emoji: '❌', category: BoardTileCategory.responses),
    BoardTile(id: 'r03', label: 'I don\'t know', labelFil: 'Hindi ko alam', emoji: '🤷', category: BoardTileCategory.responses),
    BoardTile(id: 'r04', label: 'More',          labelFil: 'Dagdag pa',    emoji: '➕', category: BoardTileCategory.responses),
    BoardTile(id: 'r05', label: 'Stop',          labelFil: 'Tigil',        emoji: '🛑', category: BoardTileCategory.responses),
    BoardTile(id: 'r06', label: 'Wait',          labelFil: 'Sandali lang', emoji: '⏳', category: BoardTileCategory.responses),
    BoardTile(id: 'r07', label: 'Again',         labelFil: 'Ulit',         emoji: '🔁', category: BoardTileCategory.responses),
    BoardTile(id: 'r08', label: 'Finished',      labelFil: 'Tapos na',     emoji: '🏁', category: BoardTileCategory.responses),
  ];

  /// Tiles grouped by category.
  static Map<BoardTileCategory, List<BoardTile>> get byCategory {
    final map = <BoardTileCategory, List<BoardTile>>{};
    for (final tile in allTiles) {
      (map[tile.category] ??= []).add(tile);
    }
    return map;
  }

  /// Tiles for a specific category.
  static List<BoardTile> forCategory(BoardTileCategory category) {
    return allTiles.where((t) => t.category == category).toList();
  }
}
