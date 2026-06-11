import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Three-button remote (prev / pause / next) used on the cast screen
/// to advance whichever content the TV is showing.
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RemoteButton(
          icon: Icons.skip_previous_rounded,
          label: 'Previous',
          onTap: onPrev,
        ),
        const SizedBox(width: 18),
        _RemoteButton(
          icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: isPaused ? 'Play' : 'Pause',
          primary: true,
          onTap: onPlayPause,
        ),
        const SizedBox(width: 18),
        _RemoteButton(
          icon: Icons.skip_next_rounded,
          label: 'Next',
          onTap: onNext,
        ),
      ],
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
    final size = primary ? 72.0 : 56.0;
    final iconSize = primary ? 36.0 : 28.0;
    final bg = primary
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.12);
    final fg = primary ? Colors.white : AppColors.primary;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        elevation: primary ? 4 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: fg, size: iconSize),
          ),
        ),
      ),
    );
  }
}
