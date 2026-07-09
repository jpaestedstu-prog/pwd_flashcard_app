import 'package:flutter/material.dart';

/// Which of the app's theme families is active.
///
/// [HCColor] and other adaptive helpers previously inferred "high contrast"
/// from `brightness == Brightness.dark`, which made the standard Dark Mode
/// render with the high-contrast palette (bright yellow on black) — the two
/// modes were visually indistinguishable in every custom-painted widget.
/// The marker makes the distinction explicit so each mode keeps its own
/// identity:
///   • light        — pastel light, shop, group, and learner-profile themes
///   • dark         — stock dark + dark shop/learner variants (soft pastels)
///   • highContrast — black background, bright accent, bordered surfaces
///   • dyslexia     — cream surfaces, Lexend type, muted calm accents
enum ThemeKind { light, dark, highContrast, dyslexia }

/// [ThemeExtension] carrying the active [ThemeKind]. Attached to every
/// [ThemeData] built by `AppTheme` so `Theme.of(context)` always knows which
/// family it belongs to (falls back to brightness when absent, e.g. in tests
/// that use stock `ThemeData`).
@immutable
class ThemeMarker extends ThemeExtension<ThemeMarker> {
  final ThemeKind kind;

  const ThemeMarker(this.kind);

  static const ThemeMarker light = ThemeMarker(ThemeKind.light);
  static const ThemeMarker dark = ThemeMarker(ThemeKind.dark);
  static const ThemeMarker highContrast = ThemeMarker(ThemeKind.highContrast);
  static const ThemeMarker dyslexia = ThemeMarker(ThemeKind.dyslexia);

  /// The active theme kind, inferred from brightness when no marker is set.
  static ThemeKind of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ThemeMarker>()?.kind ??
        (theme.brightness == Brightness.dark
            ? ThemeKind.dark
            : ThemeKind.light);
  }

  @override
  ThemeMarker copyWith({ThemeKind? kind}) => ThemeMarker(kind ?? this.kind);

  @override
  ThemeMarker lerp(ThemeExtension<ThemeMarker>? other, double t) {
    if (other is! ThemeMarker) return this;
    return t < 0.5 ? this : other;
  }
}
