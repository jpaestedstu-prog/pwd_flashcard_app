import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Helpers for animations that need to honour the `reducedMotion`
/// accessibility setting.
///
/// Most existing animation code in the app calls `Duration(milliseconds: …)`
/// directly. To make a screen reduced-motion-aware, replace those literals
/// with [Motion.duration] (or a `Motion` instance via `Motion.of(ref)`). The
/// helper returns a clamped duration when the user has opted in to less
/// motion — short enough to feel instant, long enough that animations
/// driven by AnimatedContainer/AnimatedSwitcher still complete cleanly.
class Motion {
  /// Maximum duration kept when reducedMotion is on. We keep a small
  /// nonzero value so animations like AnimatedContainer still snap to
  /// their target state without flicker; we don't return Duration.zero
  /// because some animation widgets misbehave with it.
  static const Duration reducedCap = Duration(milliseconds: 80);

  /// Multiplier applied to durations when [slowMotion] is on (~half speed).
  static const double slowFactor = 2.0;

  final bool reducedMotion;

  /// When true (and [reducedMotion] is off), animations are stretched by
  /// [slowFactor] so learners can follow them. Reduced-motion takes priority:
  /// if both are on, motion is minimized rather than slowed.
  final bool slowMotion;

  const Motion({required this.reducedMotion, this.slowMotion = false});

  /// Reads the active settings from a Riverpod scope. Use this in
  /// `ConsumerWidget`/`ConsumerStatefulWidget` build methods.
  factory Motion.of(WidgetRef ref) {
    final flags = ref.watch(
      settingsProvider.select((s) => (s.reducedMotion, s.slowMotionEnabled)),
    );
    return Motion(reducedMotion: flags.$1, slowMotion: flags.$2);
  }

  /// Static lookup that tolerates a missing scope. Returns a no-reduction
  /// instance when no [WidgetRef] is available — the safe default for
  /// non-consumer code paths so animations still play.
  static Motion ofOrDefault(WidgetRef? ref) {
    if (ref == null) return const Motion(reducedMotion: false);
    return Motion.of(ref);
  }

  /// Pick the right duration for a given animation. Returns [reducedCap]
  /// (capped) when the user prefers less motion; stretches by [slowFactor]
  /// when slow-motion is on; otherwise the full [full] duration.
  Duration duration(Duration full) {
    if (reducedMotion) {
      return full <= reducedCap ? full : reducedCap;
    }
    if (slowMotion) return full * slowFactor;
    return full;
  }

  /// Convenience: zero ms when reduced, otherwise [full] (stretched under
  /// slow-motion). Use this for celebratory effects (confetti, big bursts)
  /// that should not play at all under reduced motion.
  Duration optional(Duration full) {
    if (reducedMotion) return Duration.zero;
    return slowMotion ? full * slowFactor : full;
  }
}

extension MotionContextX on BuildContext {
  /// Convenience: read [Motion] from a `Consumer` builder context that
  /// already has a `WidgetRef` in scope. Provided as a thin extension so
  /// call sites read naturally: `motion.duration(400.ms)`.
  Motion motion(WidgetRef ref) => Motion.of(ref);
}
