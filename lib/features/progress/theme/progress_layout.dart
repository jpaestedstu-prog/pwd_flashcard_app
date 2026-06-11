import 'package:flutter/material.dart';

/// A selectable layout *template* for the Progress dashboard.
///
/// Orthogonal to [ProgressTheme] (which is color only): a layout varies the
/// **density and emphasis** of the existing sections — section spacing, card
/// padding, how many stat cards sit per row, and how big the hero mastery
/// ring is. It never adds, removes, or changes the data shown.
///
/// Every layout rides on top of the shared overflow-safe responsive
/// foundation (see `responsive_utils.dart`): the per-row stat counts below are
/// only *preferences* that the stat grid clamps against the real screen width
/// and font scale, so no template can ever cause a RenderFlex overflow.
@immutable
class ProgressLayout {
  /// Stable key persisted per profile in Hive.
  final String id;
  final String displayName;

  /// Emoji shown on the picker swatch (cheap, localisation-free icon).
  final String emoji;

  /// One-line description shown under the swatch in the picker.
  final String blurb;

  /// Vertical gap between major sections (top stats, hero ring, lists…).
  final double sectionGap;

  /// Padding inside section/stat cards.
  final EdgeInsets cardPadding;

  /// Preferred stat columns on a phone-width screen (clamped by the grid).
  final int statColumnsPhone;

  /// Preferred stat columns from the tablet tier up (clamped by the grid).
  final int statColumnsTablet;

  /// Multiplier applied to the base hero mastery-ring / avatar-ring size.
  final double heroScale;

  /// Tighter inner spacing for dense templates (smaller chart heights, gaps).
  final bool dense;

  const ProgressLayout({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.blurb,
    required this.sectionGap,
    required this.cardPadding,
    required this.statColumnsPhone,
    required this.statColumnsTablet,
    required this.heroScale,
    this.dense = false,
  });
}
