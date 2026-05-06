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
import '../../../widgets/game_widgets.dart';
import '../../../widgets/tutorial_overlay.dart';
import '../../../widgets/connectivity_indicator.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/enhanced_category_card.dart';
import '../../../widgets/animated_mascot_buddy.dart';
import '../../../widgets/seasonal_decorations.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../assessment/services/assessment_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showTutorial = false;
  Set<String> _collapsedCategories = {};

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
        setState(() {
          _collapsedCategories =
              HiveService.getCollapsedCategories(profile.id);
        });
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

  void _toggleCategory(String label) {
    final profile = ref.read(profileProvider);
    setState(() {
      if (_collapsedCategories.contains(label)) {
        _collapsedCategories.remove(label);
      } else {
        _collapsedCategories.add(label);
      }
    });
    if (profile != null) {
      HiveService.saveCollapsedCategories(profile.id, _collapsedCategories);
    }
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
                                colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
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
                // ─── 📚 Learning & Study ───────────────
                // ═══════════════════════════════════════
                SliverToBoxAdapter(
                  child: _CategoryHeader(
                    icon: Icons.auto_stories_rounded,
                    label: 'Learning & Study',
                    color: AppColors.sectionLearning,
                    padding: padding,
                    isExpanded: !_collapsedCategories.contains('Learning & Study'),
                    onTap: () => _toggleCategory('Learning & Study'),
                  ),
                ),
                if (!_collapsedCategories.contains('Learning & Study'))
                  ...[
                    const _SmartReviewBanner(),
                    _learningPathsBanner(context),
                    _guidedPracticeBanner(context),
                    _hardWordsBanner(context),
                    _recommendationsBanner(context),
                  ].map((banner) => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 0),
                          child: banner
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms),
                        ),
                      )),

                // ═══════════════════════════════════════
                // ─── 📝 Assessment & Progress ──────────
                // ═══════════════════════════════════════
                SliverToBoxAdapter(
                  child: _CategoryHeader(
                    icon: Icons.trending_up_rounded,
                    label: 'Assessment & Progress',
                    color: AppColors.sectionAssessment,
                    padding: padding,
                    isExpanded: !_collapsedCategories.contains('Assessment & Progress'),
                    onTap: () => _toggleCategory('Assessment & Progress'),
                  ),
                ),
                if (!_collapsedCategories.contains('Assessment & Progress'))
                  ...[
                    _assessmentBanner(context),
                    _learningGainBanner(context),
                    _showcaseBanner(context),
                    _goalsBanner(context),
                  ].map((banner) => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 0),
                          child: banner
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms),
                        ),
                      )),

                // ═══════════════════════════════════════
                // ─── 🗣️ Communication & Language ──────
                // ═══════════════════════════════════════
                SliverToBoxAdapter(
                  child: _CategoryHeader(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Communication & Language',
                    color: AppColors.sectionCommunication,
                    padding: padding,
                    isExpanded: !_collapsedCategories.contains('Communication & Language'),
                    onTap: () => _toggleCategory('Communication & Language'),
                  ),
                ),
                if (!_collapsedCategories.contains('Communication & Language'))
                  ...[
                    _fslDictionaryBanner(context),
                    _communicationBoardBanner(context),
                    _aiTutorBanner(context),
                  ].map((banner) => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 0),
                          child: banner
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms),
                        ),
                      )),

                // ═══════════════════════════════════════
                // ─── 🤝 Social & Collaboration ────────
                // ═══════════════════════════════════════
                SliverToBoxAdapter(
                  child: _CategoryHeader(
                    icon: Icons.people_rounded,
                    label: 'Social & Collaboration',
                    color: AppColors.sectionSocial,
                    padding: padding,
                    isExpanded: !_collapsedCategories.contains('Social & Collaboration'),
                    onTap: () => _toggleCategory('Social & Collaboration'),
                  ),
                ),
                if (!_collapsedCategories.contains('Social & Collaboration'))
                  ...[
                    _messagingBanner(context),
                    _peerCollabBanner(context),
                  ].map((banner) => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 0),
                          child: banner
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms),
                        ),
                      )),

                // ═══════════════════════════════════════
                // ─── 📓 Personal & Wellbeing ──────────
                // ═══════════════════════════════════════
                SliverToBoxAdapter(
                  child: _CategoryHeader(
                    icon: Icons.self_improvement_rounded,
                    label: 'Personal & Wellbeing',
                    color: AppColors.sectionWellbeing,
                    padding: padding,
                    isExpanded: !_collapsedCategories.contains('Personal & Wellbeing'),
                    onTap: () => _toggleCategory('Personal & Wellbeing'),
                  ),
                ),
                if (!_collapsedCategories.contains('Personal & Wellbeing'))
                  ...[
                    _moodCheckInBanner(context),
                    if (ref.watch(gamificationFeatureProvider(GamificationFeature.stickers)))
                      _stickerAlbumBanner(context),
                    _notebookBanner(context),
                  ].map((banner) => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 0),
                          child: banner
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms),
                        ),
                      )),

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
                      crossAxisCount: context.gridColumns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: context.isTablet ? 2.2 : 2.0,
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

                // ─── Quick Games Header ───────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 28, padding, 4),
                    child: SectionHeader(
                      title: AppLocalizations.of(context)?.quickGames ?? 'Quick Games',
                      onSeeAll: () => context.go('/games'),
                    ),
                  ),
                ),

                // ─── Quick Games Carousel ─────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      itemCount: GameType.values.where((g) => g != GameType.storyQuiz).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        // Cache the filtered list once instead of re-filtering per item
                        final games = GameType.values.where((g) => g != GameType.storyQuiz).toList();
                        final game = games[index];
                        return _QuickGameCard(
                              game: game,
                              onTap: () async {
                                // FSL Practice has its own hub
                                if (game == GameType.fslPractice) {
                                  context.go('/games/fsl-practice');
                                  return;
                                }
                                final result = await showDifficultyPicker(
                                  context,
                                  game,
                                );
                                if (result == null || !context.mounted) {
                                  return;
                                }
                                final categories = await showCategoryPicker(
                                  context,
                                );
                                if (categories == null || !context.mounted) {
                                  return;
                                }
                                final route = switch (game) {
                                  GameType.wordMatch => '/games/word-match',
                                  GameType.spellingBee => '/games/spelling-bee',
                                  GameType.memoryMatch => '/games/memory-match',
                                  GameType.dragAndDrop => '/games/drag-drop',
                                  GameType.flashcardQuiz =>
                                    '/games/flashcard-quiz',
                                  GameType.pronunciation =>
                                    '/games/pronunciation',
                                  GameType.sentenceBuilder =>
                                    '/games/sentence-builder',
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
                                context.go(
                                  '$route?difficulty=${result.difficulty.name}$catParam$timedParam',
                                );
                              },
                            )
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideX(begin: 0.1, end: 0);
                      },
                    ),
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

  Widget _learningPathsBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🗺️',
      title: 'Learning Paths',
      subtitle: 'Follow a structured curriculum',
      gradientColors: const [AppColors.bannerLearningStart, AppColors.bannerLearningEnd],
      onTap: () => context.push('/learning-paths'),
      semanticLabel: 'Open Learning Paths. Follow a structured curriculum.',
    );
  }
  Widget _fslDictionaryBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🤟',
      title: 'FSL Dictionary',
      subtitle: 'Browse sign language videos',
      gradientColors: const [AppColors.bannerFslStart, AppColors.bannerFslEnd],
      onTap: () => context.push('/fsl-dictionary'),
      semanticLabel: 'Open FSL Dictionary. Browse Filipino Sign Language videos.',
    );
  }

  Widget _communicationBoardBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '💬',
      title: 'Communication Board',
      subtitle: 'Tap tiles to build & speak sentences',
      gradientColors: const [AppColors.bannerCommBoardStart, AppColors.bannerCommBoardEnd],
      onTap: () => context.push('/communication-board'),
      semanticLabel: 'Open Communication Board. Tap tiles to build and speak sentences.',
    );
  }

  Widget _assessmentBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '📝',
      title: 'Assessments',
      subtitle: 'Pre & post tests to measure learning',
      gradientColors: const [AppColors.bannerAssessmentStart, AppColors.bannerAssessmentEnd],
      onTap: () => context.push('/assessment'),
      semanticLabel: 'Open Assessments. Take pre and post tests to measure your learning.',
    );
  }

  Widget _showcaseBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🎨',
      title: 'My Portfolio',
      subtitle: 'Showcase your best achievements',
      gradientColors: const [AppColors.bannerShowcaseStart, AppColors.bannerShowcaseEnd],
      onTap: () => context.push('/showcase'),
      semanticLabel: 'Open Portfolio Showcase. View and share your learning achievements.',
    );
  }

  Widget _learningGainBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '📊',
      title: 'Learning Gains',
      subtitle: 'Track your pre vs post improvement',
      gradientColors: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      onTap: () => context.push('/learning-gain'),
      semanticLabel: 'Open Learning Gains. See how much you have improved from pre-test to post-test.',
    );
  }

  Widget _recommendationsBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🧠',
      title: 'What to Study Next',
      subtitle: 'Smart recommendations just for you',
      gradientColors: const [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
      onTap: () => context.push('/recommendations'),
      semanticLabel: 'Open Smart Recommendations. Get personalized suggestions on what to study next.',
    );
  }

  Widget _moodCheckInBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '😊',
      title: 'Mood Check-In',
      subtitle: 'How are you feeling today?',
      gradientColors: const [Color(0xFFF06292), Color(0xFFE91E63)],
      onTap: () => context.push('/mood-check-in'),
      semanticLabel: 'Open Mood Check-In. Track how you feel while learning.',
    );
  }

  Widget _stickerAlbumBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🌟',
      title: 'Sticker Album',
      subtitle: 'Collect stickers as you learn',
      gradientColors: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
      onTap: () => context.push('/sticker-album'),
      semanticLabel: 'Open Sticker Album. Collect stickers as you learn.',
    );
  }

  Widget _guidedPracticeBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '📝',
      title: 'Guided Practice',
      subtitle: 'Step-by-step vocabulary exercises',
      gradientColors: const [Color(0xFF26A69A), Color(0xFF00897B)],
      onTap: () => context.push('/guided-practice'),
      semanticLabel: 'Open Guided Practice. Step-by-step vocabulary exercises.',
    );
  }

  Widget _aiTutorBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🤖',
      title: 'AI Tutor',
      subtitle: 'Chat with your study helper',
      gradientColors: const [Color(0xFF42A5F5), Color(0xFF1E88E5)],
      onTap: () => context.push('/ai-tutor'),
      semanticLabel: 'Open AI Tutor. Chat with your personal study helper.',
    );
  }

  Widget _messagingBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '💬',
      title: 'Messages',
      subtitle: 'Send encouragement to others',
      gradientColors: const [Color(0xFFAB47BC), Color(0xFF8E24AA)],
      onTap: () => context.push('/messages'),
      semanticLabel: 'Open Messages. Send encouragement to others.',
    );
  }

  Widget _peerCollabBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🤝',
      title: 'Peer Collab',
      subtitle: 'Learn together with a friend',
      gradientColors: const [Color(0xFF66BB6A), Color(0xFF43A047)],
      onTap: () => context.push('/peer-collab'),
      semanticLabel: 'Open Peer Collaboration. Learn together with a friend.',
    );
  }

  Widget _notebookBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '📓',
      title: 'My Notebook',
      subtitle: 'Write and organize study notes',
      gradientColors: const [Color(0xFF8D6E63), Color(0xFF6D4C41)],
      onTap: () => context.push('/notebook'),
      semanticLabel: 'Open Notebook. Write and organize your study notes.',
    );
  }

  Widget _hardWordsBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🔥',
      title: 'Hard Words',
      subtitle: 'Practice words you struggle with',
      gradientColors: const [Color(0xFFEF5350), Color(0xFFD32F2F)],
      onTap: () => context.push('/hard-words'),
      semanticLabel: 'Open Hard Words. Practice words you struggle with.',
    );
  }

  Widget _goalsBanner(BuildContext context) {
    return FeatureBanner(
      emoji: '🎯',
      title: 'My Goals',
      subtitle: 'Set and track your learning goals',
      gradientColors: const [Color(0xFFFF8F00), Color(0xFFFFA726)],
      onTap: () => context.push('/goals'),
      semanticLabel: 'Open My Goals. Set and track your learning goals.',
    );
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.local_fire_department_rounded,
              value: '${progress.streakDays}',
              label: AppLocalizations.of(context)?.dayStreak ?? 'Day Streak',
              iconColor: AppColors.warning,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            _StatItem(
              icon: Icons.auto_stories_rounded,
              value: '${progress.wordsLearned}',
              label: AppLocalizations.of(context)?.words ?? 'Words',
              iconColor: AppColors.accentLight,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            _StatItem(
              icon: Icons.star_rounded,
              value: '${progress.totalStars}',
              label: AppLocalizations.of(context)?.stars ?? 'Stars',
              iconColor: AppColors.warning,
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
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textOnPrimary.withValues(alpha: 0.8),
          ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Level badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
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
                      Text(
                        'Lv.${level.level} ${level.title}',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                        Color(0xFF7C4DFF),
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
      title: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Text(
            'Daily Reward!',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
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

// ─── Quick Game Card ──────────────────────────────────
class _QuickGameCard extends StatelessWidget {
  final GameType game;
  final VoidCallback onTap;

  const _QuickGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final gColor = hc.gameColor(game);
    return SizedBox(
      width: 150,
      child: AppCard(
        onTap: onTap,
        color: gColor.withValues(alpha: hc.hc ? 0.3 : 0.2),
        borderRadius: 20,
        semanticLabel: 'Play ${game.label} game',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: gColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(game.icon, size: 28, color: gColor),
            ),
            const SizedBox(height: 10),
            Text(
              game.label,
              style: AppTypography.labelMedium.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Smart Review Banner ──────────────────────────────
class _SmartReviewBanner extends ConsumerWidget {
  const _SmartReviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final weakCount = profile != null
        ? ReviewReminderService.countWordsToReview(profile.id)
        : 0;

    final subtitle = weakCount > 0
        ? '$weakCount word${weakCount == 1 ? '' : 's'} need${weakCount == 1 ? 's' : ''} practice'
        : 'Practice words you struggle with most';

    return FeatureBanner(
      emoji: '🧠',
      title: 'Smart Review',
      subtitle: subtitle,
      gradientColors: const [Color(0xFF7C4DFF), Color(0xFF448AFF)],
      onTap: () => context.push('/smart-review'),
      semanticLabel: weakCount > 0
          ? 'Start smart review. $weakCount words need practice.'
          : 'Start smart review. Practice your weakest words.',
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
          ? const [Color(0xFFEF5350), Color(0xFFFF7043)]
          : const [Color(0xFF42A5F5), Color(0xFF5C6BC0)],
      onTap: () => context.push('/assessment'),
      semanticLabel: '$count pending assessment${count > 1 ? 's' : ''} assigned to you',
    );
  }
}

// ───────────────────────────────────────────────
//  Category Header used to group feature banners
// ───────────────────────────────────────────────
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.padding,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double padding;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 24, padding, 4),
      child: Semantics(
        button: true,
        label: '${isExpanded ? "Collapse" : "Expand"} $label section',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hc.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: color.withValues(alpha: 0.25),
                  thickness: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isExpanded ? 0.0 : -0.25,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CTA shown on the home screen when the active profile is a guest
/// "Player Mode" learner. Tapping it opens the join-class flow which
/// upgrades the existing profile in place — keeping its progress.
class _JoinClassCta extends StatelessWidget {
  final VoidCallback onJoin;
  const _JoinClassCta({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onJoin,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }
}
