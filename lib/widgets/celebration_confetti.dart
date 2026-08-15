import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/celebration_style.dart';

/// A [ConfettiWidget] painted in the learner's equipped Celebration Effect.
///
/// Every confetti burst in the app goes through here, which is what makes an
/// effect bought in the Star Shop worth its stars: equip Snowfall and the game
/// you finish, the badge you unlock and the level you reach all drift white
/// instead of bursting.
///
/// Call sites keep whatever is specific to their moment — [accentColor] for a
/// badge or level colour, [blastDirection] for the level-up screen's paired
/// side cannons — and inherit everything else from the equipped style.
class CelebrationConfetti extends ConsumerWidget {
  const CelebrationConfetti({
    super.key,
    required this.controller,
    this.accentColor,
    this.blastDirection,
  });

  final ConfettiController controller;

  /// Put in front of the style's palette, for bursts that are tinted by the
  /// thing being celebrated.
  final Color? accentColor;

  /// Forces a directional blast at this angle, overriding the style's own
  /// direction. For call sites whose geometry is the point.
  final double? blastDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(celebrationStyleProvider);
    final directional =
        blastDirection != null || style.blastDirection != null;

    return ConfettiWidget(
      // Keyed on the style: ConfettiWidget reads colours, gravity and forces
      // into its particle system once, in initState, and ignores later property
      // changes. Without this the learner equips Snowfall, the widget updates,
      // and the confetti keeps bursting in the old palette.
      key: ValueKey<String>('celebration-confetti-${style.id}'),
      confettiController: controller,
      blastDirectionality: directional
          ? BlastDirectionality.directional
          : style.directionality,
      blastDirection: blastDirection ?? style.blastDirection ?? 0,
      gravity: style.gravity,
      numberOfParticles: style.numberOfParticles,
      minBlastForce: style.minBlastForce,
      maxBlastForce: style.maxBlastForce,
      emissionFrequency: style.emissionFrequency,
      colors: style.colorsLedBy(accentColor),
    );
  }
}
