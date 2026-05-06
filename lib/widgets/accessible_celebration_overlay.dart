import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/accessibility/accessible_celebration_service.dart';
import '../core/services/celebration_service.dart';
import '../core/theme/app_typography.dart';
import '../providers/app_providers.dart';
import '../providers/experiment_provider.dart';
import '../features/experiment/models/experiment_models.dart';

/// An accessible celebration overlay that adapts to the user's disability type.
///
/// Unlike [LottieCelebrationOverlay], this widget:
/// - Shows text-based feedback for screen reader users
/// - Uses high-contrast color for visual impairment
/// - Extends display duration for cognitive disabilities
/// - Skips animations entirely when appropriate
///
/// Usage:
/// ```dart
/// AccessibleCelebrationOverlay.show(
///   context: context,
///   ref: ref,
///   type: CelebrationType.starEarned,
/// );
/// ```
class AccessibleCelebrationOverlay {
  const AccessibleCelebrationOverlay._();

  /// Show an accessible celebration overlay entry.
  ///
  /// Respects experiment mode: if celebrations are disabled for the
  /// current student's experiment group, this is a no-op.
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required CelebrationType type,
  }) {
    // Check experiment flag — nothing to do if celebrations are off
    final celebrationsEnabled = ref.read(
      gamificationFeatureProvider(GamificationFeature.celebrations),
    );
    if (!celebrationsEnabled) return;

    final service = ref.read(accessibleCelebrationProvider);
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    // Always trigger sound + haptic
    service.celebrate(type);

    // Show visual overlay
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CelebrationOverlayWidget(
        type: type,
        service: service,
        isFilipino: isFilipino,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _CelebrationOverlayWidget extends StatefulWidget {
  final CelebrationType type;
  final AccessibleCelebrationService service;
  final bool isFilipino;
  final VoidCallback onDismiss;

  const _CelebrationOverlayWidget({
    required this.type,
    required this.service,
    required this.isFilipino,
    required this.onDismiss,
  });

  @override
  State<_CelebrationOverlayWidget> createState() =>
      _CelebrationOverlayWidgetState();
}

class _CelebrationOverlayWidgetState
    extends State<_CelebrationOverlayWidget> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after the appropriate duration
    Future.delayed(widget.service.durationFor(widget.type), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text =
        widget.service.textFor(widget.type, isFilipino: widget.isFilipino);
    final showVisual = widget.service.shouldShowVisualCelebration;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: text,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _celebrationColor(widget.type)
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: showVisual
                    ? [
                        BoxShadow(
                          color: _celebrationColor(widget.type)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _celebrationEmoji(widget.type),
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      text,
                      style: AppTypography.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.3, end: 0, duration: 300.ms)
                .then()
                .shimmer(
                  duration: showVisual ? 600.ms : Duration.zero,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
          ),
        ),
      ),
    );
  }

  Color _celebrationColor(CelebrationType type) {
    return switch (type) {
      CelebrationType.correctAnswer => Colors.green.shade600,
      CelebrationType.starEarned => Colors.amber.shade700,
      CelebrationType.gameComplete => Colors.blue.shade600,
      CelebrationType.perfectScore => Colors.purple.shade600,
      CelebrationType.achievementUnlocked => Colors.deepPurple.shade600,
      CelebrationType.streakMilestone => Colors.deepOrange.shade600,
      CelebrationType.levelUp => Colors.indigo.shade600,
      CelebrationType.purchase => Colors.teal.shade600,
    };
  }

  String _celebrationEmoji(CelebrationType type) {
    return switch (type) {
      CelebrationType.correctAnswer => '✓',
      CelebrationType.starEarned => '⭐',
      CelebrationType.gameComplete => '🏆',
      CelebrationType.perfectScore => '🌟',
      CelebrationType.achievementUnlocked => '🏅',
      CelebrationType.streakMilestone => '🔥',
      CelebrationType.levelUp => '🚀',
      CelebrationType.purchase => '🛍️',
    };
  }
}
