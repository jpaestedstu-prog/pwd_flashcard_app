import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/game_catalog.dart';
import '../../../core/services/game_session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_mascot_buddy.dart';
import '../../../widgets/game_launch_transition.dart';
import '../../../widgets/seasonal_decorations.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/depth_3d.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';

class GameHubScreen extends ConsumerWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.pagePadding;
    // What this profile plays, and how it's presented:
    //   • Student / Child — the roster curated for their accessibility
    //     category, under that category's heading, so a Visual-Impairment
    //     learner and a Hearing-Impairment learner see visibly different sets.
    //   • Player (guest or with progress), educators, no profile — every game
    //     in one combined list, no heading.
    // (Story Quiz is never here; it lives in the Stories tab with its picker.)
    final catalog = ref.watch(gameHubCatalogProvider);
    final games = catalog.games;

    // Personal bests, so the roster isn't an undifferentiated wall of cards:
    // every card says either "you haven't tried this yet" or "your best here
    // is N stars". Built once here rather than per card. Not a `.select` —
    // the getter returns a fresh map, which no value equality would match, so
    // selecting would rebuild just as often for more ceremony.
    final bests = ref.watch(progressProvider).effectiveGameBestStars;

    // Unfinished runs, so a card can say "you were partway through this" and
    // the learner can pick it back up. Read once here, like the bests above.
    final resumes = GameSessionService.allResumes(
      ref.watch(profileProvider)?.id,
    );

    // Hands-free "Bottom nav + feature tiles" reach: when enabled, each game
    // card registers with the shell's gaze D-pad and shows a focus ring. A pure
    // pass-through otherwise, so touch / the gaze-off layout are unchanged.
    final gazeOn = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled && s.navHomeTiles),
    );
    final gazeGrid = GazeTileGridBuilder(active: gazeOn);

    return GazeHomeRegistrar(
      active: gazeGrid.active,
      rows: gazeGrid.rows,
      child: AnimatedGradientBackground(
        preset: GradientPreset.games,
        child: Stack(
          children: [
            // Decorative only, and deliberately the FIRST child: as the
            // last one the falling emoji painted over the UI, drifting across
            // the mood check-in's faces and the stat cards. Behind the
            // (transparent) Scaffold it still shows through the page
            // background without ever crossing content.
            const SeasonalDecorations(showBanner: false),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // ─── Header ───────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                  AppLocalizations.of(context)!.games,
                                  style: AppTypography.headlineLarge,
                                )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideX(begin: -0.05, end: 0),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.learnWhileHavingFun,
                              style: AppTypography.bodyMedium.copyWith(
                                color: HCColor.of(context).textSecondary,
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                          ],
                        ),
                      ),
                    ),

                    // ─── Motivational Tip ─────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: _MotivationalTip(),
                      ),
                    ),

                    // ─── Play Together CTA (star-free multiplayer) ──
                    // Its own gaze row above the game cards, so the D-pad
                    // reaches it too.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                        child: gazeGrid
                            .section(
                              columns: 1,
                              expand: false,
                              entries: [
                                (
                                  tile:
                                      _PlayTogetherBanner(
                                        onTap: () =>
                                            context.push('/multiplayer'),
                                      ).animate().fadeIn(
                                        duration: 400.ms,
                                        delay: 150.ms,
                                      ),
                                  cell: GazeTileCell(
                                    label: AppLocalizations.of(
                                      context,
                                    )!.playTogether,
                                    onActivate: () =>
                                        context.push('/multiplayer'),
                                  ),
                                ),
                              ],
                            )
                            .first,
                      ),
                    ),

                    // ─── Accessibility category heading ───
                    // Only for Student / Child, the roles that carry a category.
                    // Not a gaze row: it's a label, nothing to activate, so the
                    // D-pad order stays banner → game cards.
                    if (catalog.isCategorised)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
                          child: _CategoryHeader(type: catalog.category!),
                        ),
                      ),

                    // ─── Game Cards Grid ──────────────────
                    // 1 col on phones, 2 on tablets, 3 on XL/ultra tablets in
                    // landscape. Aspect ratio widens as columns grow so cards
                    // don't go tall-and-skinny on big screens. Aspect ratio is
                    // also divided by the text scaler so cells grow taller at
                    // Extra Large font (1.5×) — otherwise the label + 2-line
                    // description column overflows the card by ~10 px.
                    SliverPadding(
                      padding: EdgeInsets.all(padding),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.gridColumns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio:
                              ((context.isLargeTablet
                                          ? 1.8
                                          : (context.isTablet ? 2.0 : 2.5)) /
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1.0))
                                  .clamp(1.1, 2.5),
                        ),
                        delegate: SliverChildListDelegate(
                          gazeGrid.section(
                            columns: context.gridColumns,
                            entries: [
                              for (final game in games)
                                (
                                  tile: RepaintBoundary(
                                    child:
                                        _GameCard(
                                              game: game,
                                              bestStars: bests[game.name],
                                              resume: resumes[game],
                                              onTap: () => _navigateToGame(
                                                context,
                                                ref,
                                                game,
                                              ),
                                            )
                                            .animate()
                                            .fadeIn(duration: 350.ms)
                                            .slideY(begin: 0.1, end: 0),
                                  ),
                                  cell: GazeTileCell(
                                    label: game.labelOf(
                                      AppLocalizations.of(context)!,
                                    ),
                                    onActivate: () =>
                                        _navigateToGame(context, ref, game),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
            const AnimatedMascotBuddy(),
          ],
        ),
      ),
    );
  }

  void _navigateToGame(
    BuildContext context,
    WidgetRef ref,
    GameType game,
  ) async {
    // Story Quiz is accessed from the Stories tab, not the game hub
    if (game == GameType.storyQuiz) {
      context.go('/stories');
      return;
    }

    // FSL Practice has its own hub with mode selection. Pushed, so Back from
    // the hub returns here to the Games grid.
    if (game == GameType.fslPractice) {
      context.push('/games/fsl-practice');
      return;
    }

    final profileId = ref.read(profileProvider)?.id;

    // An unfinished run comes first: offer to pick it up before asking the
    // two setup questions again, since resuming answers both of them.
    final saved = GameSessionService.resumeFor(
      profileId: profileId,
      gameType: game,
    );
    if (saved != null) {
      final choice = await _askResume(context, saved);
      if (!context.mounted) return;
      if (choice == null) return; // Dismissed — leave the run untouched.
      if (choice) {
        _launch(
          context,
          ref,
          game,
          difficulty: saved.difficulty,
          categories: saved.categories,
          timedMode: saved.timedMode,
          resume: true,
        );
        return;
      }
      // "Start Over" — drop the snapshot so the fresh run isn't shadowed by it.
      GameSessionService.clearResume(profileId: profileId, gameType: game);
    }

    final result = await showDifficultyPicker(
      context,
      game,
      profileId: profileId,
    );
    if (result == null || !context.mounted) return;

    final last = GameSessionService.lastSetup(
      profileId: profileId,
      gameType: game,
    );
    final categories = await showCategoryPicker(
      context,
      initialSelection: last?.categories,
    );
    if (categories == null || !context.mounted) return;

    // Recorded at launch, not at finish, so a run the learner abandons still
    // counts as "what I picked last time".
    GameSessionService.saveSetup(
      profileId: profileId,
      gameType: game,
      difficulty: result.difficulty,
      categories: categories,
      timedMode: result.timedMode,
    );

    _launch(
      context,
      ref,
      game,
      difficulty: result.difficulty,
      categories: categories,
      timedMode: result.timedMode,
      resume: false,
    );
  }

  /// Continue the saved run (true), start over (false), or dismissed (null).
  Future<bool?> _askResume(
    BuildContext context,
    GameResumeSnapshot saved,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resumeTitle),
        content: Text(
          l10n.resumeBody(saved.roundIndex + 1, saved.cardIds.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.resumeStartOver),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.resumeContinue),
          ),
        ],
      ),
    );
  }

  void _launch(
    BuildContext context,
    WidgetRef ref,
    GameType game, {
    required GameDifficulty difficulty,
    required List<FlashcardCategory> categories,
    required bool timedMode,
    required bool resume,
  }) {
    final route = switch (game) {
      GameType.wordMatch => '/games/word-match',
      GameType.spellingBee => '/games/spelling-bee',
      GameType.memoryMatch => '/games/memory-match',
      GameType.dragAndDrop => '/games/drag-drop',
      GameType.flashcardQuiz => '/games/flashcard-quiz',
      GameType.pronunciation => '/games/pronunciation',
      GameType.sentenceBuilder => '/games/sentence-builder',
      GameType.tracing => '/games/tracing',
      GameType.storyQuiz => '/stories',
      GameType.fslPractice => '/games/fsl-practice',
      GameType.jigsawPuzzle => '/games/jigsaw-puzzle',
      GameType.pictureWord => '/games/picture-word',
      GameType.yesOrNo => '/games/yes-or-no',
      GameType.oddOneOut => '/games/odd-one-out',
      GameType.firstLetter => '/games/first-letter',
    };
    final catParam = categories.isEmpty
        ? ''
        : '&categories=${categories.map((c) => c.index).join(',')}';
    final timedParam = timedMode ? '&timed=true' : '';
    final resumeParam = resume ? '&resume=true' : '';
    final fullRoute =
        '$route?difficulty=${difficulty.name}$catParam$timedParam$resumeParam';

    if (!context.mounted) return;
    final reducedMotion = ref.read(settingsProvider).reducedMotion;

    // Show the launch transition, then navigate
    Navigator.of(context).push(
      PageRouteBuilder(
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, a1, a2) => GameLaunchTransition(
          game: game,
          reducedMotion: reducedMotion,
          onComplete: () {
            if (context.mounted) {
              // Pop the transition overlay, then push the activity so Back /
              // back-swipe out of the game returns to this hub rather than
              // resetting the stack. Game routes carry
              // `parentNavigatorKey: rootNavigatorKey`, which is what makes
              // pushing them safe from anywhere (see shell_route_push_nav_test).
              Navigator.of(context).pop();
              context.push(fullRoute);
            }
          },
        ),
        transitionsBuilder: (ctx2, animation, a3, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ─── Motivational Tip Widget ──────────────────────────
class _MotivationalTip extends StatelessWidget {
  /// One tip per day, cycled by day-of-month. Built per locale rather than
  /// held as a const list, so the Filipino build shows Filipino tips.
  static List<String> _tips(AppLocalizations l10n) => [
    l10n.gameTipDifficulty,
    l10n.gameTipDaily,
    l10n.gameTipReview,
    l10n.gameTipStartEasy,
    l10n.gameTipVariety,
    l10n.gameTipTimed,
  ];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final tips = _tips(AppLocalizations.of(context)!);
    final tipIndex = DateTime.now().day % tips.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tips[tipIndex],
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }
}

// ─── Play Together Banner ─────────────────────────────
class _PlayTogetherBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayTogetherBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.playTogetherSemantics,
      child: AppCard(
        onTap: onTap,
        gradient: const LinearGradient(
          colors: [AppColors.playerAccent, AppColors.playerAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        padding: const EdgeInsets.all(16),
        depth: true,
        depthBubbles: true,
        child: Row(
          children: [
            const Badge3D(
              size: 52,
              emoji: '🎮',
              iconSize: 28,
              circle: false,
              borderRadius: 16,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.playTogether,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.playTogetherSubtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Accessibility Category Heading ───────────────────
/// Names the accessibility category whose roster follows, so a Student or
/// Child can see at a glance that these games were chosen for them — and so
/// two learners on different categories can tell their Games tabs apart.
class _CategoryHeader extends StatelessWidget {
  final DisabilityType type;
  const _CategoryHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final count = GameCatalog.forCategory(type).length;
    final label = type.profileTypeLabel;
    return Semantics(
      header: true,
      label:
          '$label. ${AppLocalizations.of(context)!.gamesPickedForYou(count)}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: type.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: type.color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Badge3D(
                size: 42,
                emoji: type.emoji,
                iconSize: 22,
                circle: false,
                borderRadius: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.labelLarge.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.gamesPickedForYou(count),
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 180.ms);
  }
}

class _GameCard extends StatefulWidget {
  final GameType game;

  /// The learner's best 0–3 rating in this game, or null if never played.
  /// Zero and null read differently: zero is a played game scored under 50 %,
  /// null is a game still to try.
  final int? bestStars;

  /// The learner's unfinished run in this game, if there is one to offer.
  final GameResumeSnapshot? resume;

  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.bestStars,
    required this.resume,
    required this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  /// Spoken tail on the card's label, so the badges are not sighted-only.
  ///
  /// Mirrors what the badges show rather than concatenating both records: an
  /// unfinished run replaces "not played yet", because announcing *"Not played
  /// yet. Round 3 of 5."* contradicts itself. A learner who has both a best and
  /// an unfinished run hears both, which does not.
  String _bestSemantics(AppLocalizations l10n) {
    final saved = widget.resume;
    final best = widget.bestStars;
    final parts = <String>[
      if (best != null) l10n.yourBestStars(best),
      if (saved != null)
        '${l10n.resumeRoundProgress(saved.roundIndex + 1, saved.cardIds.length)}.'
      else if (best == null)
        l10n.notPlayedYet,
    ];
    return parts.isEmpty ? '' : ' ${parts.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label:
          l10n.playGameSemantics(
            widget.game.labelOf(l10n),
            widget.game.descriptionOf(l10n),
          ) +
          _bestSemantics(l10n),
      // AppCard.depth owns the tap, the gentle 3D press-tilt (reduced-motion
      // aware) and the glossy sheen/rim/shadow, so no extra Pressable3D wrapper.
      child: AppCard(
        onTap: widget.onTap,
        gradient: Depth3D.vibrantGradient(widget.game.color),
        padding: const EdgeInsets.all(20),
        depth: true,
        depthBubbles: true,
        // Vertically centre the icon + text + play button inside the card cell.
        // AppCard's depth mode lays content out in a top-start Stack, so without
        // this the row would hug the top of the (taller) grid cell, leaving an
        // uneven gap below. Center fills the bounded cell and centres the row.
        child: Center(
          child: Row(
            children: [
              // Game icon — raised 3D coin
              Badge3D(
                size: 64,
                icon: widget.game.icon,
                iconSize: 36,
                circle: false,
                borderRadius: 20,
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.game.labelOf(l10n),
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        widget.game.descriptionOf(l10n),
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play button — raised 3D coin — with the personal-best badge
              // stacked under it. In the Row rather than positioned over the
              // card so it can never overlap the icon or the play coin at a
              // large Font Size; the Expanded text column absorbs the width.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Badge3D(
                    size: 44,
                    icon: Icons.play_arrow_rounded,
                    iconSize: 28,
                  ),
                  const SizedBox(height: 6),
                  // Already spoken by the card's own Semantics label. An
                  // unfinished run takes the slot: "you were partway through
                  // this" is the more useful thing to say, and the personal
                  // best comes back the moment that run is finished.
                  ExcludeSemantics(
                    child: widget.resume != null
                        ? const _ResumeBadge()
                        : _BestBadge(stars: widget.bestStars),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks a card whose run the learner left unfinished. Same fixed-size
/// treatment as [_BestBadge], in the warning tint so it reads as "picked up
/// mid-way" rather than as an achievement.
class _ResumeBadge extends StatelessWidget {
  const _ResumeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pause_circle_filled_rounded,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.resumeBadge,
            maxLines: 1,
            // Fixed size on purpose — see [_BestBadge]'s class doc.
            style: const TextStyle(
              fontSize: 9,
              height: 1.2,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The personal-best marker on a game card: three pips filled to the best
/// rating the learner has reached, or a "NEW" pill for a game not yet tried.
///
/// Both states are drawn at a fixed pip size rather than a scaled text style —
/// the card's height is set by the grid's aspect ratio, so a badge that grew
/// with the Font Size setting is exactly what would push the cell over.
class _BestBadge extends StatelessWidget {
  final int? stars;
  const _BestBadge({required this.stars});

  @override
  Widget build(BuildContext context) {
    final best = stars;
    if (best == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppLocalizations.of(context)!.badgeNew,
          maxLines: 1,
          // Fixed size on purpose — see the class doc.
          style: const TextStyle(
            fontSize: 9,
            height: 1.2,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < best;
        return Icon(
          earned ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 13,
          color: Colors.white.withValues(alpha: earned ? 0.95 : 0.4),
        );
      }),
    );
  }
}
