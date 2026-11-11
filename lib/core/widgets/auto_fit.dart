import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The smallest type [AutoFit] will draw words in, in logical pixels, unless a
/// label has no other way to stay whole. Twelve-point body copy is the WCAG
/// reference; eleven is the least a label on a control may fall to.
const double kMinReadableFontSize = 11;

/// Keeps a label inside the room it is given, shrinking it only as far as it
/// stays readable.
///
/// Three things used to go wrong when a control got narrower than its label:
///
///  * a plain [Text] broke **inside** a word ("Magpa / tuloy");
///  * a [FittedBox] had no floor, and drew whole labels in unreadable type: 6
///    px on a phone's XP bar, 4 px on a mission chip, 1.6 px on a report tile;
///  * [FitText] measures a real column, but it is built on `LayoutBuilder`, so
///    it cannot sit under a button, a [Wrap] or an `IntrinsicHeight`.
///
/// This does what each of those was reaching for, as a render object that lays
/// its child out without a rebuild and answers intrinsic and dry-layout
/// questions, so it can go anywhere — including, through the app's theme,
/// around the label of every button ([autoFitButtonForeground]).
///
/// In order, for a label that does not fit:
///
///  1. Slightly smaller, on one line, if that is all it takes.
///  2. Otherwise on more lines, every word whole, at full size.
///  3. Otherwise smaller and on more lines, never below the floor.
///  4. Only a word too long for the column at the floor goes below it: a whole
///     word, smaller, beats half a word.
///
/// At a large text scale step 1 is skipped sooner: a learner who asked for
/// bigger text would rather have a second line than smaller type.
class AutoFit extends SingleChildRenderObjectWidget {
  const AutoFit({
    super.key,
    required super.child,
    this.minScale = 0.75,
    this.minFontSize = kMinReadableFontSize,
    this.maxLines = 2,
    this.alignment = Alignment.center,
  });

  /// The least fraction of its size a word is drawn at before it wraps.
  final double minScale;

  /// The least size, in logical pixels, a word may be drawn at.
  final double minFontSize;

  /// How many lines to try before giving up size for fewer lines. Null: as
  /// many as the words need.
  final int? maxLines;

  /// Where the label sits when it is smaller than its box.
  final AlignmentGeometry alignment;

  @override
  RenderAutoFit createRenderObject(BuildContext context) => RenderAutoFit(
    minScale: minScale,
    minFontSize: minFontSize,
    maxLines: maxLines,
    alignment: alignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderAutoFit renderObject) {
    renderObject
      ..minScale = minScale
      ..minFontSize = minFontSize
      ..maxLines = maxLines
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// What every themed button draws its label through; set in `accessibleTheme`
/// so it reaches every button of every theme, and every button added later.
///
/// Centred: a label that wraps used to leave its second line ragged, and the
/// paragraph as wide as the column, so a button with an icon sat up to 56 px
/// off centre on a phone at the largest Font Size.
Widget autoFitButtonForeground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  if (child == null) return const SizedBox.shrink();
  return DefaultTextStyle.merge(
    textAlign: TextAlign.center,
    textWidthBasis: TextWidthBasis.longestLine,
    child: AutoFit(maxLines: 3, child: child),
  );
}

class RenderAutoFit extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderAutoFit({
    required double minScale,
    required double minFontSize,
    required int? maxLines,
    required AlignmentGeometry alignment,
    TextDirection? textDirection,
  }) : _minScale = minScale,
       _minFontSize = minFontSize,
       _maxLines = maxLines,
       _alignment = alignment,
       _textDirection = textDirection;

  double get minScale => _minScale;
  double _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  double get minFontSize => _minFontSize;
  double _minFontSize;
  set minFontSize(double value) {
    if (value == _minFontSize) return;
    _minFontSize = value;
    markNeedsLayout();
  }

  int? get maxLines => _maxLines;
  int? _maxLines;
  set maxLines(int? value) {
    if (value == _maxLines) return;
    _maxLines = value;
    markNeedsLayout();
  }

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _scale = 1;
  Offset _childOffset = Offset.zero;

  /// How much the label is drawn down from its size; 1 when it is not.
  @visibleForTesting
  double get debugScale => _scale;

  /// A LayoutBuilder under the child (a [FitText], say) has its own way of
  /// fitting, and cannot be asked how big it would like to be: leave it alone.
  static bool _hasLayoutBuilder(RenderObject root) {
    if (root is RenderConstrainedLayoutBuilder) return true;
    var found = false;
    root.visitChildren((c) {
      if (!found && _hasLayoutBuilder(c)) found = true;
    });
    return found;
  }

  /// The paragraphs under the child, in order.
  static List<RenderParagraph> _paragraphsOf(RenderObject root) {
    final found = <RenderParagraph>[];
    void walk(RenderObject r) {
      if (r is RenderParagraph) {
        found.add(r);
        return;
      }
      r.visitChildren(walk);
    }

    walk(root);
    return found;
  }

  /// Whether [p] is words, as opposed to an icon's glyph (icons are drawn
  /// from the private-use range, U+E000 to U+F8FF).
  static bool _isWords(RenderParagraph p) =>
      RegExp(r'[^\s\uE000-\uF8FF]').hasMatch(p.text.toPlainText());

  /// The size of the type in [p] as it will be drawn, before this widget
  /// scales it.
  static double _fontSizeOf(RenderParagraph p) {
    final span = p.text;
    final size = span is TextSpan ? span.style?.fontSize : null;
    return p.textScaler.scale(size ?? 14);
  }

  /// The floor for this child's biggest type.
  double _floorFor(List<RenderParagraph> words) {
    var biggest = 0.0;
    for (final p in words) {
      biggest = math.max(biggest, _fontSizeOf(p));
    }
    if (biggest <= 0) return minScale;
    return math.min(1.0, math.max(minScale, minFontSize / biggest));
  }

  /// How wide the longest unbreakable piece of [p] is, on its own line.
  /// Measured a word at a time: a centred paragraph's own minimum width has
  /// been seen to answer 9 px for "Disagree".
  static double _widestWord(RenderParagraph p) {
    final plain = p.text.toPlainText(includeSemanticsLabels: false);
    final span = p.text;
    final style = span is TextSpan ? span.style : null;
    var widest = 0.0;
    for (final m in RegExp(r'[^\s-]+-?').allMatches(plain)) {
      final painter = TextPainter(
        text: TextSpan(text: m.group(0), style: style, locale: p.locale),
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        locale: p.locale,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  ({BoxConstraints child, double scale}) _solve(BoxConstraints c) {
    final child = this.child!;
    final maxW = c.maxWidth;
    final maxH = c.maxHeight;
    if (_hasLayoutBuilder(child)) {
      return (child: BoxConstraints(maxWidth: maxW), scale: 1);
    }
    final natural = child.getMaxIntrinsicWidth(double.infinity);

    final loose = BoxConstraints(maxWidth: maxW);
    if (!maxW.isFinite || natural <= maxW || natural <= 0) {
      return (child: loose, scale: 1);
    }
    // No room at all (a button all padding): nothing to fit it into.
    if (maxW <= 0) {
      return (child: BoxConstraints(maxWidth: natural), scale: 1e-4);
    }

    final words = _paragraphsOf(child).where(_isWords).toList();
    final floor = _floorFor(words);

    // At a large text scale a second line is better than smaller type.
    final textScale = words.isEmpty ? 1.0 : words.first.textScaler.scale(1);
    final oneLineFloor = math.max(floor, textScale >= 1.3 ? 0.93 : 0.82);

    final oneLine = maxW / natural;
    if (oneLine >= oneLineFloor) {
      return (child: BoxConstraints(maxWidth: natural), scale: oneLine);
    }

    // One line or nothing: it cannot wrap, so the only way to keep it whole
    // is to draw it smaller. Everything else wraps.
    final canWrap =
        words.isNotEmpty &&
        words.every((p) => p.softWrap && p.maxLines != 1);
    if (!canWrap) {
      return (child: BoxConstraints(maxWidth: natural), scale: oneLine);
    }

    // The narrowest the child can be without splitting a word.
    var narrowest = child.getMinIntrinsicWidth(double.infinity);
    for (final p in words) {
      final own = p.getMinIntrinsicWidth(double.infinity);
      final word = _widestWord(p);
      if (word > own) narrowest += word - own;
    }

    var scale = 1.0;
    if (narrowest > maxW) {
      // Not even at the floor? Then the word, whole, smaller than the floor.
      scale = maxW / narrowest;
    }

    final limit = maxLines;
    final oneLineHeight = child.getDryLayout(const BoxConstraints()).height;
    int linesAt(double width) {
      if (oneLineHeight <= 0) return 1;
      final h = child.getDryLayout(BoxConstraints(maxWidth: width)).height;
      return (h / oneLineHeight + 0.2).floor();
    }

    // What the child has besides its words (an icon and its gap), so a
    // paragraph is measured in the width it will really get.
    var widestText = 0.0;
    for (final p in words) {
      widestText = math.max(widestText, p.getMaxIntrinsicWidth(double.infinity));
    }
    final besides = math.max(0.0, natural - widestText);

    // A paragraph with a line limit of its own is cut at it, and its dry
    // layout stops at that limit too, so the child's height cannot say it
    // was cut: count its lines in full. "You're learning! Review the words
    // you missed." lost its last line this way (8 Nov).
    bool withinOwnLimits(double width) {
      for (final p in words) {
        final own = p.maxLines;
        if (own == null) continue;
        final painter = TextPainter(
          text: p.text,
          textDirection: p.textDirection,
          textScaler: p.textScaler,
          locale: p.locale,
          strutStyle: p.strutStyle,
          textHeightBehavior: p.textHeightBehavior,
          textWidthBasis: p.textWidthBasis,
        )..layout(maxWidth: math.max(1.0, width - besides));
        final lines = painter.computeLineMetrics().length;
        painter.dispose();
        if (lines > own) return false;
      }
      return true;
    }

    bool fits(double s) =>
        withinOwnLimits(maxW / s) &&
        (limit == null || linesAt(maxW / s) <= limit);

    if (!fits(scale)) {
      // The largest size that fits, never below the floor when the floor
      // fits; when even the floor does not, smaller still rather than cut.
      var low = fits(floor) ? floor : 0.2;
      var high = math.min(scale, fits(floor) ? scale : floor);
      if (fits(low)) {
        for (var i = 0; i < 10 && high - low > 0.005; i++) {
          final mid = (low + high) / 2;
          if (fits(mid)) {
            low = mid;
          } else {
            high = mid;
          }
        }
        scale = low;
      } else {
        scale = math.min(scale, low);
      }
    }

    // Told how tall it may be, and still too tall: smaller again.
    if (maxH.isFinite) {
      final h = child.getDryLayout(BoxConstraints(maxWidth: maxW / scale)).height;
      if (h * scale > maxH && h > 0) {
        scale = math.min(scale, maxH / h);
      }
    }
    return (child: BoxConstraints(maxWidth: maxW / scale), scale: scale);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null || _hasLayoutBuilder(child)) return 0;
    final words = _paragraphsOf(child).where(_isWords).toList();
    return child.getMinIntrinsicWidth(height) * _floorFor(words);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null || _hasLayoutBuilder(child)) return 0;
    return child.getMaxIntrinsicWidth(height);
  }

  double _heightFor(double width) {
    final child = this.child;
    if (child == null || _hasLayoutBuilder(child)) return 0;
    return computeDryLayout(BoxConstraints(maxWidth: width)).height;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    final at = child.getDistanceToActualBaseline(baseline);
    if (at == null) return null;
    return _childOffset.dy + at * _scale;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    if (_hasLayoutBuilder(child)) {
      assert(
        debugCannotComputeDryLayout(
          reason: 'A LayoutBuilder below cannot be asked speculatively.',
        ),
      );
      return Size.zero;
    }
    final solved = _solve(constraints);
    final s = child.getDryLayout(solved.child);
    return constraints.constrain(s * solved.scale);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      _scale = 1;
      _childOffset = Offset.zero;
      return;
    }
    final solved = _solve(constraints);
    child.layout(solved.child, parentUsesSize: true);
    _scale = solved.scale;
    final drawn = child.size * _scale;
    size = constraints.constrain(drawn);
    final align = alignment.resolve(_textDirection ?? TextDirection.ltr);
    _childOffset = align.alongOffset(
      Offset(size.width - drawn.width, size.height - drawn.height),
    );
  }

  Matrix4 get _transform => Matrix4.identity()
    ..translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1)
    ..scaleByDouble(_scale, _scale, 1, 1);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_scale == 1) {
      layer = null;
      context.paintChild(child, offset + _childOffset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      child.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
