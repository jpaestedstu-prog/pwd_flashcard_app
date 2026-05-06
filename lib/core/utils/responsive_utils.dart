import 'package:flutter/material.dart';

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
}

/// Responsive spacing helper
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}
