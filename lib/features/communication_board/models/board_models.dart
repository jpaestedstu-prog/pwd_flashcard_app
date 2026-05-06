// Models for the AAC (Augmentative & Alternative Communication) Board.
// The board lets non-verbal or speech-impaired PWD students build
// sentences by tapping picture tiles, which are then spoken aloud via TTS.

/// A single tile on the communication board.
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
}

extension BoardTileCategoryX on BoardTileCategory {
  String get label => switch (this) {
    BoardTileCategory.greetings => 'Greetings',
    BoardTileCategory.needs    => 'Needs',
    BoardTileCategory.feelings => 'Feelings',
    BoardTileCategory.actions  => 'Actions',
    BoardTileCategory.people   => 'People',
    BoardTileCategory.places   => 'Places',
    BoardTileCategory.food     => 'Food',
    BoardTileCategory.responses => 'Responses',
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
  };
}
