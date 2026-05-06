import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../models/showcase_models.dart';

/// Detail view for a single showcase portfolio item
class ShowcaseDetailScreen extends ConsumerWidget {
  final ShowcaseItem item;

  const ShowcaseDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      body: CustomScrollView(
        slivers: [
          // ─── Gradient Header ─────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textOnPrimary),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                item.title,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.type.color,
                      item.type.color.withValues(alpha: 0.7),
                      const Color(0xFF536DFE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Text(item.type.emoji,
                          style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.type.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Description ─────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: hc.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_rounded,
                              size: 20, color: item.type.color),
                          const SizedBox(width: 8),
                          Text(
                            'Description',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.description,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                // ─── Details Card ────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: hc.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 20, color: item.type.color),
                          const SizedBox(width: 8),
                          Text(
                            'Details',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.category_rounded,
                        label: 'Type',
                        value: item.type.label,
                        color: item.type.color,
                        hc: hc,
                      ),
                      _DetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Earned',
                        value: _formatDateLong(item.earnedAt),
                        color: hc.info,
                        hc: hc,
                      ),
                      if (item.score != null && item.total != null)
                        _DetailRow(
                          icon: Icons.score_rounded,
                          label: 'Score',
                          value: '${item.score}/${item.total}',
                          color: AppColors.warning,
                          hc: hc,
                        ),
                      if (item.masteryPercent != null)
                        _DetailRow(
                          icon: Icons.percent_rounded,
                          label: 'Mastery',
                          value:
                              '${(item.masteryPercent! * 100).round()}%',
                          color: _masteryColor(item.masteryPercent!),
                          hc: hc,
                        ),
                      if (item.category != null)
                        _DetailRow(
                          icon: item.category!.icon,
                          label: 'Category',
                          value: item.category!.label,
                          color: item.category!.darkColor,
                          hc: hc,
                        ),
                      if (item.gameType != null)
                        _DetailRow(
                          icon: item.gameType!.icon,
                          label: 'Game',
                          value: item.gameType!.label,
                          color: item.gameType!.color,
                          hc: hc,
                        ),
                      _DetailRow(
                        icon: Icons.push_pin_rounded,
                        label: 'Pinned',
                        value: item.isPinned ? 'Yes' : 'No',
                        color: item.isPinned
                            ? item.type.color
                            : hc.textHint,
                        hc: hc,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.1, end: 0),

                // ─── Custom Note ──────────────────
                if (item.customNote != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📌',
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              'Personal Note',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hc.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.customNote!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _masteryColor(double pct) {
    if (pct >= 0.9) return AppColors.success;
    if (pct >= 0.7) return AppColors.info;
    if (pct >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDateLong(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final dynamic hc;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
