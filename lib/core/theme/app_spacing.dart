import 'package:flutter/widgets.dart';

/// Project-wide spacing scale.
///
/// The vast majority of layouts in the app use a small set of repeating
/// gap and padding values (4 / 8 / 16 / 20 / 24 / 32). Hard-coding those
/// numbers everywhere makes it tedious to bulk-tighten or loosen the UI.
/// Use these tokens for new layout code, and migrate inline literals
/// opportunistically when editing nearby code.
///
/// ```dart
/// const SizedBox(height: AppSpacing.md),
/// Padding(padding: EdgeInsets.all(AppSpacing.lg), ...)
/// EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm)
/// ```
class AppSpacing {
  AppSpacing._();

  /// 4 — tight icon ↔ label gap.
  static const double xs = 4;

  /// 8 — comfortable inline gap (chips, dense rows).
  static const double sm = 8;

  /// 16 — default screen-edge padding and section gap.
  static const double md = 16;

  /// 20 — slightly roomier padding for cards / large CTAs.
  static const double lg = 20;

  /// 24 — page section padding, prominent card padding.
  static const double xl = 24;

  /// 32 — outer page padding when content needs to breathe.
  static const double xxl = 32;

  /// 48 — generous gap between major sections (e.g. above CTA stacks).
  static const double xxxl = 48;

  // ─── Pre-built helpers ───────────────────────────────────

  /// `EdgeInsets.all(md)` — most common card / list-tile padding.
  static const EdgeInsets paddingMd = EdgeInsets.all(md);

  /// `EdgeInsets.all(lg)` — section / hero card padding.
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  /// `EdgeInsets.all(xl)` — page-level padding.
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  /// Vertical-only `md` padding — useful inside ListViews.
  static const EdgeInsets paddingVMd =
      EdgeInsets.symmetric(vertical: md);

  /// Horizontal-only `xl` padding — page edges.
  static const EdgeInsets paddingHXl =
      EdgeInsets.symmetric(horizontal: xl);

  // ─── SizedBox helpers ────────────────────────────────────

  /// Vertical gap of [xs].
  static const SizedBox gapXs = SizedBox(height: xs);

  /// Vertical gap of [sm].
  static const SizedBox gapSm = SizedBox(height: sm);

  /// Vertical gap of [md].
  static const SizedBox gapMd = SizedBox(height: md);

  /// Vertical gap of [lg].
  static const SizedBox gapLg = SizedBox(height: lg);

  /// Vertical gap of [xl].
  static const SizedBox gapXl = SizedBox(height: xl);

  /// Vertical gap of [xxl].
  static const SizedBox gapXxl = SizedBox(height: xxl);
}
