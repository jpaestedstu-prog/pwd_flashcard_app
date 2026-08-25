// Models for the AAC (Augmentative & Alternative Communication) Board.
// The board lets non-verbal or speech-impaired PWD students build
// sentences by tapping picture tiles, which are then spoken aloud via TTS.

/// A single tile on the communication board.
///
/// Seed tiles are `const` entries in [BoardSeedData]; custom tiles are authored
/// by a learner's adult in the board builder, carry [BoardTileCategory.custom]
/// and a `c_`-prefixed id, and are persisted per profile.
class BoardTile {
  final String id;
  final String label;       // Display text (English)
  final String labelFil;    // Display text (Filipino)
  final String emoji;       // Emoji for visual representation
  final BoardTileCategory category;

  const BoardTile({
    required this.id,
    required this.label,
    required this.labelFil,
    required this.emoji,
    required this.category,
  });

  /// True for a tile someone authored in the builder rather than one shipped
  /// in [BoardSeedData].
  bool get isCustom => category == BoardTileCategory.custom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'labelFil': labelFil,
    'emoji': emoji,
    // By name, not index: a category appended to the enum later must not
    // silently re-point every stored tile.
    'category': category.name,
  };

  /// Throws on a malformed row; callers drop what throws so one bad tile
  /// cannot cost a learner their whole board.
  factory BoardTile.fromJson(Map<String, dynamic> json) {
    final name = json['category'] as String?;
    return BoardTile(
      id: json['id'] as String,
      label: json['label'] as String,
      labelFil: json['labelFil'] as String,
      emoji: json['emoji'] as String,
      category: BoardTileCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => BoardTileCategory.custom,
      ),
    );
  }
}

/// Categories for organising communication tiles.
enum BoardTileCategory {
  greetings,
  needs,
  feelings,
  actions,
  people,
  places,
  food,
  responses,
  // Appended last, and deliberately NOT part of [BoardTileCategoryX.seedValues]:
  // this is the learner's own board, which only exists once someone has built
  // one. Every "the whole board" list must use `seedValues`, never `values`,
  // or a learner with no custom tiles gets an empty tab they can still land on.
  custom,
}

extension BoardTileCategoryX on BoardTileCategory {
  /// The categories that ship with the app — everything except
  /// [BoardTileCategory.custom].
  static const List<BoardTileCategory> seedValues = [
    BoardTileCategory.greetings,
    BoardTileCategory.needs,
    BoardTileCategory.feelings,
    BoardTileCategory.actions,
    BoardTileCategory.people,
    BoardTileCategory.places,
    BoardTileCategory.food,
    BoardTileCategory.responses,
  ];

  /// Fallback label for the custom tab; the real one is the board's own name,
  /// supplied by `BoardVocabulary.labelFor`.
  String get label => switch (this) {
    BoardTileCategory.greetings => 'Greetings',
    BoardTileCategory.needs    => 'Needs',
    BoardTileCategory.feelings => 'Feelings',
    BoardTileCategory.actions  => 'Actions',
    BoardTileCategory.people   => 'People',
    BoardTileCategory.places   => 'Places',
    BoardTileCategory.food     => 'Food',
    BoardTileCategory.responses => 'Responses',
    BoardTileCategory.custom => 'My Board',
  };

  String get labelFil => switch (this) {
    BoardTileCategory.greetings => 'Pagbati',
    BoardTileCategory.needs    => 'Pangangailangan',
    BoardTileCategory.feelings => 'Damdamin',
    BoardTileCategory.actions  => 'Aksyon',
    BoardTileCategory.people   => 'Tao',
    BoardTileCategory.places   => 'Lugar',
    BoardTileCategory.food     => 'Pagkain',
    BoardTileCategory.responses => 'Tugon',
    BoardTileCategory.custom => 'Aking Board',
  };

  String get emoji => switch (this) {
    BoardTileCategory.greetings => '👋',
    BoardTileCategory.needs    => '🙏',
    BoardTileCategory.feelings => '😊',
    BoardTileCategory.actions  => '🏃',
    BoardTileCategory.people   => '👨‍👩‍👧',
    BoardTileCategory.places   => '🏫',
    BoardTileCategory.food     => '🍎',
    BoardTileCategory.responses => '✅',
    BoardTileCategory.custom => '⭐',
  };
}
