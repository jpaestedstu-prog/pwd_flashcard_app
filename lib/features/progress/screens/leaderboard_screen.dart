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
import '../../../widgets/profile_avatar.dart';
import '../../../data/models/shop_data.dart';
import '../../../core/utils/reduced_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
      title: scope.displayName ?? _t(context).lbTitle,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: RichEmptyState(
                emoji: '🏅',
                title: _t(context).lbNoRankings,
                description:
                    _t(context).lbNoRankingsBody,
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
        text: _t(context).lbHidden,
        color: AppColors.warning,
      ));
    }
    if (config?.seasonStartAt != null) {
      notices.add(_noticeChip(
        icon: Icons.flag_rounded,
        text: _t(context).lbSeason,
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
      title: _t(context).lbJoinTitle,
      description: isChild
          ? _t(context).lbJoinChild
          : _t(context).lbJoinStudent,
      accentColor: AppColors.primary,
      actionLabel: isChild ? _t(context).lbJoinGroup : _t(context).joinClassTitle,
      actionIcon: Icons.group_add_rounded,
      onAction: () =>
          context.push(isChild ? '/join-home-group' : '/join-class'),
    );
  }

  Widget _notEnabled() {
    return RichEmptyState(
      emoji: '⏳',
      title: _t(context).lbNotEnabled,
      description: _t(context).lbNotEnabledBody,
      accentColor: AppColors.info,
    );
  }

  Widget _educatorNoScopes(bool isTeacher) {
    return RichEmptyState(
      emoji: '👩‍🏫',
      title: isTeacher ? _t(context).lbNoClasses : _t(context).lbNoGroups,
      description: isTeacher
          ? _t(context).lbNoClassesBody
          : _t(context).lbNoGroupsBody,
      accentColor: AppColors.primary,
      actionLabel: isTeacher ? _t(context).lbManageClasses : _t(context).lbManageGroups,
      actionIcon: Icons.settings_rounded,
      onAction: () => context.push(
          isTeacher ? '/classroom-manage' : '/home-group-manage'),
    );
  }

  Widget _errorState(LeaderboardScope scope) {
    return RichEmptyState(
      emoji: '⚠️',
      title: _t(context).lbError,
      description: _t(context).lbErrorBody,
      accentColor: AppColors.error,
      actionLabel: _t(context).lpRetry,
      actionIcon: Icons.refresh_rounded,
      onAction: () => ref.invalidate(onlineLeaderboardProvider(scope)),
    );
  }

  // ─── Scaffold shell ──────────────────────────────────────

  Widget _shell({required Widget child, String? title}) {
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
              child: Icon(Icons.emoji_events_rounded,
                  color: HCColor.of(context).graphic(AppColors.warning), size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(title ?? _t(context).lbTitle,
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
              label: _t(context).lbSort,
              value: _sort,
              options: LeaderboardSort.values,
              labelOf: (s) => _sortLabel(_t(context), s),
              onChanged: (v) => setState(() => _sort = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ChipSelector<LeaderboardPeriod>(
              label: _t(context).lbPeriod,
              value: _period,
              options: LeaderboardPeriod.values,
              labelOf: (p) => _periodLabel(_t(context), p),
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
                    .animate(
                      key: motionKey(context),
                      onPlay: motionLoop(context, reverse: true),
                    )
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
                    // Their equipped avatar and border, not their starting
                    // one — the podium is the whole point of buying either.
                    child: CosmeticAvatar(
                      avatarIndex: entry.avatarIndex,
                      equippedAvatarId: entry.equippedAvatarId,
                      equippedBorderId: entry.equippedBorderId,
                      radius: context.responsiveSize(i == 1 ? 18 : 15),
                      fontSize: context.responsiveSize(i == 1 ? 26 : 22),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.profileName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: isMe
                        ? HCColor.of(context).primary
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
        LeaderboardSort.byOverall => _t(context).lbPts(entry.rankScore),
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
                  color: HCColor.of(context).primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: HCColor.of(context).primary),
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

/// The display name of an entry's equipped Title, or null when they have none
/// (or own one that has since been withdrawn from sale).
///
/// Checks the type as well as the id, the way [CosmeticAvatar] does: these ids
/// arrive from another device's Hive rows, so an id in the title slot that
/// names an avatar is reachable — and without the guard the board would label
/// somebody "Alien".
String? _titleFor(LeaderboardEntry entry, bool isFilipino) =>
    ShopData.findOfType(entry.equippedTitleId, ShopItemType.title)
        ?.localizedName(isFilipino);

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
              child: CosmeticAvatar(
                avatarIndex: entry.avatarIndex,
                equippedAvatarId: entry.equippedAvatarId,
                equippedBorderId: entry.equippedBorderId,
                radius: 14,
                fontSize: 20,
              ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.profileName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // An equipped Title was previously visible on one
                          // screen the learner rarely opens. A title is a
                          // thing you wear in front of other people.
                          if (_titleFor(
                            entry,
                            Localizations.localeOf(context)
                                    .languageCode ==
                                'fil',
                          )
                              case final title?)
                            Text(
                              title,
                              style: AppTypography.labelSmall.copyWith(
                                color: HCColor.of(context).primary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
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
                          _t(context).lbYou,
                          style: AppTypography.labelSmall.copyWith(
                            color: HCColor.of(context).primary,
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
              _sortStat(context),
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: HCColor.of(context).primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortStat(BuildContext context) => switch (sortMode) {
        LeaderboardSort.byStars => '${entry.totalStars} ⭐',
        LeaderboardSort.byWords => _t(context).lbWords(entry.wordsLearned),
        LeaderboardSort.byStreak => _t(context).lbDays(entry.streakDays),
        LeaderboardSort.byOverall => _t(context).lbPts(entry.rankScore),
      };
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

String _sortLabel(AppLocalizations t, LeaderboardSort s) => switch (s) {
  LeaderboardSort.byStars => t.lbSortStars,
  LeaderboardSort.byWords => t.lbSortWords,
  LeaderboardSort.byStreak => t.lbSortStreak,
  LeaderboardSort.byOverall => t.lbSortOverall,
};

String _periodLabel(AppLocalizations t, LeaderboardPeriod p) => switch (p) {
  LeaderboardPeriod.allTime => t.lbAllTime,
  LeaderboardPeriod.thisWeek => t.lbThisWeek,
  LeaderboardPeriod.thisMonth => t.lbThisMonth,
};
