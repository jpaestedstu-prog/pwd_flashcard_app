import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/shop_data.dart';
import '../../providers/app_providers.dart';
import '../theme/app_colors.dart';

/// How a celebration's confetti looks and behaves.
///
/// This is what a Celebration Effect from the Star Shop actually buys. Before
/// this existed the effects were inert: a learner could spend 25–35 stars on
/// "Snowfall" and every celebration in the app looked exactly as it had
/// before. The equipped effect now drives every confetti burst the app fires —
/// game completions, achievements, level-ups and shop purchases alike — so the
/// purchase is visible in the place it was always meant to be.
@immutable
class CelebrationStyle {
  const CelebrationStyle({
    required this.id,
    required this.colors,
    required this.directionality,
    required this.gravity,
    required this.numberOfParticles,
    required this.minBlastForce,
    required this.maxBlastForce,
    required this.emissionFrequency,
    this.blastDirection,
  });

  /// Identifies the style so a widget key can change with it.
  ///
  /// `ConfettiWidget` builds its particle system once, in `initState`, and does
  /// not re-read colours or gravity when its properties change — equipping an
  /// effect updated the widget but left the confetti on screen looking exactly
  /// as before (caught on device; the widget-property assertions in the tests
  /// passed right through it). Keying the widget on this forces a fresh
  /// particle system the moment the learner equips something.
  final String id;

  final List<Color> colors;
  final BlastDirectionality directionality;

  /// 0 = hangs in the air, 1 = drops like a stone.
  final double gravity;
  final int numberOfParticles;
  final double minBlastForce;
  final double maxBlastForce;
  final double emissionFrequency;

  /// Only meaningful when [directionality] is
  /// [BlastDirectionality.directional].
  final double? blastDirection;

  /// What every learner sees before they buy an effect. Matches the confetti
  /// the app fired before effects were purchasable, so not owning one is not a
  /// downgrade.
  static const CelebrationStyle standard = CelebrationStyle(
    id: 'standard',
    colors: [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.warning,
      AppColors.success,
      AppColors.info,
    ],
    directionality: BlastDirectionality.explosive,
    gravity: 0.3,
    numberOfParticles: 20,
    minBlastForce: 10,
    maxBlastForce: 30,
    emissionFrequency: 0.05,
  );

  /// Hot sparks thrown hard and wide, thinning as they arc down.
  static const CelebrationStyle _fireworks = CelebrationStyle(
    id: 'fireworks',
    colors: [
      AppColors.warning,
      Color(0xFFFF7043),
      Color(0xFFEF5350),
      Color(0xFFEC407A),
      Color(0xFFAB47BC),
      Colors.white,
    ],
    directionality: BlastDirectionality.explosive,
    gravity: 0.25,
    numberOfParticles: 30,
    minBlastForce: 15,
    maxBlastForce: 40,
    emissionFrequency: 0.04,
  );

  /// The full spectrum at once — denser and wider than anything else.
  static const CelebrationStyle _rainbow = CelebrationStyle(
    id: 'rainbow',
    colors: [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF3949AB),
      Color(0xFF8E24AA),
    ],
    directionality: BlastDirectionality.explosive,
    gravity: 0.2,
    numberOfParticles: 40,
    minBlastForce: 12,
    maxBlastForce: 45,
    emissionFrequency: 0.03,
  );

  /// Slow drift straight down. Deliberately the calmest of the three: the
  /// learners most likely to choose it are the ones for whom a hard burst is
  /// too much, and it stays well short of the reduced-motion threshold.
  static const CelebrationStyle _snowfall = CelebrationStyle(
    id: 'snowfall',
    colors: [
      Colors.white,
      Color(0xFFE1F5FE),
      Color(0xFFB3E5FC),
      Color(0xFF81D4FA),
    ],
    directionality: BlastDirectionality.directional,
    blastDirection: math.pi / 2, // straight down
    gravity: 0.1,
    numberOfParticles: 35,
    minBlastForce: 1,
    maxBlastForce: 5,
    emissionFrequency: 0.02,
  );

  /// The style for an equipped celebration item, or [standard] when the
  /// learner owns none (or owns one that has since been withdrawn).
  static CelebrationStyle forItemId(String? itemId) => switch (itemId) {
        'celebration_fireworks' => _fireworks,
        'celebration_rainbow' => _rainbow,
        'celebration_snow' => _snowfall,
        _ => standard,
      };

  /// The same effect, damped for a learner who has asked for reduced motion.
  ///
  /// Deliberately *not* suppressed outright. Three of the app's four confetti
  /// sites — game completions, achievements and the shop itself — ignored
  /// `reducedMotion` entirely, so motor, cognitive and multiple-disability
  /// learners (whose presets all switch it on) were getting the full burst.
  /// But drawing nothing at all would make every Celebration Effect inert for
  /// exactly those learners, which is the same "stars bought nothing" trap the
  /// sound packs fell into. Keeping the palette and dropping the physics
  /// respects the setting and keeps the purchase visible.
  ///
  /// The id changes too, so the widget key changes and `ConfettiWidget`
  /// rebuilds its particle system when the setting is toggled.
  CelebrationStyle calmed() => CelebrationStyle(
        id: '$id-calm',
        colors: colors,
        directionality: BlastDirectionality.directional,
        blastDirection: math.pi / 2, // drifts down, never bursts outward
        gravity: 0.05,
        numberOfParticles: 8,
        minBlastForce: 1,
        maxBlastForce: 3,
        emissionFrequency: 0.01,
      );

  /// [colors] with [accent] in front, for call sites that tint confetti with
  /// something contextual (an achievement's colour, a level band's colour).
  /// Keeps the equipped effect recognisable while the moment stays itself.
  List<Color> colorsLedBy(Color? accent) =>
      accent == null ? colors : <Color>[accent, ...colors];
}

/// The celebration style for the current profile's equipped effect.
///
/// Watches [progressProvider] because equipping writes through it — the state
/// bump on equip/unequip is what makes a newly equipped effect take hold
/// without a restart.
final celebrationStyleProvider = Provider<CelebrationStyle>((ref) {
  ref.watch(progressProvider);
  final equipped = ref
      .read(progressProvider.notifier)
      .getEquippedItemId(ShopItemType.celebration);
  final style = CelebrationStyle.forItemId(equipped);

  // Reduced motion is a setting about how the app moves, so it belongs here —
  // at the one place every confetti burst now passes through — rather than
  // being re-checked (or, as it was, forgotten) at each call site.
  return ref.watch(settingsProvider).reducedMotion ? style.calmed() : style;
});
