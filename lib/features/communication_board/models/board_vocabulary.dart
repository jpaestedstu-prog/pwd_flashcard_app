import 'board_models.dart';
import 'board_presentation.dart';
import 'board_seed_data.dart';
import 'custom_board.dart';

/// Every word one learner can reach on Talk Board, and the order of the tabs
/// that hold them.
///
/// [BoardPresentation] decides which *seed* categories a learner gets;
/// [CustomBoard] is the tab they (or their adult) built. Splicing the two is
/// its own job because it is where the ordering and lookup rules live, and
/// getting them wrong is invisible until a learner's own word will not speak:
///
///   * The custom tab leads. It is the learner's curated set — the whole point
///     is that the words they need most are not two tabs away.
///   * It appears only when it has tiles. An empty tab is worse than none: the
///     gaze cursor can still land on it, and blink-to-next-category would
///     strand a hands-free learner on a blank grid.
///   * [byId] consults custom tiles *first*, then the seed. Saved phrases
///     persist ids, so a phrase containing "Ate Maria" has to resolve through
///     the same lookup that built it.
///
/// Pure — no Flutter, no Hive — so the whole splice is unit-testable.
class BoardVocabulary {
  final BoardPresentation presentation;
  final CustomBoard customBoard;

  const BoardVocabulary({
    required this.presentation,
    required this.customBoard,
  });

  /// A vocabulary with no custom tab, for callers that only have a policy.
  factory BoardVocabulary.seedOnly(BoardPresentation presentation) =>
      BoardVocabulary(
        presentation: presentation,
        customBoard: CustomBoard.empty(),
      );

  /// Whether this learner has a board of their own worth showing.
  bool get hasCustomTab => customBoard.isNotEmpty;

  /// The tabs, in display order. Never empty.
  List<BoardTileCategory> get categories => [
        if (hasCustomTab) BoardTileCategory.custom,
        ...presentation.categories,
      ];

  /// The tiles behind [category].
  ///
  /// The custom tab is deliberately *not* subject to
  /// `BoardPresentation.maxTilesPerCategory`: that cap trims a 58-tile seed
  /// catalogue nobody curated, whereas this board is exactly what an adult
  /// chose for this learner. Silently hiding the last two tiles they added
  /// would look like the save had failed.
  List<BoardTile> tilesFor(BoardTileCategory category) {
    if (category == BoardTileCategory.custom) return customBoard.resolvedTiles;
    return presentation.tilesFor(category);
  }

  /// The tile with [id], from this learner's own board or the seed data.
  BoardTile? byId(String id) =>
      customBoard.customTileById(id) ?? BoardSeedData.byId(id);

  /// The tab label — the board's own name for the custom tab, the category
  /// name otherwise.
  String labelFor(BoardTileCategory category, {required bool useFilipino}) {
    if (category == BoardTileCategory.custom) return customBoard.name;
    return useFilipino ? category.labelFil : category.label;
  }

  /// The tab after [current], wrapping. Drives the gaze blink gesture.
  BoardTileCategory nextCategory(BoardTileCategory current) {
    final tabs = categories;
    final i = tabs.indexOf(current);
    if (i == -1) return tabs.first;
    return tabs[(i + 1) % tabs.length];
  }

  /// [current] if this learner still has that tab, otherwise the first they do.
  ///
  /// The case that matters: an adult empties the custom board while the
  /// learner is sitting on that tab. Without this the board would render a
  /// grid of nothing with no way back but a tab tap.
  BoardTileCategory resolveCategory(BoardTileCategory? current) {
    final tabs = categories;
    if (current != null && tabs.contains(current)) return current;
    return tabs.first;
  }
}
