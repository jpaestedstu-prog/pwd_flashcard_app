import 'board_models.dart';

/// One sentence a learner has actually said on the Talk Board.
///
/// AAC is overwhelmingly repetitive — a learner says "I need help", "bathroom"
/// and "I am finished" dozens of times a day and a handful of other things
/// ever. Until now the board threw every sentence away the moment the learner
/// navigated back, so those dozen taps had to be repeated from scratch each
/// time; for a gaze learner that is a minute of dwell-selecting to ask to go
/// to the toilet.
///
/// Stored as tile **ids** rather than rendered text so a phrase saved in
/// English still reads (and speaks) correctly after the learner flips the
/// board to Filipino.
class SavedPhrase {
  /// Stable identity: the tile ids joined, so saying the same sentence twice
  /// bumps one entry instead of growing the list.
  final String id;

  /// The tiles in order. Ids the vocabulary can no longer answer are dropped
  /// at read time rather than stored-through, so neither a future seed edit
  /// nor a deleted custom tile can resurrect a word that is gone.
  final List<String> tileIds;

  /// When it was last spoken — the sort key for recents.
  final DateTime lastUsedAt;

  /// How many times it has been spoken. Shown to nobody; it is the tiebreak
  /// that keeps a genuinely frequent phrase ahead of a one-off.
  final int useCount;

  /// Pinned by the learner (or their teacher) to the front of the strip.
  ///
  /// Pinned phrases are never evicted by [kMaxRecentPhrases]; that cap only
  /// trims the automatic recents behind them.
  final bool pinned;

  const SavedPhrase({
    required this.id,
    required this.tileIds,
    required this.lastUsedAt,
    this.useCount = 1,
    this.pinned = false,
  });

  /// The identity a sentence of [tiles] would have.
  static String idFor(Iterable<BoardTile> tiles) =>
      tiles.map((t) => t.id).join('+');

  factory SavedPhrase.fromTiles(
    List<BoardTile> tiles, {
    required DateTime now,
    bool pinned = false,
  }) {
    return SavedPhrase(
      id: idFor(tiles),
      tileIds: tiles.map((t) => t.id).toList(),
      lastUsedAt: now,
      pinned: pinned,
    );
  }

  /// The tiles this phrase resolves to, skipping any id [lookup] cannot
  /// answer. Empty when every tile has been removed — callers treat that as a
  /// dead phrase and hide it.
  ///
  /// The lookup is required rather than defaulting to [BoardSeedData.byId]
  /// precisely because a phrase may contain the learner's *own* words: a
  /// convenient seed-only default would have silently dropped "Ate Maria" out
  /// of every saved phrase that used her, and the phrase would still have
  /// rendered — just one word shorter.
  List<BoardTile> resolve(BoardTileLookup lookup) {
    final out = <BoardTile>[];
    for (final id in tileIds) {
      final tile = lookup(id);
      if (tile != null) out.add(tile);
    }
    return out;
  }

  SavedPhrase copyWith({
    DateTime? lastUsedAt,
    int? useCount,
    bool? pinned,
  }) {
    return SavedPhrase(
      id: id,
      tileIds: tileIds,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tileIds': tileIds,
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'useCount': useCount,
    'pinned': pinned,
  };

  /// Tolerant of a malformed row: the caller drops anything that throws, so a
  /// single corrupt entry cannot empty a learner's whole phrase list.
  factory SavedPhrase.fromJson(Map<String, dynamic> json) {
    return SavedPhrase(
      id: json['id'] as String,
      tileIds: (json['tileIds'] as List).map((e) => e as String).toList(),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      useCount: (json['useCount'] as num?)?.toInt() ?? 1,
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

/// Resolves a tile id to a tile. `BoardVocabulary.byId` is the real one.
typedef BoardTileLookup = BoardTile? Function(String id);

/// How many unpinned recents to keep. Pinned phrases sit outside this cap.
///
/// Ten is roughly one screen of chips; past that the strip becomes its own
/// scrolling wall of choice, which is the exact problem
/// `BoardPresentation.maxTilesPerCategory` exists to avoid on the grid below.
const int kMaxRecentPhrases = 10;

/// Applies the ordering and the recents cap to [phrases].
///
/// Pure and separate from the store so the eviction rule — the part that can
/// silently lose a learner's pinned phrase if it is wrong — is unit-testable
/// without Hive. Pinned first (most recent of them first), then recents by
/// recency, then use count as the tiebreak.
List<SavedPhrase> orderAndCapPhrases(List<SavedPhrase> phrases) {
  int byRecency(SavedPhrase a, SavedPhrase b) {
    final t = b.lastUsedAt.compareTo(a.lastUsedAt);
    return t != 0 ? t : b.useCount.compareTo(a.useCount);
  }

  final pinned = phrases.where((p) => p.pinned).toList()..sort(byRecency);
  final recent = phrases.where((p) => !p.pinned).toList()..sort(byRecency);

  return [
    ...pinned,
    ...recent.take(kMaxRecentPhrases),
  ];
}
