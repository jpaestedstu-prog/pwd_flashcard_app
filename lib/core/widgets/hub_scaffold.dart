import 'package:flutter/material.dart';

import '../../widgets/animated_gradient_background.dart';

/// Playful, overflow-safe page scaffold for the kid / guest "hub" home
/// surfaces (Child and Player home).
///
/// It factors the established backdrop — an [AnimatedGradientBackground] (with
/// optional floating particles) behind a transparent [Scaffold] + [SafeArea] —
/// into one widget, so the hub screens share an identical look instead of each
/// re-implementing the gradient/Scaffold boilerplate (see the Student
/// `HomeScreen` for the original inline pattern).
///
/// Provide EITHER [slivers] (rendered inside a [CustomScrollView] — the common
/// hub-grid case, which scrolls so it can never bottom-overflow) OR a single
/// [child] placed directly in the [SafeArea] (the child owns its own scrolling,
/// e.g. via `OverflowSafeBody`). Exactly one of the two must be non-null.
class HubScaffold extends StatelessWidget {
  const HubScaffold({
    super.key,
    this.slivers,
    this.child,
    this.intensity = 0.35,
    this.showParticles = true,
    this.preset = GradientPreset.home,
    this.backgroundColor,
  }) : assert(
          (slivers == null) != (child == null),
          'HubScaffold needs exactly one of `slivers` or `child`.',
        );

  /// Slivers for the [CustomScrollView] body (greeting strips, hub grids).
  final List<Widget>? slivers;

  /// A single body widget placed directly in the [SafeArea]; it is responsible
  /// for its own scrolling.
  final Widget? child;

  /// Background gradient opacity (0.0–1.0). Lower = subtler.
  final double intensity;

  /// Whether to render floating particles over the gradient.
  final bool showParticles;

  /// Gradient colour preset; defaults to the warm [GradientPreset.home].
  final GradientPreset preset;

  /// Scaffold background; defaults to transparent so the gradient shows through.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget body =
        slivers != null ? CustomScrollView(slivers: slivers!) : child!;

    return AnimatedGradientBackground(
      intensity: intensity,
      showParticles: showParticles,
      preset: preset,
      child: Scaffold(
        backgroundColor: backgroundColor ?? Colors.transparent,
        body: SafeArea(child: body),
      ),
    );
  }
}
