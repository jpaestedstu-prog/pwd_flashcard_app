import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'board_models.dart';
import 'board_seed_data.dart';

/// How the Talk Board presents itself to one learner.
///
/// Talk Board was the last learner surface that looked byte-identical for
/// everyone: the same eight category tabs, the same 3-across emoji grid, the
/// same speak button, whether the learner was a sighted Player building a
/// sentence for fun or a non-verbal child with a cognitive disability trying
/// to say "bathroom".
///
/// Pure, like its siblings (`ComposerPresentation`, `RacePresentation`,
/// `ProgressPresentation`, `LockPresentation`): no Flutter, no I/O, one
/// factory, so the whole matrix is unit-testable and the board widgets read
/// flags instead of branching on [DisabilityType].
///
/// Rationale per category:
///
///   * **Visual** — the board is a grid of *emoji*, so nothing here is legible
///     without the screen reader. [speakOnTap] makes every added tile confirm
///     itself out loud (the long-press-to-hear gesture is undiscoverable when
///     you cannot see the tile), and the grid drops to two columns so each
///     target is large and the reader has half as many cells to sweep. The
///     large-text banner is omitted: it would be drawing for nobody.
///   * **Hearing (Deaf / HoH)** — synthesised speech is still exactly right
///     here, because a Deaf learner uses an AAC board to be understood by a
///     *hearing* listener. What was missing is the other half of that
///     exchange: [showSentenceBanner] renders the sentence in large type so
///     the learner can see what they are about to say and the listener can
///     read it when audio is not an option. [speakOnTap] stays off — a burst
///     of speech the learner cannot hear is feedback only to the room.
///   * **Motor** — two columns, because every extra column is another cell
///     the gaze cursor has to walk past and another small target for an
///     unsteady tap. [speakOnTap] stays off: a dwell-select is easy to
///     trigger by accident and should not blurt a word across the classroom.
///   * **Cognitive / multiple** — a wall of 58 tiles across 8 tabs is its own
///     barrier. The category set is trimmed to the four a board is actually
///     *for* (needs, responses, feelings, food), each capped at
///     [maxTilesPerCategory], and the sentence to [maxSentenceLength] — a
///     short, high-value core vocabulary rather than a menu. [speakOnTap] is
///     on so the cause-and-effect of a tap is immediate.
///   * **None** — everything, all eight categories, as before. This is what a
///     Player (With Progress) profile and an educator preview both get.
class BoardPresentation {
  /// Which **seed** category tabs are offered, in the order they should appear.
  ///
  /// Never empty, and never contains [BoardTileCategory.custom]: a learner's
  /// own board is not an accessibility decision, it is a thing that either
  /// exists or does not. `BoardVocabulary` is what splices it in.
  final List<BoardTileCategory> categories;

  /// Grid columns on a phone-width screen. A tablet gets one more.
  final int phoneColumns;

  /// Cap on the tiles shown inside one category, or null for all of them.
  final int? maxTilesPerCategory;

  /// Cap on how many tiles one sentence may hold.
  final int maxSentenceLength;

  /// Speak each tile aloud the moment it joins the sentence.
  final bool speakOnTap;

  /// Show the sentence again above the strip in large, high-contrast type.
  final bool showSentenceBanner;

  const BoardPresentation({
    required this.categories,
    required this.phoneColumns,
    required this.maxSentenceLength,
    required this.speakOnTap,
    required this.showSentenceBanner,
    this.maxTilesPerCategory,
  });

  /// Columns for the current screen width.
  int columns({required bool isTablet}) =>
      isTablet ? phoneColumns + 1 : phoneColumns;

  /// The tiles this learner sees in [category], honouring
  /// [maxTilesPerCategory].
  List<BoardTile> tilesFor(BoardTileCategory category) {
    final all = BoardSeedData.forCategory(category);
    final cap = maxTilesPerCategory;
    if (cap == null || all.length <= cap) return all;
    return all.sublist(0, cap);
  }

  /// The category after [current] in this learner's trimmed set, wrapping at
  /// the end. Drives the gaze blink-to-next-category gesture.
  ///
  /// Falls back to the first category when [current] is not on offer, which is
  /// how a board recovers if it is somehow left pointing at a trimmed-away tab.
  BoardTileCategory nextCategory(BoardTileCategory current) {
    final i = categories.indexOf(current);
    if (i == -1) return categories.first;
    return categories[(i + 1) % categories.length];
  }

  /// [current] if this learner has it, otherwise the first category they do.
  BoardTileCategory resolveCategory(BoardTileCategory? current) {
    if (current != null && categories.contains(current)) return current;
    return categories.first;
  }

  factory BoardPresentation.forType(DisabilityType type) {
    return switch (type) {
      DisabilityType.visual => const BoardPresentation(
        categories: BoardTileCategoryX.seedValues,
        phoneColumns: 2,
        maxSentenceLength: 12,
        speakOnTap: true,
        showSentenceBanner: false,
      ),
      DisabilityType.hearing => const BoardPresentation(
        categories: BoardTileCategoryX.seedValues,
        phoneColumns: 3,
        maxSentenceLength: 12,
        speakOnTap: false,
        showSentenceBanner: true,
      ),
      DisabilityType.motor => const BoardPresentation(
        categories: BoardTileCategoryX.seedValues,
        phoneColumns: 2,
        maxSentenceLength: 12,
        speakOnTap: false,
        showSentenceBanner: true,
      ),
      DisabilityType.cognitive || DisabilityType.multiple =>
        const BoardPresentation(
          categories: [
            BoardTileCategory.needs,
            BoardTileCategory.responses,
            BoardTileCategory.feelings,
            BoardTileCategory.food,
          ],
          phoneColumns: 2,
          maxTilesPerCategory: 6,
          maxSentenceLength: 4,
          speakOnTap: true,
          showSentenceBanner: true,
        ),
      DisabilityType.none => const BoardPresentation(
        categories: BoardTileCategoryX.seedValues,
        phoneColumns: 3,
        maxSentenceLength: 12,
        speakOnTap: false,
        showSentenceBanner: false,
      ),
    };
  }

  /// The board policy for [profile].
  ///
  /// Educators always get the full board regardless of their own profile: a
  /// teacher opening Talk Board is modelling it *for* a learner, and their own
  /// accessibility category should not trim the tabs they are demonstrating.
  /// Mirrors `ComposerPresentation.forProfile`.
  factory BoardPresentation.forProfile(UserProfile? profile) {
    if (profile == null) return BoardPresentation.forType(DisabilityType.none);
    if (!profile.role.isEnrollableLearner) {
      return BoardPresentation.forType(DisabilityType.none);
    }
    return BoardPresentation.forType(profile.disabilityType);
  }
}

/// The Talk Board policy for the signed-in profile.
final boardPresentationProvider = Provider<BoardPresentation>((ref) {
  return BoardPresentation.forProfile(ref.watch(profileProvider));
});

/// Grid cell aspect ratio (width / height) for a board tile at [textScale].
///
/// A tile stacks a 36 px emoji over up to two label lines, and both grow with
/// the OS font scale while a `SliverGridDelegateWithFixedCrossAxisCount` cell
/// does not — which is why the grid overflowed by 24 px at the 2.0x
/// accessibility scale on a 7" tablet. Falling ratio = taller cell = the label
/// still fits. Clamped at both ends so a big-font tile never becomes a narrow
/// ribbon and a normal one keeps its familiar shape.
double boardTileAspectRatio(double textScale) {
  final t = textScale.clamp(1.0, 2.0);
  return (0.9 - (t - 1.0) * 0.28).clamp(0.55, 0.9);
}
