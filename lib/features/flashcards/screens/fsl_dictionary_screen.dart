import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/fsl_loading_overlay.dart';
import '../../../widgets/fsl_video_sheet.dart';
import '../../../widgets/fullscreen_host.dart';
import '../widgets/fsl_offline_packs_sheet.dart';

/// Browse all flashcard words grouped by category and watch their
/// Filipino Sign Language (FSL) videos. Acts as a stand-alone
/// FSL dictionary independent of the flashcard viewer.
class FslDictionaryScreen extends ConsumerStatefulWidget {
  const FslDictionaryScreen({super.key});

  @override
  ConsumerState<FslDictionaryScreen> createState() =>
      _FslDictionaryScreenState();
}

class _FslDictionaryScreenState extends ConsumerState<FslDictionaryScreen> {
  FlashcardCategory? _selectedCategory;
  String _search = '';

  /// Hide the words that have no sign recorded. 35 of the 177 seed words are
  /// in that state — a whole fifth of the dictionary that can only ever answer
  /// a tap with "not yet" — so a learner who just wants to browse signs can
  /// take them out of the way.
  bool _signsOnly = false;

  /// Show only the learner's starred signs. 142 signs is a lot to scroll for
  /// the five you are practising this week.
  bool _favouritesOnly = false;

  /// The learner's starred signs, held in memory for the life of this screen.
  ///
  /// Seeded once in [initState] rather than re-read from Hive on every build —
  /// the grid asks about up to 177 cards, and every keystroke in the search
  /// field rebuilds. Switching profiles pops this route, so it cannot outlive
  /// its owner.
  final Set<String> _favourites = {};

  /// Current self-claims, held in state for the same reason as [_favourites]:
  /// the grid asks about every visible card on every keystroke.
  Map<String, SignMastery> _mastery = const {};

  /// Educator judgements, read-only here.
  Map<String, SignVerification> _verifications = const {};

  /// Show only the signs the learner says they can produce.
  bool _canSignOnly = false;

  @override
  void initState() {
    super.initState();
    final profileId = ref.read(profileProvider)?.id;
    if (profileId != null) {
      _favourites.addAll(HiveService.fslFavourites(profileId));
      _mastery = HiveService.fslMastery(profileId);
      _verifications = HiveService.fslVerifications(profileId);
    }
  }

  Future<void> _setMastery(Flashcard card, SignMastery next) async {
    final profileId = ref.read(profileProvider)?.id;
    if (profileId == null) return;
    await HiveService.setFslMastery(
      profileId,
      card.category.label,
      card.wordEnglish,
      next,
    );
    if (!mounted) return;
    setState(() => _mastery = HiveService.fslMastery(profileId));
    // The claim feeds the model (and, once an educator confirms it, XP), and
    // the notifier cannot see a static write.
    ref.read(progressProvider.notifier).refreshSignMastery();
  }

  Future<void> _toggleFavourite(Flashcard card) async {
    final profileId = ref.read(profileProvider)?.id;
    if (profileId == null) return;
    final key = HiveService.fslWordKey(card.category.label, card.wordEnglish);
    // Flip in memory first, then persist. A star that only lights up once a
    // disk write has come back reads as a dead control on a slow device, and
    // there is no failure here worth holding the UI for — the worst case is a
    // star that does not survive a kill in the next millisecond.
    setState(() {
      if (!_favourites.add(key)) _favourites.remove(key);
    });
    await HiveService.toggleFslFavourite(
      profileId,
      card.category.label,
      card.wordEnglish,
    );
  }

  /// True while a video is being resolved/downloaded. Only one video resolves
  /// at a time: taps on other cards are ignored while this is set, so several
  /// videos can't open or download simultaneously. Drives the full-screen
  /// loading overlay.
  bool _isResolving = false;

  Future<void> _openVideo(Flashcard card) async {
    if (_isResolving) return;

    // Nothing registered for this word (~35 of the 177 seed cards, all 20
    // Actions verbs among them) — answer immediately rather than flashing the
    // resolve overlay on a lookup that cannot succeed.
    if (!FslAssetsService.hasAnyVideoSource(card)) {
      await showFslUnavailableSheet(context, wordEnglish: card.wordEnglish);
      return;
    }

    setState(() => _isResolving = true);
    final source = await FslAssetsService.videoSourceFor(card);
    if (!mounted) return;
    setState(() => _isResolving = false);
    if (source == null) {
      // A clip IS registered, so the resolve failed rather than the sign being
      // missing — the learner is offline. Saying "no video yet" here would be
      // plainly wrong. And a sheet, not a SnackBar: this screen's audience is
      // learners who may never hear a transient toast and would just see a tap
      // that did nothing.
      await showFslUnavailableSheet(
        context,
        wordEnglish: card.wordEnglish,
        unreachable: true,
      );
      return;
    }
    final profileId = ref.read(profileProvider)?.id;
    if (profileId != null) {
      await HiveService.recordFslVideoView(
        profileId,
        card.category.label,
        card.wordEnglish,
      );
      // The write is a static call that the progress notifier cannot see, so
      // tell it — otherwise the Signs stat and the sign achievements sit a view
      // behind this screen's own counter.
      if (mounted) {
        ref.read(progressProvider.notifier).refreshSignsWatched();
      }
    }
    if (!mounted) return;
    final key = HiveService.fslWordKey(card.category.label, card.wordEnglish);
    await showFslVideoSheet(
      context,
      videoSource: source,
      wordEnglish: card.wordEnglish,
      wordFilipino: card.wordFilipino,
      mastery: _mastery[key] ?? SignMastery.notSet,
      verification: _verifications[key] ?? SignVerification.unreviewed,
      // Only the dictionary offers this: it is the one surface whose unit is a
      // single word the learner could actually be asked to produce.
      onMasteryChanged: (next) => _setMastery(card, next),
    );
    // The "N videos watched" tally is read straight from Hive during build, so
    // it only moves if something asks for a rebuild once the view is recorded.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final allCards = SeedData.allFlashcards;
    final profileId = ref.watch(profileProvider)?.id;
    // One availability resolve for the whole screen. Until it lands every card
    // renders as "no clip", which is also the correct state for the ~35 seed
    // words that genuinely have no sign recorded.
    final availability = ref.watch(fslAvailabilityProvider).valueOrNull;

    bool hasSign(Flashcard c) => availability?.hasVideo(c) ?? false;
    final totalSigns = availability?.cardsWithVideo.length ?? 0;
    final favourites = profileId == null ? const <String>{} : _favourites;
    bool isFavourite(Flashcard c) => favourites.contains(
      HiveService.fslWordKey(c.category.label, c.wordEnglish),
    );
    SignMastery masteryOf(Flashcard c) =>
        _mastery[HiveService.fslWordKey(c.category.label, c.wordEnglish)] ??
        SignMastery.notSet;
    final canSignCount = _mastery.values
        .where((m) => m == SignMastery.canSign)
        .length;

    // Filter by category, search, and the signs-only toggle
    var filtered = allCards.where((c) {
      if (_favouritesOnly && !isFavourite(c)) return false;
      if (_canSignOnly && masteryOf(c) != SignMastery.canSign) return false;
      if (_signsOnly && !hasSign(c)) return false;
      if (_selectedCategory != null && c.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return c.wordEnglish.toLowerCase().contains(q) ||
            c.wordFilipino.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort alphabetically
    filtered.sort(
      (a, b) =>
          a.wordEnglish.toLowerCase().compareTo(b.wordEnglish.toLowerCase()),
    );

    return Stack(
      children: [
        Scaffold(
          appBar: fullscreenBar(
            ref,
            AppBar(
              title: Text(
                AppLocalizations.of(context)!.fslDictionary,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => showFslOfflinePacksSheet(context),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  tooltip: 'Offline signs',
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchWords,
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: hc.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Category filter chips — height grows with text scale so the
                // chip labels never get clipped at Extra Large font size.
                SizedBox(
                  height: 42 * MediaQuery.textScalerOf(context).scale(1.0),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      // Signs-only comes first: it changes what every other
                      // chip means, and it is the filter a learner browsing
                      // signs actually wants.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: const Text('Has sign'),
                          avatar: Icon(
                            Icons.sign_language_rounded,
                            size: context.scaleIcon(16),
                          ),
                          selected: _signsOnly,
                          onSelected: (v) => setState(() => _signsOnly = v),
                          // A saturated fill with an explicit dark label.
                          // Material 3 does not recompute the label colour from
                          // `selectedColor`, so a pale fill kept the theme's
                          // light label and the selected chip was unreadable in
                          // the dark theme — checked on the tablet, not assumed.
                          selectedColor: AppColors.secondaryDark,
                          checkmarkColor: Colors.white,
                          labelStyle: _signsOnly
                              ? const TextStyle(color: Colors.white)
                              : null,
                        ),
                      ),
                      // Only offered once there is a profile to own the list.
                      if (profileId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text('My Signs · ${favourites.length}'),
                            avatar: Icon(
                              Icons.star_rounded,
                              size: context.scaleIcon(16),
                            ),
                            selected: _favouritesOnly,
                            onSelected: (v) =>
                                setState(() => _favouritesOnly = v),
                            selectedColor: AppColors.warningDark,
                            checkmarkColor: Colors.white,
                            labelStyle: _favouritesOnly
                                ? const TextStyle(color: Colors.white)
                                : null,
                          ),
                        ),
                      // Capability, kept visually apart from the amber
                      // bookmark chip beside it — different word, different
                      // icon, different colour, because the two are easy to
                      // conflate and mean quite different things.
                      if (profileId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text('I can sign · $canSignCount'),
                            avatar: Icon(
                              Icons.back_hand_rounded,
                              size: context.scaleIcon(16),
                            ),
                            selected: _canSignOnly,
                            onSelected: (v) => setState(() => _canSignOnly = v),
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: _canSignOnly
                                ? const TextStyle(color: Colors.white)
                                : null,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(AppLocalizations.of(context)!.all),
                          selected: _selectedCategory == null,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
                          selectedColor: AppColors.primaryLight,
                        ),
                      ),
                      ...FlashcardCategory.values.map((cat) {
                        final signs =
                            availability?.videoCountByCategory[cat] ?? 0;
                        // With signs-only on, a category that has none would
                        // filter to an empty grid — drop the chip rather than
                        // offer a dead end.
                        if (_signsOnly && signs == 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            // Coverage in the label: "Actions 0" is the honest
                            // answer to why that category is all crossed-out
                            // cameras, and it is the only place a learner can
                            // find out before tapping through 20 dead words.
                            label: Text('${cat.label} · $signs'),
                            avatar: Icon(cat.icon, size: context.scaleIcon(16)),
                            selected: _selectedCategory == cat,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                            selectedColor: cat.color.withValues(alpha: 0.3),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Stats. Both halves are Flexible so the row wraps its text
                // rather than overflowing at Extra Large font.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _plural(filtered.length, 'word'),
                          style: AppTypography.labelMedium.copyWith(
                            color: hc.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (profileId != null)
                        Flexible(
                          child: Text(
                            // Against the number of signs that exist, not the
                            // word count — 35 words have no clip, so "/177"
                            // would be a target nobody can reach.
                            '${HiveService.fslUniqueWordsViewed(profileId)}'
                            ' of $totalSigns signs watched',
                            textAlign: TextAlign.end,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Word grid — uses max-extent so columns reflow naturally on
                // phones (2), 10-inch tablets (3-4), and ultra-wide tablets
                // in landscape (5+). No need for breakpoint branching.
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.noWordsFound,
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                // Explicit height instead of an aspect ratio so
                                // the cell grows with the Font Size setting —
                                // see [_wordCardExtent].
                                mainAxisExtent: _wordCardExtent(context),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final card = filtered[index];
                            return _FslWordCard(
                                  card: card,
                                  hasVideo: hasSign(card),
                                  watched:
                                      profileId != null &&
                                      HiveService.hasViewedFslWord(
                                        profileId,
                                        card.category.label,
                                        card.wordEnglish,
                                      ),
                                  favourite: isFavourite(card),
                                  onToggleFavourite: profileId == null
                                      ? null
                                      : () => _toggleFavourite(card),
                                  onOpen: () => _openVideo(card),
                                )
                                .animate()
                                .fadeIn(
                                  duration: 300.ms,
                                  delay: Duration(
                                    milliseconds: 40 * (index % 10),
                                  ),
                                )
                                .slideY(begin: 0.05, end: 0);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_isResolving) const FslLoadingOverlay(),
      ],
    );
  }
}

/// `1 word` / `12 words` — the counter used to read "1 videos watched".
String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// Height one grid cell needs at the current Font Size setting.
///
/// The grid used to size cells by a fixed `childAspectRatio`, which pins the
/// height while the card's three text rows keep growing with the Font Size
/// setting — at 2.0× the content wanted ~136 dp inside a ~108 dp cell and every
/// card in the dictionary overflowed. Deriving the extent from the text scaler
/// keeps the cell and its contents growing together.
double _wordCardExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  // 44 dp of fixed chrome (padding + border + the gap under the icon row) plus
  // the three scalable rows: the 22 dp icon row, the 18 dp title at 1.4 line
  // height, and the 14 dp Filipino gloss at 1.5 — rounded up for breathing room.
  return 44 + 74 * scale;
}

class _FslWordCard extends StatelessWidget {
  final Flashcard card;

  /// Whether a clip is registered for this word. Resolved once at screen level
  /// from `fslAvailabilityProvider` rather than per card — the dictionary
  /// renders 177 of these and each used to kick off its own async availability
  /// check plus a `setState` on completion.
  final bool hasVideo;

  /// This learner has already watched this sign. Turns the dictionary from a
  /// flat list into something with a sense of ground covered — the same set
  /// that now feeds XP, the sign achievements and the progress screen.
  final bool watched;

  /// Starred into the learner's "My Signs" short list.
  final bool favourite;

  /// Null when there is no profile to own a favourites list (educator preview),
  /// which also hides the star entirely.
  final VoidCallback? onToggleFavourite;

  /// Invoked when the card is tapped. The parent owns the resolve (and the
  /// loading overlay) so only one video opens at a time, and owns the
  /// "no sign for this word yet" sheet for cards without a clip.
  final VoidCallback onOpen;

  const _FslWordCard({
    required this.card,
    required this.hasVideo,
    required this.watched,
    required this.favourite,
    required this.onToggleFavourite,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    // An InkWell, not a GestureDetector: this screen is pushed *over* the
    // shell, so hands-free input arrives as Flutter's directional focus
    // traversal (see `GazeFocusDriver`) rather than the published tile grid the
    // in-shell hubs use. Traversal can only reach a focusable widget, and can
    // only press one that answers `ActivateIntent` — `InkWell` is both, so a
    // gaze or switch learner gets the whole dictionary with no gaze-specific
    // wiring here. A bare `GestureDetector` is neither, which is why every word
    // card used to be a dead end for them.
    return Semantics(
      label: hasVideo
          ? '${card.wordEnglish}, ${card.wordFilipino}. '
                '${watched ? "Already watched. " : ""}Watch the sign.'
          : '${card.wordEnglish}, ${card.wordFilipino}. No sign video yet.',
      child: Container(
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasVideo
                ? card.category.color.withValues(alpha: 0.4)
                : hc.border,
            width: 1.5,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        card.category.icon,
                        color: card.category.color,
                        size: context.scaleIcon(18),
                      ),
                      const Spacer(),
                      if (watched)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: hc.success,
                            size: context.scaleIcon(16),
                          ),
                        ),
                      Icon(
                        hasVideo
                            ? Icons.play_circle_rounded
                            : Icons.videocam_off_rounded,
                        color: hasVideo ? AppColors.secondary : hc.textHint,
                        size: context.scaleIcon(22),
                      ),
                    ],
                  ),
                  // Flexible so that even if a font fallback makes the words taller
                  // than [_wordCardExtent] budgeted, they shrink instead of
                  // overflowing the cell.
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Expanded, so the star is laid out first and the words
                        // give way to it rather than the row overflowing at a
                        // large Font Size on the narrowest grid cell.
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  card.wordEnglish,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  card.wordFilipino,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: hc.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onToggleFavourite != null)
                          // Its own tap target inside the card's InkWell: the
                          // inner gesture wins, so starring never opens the
                          // video by accident.
                          Semantics(
                            button: true,
                            label: favourite
                                ? 'Remove ${card.wordEnglish} from My Signs'
                                : 'Add ${card.wordEnglish} to My Signs',
                            child: InkResponse(
                              onTap: onToggleFavourite,
                              radius: context.scaleIcon(20),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  favourite
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: favourite
                                      ? AppColors.warningDark
                                      : hc.textHint,
                                  size: context.scaleIcon(20),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
