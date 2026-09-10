import 'package:flutter/material.dart';

/// A row of equal-width tiles that stacks instead of squeezing.
///
/// The app lays stat tiles out three or four across in a `Row` of `Expanded`s.
/// That share does not grow with the font, so on a narrow screen — or at the
/// Visual Impairment preset's 1.4x — the label naming each number breaks
/// *inside itself*: "Best Strea / k", "Minut / es", "Total Activ / e". Nothing
/// overflows, so no overflow test can see it; the label is simply unreadable.
///
/// Reflowing to a column is the accessible answer. The tiles get the full width,
/// every word stays whole, and the only cost is height on a screen that already
/// scrolls. Shrinking the text instead would take size away from the learner who
/// asked for it.
///
/// ### Why an estimate rather than a measurement
///
/// A `TextPainter` looks like the exact answer and is not: these labels render
/// in a Google font that is not resolved at measure time, so the painter returns
/// fallback metrics, reports a fit, and the real face breaks anyway. 0.58 em per
/// character is a safe average for the app's faces, and erring toward stacking
/// costs a little height rather than a broken word.
class ReflowRow extends StatelessWidget {
  const ReflowRow({
    super.key,
    required this.children,
    required this.labels,
    this.spacing = 12,
    this.labelFontSize = 12,
    this.tilePadding = 20,
  });

  /// The tiles, in order. Must be the same length as [labels].
  final List<Widget> children;

  /// The longest word in each tile's label decides whether the row fits.
  final List<String> labels;

  /// Gap between tiles, applied horizontally or vertically to match the layout.
  final double spacing;

  /// Size of the label text, used to estimate whether it fits.
  final double labelFontSize;

  /// Horizontal padding inside one tile, excluded from the space a label has.
  final double tilePadding;

  static int _longestWord(String s) => s
      .split(RegExp(r'\s+'))
      .fold<int>(0, (max, w) => w.length > max ? w.length : max);

  @override
  Widget build(BuildContext context) {
    assert(children.length == labels.length,
        'ReflowRow needs one label per child');
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        final n = children.length;
        final each =
            (constraints.maxWidth - spacing * (n - 1)) / n - tilePadding;
        // Letter spacing is a flat number of logical pixels per character and
        // does not scale with the font, so it is added per character rather
        // than folded into the em estimate. The dyslexia theme sets 0.6 on
        // every style, which is enough to push a label that "fits" on this
        // estimate into breaking on screen.
        final letterSpacing =
            Theme.of(context).textTheme.labelMedium?.letterSpacing ?? 0;
        final needed = labels
            .map((l) =>
                _longestWord(l) * (0.58 * labelFontSize * scale + letterSpacing))
            .fold<double>(0, (a, b) => b > a ? b : a);

        if (each >= needed) {
          return Row(
            // Deliberately NOT `stretch`: these rows sit inside scroll views,
            // where stretching asks the children for an infinite height and
            // the layout asserts.
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              SizedBox(width: double.infinity, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
