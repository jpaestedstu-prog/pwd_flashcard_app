import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../screens/parent_dashboard_screen.dart';

/// Card displaying a parent recommendation with icon glow, gradient accent,
/// and staggered entrance animation.
class ParentRecommendationCard extends StatelessWidget {
  final ParentRecommendation recommendation;
  final HCColor hc;
  final int index;

  const ParentRecommendationCard({
    super.key,
    required this.recommendation,
    required this.hc,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = recommendation.color;

    // Professional panel with a colour-coded left accent stripe, replacing the
    // gradient tip card while keeping per-recommendation colour identity.
    return ProPanel(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              recommendation.icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: color.withValues(alpha: 0.4)),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (200 + index * 80).ms)
        .slideX(
          begin: 0.03,
          end: 0,
          delay: (200 + index * 80).ms,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
