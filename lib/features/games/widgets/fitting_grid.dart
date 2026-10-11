import 'package:flutter/rendering.dart';

/// A fixed-column grid delegate for a grid that does **not scroll**, whose
/// rows must all fit in [box].
///
/// A non-scrolling grid paints no overflow stripe when its rows do not fit:
/// it silently clips them, and the answers in them cannot be reached. That
/// is what happened to Word Match, Picture-Word and Pronunciation on a phone
/// held sideways (two of four answers on screen). The game's own
/// [childAspectRatio] is kept whenever every row fits at it, so a layout
/// that already fits looks exactly as before; otherwise the cells are made
/// just flat enough that every row fits. (TapQuizGame sizes its cells the
/// same way.) In an unbounded height — a grid inside a scroll view — nothing
/// is changed.
SliverGridDelegateWithFixedCrossAxisCount fittingGridDelegate({
  required BoxConstraints box,
  required int itemCount,
  required int crossAxisCount,
  double mainAxisSpacing = 0,
  double crossAxisSpacing = 0,
  double childAspectRatio = 1.0,
}) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: fittingAspectRatio(
      width: box.maxWidth,
      height: box.maxHeight,
      itemCount: itemCount,
      columns: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      preferred: childAspectRatio,
    ),
  );
}

/// The aspect ratio behind [fittingGridDelegate] — pure, so it is tested.
double fittingAspectRatio({
  required double width,
  required double height,
  required int itemCount,
  required int columns,
  required double mainAxisSpacing,
  required double crossAxisSpacing,
  required double preferred,
}) {
  if (!height.isFinite || !width.isFinite || itemCount <= 0 || columns <= 0) {
    return preferred;
  }
  final rows = (itemCount / columns).ceil();
  final cellWidth = (width - crossAxisSpacing * (columns - 1)) / columns;
  final cellHeight = (height - mainAxisSpacing * (rows - 1)) / rows;
  if (cellWidth <= 0 || cellHeight <= 0) return preferred;
  final fitting = cellWidth / cellHeight;
  return fitting > preferred ? fitting : preferred;
}
