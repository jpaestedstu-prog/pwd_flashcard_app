import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/gaze_control/widgets/gaze_modal_region.dart';

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
///
/// It is a [GazeModalRegion] as well, as every pop-up in a screen's own Stack
/// is: [AbsorbPointer] stops a finger only, and a screen reader or a game
/// controller could still reach the stars and tiles dimmed behind it (the
/// deep crawl, FSL Dictionary, 8 Nov). Back stays the screen's, so it still
/// leaves while a video loads.
class FslLoadingOverlay extends StatelessWidget {
  /// Caption shown beneath the spinner.
  /// Null says "Loading video" in the reader's language.
  final String? message;

  const FslLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return GazeModalRegion(
      child: SizedBox.expand(
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
                      message ??
                          AppLocalizations.of(context)?.fslLoadingVideo ??
                          'Loading video…',
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
      ),
    );
  }
}
