import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Responsive helpers optimized for Honor Pad X8a (1920×1200)
/// but adaptive down to phone sizes.
///
/// Breakpoints:
///   phone    < 600
///   tablet   ≥ 600
///   large    ≥ 900
///   xl       ≥ 1200
///   ultra    ≥ 1600  (Honor Pad X8a in landscape)
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isPhone => screenWidth < 600;
  bool get isTablet => screenWidth >= 600;
  bool get isLargeTablet => screenWidth >= 900;
  bool get isXLargeTablet => screenWidth >= 1200;
  bool get isUltraLargeTablet => screenWidth >= 1600;

  /// Returns [tablet] value for tablet, [phone] for phone
  T responsive<T>({required T phone, required T tablet}) {
    return isTablet ? tablet : phone;
  }

  /// Returns a value based on screen-width tier.
  T responsiveTier<T>({
    required T phone,
    required T tablet,
    T? large,
    T? xl,
    T? ultra,
  }) {
    if (screenWidth >= 1600 && ultra != null) return ultra;
    if (screenWidth >= 1200 && xl != null) return xl;
    if (screenWidth >= 900 && large != null) return large;
    if (screenWidth >= 600) return tablet;
    return phone;
  }

  /// Horizontal page padding
  double get pagePadding {
    if (screenWidth >= 1600) return 48.0;
    if (screenWidth >= 1200) return 40.0;
    if (screenWidth >= 600) return 32.0;
    return 20.0;
  }

  /// Number of grid columns
  int get gridColumns {
    if (screenWidth >= 1200) return 3;
    if (screenWidth >= 600) return 2;
    return 1;
  }

  /// Number of game grid columns
  int get gameGridColumns {
    if (screenWidth >= 1600) return 4;
    if (screenWidth >= 900) return 3;
    return 2;
  }

  /// Card height for category cards
  double get categoryCardHeight {
    if (screenWidth >= 1600) return 280.0;
    if (screenWidth >= 1200) return 240.0;
    if (screenWidth >= 600) return 200.0;
    return 160.0;
  }

  /// Fixed height for a Home "game hub" tile, sized by screen tier AND the
  /// active text scaler so tiles grow with the Font Size setting instead of
  /// clipping their icon/label.
  ///
  /// Use this as a grid `mainAxisExtent` (NOT `childAspectRatio`): tile height
  /// then never depends on tile width, which is exactly the failure mode that
  /// caused RenderFlex overflow when an aspect ratio was divided by the text
  /// scale. [large] tiles are the primary "Play & Learn" actions; the compact
  /// size is for the secondary "More" grid.
  double hubTileHeight({bool large = true}) {
    final double base = large
        ? (screenWidth >= 1200
            ? 184.0
            : screenWidth >= 600
                ? 160.0
                : 132.0)
        : (screenWidth >= 1200
            ? 128.0
            : screenWidth >= 600
                ? 114.0
                : 100.0);
    // Clamp the scaler so XL fonts enlarge tiles without runaway growth; the
    // tile content also self-protects (FittedBox + ellipsis).
    final scale = MediaQuery.textScalerOf(this).scale(1.0).clamp(1.0, 1.6);
    return base * scale;
  }

  /// Fixed, text-scale-aware height for a Vocabulary Category card.
  ///
  /// Category cards carry more than a hub tile — a raised 3D badge, a title, a
  /// word-count + progress row and a progress bar — so they need more height
  /// than [hubTileHeight] to keep every element comfortably spaced, matching
  /// the roomy proportions of the Flashcards deck cards. Like [hubTileHeight],
  /// this is a fixed extent (used as a grid `mainAxisExtent`, never a
  /// width-derived aspect ratio), so the card's height never depends on its
  /// width: it can't throw a RenderFlex overflow on any phone, tablet,
  /// orientation, or font scale — the page simply scrolls when space is tight.
  double categoryTileHeight() {
    final double base = screenWidth >= 1200
        ? 200.0
        : screenWidth >= 600
            ? 188.0
            : 172.0;
    // Grow with the Font Size setting (clamped) so large fonts get more room
    // instead of clipping; the card content also self-protects via
    // FittedBox + ellipsis.
    final scale = MediaQuery.textScalerOf(this).scale(1.0).clamp(1.0, 1.6);
    return base * scale;
  }

  /// Adaptive font size multiplier based on screen width
  double get fontScaleFactor {
    if (screenWidth >= 1600) return 1.25;
    if (screenWidth >= 1200) return 1.15;
    if (screenWidth >= 900) return 1.1;
    if (screenWidth >= 600) return 1.0;
    return 0.9;
  }

  /// Scale any base size by the screen-width tier factor.
  /// Use for icons, badges, avatars, etc.
  double responsiveSize(double baseSize) => baseSize * _sizeFactor;

  double get _sizeFactor {
    if (screenWidth >= 1600) return 1.4;
    if (screenWidth >= 1200) return 1.25;
    if (screenWidth >= 900) return 1.15;
    if (screenWidth >= 600) return 1.0;
    return 0.9;
  }

  /// Maximum content width to prevent overly wide layouts.
  double get maxContentWidth {
    if (screenWidth >= 1600) return 1400.0;
    if (screenWidth >= 1200) return 1200.0;
    if (screenWidth >= 600) return 800.0;
    return double.infinity;
  }

  /// Responsive grid spacing
  double get gridSpacing {
    if (screenWidth >= 1200) return 20.0;
    return 16.0;
  }

  /// Scale a base icon/avatar size by the currently-applied text scaler.
  /// Mirrors how text grows with the Font Size setting (S/M/L/XL = 0.85x–1.5x).
  double scaleIcon(double base) =>
      base * MediaQuery.textScalerOf(this).scale(1.0);

  /// Scale a container height by the text scaler so boxes holding scalable
  /// text grow with the Font Size setting instead of clipping it.
  double scaledHeight(double base) =>
      base * MediaQuery.textScalerOf(this).scale(1.0);

  /// Same as [scaledHeight] but clamped — for circular/fixed-aspect badges
  /// that must not grow without bound (timer pills, play circles).
  double scaledHeightCapped(double base, {double max = 1.5}) =>
      base * MediaQuery.textScalerOf(this).scale(1.0).clamp(1.0, max);
}

/// Wraps a body widget so it scrolls when the user's font scale would cause
/// vertical overflow. At normal text scale (≤ 1.2x) the child is returned
/// unchanged — zero rebuild/perf cost. At larger scales the child is placed
/// in a [SingleChildScrollView] whose viewport is sized to at least the
/// available height, so existing layouts that expect a finite parent still
/// fill the screen.
///
/// **Important:** when wrapping a body that contains `Expanded`, convert those
/// to `Flexible(fit: FlexFit.loose)` first — `Expanded` cannot live inside an
/// unbounded vertical scroll view.
class OverflowSafeBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const OverflowSafeBody({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    // Below this threshold the original layout fits; skip the scroll wrapper
    // to avoid changing hit-testing/scroll behavior at normal font sizes.
    if (scale < 1.25) {
      return padding == null ? child : Padding(padding: padding!, child: child);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: padding ?? EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

/// Deprecated spacing helper — kept as a thin alias so any lingering
/// references keep compiling. Use [AppSpacing] (lib/core/theme/app_spacing.dart)
/// as the single source of truth for spacing tokens.
@Deprecated('Use AppSpacing from core/theme/app_spacing.dart instead.')
class Spacing {
  Spacing._();

  static const double xs = AppSpacing.xs;
  static const double sm = AppSpacing.sm;
  static const double md = AppSpacing.md;
  static const double lg = AppSpacing.lg;
  static const double xl = AppSpacing.xl;
  static const double xxl = AppSpacing.xxl;
  static const double xxxl = AppSpacing.xxxl;
}
