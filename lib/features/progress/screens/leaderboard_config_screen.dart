import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/models/leaderboard_config.dart';
import '../../../providers/classroom_management_provider.dart';
import '../../../providers/home_group_provider.dart';
import '../../../providers/online_leaderboard_provider.dart';
import '../../../widgets/app_back_button.dart';

/// Educator-facing leaderboard controls for one classroom / home group.
///
/// Reached from the class / group management screen. All controls live in a
/// single scroll view so the screen never overflows on a tablet at large
/// font scale.
class LeaderboardConfigScreen extends ConsumerWidget {
  final LeaderboardScope scope;

  const LeaderboardConfigScreen({super.key, required this.scope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final configAsync = ref.watch(leaderboardConfigProvider(scope));
    final config = configAsync.valueOrNull ??
        LeaderboardConfig.defaults(scope.id ?? '');
    final writer = ref.read(leaderboardConfigWriterProvider);

    void save(LeaderboardConfig next) => writer.save(scope, next);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Leaderboard Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scope.displayName != null) ...[
                Text(
                  scope.displayName!,
                  style:
                      AppTypography.titleLarge.copyWith(color: hc.textPrimary),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Visibility ──────────────────────────
              _Section(
                title: 'Visibility',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.visible,
                  activeThumbColor: AppColors.primary,
                  title: Text('Show leaderboard to members',
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textPrimary)),
                  subtitle: Text(
                    config.visible
                        ? 'Members can see the rankings.'
                        : 'Hidden — members see "not enabled yet".',
                    style: AppTypography.bodySmall
                        .copyWith(color: hc.textSecondary),
                  ),
                  onChanged: (v) => save(config.copyWith(visible: v)),
                ),
              ),

              // ─── Ranking metric ──────────────────────
              _Section(
                title: 'Rank by',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in LeaderboardSort.values)
                      ChoiceChip(
                        label: Text(m.label),
                        selected: config.metric == m,
                        onSelected: (_) => save(config.copyWith(metric: m)),
                      ),
                  ],
                ),
              ),

              // ─── Time period / reset ─────────────────
              _Section(
                title: 'Time period',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in LeaderboardPeriod.values)
                          ChoiceChip(
                            label: Text(p.label),
                            selected: config.period == p,
                            onSelected: (_) =>
                                save(config.copyWith(period: p)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Start new season'),
                            onPressed: () => save(config.copyWith(
                                seasonStartAt: DateTime.now())),
                          ),
                        ),
                        if (config.seasonStartAt != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Clear season',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                save(config.copyWith(clearSeason: true)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Weekly/Monthly and seasons rank by recent activity. '
                      'Lifetime stars are always shown for reference.',
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ],
                ),
              ),

              // ─── Hidden members ──────────────────────
              _Section(
                title: 'Hide members',
                child: _MemberHideList(
                  scope: scope,
                  hiddenIds: config.hiddenMemberIds.toSet(),
                  onToggle: (profileId, hidden) {
                    final next = config.hiddenMemberIds.toSet();
                    if (hidden) {
                      next.add(profileId);
                    } else {
                      next.remove(profileId);
                    }
                    save(config.copyWith(hiddenMemberIds: next.toList()));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Roster with a per-member visibility toggle.
class _MemberHideList extends ConsumerWidget {
  final LeaderboardScope scope;
  final Set<String> hiddenIds;
  final void Function(String profileId, bool hidden) onToggle;

  const _MemberHideList({
    required this.scope,
    required this.hiddenIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    // Build a unified (id, name) list from whichever roster applies.
    final List<({String id, String name})> roster;
    if (scope.kind == LeaderboardScopeKind.classroom) {
      final members =
          ref.watch(classroomMembersProvider(scope.id!)).valueOrNull ??
              const [];
      roster = [
        for (final m in members) (id: m.profileId, name: m.displayName)
      ];
    } else {
      final members =
          ref.watch(homeGroupMembersProvider(scope.id!)).valueOrNull ??
              const [];
      roster = [
        for (final m in members) (id: m.profileId, name: m.displayName)
      ];
    }

    if (roster.isEmpty) {
      return Text('No members have joined yet.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary));
    }

    return Column(
      children: [
        for (final member in roster)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: !hiddenIds.contains(member.id),
            activeThumbColor: AppColors.primary,
            title: Text(member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.bodyMedium.copyWith(color: hc.textPrimary)),
            subtitle: Text(
              hiddenIds.contains(member.id) ? 'Hidden' : 'Shown',
              style:
                  AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            onChanged: (shown) => onToggle(member.id, !shown),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: AppColors.softShadow,
      ),
      // Transparent Material so any ListTile/SwitchListTile inside paints
      // its ink + background on a surface that sits *below* this colored
      // container (otherwise the container hides the tile's effects).
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    AppTypography.titleMedium.copyWith(color: hc.textPrimary)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
