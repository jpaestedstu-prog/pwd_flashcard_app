import 'package:flutter/material.dart';

import 'fit_text.dart';

/// A screen's title in its top bar, whole at every Font Size.
///
/// The bar is one line high, and on a phone the title shares it with the
/// bar's buttons: at the largest Font Size 71 titles ended in "…" on a 360 dp
/// phone, and on the tablet a long name did too ("Progreso ni Visual
/// Impairment St…", 30 Oct). This makes the title smaller as far as it must,
/// and takes a second line inside the bar's own height before it cuts
/// anything.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key, this.style, this.semanticsLabel});

  final String text;
  final TextStyle? style;

  /// What a screen reader says instead of [text] ("Spelling Bee, word 1 of
  /// 10" for "Spelling Bee • 1/10").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final centered = AppBarTheme.of(context).centerTitle ?? false;
    // The bar lays its title out with no limit on its height, so a title
    // on two lines at a large Font Size ran out of the bar and was cut
    // off at its edge ("Spelling Bee • 1/10" on a phone, 8 Nov). Told
    // the bar's own height, FitText keeps both lines inside it.
    // In a header that expands (FlexibleSpaceBar) the title has the room of
    // the expanded header, not the bar's.
    final bar = context.findAncestorWidgetOfExactType<AppBar>();
    final expanding =
        context.findAncestorWidgetOfExactType<FlexibleSpaceBar>() != null;
    final height = expanding
        ? double.infinity
        : bar?.toolbarHeight ??
              AppBarTheme.of(context).toolbarHeight ??
              kToolbarHeight;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: FitText(
        text,
        style: style,
        // Smaller than the other labels may go: a title says where the
        // learner is, and a whole one a little small beats half of one.
        minScale: 0.55,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
