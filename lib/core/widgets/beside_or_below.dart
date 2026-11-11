import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'fit_text.dart';

/// Where [BesideOrBelow] puts each of its children.
enum BesideOrBelowSlot { leading, title, trailing }

/// A header row — [leading], then [title], then [trailing] — that moves the
/// title under the other two when it would not fit whole between them (or,
/// with [drop] [BesideOrBelowSlot.trailing], moves [trailing] under the
/// title: a badge after a card's heading).
///
/// The Home greeting sat between the learner's picture and the Shop and
/// Settings buttons. With a thirty-letter name on a phone at the largest
/// Font Size that left it a column 160 px wide, and "Kumusta, Josefina Maria
/// Dela Cruz-Reyes!" lost its end (the survey, 3 Nov). Beside the buttons
/// while it fits there; under them, the width of the screen, when it does
/// not. Whether it fits is [fits], asked in layout with the room there is —
/// usually a [FitText.measurer] for the title's own text.
class BesideOrBelow
    extends SlottedMultiChildRenderObjectWidget<BesideOrBelowSlot, RenderBox> {
  const BesideOrBelow({
    super.key,
    required this.title,
    required this.fits,
    this.leading,
    this.trailing,
    this.gap = 12,
    this.trailingGap = 0,
    this.spacing = 8,
    this.drop = BesideOrBelowSlot.title,
  }) : assert(drop != BesideOrBelowSlot.leading);

  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  /// Whether the title fits whole in a column this wide.
  final bool Function(double width) fits;

  /// Between [leading] and the title beside it.
  final double gap;

  /// Between the title beside them and [trailing].
  final double trailingGap;

  /// Between the row and what goes under it.
  final double spacing;

  /// What goes under when the title does not fit: the title itself, the
  /// width of the row, or [trailing], under the title at its start.
  final BesideOrBelowSlot drop;

  @override
  Iterable<BesideOrBelowSlot> get slots => BesideOrBelowSlot.values;

  @override
  Widget? childForSlot(BesideOrBelowSlot slot) => switch (slot) {
        BesideOrBelowSlot.leading => leading,
        BesideOrBelowSlot.title => title,
        BesideOrBelowSlot.trailing => trailing,
      };

  @override
  RenderBesideOrBelow createRenderObject(BuildContext context) =>
      RenderBesideOrBelow(
        fits: fits,
        gap: gap,
        trailingGap: trailingGap,
        spacing: spacing,
        drop: drop,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBesideOrBelow renderObject,
  ) {
    renderObject
      ..fits = fits
      ..gap = gap
      ..trailingGap = trailingGap
      ..spacing = spacing
      ..drop = drop
      ..textDirection = Directionality.of(context);
  }
}

/// The layout of [BesideOrBelow].
class RenderBesideOrBelow extends RenderBox
    with
        SlottedContainerRenderObjectMixin<BesideOrBelowSlot, RenderBox>,
        RelayoutWhenSystemFontsChangeMixin {
  RenderBesideOrBelow({
    required bool Function(double width) fits,
    required double gap,
    required double trailingGap,
    required double spacing,
    required BesideOrBelowSlot drop,
    required TextDirection textDirection,
  })  : _drop = drop,
        _fits = fits,
        _gap = gap,
        _trailingGap = trailingGap,
        _spacing = spacing,
        _textDirection = textDirection;

  bool Function(double width) _fits;
  set fits(bool Function(double width) value) {
    // A new closure on every build, measuring the same text more often than
    // not; the measure is cheap, and asking again is what keeps it right
    // when the text or its style changed.
    _fits = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _trailingGap;
  set trailingGap(double value) {
    if (value == _trailingGap) return;
    _trailingGap = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  BesideOrBelowSlot _drop;
  set drop(BesideOrBelowSlot value) {
    if (value == _drop) return;
    _drop = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Whether the title went beside the others at the last layout.
  bool get titleBeside => _beside;
  bool _beside = true;

  RenderBox? get _leading => childForSlot(BesideOrBelowSlot.leading);
  RenderBox? get _title => childForSlot(BesideOrBelowSlot.title);
  RenderBox? get _trailing => childForSlot(BesideOrBelowSlot.trailing);

  /// The size, and whether the title goes beside, for [constraints]; every
  /// child laid out (or dry-laid-out) with [layoutChild] on the way.
  (Size, bool) _plan(BoxConstraints constraints, ChildLayouter layoutChild) {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    final leading = _leading;
    final trailing = _trailing;
    final title = _title;
    final lead = leading == null ? Size.zero : layoutChild(leading, loose);
    final trail = trailing == null ? Size.zero : layoutChild(trailing, loose);
    final side = width -
        lead.width -
        trail.width -
        (leading == null ? 0 : _gap) -
        (trailing == null ? 0 : _trailingGap);
    final beside = !width.isFinite || (side > 0 && _fits(side));
    if (beside) {
      final shown = title == null
          ? Size.zero
          : layoutChild(
              title,
              width.isFinite
                  ? BoxConstraints.tightFor(width: side)
                  : const BoxConstraints(),
            );
      final height = math.max(shown.height, math.max(lead.height, trail.height));
      return (constraints.constrain(Size(width, height)), true);
    }
    if (_drop == BesideOrBelowSlot.trailing) {
      // The title beside [leading] alone, [trailing] under the title.
      final room = width - lead.width - (leading == null ? 0 : _gap);
      final shown = title == null
          ? Size.zero
          : layoutChild(title, BoxConstraints.tightFor(width: math.max(0, room)));
      final row = math.max(lead.height, shown.height);
      // Under the title, within its column.
      final below = trailing == null
          ? Size.zero
          : layoutChild(trailing, BoxConstraints(maxWidth: math.max(0, room)));
      final under = trailing == null ? 0.0 : _spacing + below.height;
      return (constraints.constrain(Size(width, row + under)), false);
    }
    final shown = title == null
        ? Size.zero
        : layoutChild(title, BoxConstraints.tightFor(width: width));
    final row = math.max(lead.height, trail.height);
    return (
      constraints.constrain(Size(width, row + _spacing + shown.height)),
      false,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _plan(constraints, ChildLayoutHelper.dryLayoutChild).$1;

  @override
  void performLayout() {
    final (planned, beside) = _plan(constraints, ChildLayoutHelper.layoutChild);
    size = planned;
    _beside = beside;
    final ltr = _textDirection == TextDirection.ltr;
    // [start] from the leading edge, as an offset from the left.
    double x(double start, RenderBox child) =>
        ltr ? start : size.width - start - child.size.width;
    void place(RenderBox? child, double start, double top) {
      if (child == null) return;
      (child.parentData! as BoxParentData).offset = Offset(x(start, child), top);
    }

    final leading = _leading;
    final trailing = _trailing;
    final title = _title;
    final leadWidth = leading?.size.width ?? 0;
    final trailWidth = trailing?.size.width ?? 0;
    if (beside) {
      double middle(RenderBox? child) =>
          (size.height - (child?.size.height ?? 0)) / 2;
      place(leading, 0, middle(leading));
      place(title, leading == null ? 0 : leadWidth + _gap, middle(title));
      place(trailing, size.width - trailWidth, middle(trailing));
    } else if (_drop == BesideOrBelowSlot.trailing) {
      final row = math.max(leading?.size.height ?? 0, title?.size.height ?? 0);
      final titleStart = leading == null ? 0.0 : leadWidth + _gap;
      place(leading, 0, (row - (leading?.size.height ?? 0)) / 2);
      place(title, titleStart, (row - (title?.size.height ?? 0)) / 2);
      place(trailing, titleStart, row + _spacing);
    } else {
      final row = math.max(
        leading?.size.height ?? 0,
        trailing?.size.height ?? 0,
      );
      place(leading, 0, (row - (leading?.size.height ?? 0)) / 2);
      place(
        trailing,
        size.width - trailWidth,
        (row - (trailing?.size.height ?? 0)) / 2,
      );
      place(title, 0, row + _spacing);
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final row = (_leading?.getMinIntrinsicWidth(height) ?? 0) +
        (_trailing?.getMinIntrinsicWidth(height) ?? 0) +
        (_leading == null ? 0 : _gap);
    return math.max(row, _title?.getMinIntrinsicWidth(height) ?? 0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (_leading?.getMaxIntrinsicWidth(height) ?? 0) +
      (_title?.getMaxIntrinsicWidth(height) ?? 0) +
      (_trailing?.getMaxIntrinsicWidth(height) ?? 0) +
      (_leading == null ? 0 : _gap) +
      (_trailing == null ? 0 : _trailingGap);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _plan(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild)
          .$1
          .height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
