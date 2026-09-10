import 'package:flutter/material.dart';

/// Text that steps its own size down until its longest **word** fits on a line.
///
/// Flutter breaks *inside* a word once the word alone is wider than the line,
/// which is how the app was showing learners "Kuman / ta", "Bahagha / ri" and
/// "Tele / vision" — vocabulary words, split down the middle, on the screens
/// built to teach them. Nothing overflowed, so no overflow test could see it.
///
/// Use this for a **short label in a fixed-width tile**: a game answer, a board
/// word, a stat caption. It is the wrong tool for body copy, which should wrap
/// across lines rather than shrink.
///
/// ### It shrinks reluctantly
///
/// A low-vision learner asked for bigger text, so taking size away is a cost.
/// [minScale] floors how far it will go, and the step only happens when the word
/// genuinely would not fit. Whole word slightly smaller beats half a word at
/// full size; below the floor it stops shrinking and lets the text wrap, on the
/// grounds that a layout that broken needs a layout fix, not a smaller font.
///
/// ### Why an estimate rather than a `TextPainter`
///
/// Measuring looks exact and is not: these labels render in a Google font that
/// is not resolved at measure time, so the painter returns fallback metrics,
/// reports a fit, and the real face breaks anyway. 0.58 em per character is a
/// safe average for the app's faces.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.textAlign,
    this.minScale = 0.7,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  /// Smallest fraction of the original size this will use.
  final double minScale;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final baseSize = base.fontSize ?? 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        var size = baseSize;
        if (constraints.maxWidth.isFinite) {
          final scale = MediaQuery.textScalerOf(context).scale(1.0);
          final longest = text
              .split(RegExp(r'\s+'))
              .fold<int>(0, (max, w) => w.length > max ? w.length : max);
          if (longest > 0) {
            final needed = longest * 0.58 * scale;
            if (needed > 0) {
              // Letter spacing is a flat number of logical pixels per
              // character and does *not* scale with the font, so it cannot be
              // folded into `needed` — it comes off the available width
              // instead. The dyslexia theme sets 0.6 on every style, which is
              // what let "Happy" split as "Happ / y" in an 84dp mood tile
              // while this estimate still reported a comfortable fit.
              final spacing = longest * (base.letterSpacing ?? 0);
              final room = constraints.maxWidth - spacing;
              // Largest size at which the longest word still fits one line.
              final fits = room / needed;
              // The floor deepens as the scale rises. A flat 0.7 still split
              // "Crea / te" at 2x, and it did not need to: shrinking to 0.5
              // there still renders the word at its *unscaled* size, which is
              // what every learner at 1.0x reads happily. Never below that.
              final floor =
                  baseSize * (scale >= 1.8 ? 0.5 : minScale);
              // Never `clamp`: when the word cannot fit even at the floor, the
              // upper bound drops below the lower one and clamp throws.
              size = fits >= baseSize
                  ? baseSize
                  : (fits < floor ? floor : fits);
            }
          }
        }
        return Text(
          text,
          style: base.copyWith(fontSize: size),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}

/// A style stepped down for [text] using the **text scale alone**.
///
/// [FitText] is the better tool when it can be used, because it measures the
/// real column. It cannot be used everywhere: it is built on `LayoutBuilder`,
/// and a `LayoutBuilder` inside a widget whose parent computes intrinsic sizes
/// throws `'hasSize'` during layout. `ProActionTile` sits in exactly such a
/// grid.
///
/// So this is the layout-free fallback. It cannot know the column width, only
/// that a long word plus a large scale is the combination that splits words, so
/// it steps down on that signal. Prefer [FitText] wherever the parent allows it.
TextStyle? fittedStyle(
  BuildContext context,
  String text,
  TextStyle? base, {
  double factor = 0.85,
  int longWord = 8,
}) {
  if (base == null) return base;
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  if (scale < 1.3) return base;
  final longest = text
      .split(RegExp(r'\s+'))
      .fold<int>(0, (max, w) => w.length > max ? w.length : max);
  final size = base.fontSize;
  if (size == null) return base;
  // Letter spacing makes a word wider than its character count suggests, so
  // count it as extra characters before applying the long-word gate. Under the
  // dyslexia theme's 0.6 this is what pulls a short word like "Happy" over the
  // threshold — without it the gate returned early and did nothing at all.
  final spacing = base.letterSpacing ?? 0;
  final effective = spacing > 0
      ? longest + (longest * spacing / (size * 0.58)).round()
      : longest;
  if (effective < longWord) return base;
  // The step has to deepen with the scale. A flat 0.85 still left
  // "Works / heets" at 2x, because the tile does not widen as the font grows:
  // the shortfall is proportional, so the correction has to be too. Even the
  // deepest step here leaves the label larger than it is at 1.0x.
  var step = scale >= 1.8 ? factor * 0.8 : factor;
  // …and deepen it again by whatever share of the width letter spacing adds.
  // Spacing does not scale with the font, so it is a *fixed* surcharge per
  // character that shrinking the type cannot recover — under the dyslexia
  // theme's 0.6 that is about 6% of a tile label's width, which was the
  // difference between "Assessments" fitting and rendering "Assessment / s".
  if (spacing > 0) {
    step /= 1 + spacing / (0.58 * size);
  }
  return base.copyWith(fontSize: size * step);
}
