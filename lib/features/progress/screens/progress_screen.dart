import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/xp_level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/safe_scaffold.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/models/achievements.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../../widgets/xp_level_bar.dart';
import '../../../features/experiment/models/experiment_models.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';
import '../models/progress_presentation.dart';
import '../models/weekly_summary.dart';
import '../theme/progress_theme_provider.dart';
import '../theme/progress_layout_provider.dart';
import '../theme/progress_theme_picker.dart';
import '../widgets/shared/progress_section_header.dart';
import '../widgets/shared/category_progress_row.dart';
import '../widgets/shared/progress_stat_grid.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final allCards = ref.watch(allFlashcardsProvider);

    // How much of this page this learner is shown, and in what order. See
    // [ProgressPresentation] for why each category gets what it gets.
    final show = ref.watch(progressPresentationProvider);

    // Motion budget. Every entrance animation below runs through this, so a
    // reduced-motion profile gets the same layout with the movement taken out
    // rather than a second code path. Zero-duration effects settle on their
    // first frame, which also means nothing is hidden behind a stagger.
    Duration ms(int v) => show.animate ? Duration(milliseconds: v) : Duration.zero;

    final totalWords = allCards.length;
    final masteredWords = progress.wordsLearned;
    final streak = progress.streakDays;
    final bestStreak = progress.effectiveBestStreak;
    final totalStars = progress.totalStars;
    final starBalance = progress.starBalance;
    final gamesPlayed = progress.effectiveGamesPlayed;

    // Reading progress. Tracked on every story card since stories shipped, but
    // the Progress tab had no section for it — Cards, Games and Signs each did.
    final allStories = SeedStories.all;
    final storiesRead = progress.completedStoryIds.length;
    final storiesPerfect = progress.storyBestStars.values
        .where((s) => s >= 3)
        .length;

    // Sign-language progress. The denominator is the number of signs that
    // actually exist (142 of the 177 seed words), not the word count — 35 have
    // no clip recorded, so "/177" would be a target no learner could reach.
    final showFsl = ref.watch(accessibilityContentPolicyProvider).showFsl;
    final signsLearned = progress.signsLearned;
    final totalSigns =
        ref.watch(fslAvailabilityProvider).valueOrNull?.cardsWithVideo.length ??
        0;
    final masteryPct = totalWords > 0
        ? (masteredWords / totalWords).clamp(0.0, 1.0)
        : 0.0;

    // ─── Selectable skin + layout (yield to accessibility modes) ───
    final theme = ref.watch(progressThemeProvider);
    final layout = ref.watch(progressLayoutProvider);
    final settings = ref.watch(settingsProvider);
    final useTheme = !(settings.highContrastMode || settings.dyslexiaMode);
    // Subtle skin wash for neutral cards; null in accessibility modes so the
    // plain HCColor surface is used.
    final cardSurface = useTheme
        ? theme.cardSurface(HCColor.of(context).surface)
        : null;

    // Width-cap the content on wide tablets (center it) and use the
    // tier-aware page padding on the sides — prevents edge-to-edge stretch
    // on large screens and cramping on phones.
    final maxW = context.maxContentWidth;
    final sideInset = maxW.isFinite
        ? ((context.screenWidth - maxW) / 2).clamp(0.0, double.infinity)
        : 0.0;
    final contentHPad = context.pagePadding + sideInset;
    final headerGradient = useTheme
        ? theme.gradient
        : LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.85),
              AppColors.secondary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final headerTextColor = useTheme ? theme.onHeader : Colors.white;
    final accent = useTheme ? theme.accent : HCColor.of(context).primary;

    // Hands-free "Bottom nav + feature tiles" reach: when enabled, each action
    // button registers with the shell's gaze D-pad (one per row, top-to-bottom)
    // and shows a focus ring. A pure pass-through otherwise, so touch / the
    // gaze-off layout are unchanged.
    final gazeOn = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled && s.navHomeTiles),
    );
    final gazeGrid = GazeTileGridBuilder(active: gazeOn);
    // Wraps a single full-width action button as its own gaze row (the buttons
    // sit in an unbounded SliverList, so the ring must size to the child).
    Widget gazeButton(String label, VoidCallback onTap, Widget button) =>
        gazeGrid
            .section(
              columns: 1,
              expand: false,
              entries: [
                (
                  tile: button,
                  cell: GazeTileCell(label: label, onActivate: onTap),
                ),
              ],
            )
            .first;

    // ─── Spoken summary ───────────────────────────────────
    // The accessible equivalent of the mastery ring and the charts. Everything
    // it says is already on the page; the point is that none of it had an
    // audible form, which for a blind learner made the tab decorative.
    final week = ref.watch(weeklySummaryProvider);
    final level = XpService.currentLevel(progress);
    void speakSummary() {
      final sentences = <String>[
        l10n.spokenProgressSummary(
          level.level,
          level.title,
          masteredWords,
          totalStars,
          streak,
          bestStreak,
          gamesPlayed,
        ),
        if (show.showWeekly && !week.isEmpty)
          l10n.spokenWeekSummary(week.daysActive, week.games, week.stars),
      ];
      final tts = ref.read(ttsServiceProvider);
      // Filipino needs the fil-PH voice or it is read with English phonemes.
      if (settings.locale == 'fil') {
        tts.speakFilipino(sentences.join(' '));
      } else {
        tts.speakEnglish(sentences.join(' '));
      }
    }

    // Opens the theme/layout customize sheet — shared by the palette button's
    // tap and its gaze cell so both always agree.
    void openCustomizeSheet() => showProgressCustomizeSheet(
      context,
      selectedThemeId: theme.id,
      selectedLayoutId: layout.id,
      onThemeSelected: (id) =>
          ref.read(progressThemeProvider.notifier).select(id),
      onLayoutSelected: (id) =>
          ref.read(progressLayoutProvider.notifier).select(id),
    );

    return GazeHomeRegistrar(
      active: gazeGrid.active,
      rows: gazeGrid.rows,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ─── App Bar ────────────────────────
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              actions: [
                // Its own gaze row (the topmost), so the D-pad reaches the
                // customize sheet too.
                gazeGrid
                    .section(
                      columns: 1,
                      expand: false,
                      entries: [
                        (
                          tile: IconButton(
                            tooltip: l10n.customizeProgress,
                            icon: Icon(
                              Icons.palette_rounded,
                              color: headerTextColor,
                            ),
                            onPressed: openCustomizeSheet,
                          ),
                          cell: GazeTileCell(
                            label: l10n.customize,
                            onActivate: openCustomizeSheet,
                          ),
                        ),
                      ],
                    )
                    .first,
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  bottom: 16,
                  end: 56, // clear the palette action at large font scales
                ),
                title: Text(
                  l10n.progressTitle(profile?.name ?? 'Learner'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: headerTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(gradient: headerGradient),
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(contentHPad, 20, contentHPad, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Top Stats (responsive, overflow-safe grid) ──
                  OverflowGuard(
                        label: 'progress-top-stats',
                        child: ProgressStatGrid(
                          layout: layout,
                          stats: [
                            ProgressStat(
                              icon: Icons.local_fire_department_rounded,
                              label: l10n.streak,
                              value: '$streak',
                              // The record only earns a line once it says
                              // something the big number doesn't. It is also
                              // the consolation after a missed day: the flame
                              // resets, this doesn't.
                              suffix: bestStreak > streak
                                  ? l10n.bestStreak(bestStreak)
                                  : l10n.days,
                              color: AppColors.accent,
                            ),
                            ProgressStat(
                              icon: Icons.star_rounded,
                              label: l10n.stars,
                              value: '$totalStars',
                              // Home and the Shop show the *balance*; this card
                              // shows lifetime earnings under the same word,
                              // so a learner who has spent stars saw two
                              // different "Stars" numbers. Name both.
                              suffix: starBalance != totalStars
                                  ? l10n.starsLeftToSpend(starBalance)
                                  : '',
                              color: AppColors.warning,
                            ),
                            ProgressStat(
                              icon: Icons.menu_book_rounded,
                              label: l10n.words,
                              value: '$masteredWords',
                              suffix: '/ $totalWords',
                              color: AppColors.secondary,
                            ),
                            // Lifetime count. The Recent Games list below only
                            // ever shows the last ten, so this was the one
                            // number that said how much play has happened.
                            ProgressStat(
                              icon: Icons.sports_esports_rounded,
                              label: l10n.games,
                              value: '$gamesPlayed',
                              color: AppColors.info,
                            ),
                            // Only for learners the FSL surfaces are shown to —
                            // a stat a visual-impairment or cognitive profile can
                            // never move would just read as a permanent zero.
                            if (showFsl)
                              ProgressStat(
                                icon: Icons.sign_language_rounded,
                                label: l10n.signs,
                                value: '$signsLearned',
                                suffix: totalSigns > 0 ? '/ $totalSigns' : '',
                                color: AppColors.secondaryDark,
                              ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: ms(400))
                      .slideY(begin: -0.15, end: 0),

                  SizedBox(height: layout.sectionGap),

                  // ─── Level ───────────────────────
                  // The learner's level was on every *home* screen but not on
                  // the tab named Progress — the one place they come to ask
                  // "how am I doing?". Same shared bar, so the number here can
                  // never disagree with the one on Home.
                  XpLevelBar(progress: progress, showNextGoal: true)
                      .animate()
                      .fadeIn(duration: ms(400), delay: ms(120))
                      .slideY(begin: -0.1, end: 0),

                  SizedBox(height: layout.sectionGap),

                  // ─── Hear my progress ────────────
                  // Everything below is a number or a shape. This says it out
                  // loud, which for a blind learner is the difference between
                  // a progress tab and a decoration.
                  if (show.speakSummary) ...[
                    gazeButton(
                      l10n.hearMyProgress,
                      speakSummary,
                      FilledButton.tonalIcon(
                            onPressed: speakSummary,
                            icon: const Icon(Icons.volume_up_rounded),
                            label: Text(l10n.hearMyProgress),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: ms(400), delay: ms(160)),
                    ),
                    SizedBox(height: layout.sectionGap),
                  ],

                  // ─── Overall Mastery ─────────────
                  Semantics(
                        label:
                            'Overall mastery: ${(masteryPct * 100).round()} percent. '
                            '$masteredWords out of $totalWords words learned.',
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              // Responsive, text-scaler-aware ring so it fits small
                              // tablets in portrait/split-screen and grows (capped)
                              // with the Font Size setting instead of clipping.
                              final ringRadius = context.scaledHeightCapped(
                                context.responsiveTier(
                                      phone: 72.0,
                                      tablet: 80.0,
                                      large: 92.0,
                                      xl: 100.0,
                                    ) *
                                    layout.heroScale,
                                max: 1.3,
                              );
                              return CircularPercentIndicator(
                                radius: ringRadius,
                                lineWidth: ringRadius * 0.17,
                                percent: masteryPct.clamp(0.0, 1.0),
                                center: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${(masteryPct * 100).round()}%',
                                      style: AppTypography.headlineMedium
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: accent,
                                          ),
                                    ),
                                    Text(
                                      l10n.mastery,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: HCColor.of(
                                          context,
                                        ).textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                progressColor: accent,
                                backgroundColor: useTheme
                                    ? accent.withValues(alpha: 0.15)
                                    : HCColor.of(context).primaryLight,
                                circularStrokeCap: CircularStrokeCap.round,
                                animation: true,
                                animationDuration: 1000,
                              );
                            },
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: ms(600), delay: ms(200))
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                      ),

                  SizedBox(height: layout.sectionGap),

                  // ─── This Week ───────────────────
                  // Every other figure on this page is a lifetime total, which
                  // stops moving visibly once it is large — so the tab slowly
                  // stops giving feedback to whoever has used it longest.
                  if (show.showWeekly) ...[
                    ProgressSectionHeader(
                      title: l10n.thisWeek,
                      icon: Icons.date_range_rounded,
                      iconColor: accent,
                    ),
                    const SizedBox(height: 12),
                    if (week.isEmpty)
                      _EmptyNote(
                        icon: Icons.hourglass_empty_rounded,
                        message: l10n.weeklyEmpty,
                      ).animate().fadeIn(duration: ms(400), delay: ms(260))
                    else
                      OverflowGuard(
                        label: 'progress-weekly-stats',
                        child: ProgressStatGrid(
                          layout: layout,
                          stats: [
                            ProgressStat(
                              icon: Icons.event_available_rounded,
                              label: l10n.daysActive,
                              value: '${week.daysActive}',
                              suffix: '/ ${WeeklySummary.days}',
                              color: AppColors.accent,
                            ),
                            ProgressStat(
                              icon: Icons.timer_rounded,
                              label: l10n.minutesStudied,
                              value: '${week.minutes}',
                              color: AppColors.info,
                            ),
                            ProgressStat(
                              icon: Icons.sports_esports_rounded,
                              label: l10n.games,
                              value: '${week.games}',
                              color: AppColors.secondary,
                            ),
                            ProgressStat(
                              icon: Icons.star_rounded,
                              label: l10n.stars,
                              value: '${week.stars}',
                              color: AppColors.warning,
                            ),
                            ProgressStat(
                              icon: Icons.menu_book_rounded,
                              label: l10n.newWords,
                              value: '${week.words}',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: ms(400), delay: ms(260)),

                    SizedBox(height: layout.sectionGap),
                  ],

                  // ─── Leaderboard + analytics ─────
                  // Hidden for player mode: the leaderboard is class-based and
                  // the analytics dashboards are teacher/parent monitoring
                  // tools. The player keeps their own progress (streak
                  // calendar, certificates, category progress) below.
                  if (profile?.isPlayerMode != true &&
                      ref.watch(
                        gamificationFeatureProvider(
                          GamificationFeature.leaderboard,
                        ),
                      )) ...[
                    gazeButton(
                      l10n.viewLeaderboard,
                      () => context.push('/leaderboard'),
                      FilledButton.icon(
                            onPressed: () => context.push('/leaderboard'),
                            icon: const Icon(Icons.leaderboard_rounded),
                            label: Text(l10n.viewLeaderboard),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: ms(400), delay: ms(350))
                          .slideY(begin: 0.1, end: 0),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Both chart dashboards ride on the same policy flag, so a
                  // learner who is not shown one is not shown the other.
                  if (show.showChartScreens) ...[
                    gazeButton(
                      l10n.detailedAnalytics,
                      () => context.push('/analytics'),
                      OutlinedButton.icon(
                            onPressed: () => context.push('/analytics'),
                            icon: const Icon(Icons.analytics_rounded),
                            label: Text(l10n.detailedAnalytics),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: ms(400), delay: ms(400))
                          .slideY(begin: 0.1, end: 0),
                    ),
                    const SizedBox(height: 12),

                    // "Learning Insights" — the adaptive-analytics dashboard
                    // (spaced-repetition heatmap, difficulty history). It has
                    // existed since the adaptive-difficulty work shipped and
                    // was reachable only by speaking "/adaptive-analytics" at
                    // the voice navigator: no button anywhere in the app.
                    gazeButton(
                      l10n.advancedAnalytics,
                      () => context.push('/adaptive-analytics'),
                      OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/adaptive-analytics'),
                            icon: const Icon(Icons.insights_rounded),
                            label: Text(l10n.advancedAnalytics),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: ms(400), delay: ms(420))
                          .slideY(begin: 0.1, end: 0),
                    ),
                    const SizedBox(height: 12),
                  ],

                  gazeButton(
                    l10n.streakCalendar,
                    () => context.push('/streak-calendar'),
                    OutlinedButton.icon(
                          onPressed: () => context.push('/streak-calendar'),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(l10n.streakCalendar),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: ms(400), delay: ms(450))
                        .slideY(begin: 0.1, end: 0),
                  ),

                  const SizedBox(height: 12),

                  gazeButton(
                    'Certificates',
                    () => context.push('/certificates'),
                    OutlinedButton.icon(
                          onPressed: () => context.push('/certificates'),
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: Text(l10n.certificates),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: ms(400), delay: ms(500))
                        .slideY(begin: 0.1, end: 0),
                  ),

                  SizedBox(height: layout.sectionGap),

                  // ─── Category Progress ──────────
                  ProgressSectionHeader(
                    title: l10n.categoryProgress,
                    icon: Icons.category_rounded,
                    iconColor: accent,
                  ),
                  const SizedBox(height: 12),

                  ...FlashcardCategory.values.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    final catCards = allCards
                        .where((c) => c.category == cat)
                        .toList();
                    final catPct = progress.categoryProgress[cat.label] ?? 0.0;
                    final catMastered = (catPct * catCards.length).round();

                    return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: CategoryProgressRow(
                            icon: cat.icon,
                            label: cat.label,
                            color: cat.color,
                            mastered: catMastered,
                            total: catCards.length,
                            percent: catPct,
                            surface: cardSurface,
                          ),
                        )
                        .animate()
                        .fadeIn(
                          duration: ms(400),
                          delay: ms(300 + i * 80),
                        )
                        .slideX(begin: 0.1, end: 0);
                  }),

                  SizedBox(height: layout.sectionGap),

                  // ─── Recent Games ─────────────
                  ProgressSectionHeader(
                    title: l10n.recentGames,
                    icon: Icons.sports_esports_rounded,
                    iconColor: accent,
                  ),
                  const SizedBox(height: 12),
                  if (progress.recentScores.isEmpty)
                    _EmptyNote(
                      icon: Icons.sports_esports_rounded,
                      message: l10n.playGamePrompt,
                    ).animate().fadeIn(duration: ms(400), delay: ms(750))
                  else
                    ...progress.recentScores.reversed
                        .take(show.maxRecentGames)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          final i = entry.key;
                          final score = entry.value;
                          return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RecentGameTile(score: score),
                              )
                              .animate()
                              .fadeIn(
                                duration: ms(400),
                                delay: ms(750 + i * 60),
                              )
                              .slideX(begin: 0.1, end: 0);
                        }),

                  SizedBox(height: layout.sectionGap),

                  // ─── Reading / Sign Language ─────
                  // Both were tracked and neither was shown: the Stories tab
                  // has stamped every cover with a ✓ and a ★ since it shipped,
                  // and sign *production* — the milestone, not the watching —
                  // had no surface at all.
                  //
                  // Order is the policy's call. For a Deaf learner the sign
                  // section is the headline and goes first; for everyone else
                  // reading leads. Same two blocks either way.
                  ...(() {
                    final reading = <Widget>[
                      ProgressSectionHeader(
                        title: l10n.reading,
                        icon: Icons.auto_stories_rounded,
                        iconColor: accent,
                      ),
                      const SizedBox(height: 12),
                      OverflowGuard(
                        label: 'progress-reading-stats',
                        child: ProgressStatGrid(
                          layout: layout,
                          stats: [
                            ProgressStat(
                              icon: Icons.auto_stories_rounded,
                              label: l10n.storiesRead,
                              value: '$storiesRead',
                              suffix: '/ ${allStories.length}',
                              color: AppColors.secondary,
                            ),
                            ProgressStat(
                              icon: Icons.star_rounded,
                              label: l10n.perfectQuizzes,
                              value: '$storiesPerfect',
                              color: AppColors.warning,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: ms(400), delay: ms(780)),
                      SizedBox(height: layout.sectionGap),
                    ];

                    final signing = <Widget>[
                      if (showFsl) ...[
                        ProgressSectionHeader(
                          title: l10n.signLanguage,
                          icon: Icons.sign_language_rounded,
                          iconColor: AppColors.secondaryDark,
                        ),
                        const SizedBox(height: 12),
                        OverflowGuard(
                          label: 'progress-sign-stats',
                          child: ProgressStatGrid(
                            layout: layout,
                            stats: [
                              ProgressStat(
                                icon: Icons.visibility_rounded,
                                label: l10n.signsWatched,
                                value: '$signsLearned',
                                suffix: totalSigns > 0 ? '/ $totalSigns' : '',
                                color: AppColors.secondaryDark,
                              ),
                              ProgressStat(
                                icon: Icons.back_hand_rounded,
                                label: l10n.signsCanMake,
                                value: '${progress.signsClaimed}',
                                color: AppColors.info,
                              ),
                              ProgressStat(
                                icon: Icons.verified_rounded,
                                label: l10n.signsConfirmed,
                                value: '${progress.signsConfirmed}',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: ms(400), delay: ms(800)),
                        SizedBox(height: layout.sectionGap),
                      ],
                    ];

                    return show.signFirst
                        ? [...signing, ...reading]
                        : [...reading, ...signing];
                  })(),

                  // ─── Star Collection ─────────────
                  // Decorative — the star *count* is already in the stat grid
                  // at the top — so it is the first thing dropped when the page
                  // needs to be shorter.
                  if (show.showStarGrid) ...[
                    ProgressSectionHeader(
                      title: l10n.starCollection,
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    _StarGrid(
                      totalStars: totalStars,
                    ).animate().fadeIn(duration: ms(400), delay: ms(800)),

                    SizedBox(height: layout.sectionGap),
                  ],

                  // ─── Achievement Badges ──────────
                  ProgressSectionHeader(
                    title: l10n.achievements,
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final unlockedIds = ref.watch(
                        unlockedAchievementsProvider,
                      );
                      if (unlockedIds.isEmpty) {
                        return _EmptyNote(
                          icon: Icons.emoji_events_outlined,
                          message: l10n.firstBadgePrompt,
                        ).animate().fadeIn(duration: ms(400), delay: ms(900));
                      }
                      // A short page shows what was earned and counts the rest.
                      // Thirty-seven badges of which most are grey reads as a
                      // list of failures to a learner who is already finding
                      // the page long.
                      final shown = show.showLockedAchievements
                          ? Achievements.all
                          : Achievements.all
                                .where((a) => unlockedIds.contains(a.id))
                                .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!show.showLockedAchievements)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                l10n.badgesEarned(
                                  unlockedIds.length,
                                  Achievements.all.length,
                                ),
                                style: AppTypography.labelLarge.copyWith(
                                  color: HCColor.of(context).textSecondary,
                                ),
                              ),
                            ),
                          _AchievementRow(
                            achievements: shown,
                            unlockedIds: unlockedIds,
                          ),
                        ],
                      ).animate().fadeIn(duration: ms(400), delay: ms(900));
                    },
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// Empty-section note
// ────────────────────────────────────────

/// "Nothing here yet" for a section, in words rather than as a row of zeros.
///
/// One implementation for the three sections that can be empty (Recent Games,
/// This Week, Achievements) — they had each declared the same 24-padding
/// icon-and-text container inline, and had already drifted apart in wording.
class _EmptyNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyNote({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: hc.textHint),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Star Collection Grid
// ────────────────────────────────────────
class _StarGrid extends StatelessWidget {
  final int totalStars;
  const _StarGrid({required this.totalStars});

  @override
  Widget build(BuildContext context) {
    final displayCount = totalStars > 20 ? totalStars : 20;
    return Semantics(
      label: '$totalStars stars earned',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalStars > 20)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '⭐ $totalStars stars collected!',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(displayCount.clamp(0, 50), (i) {
              final earned = i < totalStars;
              return Icon(
                earned ? Icons.star_rounded : Icons.star_border_rounded,
                size: 32,
                color: earned ? AppColors.warning : HCColor.of(context).border,
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Achievement Badges
// ────────────────────────────────────────
class _AchievementRow extends StatelessWidget {
  final List<Achievement> achievements;
  final Set<String> unlockedIds;
  const _AchievementRow({
    required this.achievements,
    required this.unlockedIds,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: achievements.map((a) {
        final unlocked = unlockedIds.contains(a.id);
        return Semantics(
          label:
              '${a.title} achievement${unlocked ? ', unlocked' : ', locked'}',
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? a.color.withValues(alpha: 0.15)
                      : HCColor.of(context).surfaceLight,
                  border: Border.all(
                    color: unlocked ? a.color : HCColor.of(context).border,
                    width: 2,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: a.color.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  a.icon,
                  color: unlocked ? a.color : HCColor.of(context).textHint,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                // Grow the label box with the Font Size setting (capped) so the
                // 2-line title doesn't clip at large scales.
                width: context.scaleIcon(64).clamp(64.0, 96.0),
                child: Text(
                  a.title,
                  style: AppTypography.labelSmall.copyWith(
                    color: unlocked
                        ? HCColor.of(context).textPrimary
                        : HCColor.of(context).textHint,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────
// Recent Game Score Tile
// ────────────────────────────────────────
class _RecentGameTile extends StatelessWidget {
  final GameScore score;
  const _RecentGameTile({required this.score});

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = score.total > 0 ? score.score / score.total : 0.0;
    final gt = score.gameType;
    return Semantics(
      label:
          '${gt.label}: ${score.score} of ${score.total}, '
          '${(pct * 100).round()} percent, '
          '${score.starsEarned} stars, ${_formatDate(score.date)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gt.color.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: gt.color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gt.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gt.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(gt.icon, color: gt.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gt.label,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${score.score}/${score.total}  •  ${(pct * 100).round()}%'
                    '  •  ${_formatDate(score.date)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final earned = i < score.starsEarned;
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    earned ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: earned
                        ? AppColors.warning
                        : HCColor.of(context).border,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
