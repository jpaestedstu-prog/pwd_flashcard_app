import 'package:flutter/material.dart';

/// The two calming activities a student can pick on the "I Need a Break"
/// screen. Both are deliberately **no-fail** and time-boxed (~1 minute), and
/// the student always returns to the exact lesson / flashcard / game they left.
///
/// Kept as a tiny self-contained enum (no Hive, no persistence) so the whole
/// break feature has no side effects — it can be opened from anywhere and
/// dismissed without touching app state.
enum BreakActivity {
  /// A slow guided-breathing animation (expand on the inhale, hold, contract
  /// on the exhale) with matching text cues.
  breathing,

  /// A gentle, endless bubble-popping field — tap to pop, nothing to lose.
  bubbles;

  /// Short title shown on the chooser card and the activity header.
  String get label => switch (this) {
        BreakActivity.breathing => 'Breathe',
        BreakActivity.bubbles => 'Pop Bubbles',
      };

  /// One-line description shown under the title on the chooser card.
  String get description => switch (this) {
        BreakActivity.breathing => 'Slow, calming breaths',
        BreakActivity.bubbles => 'Gently pop the bubbles',
      };

  /// Material icon for the chooser card / header.
  IconData get icon => switch (this) {
        BreakActivity.breathing => Icons.self_improvement_rounded,
        BreakActivity.bubbles => Icons.bubble_chart_rounded,
      };

  /// Large friendly emoji for the chooser card.
  String get emoji => switch (this) {
        BreakActivity.breathing => '🌬️',
        BreakActivity.bubbles => '🫧',
      };
}
