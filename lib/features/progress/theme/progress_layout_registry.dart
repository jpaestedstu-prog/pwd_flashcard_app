import 'package:flutter/material.dart';

import 'progress_layout.dart';

/// The catalogue of selectable Progress layout templates.
///
/// `comfortable` reproduces the current spacing/sizing exactly and is the
/// default, so existing learners see no change until they pick another
/// template.
class ProgressLayouts {
  ProgressLayouts._();

  /// Default — matches today's hand-tuned spacing so it's a visual no-op.
  static const ProgressLayout comfortable = ProgressLayout(
    id: 'comfortable',
    displayName: 'Comfortable',
    emoji: '🛋️',
    blurb: 'Roomy & easy to read',
    sectionGap: 28,
    cardPadding: EdgeInsets.all(16),
    statColumnsPhone: 3,
    statColumnsTablet: 3,
    heroScale: 1.0,
  );

  /// Tighter — fits more on small / split-screen tablets.
  static const ProgressLayout compact = ProgressLayout(
    id: 'compact',
    displayName: 'Compact',
    emoji: '📋',
    blurb: 'Tighter, fits more',
    sectionGap: 18,
    cardPadding: EdgeInsets.all(12),
    statColumnsPhone: 3,
    statColumnsTablet: 4,
    heroScale: 0.85,
    dense: true,
  );

  /// Bold — bigger hero ring and roomier cards for show-and-tell.
  static const ProgressLayout showcase = ProgressLayout(
    id: 'showcase',
    displayName: 'Showcase',
    emoji: '✨',
    blurb: 'Big & bold visuals',
    sectionGap: 36,
    cardPadding: EdgeInsets.all(20),
    statColumnsPhone: 2,
    statColumnsTablet: 3,
    heroScale: 1.2,
  );

  /// Default applied when a profile hasn't chosen a template.
  static const ProgressLayout defaultLayout = comfortable;

  /// All templates in picker order.
  static const List<ProgressLayout> all = [
    comfortable,
    compact,
    showcase,
  ];

  /// Resolve a stored id back to a template, falling back to [defaultLayout].
  static ProgressLayout byId(String? id) =>
      all.firstWhere((l) => l.id == id, orElse: () => defaultLayout);
}
