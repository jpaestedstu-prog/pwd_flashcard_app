import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A text field's label, whole: a little smaller where the field is too
/// narrow for it, never cut.
///
/// A field's label has one line, and Flutter ends a label that does not fit
/// it with "…". On a phone at the largest Font Size "Kumpirmahin ang
/// password", "Paglalarawan (opsyonal)" and "Code ng home group" all lost
/// their ends (3 Nov). Use it as `InputDecoration(label: FitLabel(text))` in
/// place of `labelText: text`: it takes the label's style from the field,
/// resting and floating, and stays at that size wherever it fits.
class FitLabel extends StatelessWidget {
  const FitLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => _ScaleDown(
        child: Text(text, maxLines: 1, softWrap: false),
      );
}

class _ScaleDown extends SingleChildRenderObjectWidget {
  const _ScaleDown({required super.child});

  @override
  RenderFittedBox createRenderObject(BuildContext context) =>
      _RenderScaleDown(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderFittedBox renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

/// A scale-down [RenderFittedBox] that reports its child's baseline where it
/// is drawn. The field sets its label by its baseline; a plain FittedBox
/// reports the baseline of the text at full size, which put a shrunk label
/// out of line with the field's border.
class _RenderScaleDown extends RenderFittedBox {
  _RenderScaleDown({super.textDirection})
      : super(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
        );

  /// Where a baseline [childBaseline] below the top of a child of
  /// [childSize] falls in a box of [boxSize].
  static double _placed(double childBaseline, Size childSize, Size boxSize) {
    if (childSize.isEmpty) return childBaseline;
    final scale = math.min(
      1.0,
      math.min(
        boxSize.width / childSize.width,
        boxSize.height / childSize.height,
      ),
    );
    final top = (boxSize.height - childSize.height * scale) / 2;
    return top + childBaseline * scale;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    final at = child.getDistanceToActualBaseline(baseline);
    if (at == null) return null;
    return _placed(at, child.size, size);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    const loose = BoxConstraints();
    final at = child.getDryBaseline(loose, baseline);
    if (at == null) return null;
    return _placed(at, child.getDryLayout(loose), getDryLayout(constraints));
  }
}
