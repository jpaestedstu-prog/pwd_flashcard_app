import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/game_catalog.dart';
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
                                    label: 'Play Together',
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
                                    label: game.label,
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
            const SeasonalDecorations(showBanner: false),
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

    final result = await showDifficultyPicker(
      context,
      game,
      profileId: ref.read(profileProvider)?.id,
    );
    if (result == null || !context.mounted) return;

    final categories = await showCategoryPicker(context);
    if (categories == null || !context.mounted) return;

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
    final timedParam = result.timedMode ? '&timed=true' : '';
    final fullRoute =
        '$route?difficulty=${result.difficulty.name}$catParam$timedParam';

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
  static const _tips = [
    '💡 Tip: Try different difficulty levels to challenge yourself!',
    '🔥 Playing games daily builds stronger memory!',
    '🌟 Review words you missed to learn faster!',
    '🎯 Start with Easy mode, then level up when ready!',
    '🧩 Each game teaches in a different way — try them all!',
    '⏱️ Timed mode is great for building speed!',
  ];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final tipIndex = DateTime.now().day % _tips.length;
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
              _tips[tipIndex],
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
      label:
          'Play Together. Race a friend online or on this device, just for fun.',
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
                    'Play Together',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Race a friend — just for fun!',
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
      label: '$label. $count games picked for you.',
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
                      '$count games picked for you',
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
  final VoidCallback onTap;

  const _GameCard({required this.game, required this.onTap});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play ${widget.game.label}. ${widget.game.description}',
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
                      widget.game.label,
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
                        widget.game.description,
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
              // Play button — raised 3D coin
              const Badge3D(
                size: 44,
                icon: Icons.play_arrow_rounded,
                iconSize: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
