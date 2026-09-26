import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../navigation/bottom_nav_shell.dart';
import '../services/educator_recommendations.dart';

/// One recommendation on the educator dashboard, with the next step attached.
///
/// The card used to be text only: it told an educator that a learner had been
/// away for nine days and then left them to find the alarm screen themselves.
/// Every recommendation now carries a route, so reading it and acting on it
/// are the same gesture.
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

  /// Follow the card's action.
  ///
  /// A bottom-nav destination has to be `go`, not `push`: the shell already
  /// holds a page for it, and pushing a second one trips Navigator's
  /// duplicate-page-key assertion — the card looked broken and raised the
  /// global error snackbar instead of navigating. Everything else here is a
  /// drill-down and pushes normally, so Back returns to the dashboard.
  void _followAction(BuildContext context) {
    final route = recommendation.actionRoute;
    if (isEducatorTabRoute(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = recommendation.color;
    final rollup = recommendation.childName.isEmpty;

    // Professional panel with a colour-coded left accent stripe, replacing the
    // gradient tip card while keeping per-recommendation colour identity.
    return ProPanel(
      accent: color,
      padding: const EdgeInsets.all(14),
      onTap: () => _followAction(context),
      child: Semantics(
        button: true,
        // Read as one sentence rather than three fragments, and say what
        // happens on activation — the label is the only cue a screen-reader
        // user gets that the card does anything.
        label:
            '${recommendation.title}. ${recommendation.description} '
            '${recommendation.actionLabel}.',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  child: Icon(recommendation.icon, size: 22, color: color),
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
                // A roster-wide card speaks for several learners at once —
                // flag it so an educator can tell it apart from the per-learner
                // rows at a glance.
                if (rollup)
                  Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // The action reads as a link rather than a filled button: six
            // filled buttons down the feed would each shout as loudly as the
            // recommendation itself.
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      recommendation.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: HCColor.of(context).readable(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // No per-card entrance animation: recommendation cards are built by a
    // lazy sliver and rebuilt on scroll-back, so a staggered `.animate()`
    // replays from opacity 0 every time.
  }
}
