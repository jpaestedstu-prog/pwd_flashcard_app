import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/celebration_confetti.dart';
import '../models/sticker_models.dart';

/// Announces stickers the learner earned but has never been shown.
///
/// Stickers were the only reward in the app with no moment of arrival: the
/// unlock check ran when the album happened to be opened, its return value
/// was discarded, and the new sticker simply appeared among the others as
/// though it had always been there. Achievements have had
/// `AchievementUnlockedOverlay` since they shipped; this is its counterpart,
/// deliberately built to the same shape — one card at a time, confetti in the
/// rarity colour, a Continue button that walks the queue.
class StickerUnlockedOverlay extends StatefulWidget {
  final List<Sticker> stickers;
  final bool isFilipino;
  final VoidCallback onDismiss;

  /// Skip the confetti and the elastic entrance. Wired to the learner's
  /// reduced-motion setting by the caller.
  final bool reducedMotion;

  const StickerUnlockedOverlay({
    super.key,
    required this.stickers,
    required this.isFilipino,
    required this.onDismiss,
    this.reducedMotion = false,
  });

  @override
  State<StickerUnlockedOverlay> createState() => _StickerUnlockedOverlayState();
}

class _StickerUnlockedOverlayState extends State<StickerUnlockedOverlay> {
  late ConfettiController _confettiController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    if (!widget.reducedMotion) {
      _confettiController.play();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.stickers.length - 1) {
      setState(() => _currentIndex++);
      if (!widget.reducedMotion) _confettiController.play();
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Defensive: an empty queue should never be mounted, but a rebuild during
    // dismissal must not index out of range.
    if (widget.stickers.isEmpty) return const SizedBox.shrink();

    final hc = HCColor.of(context);
    final sticker = widget.stickers[_currentIndex];
    final isFilipino = widget.isFilipino;
    final accent = sticker.rarity.color;
    final hasMore = _currentIndex < widget.stickers.length - 1;
    final name = sticker.nameOf(isFilipino: isFilipino);

    return Semantics(
      // Spoken as one announcement: a learner using a screen reader should
      // hear what they won, not have to sweep a card for it.
      label: isFilipino
          ? 'Bagong sticker! $name, ${sticker.rarity.labelOf(isFilipino: true)}.'
          : 'New sticker! $name, ${sticker.rarity.labelOf(isFilipino: false)}.',
      liveRegion: true,
      child: Material(
        color: Colors.black54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.reducedMotion)
              RepaintBoundary(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: CelebrationConfetti(
                      controller: _confettiController,
                      accentColor: accent,
                    ),
                  ),
                ),
              ),
            SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: hc.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFilipino
                            ? '🌟 Bagong Sticker!'
                            : '🌟 New Sticker!',
                        style: AppTypography.labelLarge.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // The sticker itself, on a rarity-tinted plate that
                    // follows the theme rather than a fixed pale swatch.
                    _StickerPlate(
                      sticker: sticker,
                      accent: accent,
                      reducedMotion: widget.reducedMotion,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hc.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        sticker.rarity.stars,
                        (_) => Icon(Icons.star_rounded,
                            size: 18, color: accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sticker.unlockDescriptionOf(isFilipino: isFilipino),
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.stickers.length > 1) ...[
                      const SizedBox(height: 12),
                      Text(
                        isFilipino
                            ? '${_currentIndex + 1} sa ${widget.stickers.length}'
                            : '${_currentIndex + 1} of ${widget.stickers.length}',
                        style: AppTypography.labelSmall
                            .copyWith(color: hc.textHint),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          hasMore
                              ? (isFilipino ? 'Susunod' : 'Next')
                              : (isFilipino ? 'Sige!' : 'Awesome!'),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticker on its rarity plate, with the pop-in entrance.
///
/// Split out so the entrance can be skipped wholesale under reduced motion
/// rather than animated to a no-op — a scale that starts at zero and is told
/// not to run would leave the sticker invisible.
class _StickerPlate extends StatelessWidget {
  final Sticker sticker;
  final Color accent;
  final bool reducedMotion;

  const _StickerPlate({
    required this.sticker,
    required this.accent,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final plate = Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: sticker.rarity.surfaceOn(hc),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(sticker.emoji, style: const TextStyle(fontSize: 56)),
      ),
    );

    if (reducedMotion) return plate;

    return plate.animate().scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.elasticOut,
        );
  }
}
