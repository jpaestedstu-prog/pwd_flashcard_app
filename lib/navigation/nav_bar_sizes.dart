import 'package:flutter/widgets.dart';

import '../core/utils/responsive_utils.dart';

/// The learner tab bar's sizes, grown with the Font Size.
///
/// One place for the bar ([BottomNavShell]) and for the floating AI Buddy,
/// which rests just above it: the buddy used a fixed 84 dp while the bar grew
/// with the text to about 90 dp on a phone at 1.5x, and taller on a big
/// window, so the buddy sat on the top of the Progress tab (9 Nov).
@immutable
class NavBarSizes {
  const NavBarSizes._({
    required this.bar,
    required this.iconSelected,
    required this.iconUnselected,
    required this.gap,
    required this.dot,
  });

  factory NavBarSizes.of(BuildContext context) {
    final iconSel = context.scaleIcon(context.responsiveSize(26));
    final iconUnsel = context.scaleIcon(context.responsiveSize(22));
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    // Label height for layout math (Text applies textScaler internally
    // when rendering; we mirror it here so the height calculation matches).
    final fontSel = context.responsiveSize(11.5) * scale;
    final gap = (4.0 * scale).clamp(3.0, 8.0);
    const dot = 5.0;
    // Selected item is the tallest: icon + gap + textLineHeight + gap + dot.
    // ~1.25 line-height fits Nunito at all weights without descender clipping.
    final content = iconSel + gap + fontSel * 1.25 + gap + dot;
    // 12dp vertical padding (6 top + 6 bottom) so content never touches edges.
    return NavBarSizes._(
      bar: content + 12,
      iconSelected: iconSel,
      iconUnselected: iconUnsel,
      gap: gap,
      dot: dot,
    );
  }

  /// The bar's height, above the system inset under it.
  final double bar;
  final double iconSelected;
  final double iconUnselected;
  final double gap;
  final double dot;
}
