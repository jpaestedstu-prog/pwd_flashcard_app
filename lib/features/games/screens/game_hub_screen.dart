import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../widgets/tilt_3d.dart';

class GameHubScreen extends ConsumerWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.pagePadding;
    final games = GameType.values.where((g) => g != GameType.storyQuiz).toList();

    return AnimatedGradientBackground(
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
                    Text(AppLocalizations.of(context)!.games, style: AppTypography.headlineLarge)
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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                child: _PlayTogetherBanner(
                  onTap: () => context.push('/multiplayer'),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
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
                  childAspectRatio: ((context.isLargeTablet
                              ? 1.8
                              : (context.isTablet ? 2.0 : 2.5)) /
                          MediaQuery.textScalerOf(context).scale(1.0))
                      .clamp(1.1, 2.5),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final game = games[index];
                  return RepaintBoundary(
                    child: _GameCard(
                          game: game,
                          onTap: () => _navigateToGame(context, ref, game),
                        )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.1, end: 0),
                  );
                }, childCount: games.length),
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
    );
  }

  void _navigateToGame(BuildContext context, WidgetRef ref, GameType game) async {
    // Story Quiz is accessed from the Stories tab, not the game hub
    if (game == GameType.storyQuiz) {
      context.go('/stories');
      return;
    }

    // FSL Practice has its own hub with mode selection
    if (game == GameType.fslPractice) {
      context.go('/games/fsl-practice');
      return;
    }

    final result = await showDifficultyPicker(context, game);
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
    };
    final catParam = categories.isEmpty
        ? ''
        : '&categories=${categories.map((c) => c.index).join(',')}';
    final timedParam = result.timedMode ? '&timed=true' : '';
    final fullRoute = '$route?difficulty=${result.difficulty.name}$catParam$timedParam';

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
              // Pop the transition overlay then navigate
              Navigator.of(context).pop();
              context.go(fullRoute);
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
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _tips[tipIndex],
              style: AppTypography.bodySmall.copyWith(
                color: hc.textSecondary,
              ),
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
      label: 'Play Together. Race a friend online or on this device, just for fun.',
      child: AppCard(
        onTap: onTap,
        gradient: const LinearGradient(
          colors: [AppColors.playerAccent, AppColors.playerAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('🎮', style: TextStyle(fontSize: 28)),
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
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: Pressable3D(
          maxTilt: 0.05,
          pressScale: 0.96,
          child: AppCard(
            gradient: LinearGradient(
              colors: [
                widget.game.color,
                widget.game.color.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Game icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(widget.game.icon, size: 36, color: Colors.white),
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
                // Play button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
