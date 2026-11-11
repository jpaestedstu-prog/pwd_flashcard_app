import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/form_factor.dart';

/// Responsive helpers optimized for Honor Pad X8a (1920×1200)
/// but adaptive down to phone sizes.
///
/// Breakpoints:
///   phone    < 600
///   tablet   ≥ 600
///   large    ≥ 900
///   xl       ≥ 1200
///   ultra    ≥ 1600
///
/// **Which side is measured.** The *size class* — how big tiles, icons and
/// heights are — follows the screen's **shortest side**, as Android's own
/// sw600dp rule does: a phone stays a phone when it is turned sideways. Until
/// 1.4.0 the app was portrait-only, where the width *is* the shortest side,
/// so every layout tuned then is unchanged; but a 20:9 phone held sideways is
/// 914 dp wide and 411 dp tall, and measuring the width gave it large-tablet
/// tiles and icons with a phone's height (the onboarding screens overflowed).
/// What genuinely depends on the width — how many columns fit, how wide the
/// content may run — still measures the width ([gridColumns],
/// [gameGridColumns], [maxContentWidth], [gridSpacing]).
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// The side that decides the size class (see above).
  double get _classSide => MediaQuery.sizeOf(this).shortestSide;

  bool get isPhone => _classSide < 600;
  bool get isTablet => _classSide >= 600;
  bool get isLargeTablet => _classSide >= 900;
  bool get isXLargeTablet => _classSide >= 1200;
  bool get isUltraLargeTablet => _classSide >= 1600;

  /// Returns [tablet] value for tablet, [phone] for phone
  T responsive<T>({required T phone, required T tablet}) {
    return isTablet ? tablet : phone;
  }

  /// Returns a value based on the size-class tier.
  T responsiveTier<T>({
    required T phone,
    required T tablet,
    T? large,
    T? xl,
    T? ultra,
  }) {
    final side = _classSide;
    if (side >= 1600 && ultra != null) return ultra;
    if (side >= 1200 && xl != null) return xl;
    if (side >= 900 && large != null) return large;
    if (side >= 600) return tablet;
    return phone;
  }

  /// Phone, tablet or a computer's browser. See [FormFactor]; the sizes
  /// that differ between them live in [FormMetrics] and [adaptTheme].
  FormFactor get formFactor => FormFactor.of(this);

  /// The page's edge padding for its size class. For the top and bottom of
  /// a page, which a wide window does not change ([pagePadding] grows on
  /// one, and as the space above a grid it opened a gap of 260 px).
  double get pageInset {
    final side = _classSide;
    if (side >= 1600) return 48.0;
    if (side >= 1200) return 40.0;
    if (side >= 600) return 32.0;
    return 20.0;
  }

  /// Horizontal page padding. On a wide window it grows, so a page that
  /// fills the window keeps its content in a column of [hubContentWidth]
  /// rather than stretching it edge to edge. Sideways only: the top and
  /// bottom take [pageInset].
  double get pagePadding {
    final base = pageInset;
    final content = hubContentWidth;
    if (content == null) return base;
    final gutter = (screenWidth - content) / 2;
    return gutter > base ? gutter : base;
  }

  /// How wide a page that fills the window may run its content, on a window
  /// wide enough for it to matter. Null: no limit (phones and tablets, whose
  /// layouts are made for the width they have).
  double? get hubContentWidth {
    if (screenWidth >= 1600) return 1400;
    if (screenWidth >= 1200) return 1200;
    return null;
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
    final side = _classSide;
    if (side >= 1600) return 280.0;
    if (side >= 1200) return 240.0;
    if (side >= 600) return 200.0;
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
    final side = _classSide;
    // A tile on a very narrow screen puts its words on more lines. Android's
    // Display Size at Largest makes an ordinary phone this narrow too.
    final narrow = screenWidth < 350;
    final double base = large
        ? (side >= 1200
            ? 184.0
            : side >= 600
                ? 160.0
                : narrow
                    ? 180.0
                    : 132.0)
        : (side >= 1200
            ? 128.0
            : side >= 600
                ? 114.0
                : narrow
                    ? 116.0
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
    final side = _classSide;
    final double base = side >= 1200
        ? 200.0
        : side >= 600
            ? 188.0
            : 172.0;
    // Grow with the Font Size setting (clamped) so large fonts get more room
    // instead of clipping; the card content also self-protects via
    // FittedBox + ellipsis.
    final scale = MediaQuery.textScalerOf(this).scale(1.0).clamp(1.0, 1.6);
    return base * scale;
  }

  /// Scale any base size by the size-class tier factor.
  /// Use for icons, badges, avatars, etc.
  double responsiveSize(double baseSize) => baseSize * _sizeFactor;

  double get _sizeFactor {
    final side = _classSide;
    if (side >= 1600) return 1.4;
    if (side >= 1200) return 1.25;
    if (side >= 900) return 1.15;
    if (side >= 600) return 1.0;
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
