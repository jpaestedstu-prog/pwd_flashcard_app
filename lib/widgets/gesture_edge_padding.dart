import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Horizontal padding that keeps a drawing or dragging surface clear of the
/// screen edges where the system's back gesture starts.
///
/// With gesture navigation (the default on most phones now) a drag that
/// begins within about 30 dp of the left or right edge is the back gesture,
/// not a touch for the app. On a phone the tracing canvas reached to 16 dp
/// from the edge, so a stroke begun there paused the game instead of
/// drawing (Villaon V671N: 51 px strips at 1.7 px per dp).
/// [MediaQuery.systemGestureInsetsOf] gives those strips; they are zero with
/// the three-button bar, where this is just [minimum] on each side.
///
/// For a surface whose parent spans the screen's width, as a page body does.
EdgeInsets gestureSafeHorizontal(
  BuildContext context, {
  double minimum = 16,
  double gap = 4,
}) {
  final insets = MediaQuery.systemGestureInsetsOf(context);
  double side(double inset) => math.max(minimum, inset > 0 ? inset + gap : 0);
  return EdgeInsets.only(left: side(insets.left), right: side(insets.right));
}
