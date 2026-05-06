import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../data/models/leaderboard.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardSort _sort = LeaderboardSort.byOverall;
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;

  @override
  void initState() {
    super.initState();
    // Refresh on open
    Future.microtask(
        () => ref.read(leaderboardProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(leaderboardProvider.notifier);
    final entries = notifier.filtered(sort: _sort, period: _period);
    final currentProfile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.leaderboard),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Filters ──────────────────────────
          _buildFilters()
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: -0.08, end: 0),
          const SizedBox(height: 4),

          // ─── Podium (top 3) ───────────────────
          if (entries.length >= 3)
            _buildPodium(entries.take(3).toList(), currentProfile?.id)
                .animate()
                .fadeIn(duration: 500.ms, delay: 150.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                ),

          // ─── Full List ────────────────────────
          Expanded(
            child: entries.isEmpty
                ? RichEmptyState(
                    emoji: '🏅',
                    title: AppLocalizations.of(context)!.noEntriesYet,
                    description:
                        'Complete activities and games to appear on the leaderboard!',
                    accentColor: AppColors.primary,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isMe =
                          entry.profileId == currentProfile?.id;
                      return _LeaderboardTile(
                        rank: index + 1,
                        entry: entry,
                        isCurrentUser: isMe,
                        sortMode: _sort,
                      )
                          .animate()
                          .fadeIn(
                              duration: 300.ms,
                              delay: (200 + index * 60).ms)
                          .slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Sort selector
          Expanded(
            child: _ChipSelector<LeaderboardSort>(
              label: 'Sort',
              value: _sort,
              options: LeaderboardSort.values,
              labelOf: (s) => s.label,
              onChanged: (v) => setState(() => _sort = v),
            ),
          ),
          const SizedBox(width: 12),
          // Period selector
          Expanded(
            child: _ChipSelector<LeaderboardPeriod>(
              label: 'Period',
              value: _period,
              options: LeaderboardPeriod.values,
              labelOf: (p) => p.label,
              onChanged: (v) => setState(() => _period = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(
      List<LeaderboardEntry> top3, String? currentProfileId) {
    // Order: 2nd, 1st, 3rd
    final order = [top3[1], top3[0], top3[2]];
    final heights = [80.0, 120.0, 60.0];
    final medals = ['🥈', '🥇', '🥉'];
    final ranks = [2, 1, 3];
    final medalGlows = [
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFFFD700), // gold
      const Color(0xFFCD7F32), // bronze
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final entry = order[i];
          final isMe = entry.profileId == currentProfileId;
          final avatar = AvatarData.getAvatar(entry.avatarIndex);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing medal
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: medalGlows[i].withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(medals[i],
                      style: TextStyle(fontSize: i == 1 ? 30 : 24)),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.12, 1.12),
                      duration: 1800.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 6),
                // Avatar with glow ring
                Container(
                  width: i == 1 ? 52 : 44,
                  height: i == 1 ? 52 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : HCColor.of(context).surfaceLight,
                    border: Border.all(
                      color: isMe
                          ? AppColors.primary
                          : medalGlows[i].withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: medalGlows[i].withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(avatar.emoji,
                        style: TextStyle(fontSize: i == 1 ? 26 : 22)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.profileName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: isMe ? AppColors.primary : HCColor.of(context).textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  _statValue(entry),
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                // Enhanced podium bar with gradient
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        medalGlows[i].withValues(alpha: 0.35),
                        medalGlows[i].withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    border: Border(
                      top: BorderSide(
                        color: medalGlows[i].withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#${ranks[i]}',
                      style: AppTypography.titleMedium.copyWith(
                        color: medalGlows[i].withValues(alpha: 0.7),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scaleY(
                      begin: 0,
                      end: 1,
                      duration: 600.ms,
                      delay: (200 + i * 150).ms,
                      alignment: Alignment.bottomCenter,
                      curve: Curves.easeOutBack,
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _statValue(LeaderboardEntry entry) => switch (_sort) {
    LeaderboardSort.byStars => '⭐ ${entry.totalStars}',
    LeaderboardSort.byWords => '📖 ${entry.wordsLearned}',
    LeaderboardSort.byStreak => '🔥 ${entry.streakDays}d',
    LeaderboardSort.byOverall => '${entry.rankScore} pts',
  };
}

// ─── Reusable Chip Selector ──────────────────────────────

class _ChipSelector<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _ChipSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${labelOf(value)}',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: AppColors.primary),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map((o) => PopupMenuItem<T>(
                value: o,
                child: Text(labelOf(o)),
              ))
          .toList(),
    );
  }
}

// ─── Leaderboard Tile ────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final LeaderboardSort sortMode;

  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.sortMode,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarData.getAvatar(entry.avatarIndex);
    final isTopThree = rank <= 3;
    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.08)
            : HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.3)
              : isTopThree
                  ? medalColors[rank - 1].withValues(alpha: 0.25)
                  : HCColor.of(context).border,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isCurrentUser ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge — enhanced for top 3
          SizedBox(
            width: 36,
            child: isTopThree
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          medalColors[rank - 1].withValues(alpha: 0.3),
                          medalColors[rank - 1].withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        ['🥇', '🥈', '🥉'][rank - 1],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),

          // Avatar with ring
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : HCColor.of(context).surfaceLight,
              border: Border.all(
                color: isCurrentUser
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : isTopThree
                        ? medalColors[rank - 1].withValues(alpha: 0.4)
                        : HCColor.of(context).border,
                width: 1.5,
              ),
              boxShadow: isTopThree
                  ? [
                      BoxShadow(
                        color: medalColors[rank - 1].withValues(alpha: 0.2),
                        blurRadius: 6,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child:
                  Text(avatar.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 10),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.profileName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: isCurrentUser
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'You',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '⭐ ${entry.totalStars}  ·  📖 ${entry.wordsLearned}  ·  🔥 ${entry.streakDays}d',
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Sort-specific stat badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              _sortStat(),
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortStat() => switch (sortMode) {
    LeaderboardSort.byStars => '${entry.totalStars} ⭐',
    LeaderboardSort.byWords => '${entry.wordsLearned} words',
    LeaderboardSort.byStreak => '${entry.streakDays} days',
    LeaderboardSort.byOverall => '${entry.rankScore} pts',
  };
}
