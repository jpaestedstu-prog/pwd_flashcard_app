import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// How much of the Progress tab a learner is shown.
///
///   * [essential] — the figures that answer "how am I doing?" and nothing
///     else. Chosen where a long, dense, number-heavy page is itself the
///     barrier (cognitive, multiple). Fewer sections, no wall of locked
///     badges, no chart dashboards.
///   * [full] — every section, including the star grid, the complete badge
///     wall, the weekly summary and the chart screens.
enum ProgressDepth { essential, full }

/// The presentation policy for the Progress tab, derived from the learner's
/// accessibility category ([DisabilityType]), their live [AppSettings], and
/// whether they are in Player mode.
///
/// The rest of this app already adapts per accessibility category — the games
/// roster (`GameCatalog`), the AI companion (`CompanionPresentation`), Play
/// Together (`RacePresentation`), the time's-up hand-off (`LockPresentation`).
/// Progress was the holdout: it rendered byte-identical for a Deaf learner, a
/// blind learner and a learner with a cognitive disability, gated only on
/// whether the FSL sections appeared.
///
/// What that cost, concretely:
///   * A learner with a cognitive/learning disability met ten sections, a
///     fifty-icon star grid and thirty-seven badges of which most are grey.
///     "How am I doing?" is not answered by more numbers.
///   * A blind or low-vision learner met a percentage ring and, one tap away,
///     seven charts — none of which say anything out loud. The figures were
///     all there; the modality was not.
///   * A Deaf learner's sign progress — the whole point of the app for them —
///     sat below reading.
///
/// Kept pure (no I/O, no BuildContext) so the whole adaptive matrix is
/// unit-testable, exactly like [CompanionPresentation].
class ProgressPresentation {
  final ProgressDepth depth;

  /// Offer a "Hear my progress" button that speaks a plain-language summary.
  /// This is the accessible equivalent of the mastery ring and the charts, so
  /// it is on wherever reading the screen may not be the easiest path.
  final bool speakSummary;

  /// Put the Sign Language section above Reading. For a Deaf learner sign
  /// production is the headline, not a footnote.
  final bool signFirst;

  /// Show the "This Week" section.
  final bool showWeekly;

  /// Show the Star Collection grid. It is decorative — the star *count* is
  /// already in the stat grid above it — so it is the first thing to go when
  /// the page needs to be shorter.
  final bool showStarGrid;

  /// Draw locked badges greyed-out alongside the earned ones. When off, only
  /// what the learner has actually earned is shown, plus a count.
  final bool showLockedAchievements;

  /// Offer the chart dashboards (Detailed Analytics, Adaptive Analytics).
  final bool showChartScreens;

  /// How many entries the Recent Games list shows.
  final int maxRecentGames;

  /// Run the staggered entrance animations.
  final bool animate;

  const ProgressPresentation({
    required this.depth,
    required this.speakSummary,
    required this.signFirst,
    required this.showWeekly,
    required this.showStarGrid,
    required this.showLockedAchievements,
    required this.showChartScreens,
    required this.maxRecentGames,
    required this.animate,
  });

  bool get isEssential => depth == ProgressDepth.essential;

  /// Derives the presentation for a learner.
  ///
  /// [isPlayerMode] keeps the existing Player rule intact: the class
  /// leaderboard and the analytics dashboards are not a guest's to see, and
  /// that decision is made here now rather than inline in the screen.
  factory ProgressPresentation.forProfile(
    DisabilityType type,
    AppSettings s, {
    bool isPlayerMode = false,
  }) {
    // Short page where length and density are the barrier. Motor and visual
    // profiles are deliberately *not* included: their barrier is input and
    // legibility, which shortening the page does not help and does cost them
    // information they can otherwise use.
    final depth =
        (type == DisabilityType.cognitive || type == DisabilityType.multiple)
        ? ProgressDepth.essential
        : ProgressDepth.full;
    final essential = depth == ProgressDepth.essential;

    // Spoken summary: for anyone already using text-to-speech, and always for
    // visual / multiple, where the ring and the charts carry meaning that has
    // no audible form. Mirrors `CompanionPresentation.announce`.
    final speakSummary =
        s.ttsEnabled ||
        type == DisabilityType.visual ||
        type == DisabilityType.multiple;

    return ProgressPresentation(
      depth: depth,
      speakSummary: speakSummary,
      signFirst: type == DisabilityType.hearing,
      showWeekly: !essential,
      showStarGrid: !essential,
      showLockedAchievements: !essential,
      showChartScreens: !essential && !isPlayerMode,
      maxRecentGames: essential ? 5 : 10,
      animate: !s.reducedMotion,
    );
  }
}

/// Progress presentation for the active learner.
final progressPresentationProvider = Provider<ProgressPresentation>((ref) {
  final profile = ref.watch(profileProvider);
  final settings = ref.watch(settingsProvider);
  return ProgressPresentation.forProfile(
    profile?.disabilityType ?? DisabilityType.none,
    settings,
    isPlayerMode: profile?.isPlayerMode ?? false,
  );
});
