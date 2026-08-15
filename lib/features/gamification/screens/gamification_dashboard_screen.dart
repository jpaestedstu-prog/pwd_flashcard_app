import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/models.dart';
import '../../../data/models/shop_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/xp_level_bar.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../../features/experiment/models/experiment_models.dart';
import '../../gaze_control/widgets/gaze_dpad_scope.dart';

/// Learner-facing gamification summary — the "Player Profile" — showing the
/// level, every gamification metric, and the shortcuts to the reward screens.
///
/// Reached from the Student / Player-with-Progress home banner and the Child
/// home's "My Player Card" tile.
///
/// Three things this screen has to get right, because it is one of the few
/// places a learner visits purely for encouragement:
///
///  * **It follows the learner's theme.** Every colour resolves through
///    [HCColor], so the high-contrast, dark and dyslexia presets reach it. It
///    used to render the same pastel-on-white regardless — a learner on the
///    visual-impairment preset saw a high-contrast home and then this.
///  * **Its chips are readable.** The quick actions were coloured text on an
///    8%-alpha tint of that same colour, the worst contrast on the screen.
///    Labels are now [HCColor.textPrimary] on a surface, with the colour
///    carried by the icon and border instead of the text.
///  * **It is reachable hands-free.** The actions publish [GazeDpadCell]s in
///    the same rows they are drawn in, plus an exit row, so the head D-pad and
///    spoken commands operate it like any hub. Without that, a gaze learner
///    could open this screen from the home tile and then only fall back to
///    generic focus traversal, with nothing to say out loud.
class GamificationDashboardScreen extends ConsumerWidget {
  const GamificationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final experiment = ref.watch(experimentProvider);
    final hc = HCColor.of(context);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('No profile')),
      );
    }

    final achievements = ref.watch(unlockedAchievementsProvider);
    final totalAchievements = Achievements.all.length;
    final stickers = HiveService.getOwnedStickers(profile.id);
    final equippedAvatar = ref
        .read(progressProvider.notifier)
        .getEquippedShopItem(ShopItemType.avatar);
    final equippedTitle = ref
        .read(progressProvider.notifier)
        .getEquippedShopItem(ShopItemType.title);

    final actions = _actionsFor(context, isFilipino, experiment, hc);

    // The action grid's column count is computed here, not inside the body, so
    // the published gaze rows and the drawn rows come from the same number —
    // ▲ ▼ only means anything if a published row is a row on screen.
    return LayoutBuilder(
      builder: (context, outer) {
        final width = outer.maxWidth - context.pagePadding * 2;
        final statColumns = _columnsFor(context, width, minTile: _minStatTile);
        // Actions may drop to one per row: their labels are phrases, and at XL
        // font on a small phone even two columns cannot fit "Leaderboard"
        // without breaking it mid-word. Bigger text buys fewer columns, which
        // is the accessible trade — shrinking the label would undo the setting
        // the learner just chose. Stat tiles hold short numbers and stay at 2+.
        final actionColumns = _columnsFor(
          context,
          width,
          minTile: _minActionTile,
          minColumns: 1,
        );
        final actionRows = _chunk(actions, actionColumns);

        return GazeDpadScope(
          rows: [
            for (final row in actionRows)
              [
                for (final a in row)
                  GazeDpadCell(
                    label: a.label,
                    onActivate: () => a.open(context),
                  ),
              ],
          ],
          // The way out. A learner who cannot reach a touch target cannot reach
          // the app bar's back arrow either.
          onExit: () => context.popOrGo('/home'),
          exitLabel: isFilipino ? 'Bumalik' : 'Back',
          builder: (context, gaze) => _body(
            context: context,
            hc: hc,
            profile: profile,
            progress: progress,
            equippedAvatar: equippedAvatar,
            equippedTitle: equippedTitle,
            achievementsUnlocked: achievements.length,
            totalAchievements: totalAchievements,
            stickerCount: stickers.length,
            isFilipino: isFilipino,
            experiment: experiment,
            statColumns: statColumns,
            actionColumns: actionColumns,
            actionRows: actionRows,
            gaze: gaze,
          ),
        );
      },
    );
  }

  Widget _body({
    required BuildContext context,
    required HCColor hc,
    required UserProfile profile,
    required LearningProgress progress,
    required ShopItem? equippedAvatar,
    required ShopItem? equippedTitle,
    required int achievementsUnlocked,
    required int totalAchievements,
    required int stickerCount,
    required bool isFilipino,
    required ExperimentConfig experiment,
    required int statColumns,
    required int actionColumns,
    required List<List<_ActionItem>> actionRows,
    required GazeDpadState gaze,
  }) {
    final padding = context.pagePadding;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        title: Text(isFilipino ? 'Profile ng Manlalaro' : 'Player Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: hc.textPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              hc.primary.withValues(alpha: hc.isDark ? 0.16 : 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              // Stretch, so the player card fills the width like everything
              // else — it used to shrink-wrap its name and float as a narrow
              // island above a full-width grid.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlayerCard(
                      name: profile.name,
                      avatarIndex: profile.avatarIndex,
                      equippedAvatar: equippedAvatar,
                      equippedTitle: equippedTitle,
                      hc: hc,
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.05, end: 0),
                const SizedBox(height: 20),
                // Level & next goal. The screen is *named* Player Profile and
                // used to be the one place that never mentioned the player's
                // level — it lived only on the home bar and in the level-up
                // overlay. Same widget as both home screens, so the numbers
                // cannot drift apart.
                XpLevelBar(
                  progress: progress,
                  showNextGoal: true,
                ).animate().fadeIn(duration: 400.ms, delay: 60.ms),
                const SizedBox(height: 20),
                _statsGrid(
                  progress: progress,
                  achievementsUnlocked: achievementsUnlocked,
                  totalAchievements: totalAchievements,
                  stickerCount: stickerCount,
                  isFilipino: isFilipino,
                  experiment: experiment,
                  hc: hc,
                  columns: statColumns,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 20),
                _quickActions(
                  context: context,
                  isFilipino: isFilipino,
                  hc: hc,
                  columns: actionColumns,
                  actionRows: actionRows,
                  gaze: gaze,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Layout ───────────────────────────────────────────
  //
  // Tiles are sized by a minimum readable width rather than a hardcoded
  // "always three across". At 2x font on a 360dp phone the old `/3` split gave
  // each card ~97dp for a title-large number and a two-line label.

  /// Stat tiles hold a number and a short label, so they pack tightly.
  static const double _minStatTile = 104;

  /// Action chips hold a whole phrase ("Streak Calendar"), so they need room —
  /// at the stat-tile width "Leaderboard" broke mid-word into "Leaderboa / rd".
  static const double _minActionTile = 168;

  static int _columnsFor(
    BuildContext context,
    double available, {
    required double minTile,
    int minColumns = 2,
  }) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return (available / (minTile * scale.clamp(1.0, 1.8))).floor().clamp(
      minColumns,
      4,
    );
  }

  static List<List<T>> _chunk<T>(List<T> items, int size) => [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, (i + size).clamp(0, items.length)),
  ];

  /// A grid of equal-width cells laid out in rows of [columns], so the visual
  /// rows and the published gaze rows are the same thing by construction.
  static Widget _grid({
    required List<List<Widget>> rows,
    required int columns,
    double spacing = 12,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (r, row) in rows.indexed) ...[
        if (r > 0) SizedBox(height: spacing),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(
                  // Short final rows keep the cell width of a full row
                  // instead of stretching the survivors across the page.
                  child: c < row.length ? row[c] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );

  // ─── Stats ────────────────────────────────────────────

  Widget _statsGrid({
    required LearningProgress progress,
    required int achievementsUnlocked,
    required int totalAchievements,
    required int stickerCount,
    required bool isFilipino,
    required ExperimentConfig experiment,
    required HCColor hc,
    required int columns,
  }) {
    final stats = <_StatItem>[];

    if (experiment.isFeatureEnabled(GamificationFeature.stars)) {
      stats.add(
        _StatItem(
          emoji: '⭐',
          value: '${progress.starBalance}',
          label: isFilipino ? 'Mga Bituin' : 'Stars',
          color: hc.statWarning,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.streaks)) {
      final best = progress.effectiveBestStreak;
      stats.add(
        _StatItem(
          emoji: '🔥',
          value: '${progress.streakDays}',
          label: isFilipino ? 'Araw na Streak' : 'Day Streak',
          // The personal best is what XP is scored off, so a learner whose streak
          // broke can see that the days they earned are still counted.
          sublabel: best > progress.streakDays
              ? (isFilipino ? 'Pinakamahaba: $best' : 'Best: $best')
              : null,
          color: hc.statError,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.achievements)) {
      stats.add(
        _StatItem(
          emoji: '🏆',
          value: '$achievementsUnlocked/$totalAchievements',
          label: isFilipino ? 'Mga Tagumpay' : 'Achievements',
          color: hc.statAccent,
        ),
      );
    }

    // Always show words learned
    stats.add(
      _StatItem(
        emoji: '📚',
        value: '${progress.wordsLearned}',
        label: isFilipino ? 'Natutunan' : 'Words Learned',
        color: hc.statInfo,
      ),
    );

    // Lifetime total. `recentScores` is trimmed to the last 20 for the charts,
    // so reading its length froze this tile at 20 for any regular player.
    stats.add(
      _StatItem(
        emoji: '🎮',
        value: '${progress.effectiveGamesPlayed}',
        label: isFilipino ? 'Mga Laro' : 'Games Played',
        color: hc.statSuccess,
      ),
    );

    if (experiment.isFeatureEnabled(GamificationFeature.stickers)) {
      stats.add(
        _StatItem(
          emoji: '🎨',
          value: '$stickerCount',
          label: isFilipino ? 'Mga Sticker' : 'Stickers',
          color: hc.statSecondary,
        ),
      );
    }

    return _grid(
      columns: columns,
      rows: _chunk([
        for (final s in stats) _StatCard(stat: s, hc: hc),
      ], columns),
    );
  }

  // ─── Quick actions ────────────────────────────────────

  List<_ActionItem> _actionsFor(
    BuildContext context,
    bool isFilipino,
    ExperimentConfig experiment,
    HCColor hc,
  ) {
    final actions = <_ActionItem>[];

    if (experiment.isFeatureEnabled(GamificationFeature.leaderboard)) {
      actions.add(
        _ActionItem(
          icon: Icons.leaderboard_rounded,
          label: isFilipino ? 'Leaderboard' : 'Leaderboard',
          route: '/leaderboard',
          color: hc.statInfo,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.shop)) {
      actions.add(
        _ActionItem(
          icon: Icons.store_rounded,
          label: isFilipino ? 'Tindahan' : 'Shop',
          route: '/shop',
          color: hc.statWarning,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.streaks)) {
      actions.add(
        _ActionItem(
          icon: Icons.calendar_month_rounded,
          label: isFilipino ? 'Kalendaryo' : 'Streak Calendar',
          route: '/streak-calendar',
          color: hc.statError,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.stickers)) {
      actions.add(
        _ActionItem(
          icon: Icons.auto_awesome_rounded,
          label: isFilipino ? 'Album' : 'Sticker Album',
          route: '/sticker-album',
          color: hc.statSecondary,
        ),
      );
    }

    if (experiment.isFeatureEnabled(GamificationFeature.dailyChallenge)) {
      actions.add(
        _ActionItem(
          icon: Icons.today_rounded,
          label: 'Daily Challenge',
          route: '/daily-challenge',
          color: hc.statSuccess,
        ),
      );
    }

    actions.add(
      _ActionItem(
        icon: Icons.bar_chart_rounded,
        label: isFilipino ? 'Progreso' : 'Progress',
        route: '/progress',
        color: hc.statAccent,
        useGo: true, // Progress is a ShellRoute tab — must use go() not push()
      ),
    );

    return actions;
  }

  Widget _quickActions({
    required BuildContext context,
    required bool isFilipino,
    required HCColor hc,
    required int columns,
    required List<List<_ActionItem>> actionRows,
    required GazeDpadState gaze,
  }) {
    if (actionRows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFilipino ? 'Mga Mabilisang Aksyon' : 'Quick Actions',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: hc.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _grid(
          columns: columns,
          rows: [
            for (final (r, row) in actionRows.indexed)
              [
                for (final (c, action) in row.indexed)
                  _ActionChip(
                    action: action,
                    hc: hc,
                    focused: gaze.isFocused(r, c),
                    onTap: () => action.open(context),
                  ),
              ],
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final int avatarIndex;
  final ShopItem? equippedAvatar;
  final ShopItem? equippedTitle;
  final HCColor hc;

  const _PlayerCard({
    required this.name,
    required this.avatarIndex,
    this.equippedAvatar,
    this.equippedTitle,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: hc.surface,
      borderRadius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  hc.primary.withValues(alpha: 0.3),
                  hc.primary.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Center(
              child: Text(
                equippedAvatar?.emoji ?? _defaultEmoji(avatarIndex),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            name,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: hc.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Title
          if (equippedTitle != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: hc.primary.withValues(alpha: hc.isDark ? 0.24 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hc.primary.withValues(alpha: 0.5)),
              ),
              child: Text(
                equippedTitle!.name,
                style: AppTypography.labelMedium.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _defaultEmoji(int index) {
    const avatars = ['😊', '😎', '🤓', '🦸', '🧙', '🐱', '🦊', '🐸'];
    return avatars[index % avatars.length];
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;
  final HCColor hc;

  const _StatCard({required this.stat, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${stat.value} ${stat.label}'
          '${stat.sublabel != null ? ', ${stat.sublabel}' : ''}',
      excludeSemantics: true,
      child: AppCard(
        color: hc.surface,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(stat.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            FittedBox(
              // The value is the biggest text in the tile; at XL font scales it
              // is what used to push the row into an overflow stripe.
              fit: BoxFit.scaleDown,
              child: Text(
                stat.value,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: stat.color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (stat.sublabel != null)
              Text(
                stat.sublabel!,
                style: AppTypography.labelSmall.copyWith(
                  color: stat.color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// A quick-action shortcut.
///
/// The label is [HCColor.textPrimary] on [HCColor.surface] — a contrast pair
/// the theme already guarantees — while the action's colour is carried by the
/// icon and the border. The previous chip painted the label *in* the accent
/// colour over an 8%-alpha wash of it, which on the light theme left "Shop" as
/// orange-on-almost-white.
class _ActionChip extends StatelessWidget {
  final _ActionItem action;
  final HCColor hc;
  final bool focused;
  final VoidCallback onTap;

  const _ActionChip({
    required this.action,
    required this.hc,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Comfortably above the 48dp accessibility floor, and it grows with the
    // Font Size setting so the label never crowds the icon.
    final minHeight = context.scaledHeightCapped(56, max: 1.6);

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: Stack(
        // Without this the non-positioned Material gets *loose* constraints and
        // shrink-wraps its label, so "Shop" drew a chip half the width of
        // "Streak Calendar" in the same grid row.
        fit: StackFit.passthrough,
        children: [
          Material(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: action.color.withValues(alpha: hc.hc ? 1.0 : 0.55),
                    width: hc.hc ? 2 : 1.5,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, color: action.color, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          action.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String emoji;
  final String value;
  final String label;

  /// Optional second line under [label], e.g. a personal best.
  final String? sublabel;
  final Color color;

  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    this.sublabel,
  });
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final bool useGo;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    this.useGo = false,
  });

  void open(BuildContext context) =>
      useGo ? context.go(route) : context.push(route);
}
