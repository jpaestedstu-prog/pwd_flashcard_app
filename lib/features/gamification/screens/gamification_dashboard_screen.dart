import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/shop_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../../features/experiment/models/experiment_models.dart';

/// Student-facing gamification summary screen showing a "Player Profile"
/// with all gamification metrics in one place.
class GamificationDashboardScreen extends ConsumerWidget {
  const GamificationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final experiment = ref.watch(experimentProvider);
    final padding = context.pagePadding;
    final colorScheme = Theme.of(context).colorScheme;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('No profile')),
      );
    }

    final achievements =
        HiveService.getUnlockedAchievements(profile.id);
    final totalAchievements = Achievements.all.length;
    final stickers = HiveService.getOwnedStickers(profile.id);
    final equippedAvatar =
        ref.read(progressProvider.notifier).getEquippedShopItem(ShopItemType.avatar);
    final equippedTitle =
        ref.read(progressProvider.notifier).getEquippedShopItem(ShopItemType.title);

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Profile ng Manlalaro' : 'Player Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                // Player card
                _PlayerCard(
                  name: profile.name,
                  avatarIndex: profile.avatarIndex,
                  equippedAvatar: equippedAvatar,
                  equippedTitle: equippedTitle,
                  isFilipino: isFilipino,
                  colorScheme: colorScheme,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
                const SizedBox(height: 20),
                // Stats grid
                _buildStatsGrid(
                  context,
                  ref,
                  progress,
                  achievements.length,
                  totalAchievements,
                  stickers.length,
                  isFilipino,
                  experiment,
                  colorScheme,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 20),
                // Quick actions
                _buildQuickActions(
                    context, isFilipino, experiment, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    WidgetRef ref,
    dynamic progress,
    int achievementsUnlocked,
    int totalAchievements,
    int stickerCount,
    bool isFilipino,
    ExperimentConfig experiment,
    ColorScheme colorScheme,
  ) {
    final stats = <_StatItem>[];

    if (experiment.isFeatureEnabled(GamificationFeature.stars)) {
      stats.add(_StatItem(
        emoji: '⭐',
        value: '${progress.starBalance}',
        label: isFilipino ? 'Mga Bituin' : 'Stars',
        color: Colors.amber,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.streaks)) {
      stats.add(_StatItem(
        emoji: '🔥',
        value: '${progress.streakDays}',
        label: isFilipino ? 'Araw na Streak' : 'Day Streak',
        color: Colors.deepOrange,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.achievements)) {
      stats.add(_StatItem(
        emoji: '🏆',
        value: '$achievementsUnlocked/$totalAchievements',
        label: isFilipino ? 'Mga Tagumpay' : 'Achievements',
        color: Colors.purple,
      ));
    }

    // Always show words learned
    stats.add(_StatItem(
      emoji: '📚',
      value: '${progress.wordsLearned}',
      label: isFilipino ? 'Natutunan' : 'Words Learned',
      color: Colors.blue,
    ));

    stats.add(_StatItem(
      emoji: '🎮',
      value: '${progress.recentScores.length}',
      label: isFilipino ? 'Mga Laro' : 'Games Played',
      color: Colors.teal,
    ));

    if (experiment.isFeatureEnabled(GamificationFeature.stickers)) {
      stats.add(_StatItem(
        emoji: '🎨',
        value: '$stickerCount',
        label: isFilipino ? 'Mga Sticker' : 'Stickers',
        color: Colors.pink,
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: stats.asMap().entries.map((entry) {
        final stat = entry.value;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 3 * 12 - 2 * context.pagePadding) / 3,
          child: _StatCard(stat: stat, colorScheme: colorScheme),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    bool isFilipino,
    ExperimentConfig experiment,
    ColorScheme colorScheme,
  ) {
    final actions = <_ActionItem>[];

    if (experiment.isFeatureEnabled(GamificationFeature.leaderboard)) {
      actions.add(const _ActionItem(
        icon: Icons.leaderboard_rounded,
        label: 'Leaderboard',
        route: '/leaderboard',
        color: Colors.indigo,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.shop)) {
      actions.add(_ActionItem(
        icon: Icons.store_rounded,
        label: isFilipino ? 'Tindahan' : 'Shop',
        route: '/shop',
        color: Colors.amber.shade700,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.streaks)) {
      actions.add(_ActionItem(
        icon: Icons.calendar_month_rounded,
        label: isFilipino ? 'Kalendaryo' : 'Streak Calendar',
        route: '/streak-calendar',
        color: Colors.deepOrange,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.stickers)) {
      actions.add(_ActionItem(
        icon: Icons.auto_awesome_rounded,
        label: isFilipino ? 'Album' : 'Sticker Album',
        route: '/sticker-album',
        color: Colors.pink,
      ));
    }

    if (experiment.isFeatureEnabled(GamificationFeature.dailyChallenge)) {
      actions.add(_ActionItem(
        icon: Icons.today_rounded,
        label: isFilipino ? 'Daily Challenge' : 'Daily Challenge',
        route: '/daily-challenge',
        color: Colors.green,
      ));
    }

    actions.add(_ActionItem(
      icon: Icons.bar_chart_rounded,
      label: isFilipino ? 'Progreso' : 'Progress',
      route: '/progress',
      color: Colors.blue,
      useGo: true, // Progress is a ShellRoute tab — must use go() not push()
    ));

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFilipino ? 'Mga Mabilisang Aksyon' : 'Quick Actions',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.asMap().entries.map((entry) {
            final action = entry.value;
            return Semantics(
              button: true,
              label: action.label,
              child: Material(
                color: action.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => action.useGo
                      ? context.go(action.route)
                      : context.push(action.route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, color: action.color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          action.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: action.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
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
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _PlayerCard({
    required this.name,
    required this.avatarIndex,
    this.equippedAvatar,
    this.equippedTitle,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
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
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primary.withValues(alpha: 0.1),
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
              ),
            ),
            // Title
            if (equippedTitle != null) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  equippedTitle!.name,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
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
  final ColorScheme colorScheme;

  const _StatCard({required this.stat, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(stat.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              stat.value,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: stat.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: AppTypography.labelSmall.copyWith(
                color: colorScheme.onSurfaceVariant,
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

class _StatItem {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
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
}
