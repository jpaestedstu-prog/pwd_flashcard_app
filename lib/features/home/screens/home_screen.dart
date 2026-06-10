import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/daily_challenge.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/review_reminder_service.dart';
import '../../../core/services/daily_login_reward_service.dart';
import '../../../core/services/xp_level_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../../features/experiment/models/experiment_models.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../widgets/tutorial_overlay.dart';
import '../../../widgets/connectivity_indicator.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/enhanced_category_card.dart';
import '../../../widgets/animated_mascot_buddy.dart';
import '../../../widgets/seasonal_decorations.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../assessment/services/assessment_service.dart';
import '../widgets/home_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    // Check tutorial status after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider);
      if (profile != null) {
        if (!HiveService.hasSeenTutorial(profile.id)) {
          setState(() => _showTutorial = true);
        } else {
          // Only show login reward if tutorial is not showing
          _showLoginRewardIfNeeded(profile.id);
        }
      }
    });
  }

  Future<void> _showLoginRewardIfNeeded(String profileId) async {
    // Skip daily login reward when stars feature is disabled (control group)
    final starsEnabled =
        ref.read(gamificationFeatureProvider(GamificationFeature.stars));
    if (!starsEnabled) return;

    if (DailyLoginReward.hasClaimedToday(profileId)) return;
    if (!mounted) return;

    final stars = await DailyLoginReward.claimReward(profileId);
    if (stars <= 0 || !mounted) return;

    // Award stars via progress provider
    ref.read(progressProvider.notifier).addStars(stars);

    final streak = DailyLoginReward.getStreak(profileId);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DailyLoginRewardDialog(
        starsEarned: stars,
        streakDay: streak,
      ),
    );
  }

  void _completeTutorial() {
    final profile = ref.read(profileProvider);
    if (profile != null) {
      HiveService.markTutorialSeen(profile.id);
    }
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    return AnimatedGradientBackground(
      child: Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ─── App Bar ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                    child: Row(
                      children: [
                        ProfileAvatar(profile: profile, radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                    header: true,
                                    child: Text(
                                      AppLocalizations.of(context)?.greeting(profile?.name ?? 'Learner') ?? 'Hi, ${profile?.name ?? 'Learner'}! 👋',
                                      style: AppTypography.headlineLarge
                                          .copyWith(color: hc.textPrimary),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: -0.05, end: 0),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)?.readyToLearn ?? 'Ready to learn new words today?',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: hc.textSecondary,
                                ),
                              ).animate().fadeIn(
                                duration: 400.ms,
                                delay: 100.ms,
                              ),
                            ],
                          ),
                        ),
                        // Connectivity indicator (visible only when offline)
                        const ConnectivityIndicator(),
                        // Settings gear
                        if (ref.watch(gamificationFeatureProvider(GamificationFeature.shop)))
                        Semantics(
                              button: true,
                              label: 'Open star shop',
                              child: IconButton(
                                onPressed: () => context.push('/shop'),
                                icon: const Icon(Icons.store_rounded),
                                iconSize: 28,
                                color: hc.textSecondary,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 190.ms),
                        Semantics(
                              button: true,
                              label: 'Open settings',
                              child: IconButton(
                                onPressed: () => context.push('/settings'),
                                icon: const Icon(Icons.settings_rounded),
                                iconSize: 28,
                                color: hc.textSecondary,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .rotate(begin: -0.1, end: 0, duration: 500.ms),
                      ],
                    ),
                  ),
                ),

                // ─── Streak & Stats Banner ────────────
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: padding,
                        vertical: 20,
                      ),
                      child: _StatsBanner(progress: progress)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 150.ms)
                          .slideY(begin: 0.08, end: 0),
                    ),
                  ),
                ),

                // ─── Player Mode CTA: upgrade to a class ─
                if (profile?.isGuestPlayer == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(padding, 0, padding, 16),
                      child: _JoinClassCta(
                        onJoin: () => context.push('/join-class'),
                      ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
                    ),
                  ),

                // ─── Live Class CTA: join the live activity ─
                // Shown when the learner belongs to a classroom or home group,
                // so they can jump into a teacher/parent-run live session and
                // raise their hand.
                if (profile != null &&
                    !profile.isGuestPlayer &&
                    (profile.classroomId != null ||
                        profile.homeGroupId != null))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(padding, 0, padding, 16),
                      child: _LiveClassCta(
                        onTap: () => context.push('/live-session'),
                      ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
                    ),
                  ),

                // ─── XP & Level Bar ───────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                    child: _XpLevelBar(progress: progress)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 175.ms)
                        .slideY(begin: 0.08, end: 0),
                  ),
                ),

                // ─── Player Profile / Gamification Dashboard ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                    child: Semantics(
                      button: true,
                      label: 'View your Player Profile with stats and rewards',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push('/gamification-dashboard'),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.playerAccent,
                                  AppColors.playerAccentLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Text('🎮', style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Player Profile',
                                        style: AppTypography.labelLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'View your stats, rewards & achievements',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 185.ms)
                    .slideY(begin: 0.08, end: 0),
                  ),
                ),

                // ─── Daily Word Card (gated by dailyChallenge experiment flag) ──
                if (ref.watch(gamificationFeatureProvider(GamificationFeature.dailyChallenge)))
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: _DailyWordCard()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms)
                          .slideY(begin: 0.08, end: 0),
                    ),
                  ),
                ),

                // ─── Pending Assignments Banner ────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                    child: _PendingAssignmentsBanner(profileId: profile?.id)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 250.ms),
                  ),
                ),

                // ═══════════════════════════════════════
                // ─── ▶ Play & Learn (core game hub) ────
                // ═══════════════════════════════════════
                _sectionHeaderSliver(
                  context,
                  padding: padding,
                  title: 'Play & Learn',
                  icon: Icons.sports_esports_rounded,
                  color: AppColors.playerAccent,
                ),
                _tileGridSliver(
                  context,
                  padding: padding,
                  columns: _coreColumns(context),
                  extent: context.hubTileHeight(),
                  tiles: _coreTiles(context),
                ),

                // ═══════════════════════════════════════
                // ─── More tools, grouped & organized ───
                // ═══════════════════════════════════════
                ..._moreSections(context, padding),

                // ─── Categories Header ────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 28, padding, 4),
                    child: SectionHeader(
                      title: AppLocalizations.of(context)?.vocabularyCategories ?? 'Vocabulary Categories',
                      onSeeAll: () => context.go('/flashcards'),
                    ),
                  ),
                ),

                // ─── Category Grid ────────────────────
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _coreColumns(context),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Fixed, text-scale-aware cell height instead of an aspect
                      // ratio: the card fills the cell via Expanded/Flexible, so
                      // it can never collapse or overflow at large font sizes.
                      mainAxisExtent: context.hubTileHeight(),
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final category = FlashcardCategory.values[index];
                      final catCards = SeedData.getByCategory(category);
                      return RepaintBoundary(
                        child: EnhancedCategoryCard(
                              category: category,
                              wordCount: catCards.length,
                              progress:
                                  progress.categoryProgress[category.label] ?? 0,
                              onTap: () => context.go(
                                '/flashcards/viewer/${category.index}',
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(begin: 0.1, end: 0),
                      );
                    }, childCount: FlashcardCategory.values.length),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
        if (_showTutorial)
          TutorialOverlay(
            steps: tutorialStepsForRole(profile?.role),
            onComplete: _completeTutorial,
          ),
        // Mascot companion
        const AnimatedMascotBuddy(),
        // Seasonal event decorations
        const SeasonalDecorations(),
      ],
    ),
    );
  }

  // ─── Game-hub helpers ─────────────────────────────────

  /// Columns for the large "Play & Learn" tiles (and the vocabulary grid).
  int _coreColumns(BuildContext context) => context.screenWidth >= 1200
      ? 4
      : context.screenWidth >= 600
          ? 3
          : 2;

  /// Columns for the compact "More" tiles.
  int _moreColumns(BuildContext context) => context.screenWidth >= 1200
      ? 5
      : context.screenWidth >= 600
          ? 4
          : 3;

  /// A [SectionHeader] wrapped as a sliver.
  Widget _sectionHeaderSliver(
    BuildContext context, {
    required double padding,
    required String title,
    IconData? icon,
    Color? color,
    VoidCallback? onSeeAll,
    double top = 28,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, top, padding, 8),
        child: SectionHeader(
          title: title,
          icon: icon,
          color: color,
          onSeeAll: onSeeAll,
        ),
      ),
    );
  }

  /// A fixed-height tile grid as a sliver. Uses `mainAxisExtent` so a tile's
  /// height never depends on its width — overflow-proof at any tablet size or
  /// font scale.
  Widget _tileGridSliver(
    BuildContext context, {
    required double padding,
    required int columns,
    required double extent,
    required List<Widget> tiles,
  }) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: extent,
        ),
        delegate: SliverChildListDelegate(tiles),
      ),
    );
  }

  /// The six primary "Play & Learn" tiles.
  List<Widget> _coreTiles(BuildContext context) {
    final profile = ref.read(profileProvider);
    final weak = profile != null
        ? ReviewReminderService.countWordsToReview(profile.id)
        : 0;
    return [
      HomeTile(
        emoji: '🎮',
        label: 'Games',
        subtitle: 'Play & learn',
        gradient: const [AppColors.playerAccent, AppColors.playerAccentLight],
        onTap: () => context.go('/games'),
      ),
      HomeTile(
        emoji: '📚',
        label: 'Words',
        subtitle: 'Flashcards',
        gradient: const [
          AppColors.bannerLearningStart,
          AppColors.bannerLearningEnd
        ],
        onTap: () => context.go('/flashcards'),
      ),
      HomeTile(
        emoji: '📖',
        label: 'Stories',
        subtitle: 'Read & answer',
        gradient: const [
          AppColors.bannerStickerStart,
          AppColors.bannerStickerEnd
        ],
        onTap: () => context.go('/stories'),
      ),
      HomeTile(
        emoji: '🤟',
        label: 'FSL Practice',
        subtitle: 'Sign language',
        gradient: const [AppColors.bannerFslStart, AppColors.bannerFslEnd],
        onTap: () => context.go('/games/fsl-practice'),
      ),
      HomeTile(
        emoji: '🧠',
        label: 'Smart Review',
        subtitle: weak > 0 ? '$weak to practice' : 'Review words',
        gradient: const [
          AppColors.bannerSmartReviewStart,
          AppColors.bannerSmartReviewEnd
        ],
        onTap: () => context.push('/smart-review'),
      ),
      HomeTile(
        emoji: '🏆',
        label: 'Progress',
        subtitle: 'Your journey',
        gradient: const [
          AppColors.bannerLearningGainStart,
          AppColors.bannerLearningGainEnd
        ],
        onTap: () => context.go('/progress'),
      ),
    ];
  }

  /// The grouped, compact "More" sections — every remaining feature, organized
  /// under the five original category labels. Returns a flat list of slivers
  /// (a header + a compact tile grid per group) to spread into the main list.
  List<Widget> _moreSections(BuildContext context, double padding) {
    final columns = _moreColumns(context);
    final extent = context.hubTileHeight(large: false);
    final stickersOn =
        ref.watch(gamificationFeatureProvider(GamificationFeature.stickers));

    HomeTile tile({
      required String emoji,
      required String label,
      required List<Color> gradient,
      required VoidCallback onTap,
    }) =>
        HomeTile(
          emoji: emoji,
          label: label,
          gradient: gradient,
          onTap: onTap,
          compact: true,
        );

    return [
      // ── Learning & Study ──
      _sectionHeaderSliver(
        context,
        padding: padding,
        title: 'Learning & Study',
        icon: Icons.auto_stories_rounded,
        color: AppColors.sectionLearning,
      ),
      _tileGridSliver(
        context,
        padding: padding,
        columns: columns,
        extent: extent,
        tiles: [
          tile(
            emoji: '🗺️',
            label: 'Learning Paths',
            gradient: const [
              AppColors.bannerLearningStart,
              AppColors.bannerLearningEnd
            ],
            onTap: () => context.push('/learning-paths'),
          ),
          tile(
            emoji: '✍️',
            label: 'Guided Practice',
            gradient: const [
              AppColors.bannerGuidedStart,
              AppColors.bannerGuidedEnd
            ],
            onTap: () => context.push('/guided-practice'),
          ),
          tile(
            emoji: '🔥',
            label: 'Hard Words',
            gradient: const [
              AppColors.bannerHardWordsStart,
              AppColors.bannerHardWordsEnd
            ],
            onTap: () => context.push('/hard-words'),
          ),
          tile(
            emoji: '🧭',
            label: 'What to Study',
            gradient: const [
              AppColors.bannerRecommendStart,
              AppColors.bannerRecommendEnd
            ],
            onTap: () => context.push('/recommendations'),
          ),
        ],
      ),

      // ── Assessment & Progress ──
      _sectionHeaderSliver(
        context,
        padding: padding,
        title: 'Assessment & Progress',
        icon: Icons.trending_up_rounded,
        color: AppColors.sectionAssessment,
      ),
      _tileGridSliver(
        context,
        padding: padding,
        columns: columns,
        extent: extent,
        tiles: [
          tile(
            emoji: '📝',
            label: 'Assessments',
            gradient: const [
              AppColors.bannerAssessmentStart,
              AppColors.bannerAssessmentEnd
            ],
            onTap: () => context.push('/assessment'),
          ),
          tile(
            emoji: '📊',
            label: 'Learning Gains',
            gradient: const [
              AppColors.bannerLearningGainStart,
              AppColors.bannerLearningGainEnd
            ],
            onTap: () => context.push('/learning-gain'),
          ),
          tile(
            emoji: '🎨',
            label: 'My Portfolio',
            gradient: const [
              AppColors.bannerShowcaseStart,
              AppColors.bannerShowcaseEnd
            ],
            onTap: () => context.push('/showcase'),
          ),
          tile(
            emoji: '🎯',
            label: 'My Goals',
            gradient: const [
              AppColors.bannerGoalsStart,
              AppColors.bannerGoalsEnd
            ],
            onTap: () => context.push('/goals'),
          ),
          tile(
            emoji: '😊',
            label: 'How was it?',
            gradient: const [
              AppColors.bannerLearningStart,
              AppColors.bannerLearningEnd
            ],
            onTap: () => context.push('/smileyometer'),
          ),
        ],
      ),

      // ── Communication & Language ──
      _sectionHeaderSliver(
        context,
        padding: padding,
        title: 'Communication & Language',
        icon: Icons.record_voice_over_rounded,
        color: AppColors.sectionCommunication,
      ),
      _tileGridSliver(
        context,
        padding: padding,
        columns: columns,
        extent: extent,
        tiles: [
          tile(
            emoji: '🤟',
            label: 'FSL Dictionary',
            gradient: const [AppColors.bannerFslStart, AppColors.bannerFslEnd],
            onTap: () => context.push('/fsl-dictionary'),
          ),
          tile(
            emoji: '🗣️',
            label: 'Speech to Sign',
            gradient: const [AppColors.bannerFslStart, AppColors.bannerFslEnd],
            onTap: () => context.push('/sign-interpreter'),
          ),
          tile(
            emoji: '💬',
            label: 'Talk Board',
            gradient: const [
              AppColors.bannerCommBoardStart,
              AppColors.bannerCommBoardEnd
            ],
            onTap: () => context.push('/communication-board'),
          ),
          tile(
            emoji: '🤖',
            label: 'AI Tutor',
            gradient: const [
              AppColors.bannerAiTutorStart,
              AppColors.bannerAiTutorEnd
            ],
            onTap: () => context.push('/ai-tutor'),
          ),
        ],
      ),

      // ── Social & Collaboration ──
      _sectionHeaderSliver(
        context,
        padding: padding,
        title: 'Social & Collaboration',
        icon: Icons.people_rounded,
        color: AppColors.sectionSocial,
      ),
      _tileGridSliver(
        context,
        padding: padding,
        columns: columns,
        extent: extent,
        tiles: [
          tile(
            emoji: '🎮',
            label: 'Play Together',
            gradient: const [
              AppColors.playerAccent,
              AppColors.playerAccentLight
            ],
            onTap: () => context.push('/multiplayer'),
          ),
          tile(
            emoji: '💌',
            label: 'Messages',
            gradient: const [
              AppColors.bannerMessagingStart,
              AppColors.bannerMessagingEnd
            ],
            onTap: () => context.push('/messages'),
          ),
          tile(
            emoji: '🤝',
            label: 'Peer Collab',
            gradient: const [
              AppColors.bannerPeerStart,
              AppColors.bannerPeerEnd
            ],
            onTap: () => context.push('/peer-collab'),
          ),
        ],
      ),

      // ── Personal & Wellbeing ──
      _sectionHeaderSliver(
        context,
        padding: padding,
        title: 'Personal & Wellbeing',
        icon: Icons.self_improvement_rounded,
        color: AppColors.sectionWellbeing,
      ),
      _tileGridSliver(
        context,
        padding: padding,
        columns: columns,
        extent: extent,
        tiles: [
          tile(
            emoji: '😊',
            label: 'Mood Check-In',
            gradient: const [AppColors.bannerMoodStart, AppColors.bannerMoodEnd],
            onTap: () => context.push('/mood-check-in'),
          ),
          if (stickersOn)
            tile(
              emoji: '🌟',
              label: 'Sticker Album',
              gradient: const [
                AppColors.bannerStickerStart,
                AppColors.bannerStickerEnd
              ],
              onTap: () => context.push('/sticker-album'),
            ),
          tile(
            emoji: '📓',
            label: 'My Notebook',
            gradient: const [
              AppColors.bannerNotebookStart,
              AppColors.bannerNotebookEnd
            ],
            onTap: () => context.push('/notebook'),
          ),
        ],
      ),
    ];
  }
}

// ─── Stats Banner ─────────────────────────────────────
class _StatsBanner extends StatelessWidget {
  final LearningProgress progress;
  const _StatsBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Stats: ${progress.streakDays} day streak, '
          '${progress.wordsLearned} words learned, '
          '${progress.totalStars} stars earned',
      child: AppCard(
        gradient: HCColor.of(context).primaryGradient,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.local_fire_department_rounded,
                value: '${progress.streakDays}',
                label: AppLocalizations.of(context)?.dayStreak ?? 'Day Streak',
                iconColor: AppColors.warning,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.auto_stories_rounded,
                value: '${progress.wordsLearned}',
                label: AppLocalizations.of(context)?.words ?? 'Words',
                iconColor: AppColors.accentLight,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.star_rounded,
                value: '${progress.totalStars}',
                label: AppLocalizations.of(context)?.stars ?? 'Stars',
                iconColor: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 6),
        // Scale the value down rather than overflow when the number is large
        // or the font scale is high.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textOnPrimary.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── XP & Level Bar ───────────────────────────────────
class _XpLevelBar extends StatelessWidget {
  final LearningProgress progress;
  const _XpLevelBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final xp = XpService.calculateXp(progress);
    final level = XpService.currentLevel(progress);
    final next = XpService.nextLevel(progress);
    final fraction = XpService.progressToNextLevel(progress);

    return Semantics(
      label:
          'Level ${level.level} ${level.title}, $xp XP, '
          '${next != null ? '${next.xpRequired - xp} XP to next level' : 'Max level reached'}',
      child: AppCard(
        color: HCColor.of(context).surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 16,
        child: Row(
          children: [
            // Level badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.playerAccent,
                    AppColors.playerAccentPurpleLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                level.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Level info + XP bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Lv.${level.level} ${level.title}',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),
                      Text(
                        next != null
                            ? '$xp / ${next.xpRequired} XP'
                            : '$xp XP ✨',
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.playerAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Login Reward Dialog ────────────────────────
class _DailyLoginRewardDialog extends StatelessWidget {
  final int starsEarned;
  final int streakDay;

  const _DailyLoginRewardDialog({
    required this.starsEarned,
    required this.streakDay,
  });

  @override
  Widget build(BuildContext context) {
    // Show the 7-day reward cycle
    final rewards = List.generate(7, (i) => DailyLoginReward.rewardForDay(i + 1));
    final currentDayIndex = ((streakDay - 1) % 7);

    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daily Reward!',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Day $streakDay',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Star reward display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.warning, size: 32),
              const SizedBox(width: 4),
              Text(
                '+$starsEarned',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 7-day cycle preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final isCurrent = i == currentDayIndex;
              final isPast = i < currentDayIndex;
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.warning
                          : isPast
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent
                          ? Border.all(color: AppColors.warning, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: isPast
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: AppColors.success)
                        : Text(
                            '${rewards[i]}',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  isCurrent ? AppColors.textOnPrimary : HCColor.of(context).textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'D${i + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 9,
                      color: isCurrent
                          ? AppColors.warning
                          : HCColor.of(context).textSecondary,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Come back tomorrow for more!',
            style: AppTypography.bodySmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Collect! 🌟'),
        ),
      ],
    );
  }
}

// ─── Daily Word Challenge Card ────────────────────────
class _DailyWordCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DailyWordCard> createState() => _DailyWordCardState();
}

class _DailyWordCardState extends ConsumerState<_DailyWordCard> {
  late Flashcard _card;
  late List<String> _choices;
  int? _selectedIndex;
  bool _answered = false;
  bool _isCorrect = false;
  bool _alreadyCompleted = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _card = DailyChallenge.todaysWord();
    _choices = DailyChallenge.generateChoices(_card);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _alreadyCompleted = DailyChallenge.hasCompletedToday(profile.id);
      _streak = DailyChallenge.getStreak(profile.id);
    }
  }

  void _selectChoice(int index) async {
    if (_answered || _alreadyCompleted) return;
    final correct = _choices[index] == _card.wordFilipino;
    final haptic = ref.read(hapticServiceProvider);
    setState(() {
      _selectedIndex = index;
      _answered = true;
      _isCorrect = correct;
    });
    if (correct) {
      haptic.celebration();
    } else {
      haptic.error();
    }
    // Save result
    final profile = ref.read(profileProvider);
    if (profile != null) {
      await DailyChallenge.markCompleted(profile.id, correct);
      if (!mounted) return;
      // Completing the daily challenge is a learning activity — keep the
      // streak alive regardless of whether the answer was correct.
      ref.read(progressProvider.notifier).recordDailyActivity();
      if (correct) {
        ref.read(progressProvider.notifier).addStars(2);
      }
      setState(() {
        _alreadyCompleted = true;
        _streak = DailyChallenge.getStreak(profile.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppColors.warmGradient,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🏆 Daily Challenge',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (_streak > 0) ...[
                Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_streak day streak',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Navigate to full daily challenge screen
              Semantics(
                button: true,
                label: 'View full daily challenge with calendar and stats',
                child: GestureDetector(
                  onTap: () => context.push('/daily-challenge'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textOnPrimary,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Word display with emoji
          Row(
            children: [
              Text(
                FlashcardEmojis.forId(_card.id),
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _card.wordEnglish,
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _card.exampleSentence ?? '',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quiz or result
          if (_alreadyCompleted && !_answered) ...[
            // Already done today (from a previous session)
            _buildCompletedBanner(),
          ] else ...[
            // Prompt
            Text(
              'What is this in Filipino?',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // Choices
            ...List.generate(_choices.length, (i) {
              Color bgColor;
              Color borderColor;
              if (!_answered) {
                bgColor = Colors.white.withValues(alpha: 0.2);
                borderColor = Colors.white.withValues(alpha: 0.4);
              } else if (i == _selectedIndex) {
                bgColor = _isCorrect
                    ? Colors.greenAccent.withValues(alpha: 0.35)
                    : Colors.redAccent.withValues(alpha: 0.35);
                borderColor = _isCorrect
                    ? Colors.greenAccent
                    : Colors.redAccent;
              } else if (_choices[i] == _card.wordFilipino && _answered) {
                // Highlight correct answer
                bgColor = Colors.greenAccent.withValues(alpha: 0.25);
                borderColor = Colors.greenAccent;
              } else {
                bgColor = Colors.white.withValues(alpha: 0.1);
                borderColor = Colors.white.withValues(alpha: 0.2);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _selectChoice(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _choices[i],
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_answered && _choices[i] == _card.wordFilipino)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 22,
                          ),
                        if (_answered && i == _selectedIndex && !_isCorrect)
                          const Icon(
                            Icons.cancel_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // Result message
            if (_answered) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isCorrect
                        ? Icons.celebration_rounded
                        : Icons.lightbulb_rounded,
                    color: AppColors.textOnPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isCorrect
                        ? 'Correct! +2 bonus stars ⭐'
                        : 'The answer is: ${_card.wordFilipino}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return AppCard(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Challenge Complete! ✨',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'The answer was: ${_card.wordFilipino}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending Assignments Banner ────────────────────────
class _PendingAssignmentsBanner extends StatelessWidget {
  final String? profileId;
  const _PendingAssignmentsBanner({required this.profileId});

  @override
  Widget build(BuildContext context) {
    if (profileId == null) return const SizedBox.shrink();
    final pending = AssessmentService.getPendingAssignments(profileId!);
    if (pending.isEmpty) return const SizedBox.shrink();

    final count = pending.length;
    final hasOverdue = pending.any((a) => a.isOverdue);

    return FeatureBanner(
      emoji: hasOverdue ? '⚠️' : '📋',
      title: hasOverdue ? 'Overdue Assignments' : 'Pending Assignments',
      subtitle: 'You have $count assessment${count > 1 ? 's' : ''} to complete',
      gradientColors: hasOverdue
          ? const [AppColors.error, AppColors.sectionAssessment]
          : const [AppColors.info, AppColors.sectionLearning],
      onTap: () => context.push('/assessment'),
      semanticLabel: '$count pending assessment${count > 1 ? 's' : ''} assigned to you',
    );
  }
}

/// CTA shown on the home screen when the active profile is a guest
/// "Player Mode" learner. Tapping it opens the join-class flow which
/// upgrades the existing profile in place — keeping its progress.
class _LiveClassCta extends StatelessWidget {
  final VoidCallback onTap;
  const _LiveClassCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      semanticLabel: 'Join the live class activity and raise your hand.',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0x1A4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.live_tv_rounded, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join the class', style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Answer live questions for stars and raise your hand for help.',
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: HCColor.of(context).textSecondary),
        ],
      ),
    );
  }
}

class _JoinClassCta extends StatelessWidget {
  final VoidCallback onJoin;
  const _JoinClassCta({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onJoin,
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      semanticLabel: 'Have a class code? Join a class to save your progress.',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Have a class code?',
                    style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Join a class to save your progress and let your teacher follow along.',
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16,
              color: HCColor.of(context).textSecondary),
        ],
      ),
    );
  }
}
