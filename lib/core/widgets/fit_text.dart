import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Text that steps its own size down until its longest **word** fits on a line
/// and the whole text fits in [maxLines].
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
/// genuinely would not fit, or the text would be cut short with "…". Whole word
/// slightly smaller beats half a word at full size. Below the floor the type
/// stays at the floor and the whole text is drawn smaller, laid out as
/// narrow as its longest word allows: it used to wrap there, splitting words
/// ("Kamak / ailang", "Experi / ment" at 2x, 3 Nov). A layout that tight
/// still wants a layout fix; this keeps it readable meanwhile.
///
/// ### Measured, and measured again when the font arrives
///
/// It used to estimate 0.58 em a letter, because a measurement taken before
/// the app's Google font has loaded uses fallback metrics. The estimate cut
/// text all the same: "Mga Salita" became "Mga Sal…" in one line, and the
/// Games hub's descriptions ran past three, at the largest Font Size in
/// Filipino (30 Oct). So it measures with a [TextPainter] in the text's own
/// style, and measures again when a font finishes loading (Flutter announces
/// that through [PaintingBinding.systemFonts]).
class FitText extends StatefulWidget {
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.textAlign,
    this.minScale = 0.7,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;

  /// What a screen reader says instead of [text], as [Text.semanticsLabel].
  final String? semanticsLabel;

  /// Null for a paragraph: as many lines as it takes, never cut short.
  final int? maxLines;
  final TextAlign? textAlign;

  /// Smallest fraction of the original size this will use.
  final double minScale;

  /// Whether [text], drawn as a [FitText] with these settings would draw it,
  /// fits whole in a column of a given width: every word on a line, within
  /// [maxLines], at no smaller than the floor.
  ///
  /// Read from [context] now and measured later, so that a layout can ask
  /// while it lays out where the text is to go ([BesideOrBelow]).
  static bool Function(double width) measurer(
    BuildContext context,
    String text, {
    TextStyle? style,
    int? maxLines = 2,
    double minScale = 0.7,
    TextAlign? textAlign,
  }) {
    final fit = _Fit(
      context,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      minScale: minScale,
    );
    return (width) => !fit.measure(text, width, double.infinity).$2;
  }

  @override
  State<FitText> createState() => _FitTextState();
}

class _FitTextState extends State<FitText> {
  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  void _fontsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fit = _Fit(
      context,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      minScale: widget.minScale,
    );
    final base = fit.base;

    return LayoutBuilder(
      builder: (context, constraints) {
        final (size, belowFloor, wrapWidth) = fit.measureWithWrap(
          widget.text,
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final text = Text(
          widget.text,
          style: base.copyWith(fontSize: size),
          maxLines: widget.maxLines,
          overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
          textAlign: widget.textAlign,
          // Wrapping as it was measured: an app bar turns it off for its
          // title, and the second line measured for it never came.
          softWrap: true,
          semanticsLabel: widget.semanticsLabel,
        );
        // Not even the floor fits: the whole text, smaller still, rather
        // than "Nasasa…" on one line (a mood, a stat, a word — a phone at the
        // largest Font Size, 30 Oct) or a word split across two ("Kamak /
        // ailang", 3 Nov). Laid out as narrow as its longest word allows, so
        // it shrinks as little as it can.
        if (belowFloor) {
          final alignment = switch (widget.textAlign) {
            TextAlign.center => Alignment.center,
            TextAlign.right || TextAlign.end => AlignmentDirectional.centerEnd,
            _ => AlignmentDirectional.centerStart,
          };
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: widget.maxLines == 1
                ? text
                : SizedBox(width: wrapWidth, child: text),
          );
        }
        return text;
      },
    );
  }
}

/// What [FitText] measures with, read from the context at build time so that
/// the measuring itself can run later, in layout ([FitText.measurer]).
class _Fit {
  _Fit(
    BuildContext context, {
    required TextStyle? style,
    required this.textAlign,
    required this.maxLines,
    required this.minScale,
  })  : defaults = DefaultTextStyle.of(context),
        scaler = MediaQuery.textScalerOf(context),
        direction = Directionality.of(context),
        locale = Localizations.maybeLocaleOf(context) {
    base = style == null
        ? defaults.style
        : style.inherit
        ? defaults.style.merge(style)
        : style;
  }

  final DefaultTextStyle defaults;
  final TextScaler scaler;
  final TextDirection direction;
  final Locale? locale;
  final TextAlign? textAlign;
  final int? maxLines;
  final double minScale;
  late final TextStyle base;

  /// The font size [text] is drawn at in a box [width] wide and [maxHeight]
  /// high, and whether even the floor was too big for it — and then the
  /// width to lay it out in, every word whole, before it is drawn smaller to
  /// fit (see [FitText]).
  (double, bool) measure(String text, double width, double maxHeight) {
    final (size, belowFloor, _) = measureWithWrap(text, width, maxHeight);
    return (size, belowFloor);
  }

  (double, bool, double) measureWithWrap(
    String text,
    double width,
    double maxHeight,
  ) {
    final baseSize = base.fontSize ?? 14.0;
    var size = baseSize;
    var belowFloor = false;
    var wrapWidth = width;
    // The column's own width, as [fits] is asked about it by default.
    final width0 = width;
    if (width.isFinite && text.trim().isNotEmpty) {
      // How wide [piece] is on one line at [fontSize].
      double lineWidth(String piece, double fontSize) {
        final painter = TextPainter(
          text: TextSpan(text: piece, style: base.copyWith(fontSize: fontSize)),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
        )..layout();
        final w = painter.width;
        painter.dispose();
        return w;
      }

      // The widest word, measured on its own: a paragraph's
      // minIntrinsicWidth is no guide (centred, it said "Disagree" fitted
      // a column it was split in). A line may end after a hyphen, so
      // "Sunod-sunod" is two pieces, "Sunod-" and "sunod".
      var widest = '';
      var widestWidth = 0.0;
      for (final m in RegExp(r'[^\s-]+-?').allMatches(text)) {
        final word = m.group(0)!;
        final w = lineWidth(word, baseSize);
        if (w > widestWidth) {
          widest = word;
          widestWidth = w;
        }
      }

      // Whether the text, at [fontSize], keeps every word whole and
      // ends within [maxLines].
      bool fits(double fontSize, [double? inWidth]) {
        final width = inWidth ?? width0;
        // Exactly: a word 0.13 px too wide for its column was split
        // ("Disagre / e") when this allowed half a pixel.
        if (lineWidth(widest, fontSize) > width) return false;
        final painter = TextPainter(
          text: TextSpan(text: text, style: base.copyWith(fontSize: fontSize)),
          textDirection: direction,
          textAlign: textAlign ?? defaults.textAlign ?? TextAlign.start,
          textScaler: scaler,
          maxLines: maxLines,
          locale: locale,
          textWidthBasis: defaults.textWidthBasis,
          textHeightBehavior: defaults.textHeightBehavior,
        )..layout(maxWidth: width);
        // And within the height it was given, when it was given one (a
        // Flexible in a card): past it the last line was clipped.
        // (Not the height, once the text is to be drawn smaller as a whole:
        // that scales the height down with it.)
        final whole = !painter.didExceedMaxLines &&
            (inWidth != null ||
                !maxHeight.isFinite ||
                painter.height <= maxHeight);
        painter.dispose();
        return whole;
      }

      if (!fits(baseSize)) {
        // The floor deepens as the scale rises. A flat 0.7 still split
        // "Crea / te" at 2x, and it did not need to: shrinking to 0.5
        // there still renders the word at its *unscaled* size, which is
        // what every learner at 1.0x reads happily. Never below that.
        final floor = baseSize * (scaler.scale(1.0) >= 1.8 ? 0.5 : minScale);
        // The largest size that fits, to a tenth of a pixel; the floor
        // when even that does not.
        var low = floor;
        var high = baseSize;
        if (fits(floor)) {
          while (high - low > 0.1) {
            final mid = (low + high) / 2;
            if (fits(mid)) {
              low = mid;
            } else {
              high = mid;
            }
          }
        } else {
          belowFloor = true;
          // The narrowest width that holds the text, at the floor, in its
          // lines with every word whole: from the longest word (never
          // narrower than the column itself — a text too tall for its box
          // only needs drawing smaller) up to the whole text on one line.
          var narrow = math.max(width, lineWidth(widest, floor).ceilToDouble());
          var wide = math.max(narrow, lineWidth(text, floor).ceilToDouble());
          if (maxLines == null || fits(floor, narrow)) {
            wide = narrow;
          } else {
            // To within a pixel. Halved every time (no rounding inside the
            // loop: a rounded middle could equal an end, and the search
            // never ended — a test hung on it, 4 Nov).
            for (var i = 0; i < 24 && wide - narrow > 1; i++) {
              final mid = (narrow + wide) / 2;
              if (fits(floor, mid)) {
                wide = mid;
              } else {
                narrow = mid;
              }
            }
          }
          wrapWidth = wide.ceilToDouble();
        }
        size = low;
      }
    }
    return (size, belowFloor, wrapWidth);
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
