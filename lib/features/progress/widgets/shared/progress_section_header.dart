import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';

/// Consistent section heading for the progress views: a title in
/// `titleMedium` / w700 with an optional leading icon and trailing action.
///
/// Shared so the Student progress screen, the student profile detail screen,
/// and the child detail sheet all present sections the same way. The title is
/// allowed up to two lines and ellipsizes, so it never overflows when the
/// system font scale is large.
class ProgressSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  /// Whether the title is a stop of its own. False inside a panel read as
  /// one stop with its title (the Progress tab's "This Week"): the stop
  /// itself becomes the heading, and the title is still read first. As a stop
  /// of its own there it came after the panel's words (4 Nov).
  final bool ownStop;

  const ProgressSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.ownStop = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Semantics(
            container: ownStop,
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
