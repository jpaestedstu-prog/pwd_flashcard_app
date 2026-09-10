import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pro_surface.dart';

/// Three-button remote (prev / pause / next) used on the cast screen
/// to advance whichever content the TV is showing.
///
/// Laid out as three equal rectangle cells — the same 12px corners and
/// icon-over-label stack as the tile grids above it on the cast screen and on
/// the educator Home. They were three floating circles of two different
/// diameters, which read as a media widget bolted onto a dashboard; equal
/// blocks also give the middle (play/pause) button the same generous tap
/// target as its neighbours instead of relying on size alone to mark it out.
class TvCastRemoteControls extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPrev;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const TvCastRemoteControls({
    super.key,
    required this.isPaused,
    required this.onPrev,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RemoteButton(
              icon: Icons.skip_previous_rounded,
              label: 'Previous',
              onTap: onPrev,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _RemoteButton(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: isPaused ? 'Play' : 'Pause',
              primary: true,
              onTap: onPlayPause,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _RemoteButton(
              icon: Icons.skip_next_rounded,
              label: 'Next',
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _RemoteButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    final bg = primary
        ? hc.primary
        : Color.alphaBlend(
            hc.primary.withValues(alpha: 0.08),
            hc.cardBackground,
          );
    final fg = primary ? Colors.white : hc.primary;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: ProSurface.borderRadius,
          side: BorderSide(
            color: primary
                ? hc.primary
                : hc.primary.withValues(alpha: 0.30),
            width: primary ? 2 : ProSurface.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 14,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed size in a FittedBox, exactly like a ProActionTile's
                // icon badge: the glyph never grows with the font setting, so
                // the label keeps its room in a third of a narrow phone.
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Icon(icon, size: 32, color: fg),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
