import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// A full-screen, input-blocking loading overlay shown while an FSL video is
/// being resolved/downloaded.
///
/// Render it as the *last* child of a [Stack] that wraps a screen's
/// [Scaffold], gated on that screen's loading flag:
///
/// ```dart
/// return Stack(
///   children: [
///     Scaffold(...),
///     if (_isLoadingFsl) const FslLoadingOverlay(),
///   ],
/// );
/// ```
///
/// While visible it dims the whole screen (app bar included) and swallows all
/// pointer events via [AbsorbPointer], so no other control — including a second
/// FSL tap — can fire until the video has finished loading.
class FslLoadingOverlay extends StatelessWidget {
  /// Caption shown beneath the spinner.
  final String message;

  const FslLoadingOverlay({super.key, this.message = 'Loading video…'});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 150.ms),
          ),
        ),
      ),
    );
  }
}
