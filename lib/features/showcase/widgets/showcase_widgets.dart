import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../data/models/enums.dart';
import '../models/showcase_models.dart';

/// A card displaying a single showcase portfolio item with enhanced visuals:
/// shimmer shine on header, glow for pinned items, mastery progress bar,
/// and type-specific decorative background accent.
class ShowcaseCard extends StatelessWidget {
  final ShowcaseItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onRemove;

  const ShowcaseCard({
    super.key,
    required this.item,
    this.onTap,
    this.onPin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final typeColor = item.type.color;

    return Semantics(
      button: true,
      label:
          '${item.type.label}: ${item.title}. ${item.description}. '
          '${item.isPinned ? "Pinned." : ""}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: item.isPinned
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: item.isPinned
                  ? typeColor.withValues(alpha: 0.6)
                  : hc.border,
              width: item.isPinned ? 2 : 1,
            ),
          ),
          color: hc.surface,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header with type color + shine ────
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            typeColor.withValues(alpha: 0.18),
                            item.type.lightColor,
                            typeColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Enhanced emoji container with double ring
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: typeColor.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                item.type.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.type.label,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: typeColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: hc.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (item.isPinned)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.push_pin_rounded,
                                size: 16,
                                color: typeColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Shimmer shine overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: const Alignment(-1.5, -0.5),
                              end: const Alignment(1.5, 0.5),
                            ),
                          ),
                        )
                            .animate(
                              onPlay: (c) => c.repeat(),
                            )
                            .moveX(
                              begin: -200,
                              end: 200,
                              duration: 3000.ms,
                              curve: Curves.easeInOut,
                            )
                            .fadeIn(duration: 600.ms),
                      ),
                    ),
                  ],
                ),

                // ─── Body ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    item.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ─── Score + mastery progress bar ─────
                if (item.score != null && item.total != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stars_rounded,
                                      size: 13, color: typeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.score}/${item.total}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: typeColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.masteryPercent != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _masteryColor(item.masteryPercent!)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(item.masteryPercent! * 100).round()}%',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: _masteryColor(item.masteryPercent!),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Mastery progress bar
                        if (item.masteryPercent != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Stack(
                                children: [
                                  Container(
                                    color: _masteryColor(item.masteryPercent!)
                                        .withValues(alpha: 0.12),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor:
                                        item.masteryPercent!.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _masteryColor(item.masteryPercent!),
                                            _masteryColor(item.masteryPercent!)
                                                .withValues(alpha: 0.7),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  )
                                      .animate()
                                      .scaleX(
                                        begin: 0,
                                        end: 1,
                                        duration: 800.ms,
                                        delay: 300.ms,
                                        alignment: Alignment.centerLeft,
                                        curve: Curves.easeOutCubic,
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                if (item.category != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Chip(
                      label: Text(
                        item.category!.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: item.category!.darkColor,
                        ),
                      ),
                      backgroundColor:
                          item.category!.color.withValues(alpha: 0.3),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                    ),
                  ),

                // ─── Footer: date + actions ─────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: hc.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(item.earnedAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textHint,
                        ),
                      ),
                      const Spacer(),
                      if (onPin != null)
                        IconButton(
                          onPressed: onPin,
                          icon: Icon(
                            item.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            size: 18,
                            color: item.isPinned
                                ? typeColor
                                : hc.textHint,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: item.isPinned ? 'Unpin' : 'Pin to top',
                        ),
                      if (onRemove != null)
                        IconButton(
                          onPressed: onRemove,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: hc.textHint,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove from showcase',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _masteryColor(double pct) {
    if (pct >= 0.9) return AppColors.success;
    if (pct >= 0.7) return AppColors.info;
    if (pct >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Header widget for the portfolio showing student name & stats
class PortfolioHeader extends StatelessWidget {
  final String name;
  final int totalItems;
  final int pinnedItems;
  final int achievementCount;
  final int starsEarned;

  const PortfolioHeader({
    super.key,
    required this.name,
    required this.totalItems,
    required this.pinnedItems,
    required this.achievementCount,
    required this.starsEarned,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE040FB), Color(0xFF7C4DFF), Color(0xFF536DFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎨', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$name's Portfolio",
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Showcase your best moments!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MiniStat(
                icon: Icons.collections_bookmark_rounded,
                label: 'Items',
                value: '$totalItems',
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.push_pin_rounded,
                label: 'Pinned',
                value: '$pinnedItems',
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.emoji_events_rounded,
                label: 'Awards',
                value: '$achievementCount',
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.star_rounded,
                label: 'Stars',
                value: '$starsEarned',
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.1, end: 0);
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textOnPrimary, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.75),
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no showcase items exist yet
class ShowcaseEmptyState extends StatelessWidget {
  final VoidCallback onAutoPopulate;

  const ShowcaseEmptyState({
    super.key,
    required this.onAutoPopulate,
  });

  @override
  Widget build(BuildContext context) {
    return RichEmptyState(
      emoji: '🖼️',
      title: 'Your Portfolio is Empty',
      description:
          'Start by auto-curating your best moments or add items manually as you learn!',
      actionLabel: 'Auto-Curate My Portfolio',
      actionIcon: Icons.auto_awesome_rounded,
      onAction: onAutoPopulate,
      accentColor: const Color(0xFF7C4DFF),
    );
  }
}

/// Filter chip row for showcase item types
class ShowcaseFilterChips extends StatelessWidget {
  final ShowcaseItemType? selectedFilter;
  final Map<ShowcaseItemType, int> typeCounts;
  final ValueChanged<ShowcaseItemType?> onFilterChanged;

  const ShowcaseFilterChips({
    super.key,
    this.selectedFilter,
    required this.typeCounts,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selectedFilter == null,
              label: const Text('All'),
              onSelected: (_) => onFilterChanged(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...ShowcaseItemType.values.where((t) => (typeCounts[t] ?? 0) > 0).map(
            (type) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selectedFilter == type,
                label: Text(
                    '${type.emoji} ${type.label} (${typeCounts[type] ?? 0})'),
                onSelected: (_) => onFilterChanged(
                    selectedFilter == type ? null : type),
                selectedColor: type.color.withValues(alpha: 0.2),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
