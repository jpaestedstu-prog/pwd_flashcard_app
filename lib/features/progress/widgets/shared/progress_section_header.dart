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

  const ProgressSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
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
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
