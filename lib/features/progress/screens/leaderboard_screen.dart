import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/models/leaderboard_config.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/firestore_stream_helpers.dart';
import '../../../providers/online_leaderboard_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../core/constants/avatar_data.dart';

/// Membership-scoped leaderboard.
///
/// A learner sees the board for the class / home group they joined (and
/// only if their teacher / parent enabled it). An educator sees and previews
/// the board for the class / group they own — they configure it from the
/// management screen. Nobody ever sees a global, cross-class board.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  // Local sort/period only used when no educator config exists.
  LeaderboardSort _sort = LeaderboardSort.byOverall;
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;

  // Educator's currently selected scope when they own more than one.
  LeaderboardScope? _educatorSelected;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return _shell(child: const SizedBox.shrink());
    }
    if (profile.role.isEducator) {
      return _buildEducator(profile);
    }
    return _buildLearner(profile);
  }

  // ─── Learner path ────────────────────────────────────────

  Widget _buildLearner(UserProfile profile) {
    LeaderboardScope? scope;
    if (profile.classroomId != null && profile.classroomId!.isNotEmpty) {
      scope = LeaderboardScope.classroom(
        profile.classroomId,
        displayName:
            HiveService.getCachedClassroom(profile.classroomId!)?.name,
      );
    } else if (profile.homeGroupId != null &&
        profile.homeGroupId!.isNotEmpty) {
      scope = LeaderboardScope.homeGroup(
        profile.homeGroupId,
        displayName:
            HiveService.getCachedHomeGroup(profile.homeGroupId!)?.name,
      );
    }

    if (scope == null) {
      return _shell(child: _joinPrompt(profile));
    }
    return _board(scope, viewer: profile, isEducator: false);
  }

  // ─── Educator path ───────────────────────────────────────

  Widget _buildEducator(UserProfile profile) {
    final isTeacher = profile.role == UserRole.teacher;
    final List<LeaderboardScope> scopes;
    final bool loading;
    if (isTeacher) {
      final async = ref.watch(classroomsByTeacherStreamProvider(profile.id));
      loading = async.isLoading && !async.hasValue;
      scopes = [
        for (final c in async.valueOrNull ?? const [])
          LeaderboardScope.classroom(c.id, displayName: c.name)
      ];
    } else {
      final async = ref.watch(homeGroupsByOwnerStreamProvider(profile.id));
      loading = async.isLoading && !async.hasValue;
      scopes = [
        for (final g in async.valueOrNull ?? const [])
          LeaderboardScope.homeGroup(g.id, displayName: g.name)
      ];
    }

    if (loading) {
      return _shell(child: const Center(child: CircularProgressIndicator()));
    }
    if (scopes.isEmpty) {
      return _shell(child: _educatorNoScopes(isTeacher));
    }

    final selected = (_educatorSelected != null &&
            scopes.contains(_educatorSelected))
        ? scopes.firstWhere((s) => s == _educatorSelected)
        : scopes.first;

    return _board(
      selected,
      viewer: profile,
      isEducator: true,
      educatorScopes: scopes,
    );
  }

  // ─── The board itself ────────────────────────────────────

  Widget _board(
    LeaderboardScope scope, {
    required UserProfile viewer,
    required bool isEducator,
    List<LeaderboardScope>? educatorScopes,
  }) {
    final entriesAsync = ref.watch(onlineLeaderboardProvider(scope));
    final config = ref.watch(leaderboardConfigProvider(scope)).valueOrNull;

    // Learners only see the board when the educator has enabled it.
    final hiddenForLearner =
        !isEducator && (config == null || !config.visible);

    return _shell(
      title: scope.displayName ?? 'Leaderboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(onlineLeaderboardProvider(scope));
          await ref.read(onlineLeaderboardProvider(scope).future);
        },
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorState(scope),
          data: (raw) {
            if (hiddenForLearner) return _notEnabled();

            final sort = config?.metric ?? _sort;
            final period = config?.period ?? _period;
            final entries = applyLeaderboardFilters(
              raw,
              sort: sort,
              period: period,
              hiddenIds: config?.hiddenMemberIds.toSet() ?? const {},
              seasonStartAt: config?.seasonStartAt,
            );

            return _scrollBody(
              scope: scope,
              entries: entries,
              viewer: viewer,
              isEducator: isEducator,
              educatorScopes: educatorScopes,
              config: config,
              sort: sort,
            );
          },
        ),
      ),
    );
  }

  Widget _scrollBody({
    required LeaderboardScope scope,
    required List<LeaderboardEntry> entries,
    required UserProfile viewer,
    required bool isEducator,
    required List<LeaderboardScope>? educatorScopes,
    required LeaderboardConfig? config,
    required LeaderboardSort sort,
  }) {
    // Local sort/period chips appear only when no educator config governs
    // the board (otherwise the educator's choice is authoritative).
    final showLocalFilters = config == null;

    return CustomScrollView(
      // Always scrollable so RefreshIndicator works even on short lists.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _header(scope, isEducator, educatorScopes, config),
        ),
        if (showLocalFilters)
          SliverToBoxAdapter(
            child: _buildFilters()
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.08, end: 0),
          ),
        if (entries.length >= 3)
          SliverToBoxAdapter(
            child: _buildPodium(entries.take(3).toList(), sort, viewer.id)
                .animate()
                .fadeIn(duration: 500.ms, delay: 150.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                ),
          ),
        if (entries.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: RichEmptyState(
                emoji: '🏅',
                title: 'No rankings yet',
                description:
                    'Complete activities and games to appear on the leaderboard!',
                accentColor: AppColors.primary,
              ),
            ),
          )
        else
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  final isMe = entry.profileId == viewer.id;
                  return _LeaderboardTile(
                    rank: index + 1,
                    entry: entry,
                    isCurrentUser: isMe,
                    sortMode: sort,
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 40).ms)
                      .slideX(begin: 0.05, end: 0);
                },
                childCount: entries.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ─── Header (scope name, educator scope picker, notices) ─

  Widget _header(
    LeaderboardScope scope,
    bool isEducator,
    List<LeaderboardScope>? educatorScopes,
    LeaderboardConfig? config,
  ) {
    final hc = HCColor.of(context);
    final notices = <Widget>[];

    if (isEducator && (config == null || !config.visible)) {
      notices.add(_noticeChip(
        icon: Icons.visibility_off_rounded,
        text: 'Hidden from members — enable in Leaderboard settings',
        color: AppColors.warning,
      ));
    }
    if (config?.seasonStartAt != null) {
      notices.add(_noticeChip(
        icon: Icons.flag_rounded,
        text: 'Season active — ranking recent activity',
        color: AppColors.info,
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Educator scope picker (only when they own more than one).
          if (isEducator &&
              educatorScopes != null &&
              educatorScopes.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in educatorScopes)
                  ChoiceChip(
                    label: Text(s.displayName ?? 'Group',
                        overflow: TextOverflow.ellipsis),
                    selected: s == scope,
                    onSelected: (_) =>
                        setState(() => _educatorSelected = s),
                  ),
              ],
            ),
          if (scope.displayName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                scope.displayName!,
                style:
                    AppTypography.titleMedium.copyWith(color: hc.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          for (final n in notices)
            Padding(padding: const EdgeInsets.only(top: 8), child: n),
        ],
      ),
    );
  }

  Widget _noticeChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTypography.bodySmall
                  .copyWith(color: HCColor.of(context).textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty / disabled states ─────────────────────────────

  Widget _joinPrompt(UserProfile profile) {
    final isChild = profile.role == UserRole.child;
    return RichEmptyState(
      emoji: '🏅',
      title: 'Join to see the leaderboard',
      description: isChild
          ? 'Join your family home group to see how you rank with everyone!'
          : 'Join your class to see how you rank with your classmates!',
      accentColor: AppColors.primary,
      actionLabel: isChild ? 'Join a Home Group' : 'Join a Class',
      actionIcon: Icons.group_add_rounded,
      onAction: () =>
          context.push(isChild ? '/join-home-group' : '/join-class'),
    );
  }

  Widget _notEnabled() {
    return const RichEmptyState(
      emoji: '⏳',
      title: 'Leaderboard not enabled yet',
      description:
          'Your teacher or parent hasn\'t turned on the leaderboard for your group yet. Check back soon!',
      accentColor: AppColors.info,
    );
  }

  Widget _educatorNoScopes(bool isTeacher) {
    return RichEmptyState(
      emoji: '👩‍🏫',
      title: isTeacher ? 'No classes yet' : 'No home groups yet',
      description: isTeacher
          ? 'Create a class and invite students to start a leaderboard.'
          : 'Create a home group and invite your children to start a leaderboard.',
      accentColor: AppColors.primary,
      actionLabel: isTeacher ? 'Manage Classes' : 'Manage Home Groups',
      actionIcon: Icons.settings_rounded,
      onAction: () => context.push(
          isTeacher ? '/classroom-manage' : '/home-group-manage'),
    );
  }

  Widget _errorState(LeaderboardScope scope) {
    return RichEmptyState(
      emoji: '⚠️',
      title: 'Couldn\'t load the leaderboard',
      description:
          'Check your connection and try again. Your last-known rankings show when you\'re back online.',
      accentColor: AppColors.error,
      actionLabel: 'Retry',
      actionIcon: Icons.refresh_rounded,
      onAction: () => ref.invalidate(onlineLeaderboardProvider(scope)),
    );
  }

  // ─── Scaffold shell ──────────────────────────────────────

  Widget _shell({required Widget child, String title = 'Leaderboard'}) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/progress'),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: child,
    );
  }

  // ─── Filters (local; only when no config) ────────────────

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
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

  // ─── Podium (top 3) ──────────────────────────────────────

  Widget _buildPodium(
    List<LeaderboardEntry> top3,
    LeaderboardSort sort,
    String? currentProfileId,
  ) {
    final order = [top3[1], top3[0], top3[2]];
    final screenH = MediaQuery.sizeOf(context).height;
    final heights = <double>[
      (screenH * 0.085).clamp(56.0, 110.0),
      (screenH * 0.13).clamp(84.0, 180.0),
      (screenH * 0.065).clamp(44.0, 90.0),
    ];
    final medals = ['🥈', '🥇', '🥉'];
    final ranks = [2, 1, 3];
    final medalGlows = [
      const Color(0xFFC0C0C0),
      const Color(0xFFFFD700),
      const Color(0xFFCD7F32),
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
                      style: TextStyle(
                          fontSize:
                              context.responsiveSize(i == 1 ? 30 : 24))),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.12, 1.12),
                      duration: 1800.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 6),
                Container(
                  width: context.responsiveSize(i == 1 ? 52 : 44),
                  height: context.responsiveSize(i == 1 ? 52 : 44),
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
                        style: TextStyle(
                            fontSize:
                                context.responsiveSize(i == 1 ? 26 : 22))),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.profileName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: isMe
                        ? AppColors.primary
                        : HCColor.of(context).textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  _statValue(entry, sort),
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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

  String _statValue(LeaderboardEntry entry, LeaderboardSort sort) =>
      switch (sort) {
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
            Flexible(
              child: Text(
                '$label: ${labelOf(value)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
