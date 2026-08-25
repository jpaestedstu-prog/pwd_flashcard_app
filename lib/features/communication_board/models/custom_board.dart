import 'dart:math';

import 'board_models.dart';
import 'board_seed_data.dart';

/// A learner's own Talk Board tab: the tiles they personally need, in the
/// order they want them.
///
/// Two kinds of entry live in one ordered list:
///
///   * **Seed references** — an id like `n01` that resolves through
///     [BoardSeedData]. Lets an adult pull "I need help" and "Bathroom" to the
///     front instead of making the learner walk two tabs to reach them.
///   * **Custom tiles** — words the seed data cannot know: "Ate Maria",
///     "Sir Kevin", the name of this particular school. These carry a
///     `c_`-prefixed id, live in [customTiles], and are the reason this
///     feature exists — a board that cannot say the learner's own teacher's
///     name is not their board.
///
/// [tileIds] is the single source of truth for *order and membership*;
/// [customTiles] is a lookup table for the ids in it that no seed can answer.
/// [normalized] keeps the two consistent.
class CustomBoard {
  /// Shown as the tab label on Talk Board, so it is the learner's word for
  /// their own board, not a filename.
  final String name;

  /// Ordered tile ids — seed ids and `c_` ids mixed.
  final List<String> tileIds;

  /// The tiles this board invented, keyed into by [tileIds].
  final List<BoardTile> customTiles;

  final DateTime updatedAt;

  const CustomBoard({
    required this.name,
    required this.tileIds,
    required this.customTiles,
    required this.updatedAt,
  });

  static const String defaultName = 'My Board';

  /// The board a profile has before anyone has built one.
  static CustomBoard empty({DateTime? at}) => CustomBoard(
        name: defaultName,
        tileIds: const [],
        customTiles: const [],
        updatedAt: at ?? DateTime(2000),
      );

  /// True when there is nothing to show — Talk Board hides the tab entirely
  /// rather than offering an empty one the gaze cursor can still land on.
  bool get isEmpty => resolvedTiles.isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, BoardTile> get _customById => {
        for (final t in customTiles) t.id: t,
      };

  /// The tile with [id] if this board owns a custom one by that name.
  BoardTile? customTileById(String id) => _customById[id];

  /// The board's tiles in order, dropping any id that no longer resolves.
  ///
  /// A seed tile retired from [BoardSeedData] and a custom tile deleted from
  /// [customTiles] both vanish here rather than rendering as a blank cell.
  List<BoardTile> get resolvedTiles {
    final custom = _customById;
    final out = <BoardTile>[];
    for (final id in tileIds) {
      final tile = custom[id] ?? BoardSeedData.byId(id);
      if (tile != null) out.add(tile);
    }
    return out;
  }

  /// A copy with [tileIds] de-duplicated and truncated to
  /// [kMaxCustomBoardTiles], and orphaned [customTiles] dropped.
  ///
  /// Orphan pruning matters: a custom tile removed from the board would
  /// otherwise sit in storage forever, and — worse — keep resolving inside old
  /// saved phrases, so a word the adult deleted would still be sayable.
  CustomBoard get normalized {
    final seen = <String>{};
    final ids = <String>[];
    for (final id in tileIds) {
      if (seen.add(id)) ids.add(id);
      if (ids.length >= kMaxCustomBoardTiles) break;
    }
    final kept = ids.toSet();
    return CustomBoard(
      name: name.trim().isEmpty ? defaultName : name.trim(),
      tileIds: ids,
      customTiles: [
        for (final t in customTiles)
          if (kept.contains(t.id)) t,
      ],
      updatedAt: updatedAt,
    );
  }

  CustomBoard copyWith({
    String? name,
    List<String>? tileIds,
    List<BoardTile>? customTiles,
    DateTime? updatedAt,
  }) {
    return CustomBoard(
      name: name ?? this.name,
      tileIds: tileIds ?? this.tileIds,
      customTiles: customTiles ?? this.customTiles,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tileIds': tileIds,
        'customTiles': customTiles.map((t) => t.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Tolerant: a row whose custom-tile list is partly corrupt still yields the
  /// tiles that did parse, and the ids pointing at the broken ones simply stop
  /// resolving.
  factory CustomBoard.fromJson(Map<String, dynamic> json) {
    final tiles = <BoardTile>[];
    for (final raw in (json['customTiles'] as List? ?? const [])) {
      try {
        tiles.add(BoardTile.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (_) {
        continue;
      }
    }
    return CustomBoard(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : defaultName,
      tileIds: [
        for (final id in (json['tileIds'] as List? ?? const []))
          if (id is String) id,
      ],
      customTiles: tiles,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              DateTime(2000),
    );
  }
}

/// Cap on how many tiles one custom board may hold.
///
/// The builder's own grid was already capped at 24; the same number here keeps
/// the tab a browsable page rather than a second wall of vocabulary, which is
/// the thing `BoardPresentation.maxTilesPerCategory` exists to prevent.
const int kMaxCustomBoardTiles = 24;

/// Longest a custom tile's label may be.
///
/// Board tiles render the label at `maxLines: 2` in small type, so anything
/// past this is ellipsised into uselessness — better to refuse it in the
/// builder, where the adult can shorten it, than to silently truncate it on
/// the learner's board.
const int kMaxCustomTileLabel = 24;

/// The `c_` prefix that separates an authored tile from a seed id.
///
/// Seed ids are two letters plus digits (`g01`, `n05`, `r08`), so the prefix
/// cannot collide, and `BoardVocabulary.byId` can consult one map or the other
/// without ambiguity.
const String kCustomTileIdPrefix = 'c_';

final Random _idRandom = Random();

/// A fresh id for an authored tile.
///
/// Time plus randomness rather than a counter: two devices editing the same
/// profile's board offline must not both mint `c_3`.
String newCustomTileId({DateTime? now, Random? random}) {
  final at = (now ?? DateTime.now()).microsecondsSinceEpoch;
  final salt = (random ?? _idRandom).nextInt(1 << 20);
  return '$kCustomTileIdPrefix${at.toRadixString(36)}'
      '${salt.toRadixString(36)}';
}

/// Whether [id] names an authored tile rather than a seed one.
bool isCustomTileId(String id) => id.startsWith(kCustomTileIdPrefix);

/// Why a proposed custom tile cannot be created, or null when it is fine.
///
/// Pure and separate from the builder screen so the rules are testable without
/// pumping a widget — these are the messages an adult actually sees.
String? validateCustomTile({
  required String label,
  required String labelFil,
  required String emoji,
}) {
  final en = label.trim();
  final fil = labelFil.trim();
  if (en.isEmpty) return 'Enter the word in English.';
  if (en.length > kMaxCustomTileLabel) {
    return 'English word is too long (max $kMaxCustomTileLabel characters).';
  }
  if (fil.length > kMaxCustomTileLabel) {
    return 'Filipino word is too long (max $kMaxCustomTileLabel characters).';
  }
  if (emoji.trim().isEmpty) return 'Pick a picture for the tile.';
  return null;
}

/// Builds a tile from validated input.
///
/// An empty Filipino label falls back to the English one rather than being
/// stored blank: the board's FIL toggle would otherwise render an empty tile,
/// and the TTS would speak nothing at the one moment the learner needed it to.
BoardTile buildCustomTile({
  required String label,
  required String labelFil,
  required String emoji,
  String? id,
  DateTime? now,
  Random? random,
}) {
  final en = label.trim();
  final fil = labelFil.trim();
  return BoardTile(
    id: id ?? newCustomTileId(now: now, random: random),
    label: en,
    labelFil: fil.isEmpty ? en : fil,
    emoji: emoji.trim(),
    category: BoardTileCategory.custom,
  );
}

/// The picture palette offered when authoring a tile.
///
/// A fixed emoji set rather than a photo picker or a full emoji keyboard: it
/// renders identically on every device with no download and no permission
/// prompt, and it is short enough that an adult can scan it. Grouped roughly by
/// people, places, food, activity and feeling, which is where custom
/// vocabulary actually lands.
const List<String> kCustomTileEmoji = [
  // People
  '👩', '👨', '👧', '👦', '👵', '👴', '👩‍🏫', '👨‍🏫',
  '🧑‍🤝‍🧑', '👮', '👩‍⚕️', '🧑‍🍳', '👶', '🧕', '🙋', '🤝',
  // Places & things
  '🏫', '🏠', '🏥', '🏪', '⛪', '🚌', '🚗', '🛝',
  '🛏️', '🚪', '🪑', '📚', '✏️', '🎒', '📱', '🧸',
  // Food & drink
  '🍚', '🍞', '🍎', '🍌', '🥛', '💧', '🍜', '🍗',
  '🥚', '🍪', '🧃', '🍽️',
  // Activity
  '🎮', '⚽', '🎨', '🎵', '📖', '🏃', '🛁', '💤',
  '🧼', '🚻', '💊', '🩹',
  // Feeling & response
  '😊', '😢', '😠', '😨', '😴', '🤩', '👍', '👎',
  '✅', '❌', '❤️', '⭐',
];
