import 'package:flutter/material.dart';

/// Custom clipper that cuts a rectangular piece from an image grid,
/// with optional jigsaw-style tab/blank bumps on each edge.
///
/// [row] and [col] identify which piece this is in the grid.
/// [rows] and [cols] define the grid dimensions (e.g. 3×3).
/// [tabStatus] controls which edges have a tab (outward bump),
/// blank (inward notch), or flat edge (for border pieces).
class JigsawPieceClipper extends CustomClipper<Path> {
  final int row;
  final int col;
  final int rows;
  final int cols;

  /// Edge bump configuration: +1 = tab (outward), -1 = blank (inward), 0 = flat
  final int topTab;
  final int rightTab;
  final int bottomTab;
  final int leftTab;

  const JigsawPieceClipper({
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
    this.topTab = 0,
    this.rightTab = 0,
    this.bottomTab = 0,
    this.leftTab = 0,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final bumpW = w * 0.18;
    final bumpH = h * 0.18;

    final path = Path();
    path.moveTo(0, 0);

    // ─── Top edge ─────────────────────────────────
    if (topTab != 0) {
      path.lineTo(w * 0.35, 0);
      path.cubicTo(
        w * 0.35, topTab * -bumpH,
        w * 0.65, topTab * -bumpH,
        w * 0.65, 0,
      );
    }
    path.lineTo(w, 0);

    // ─── Right edge ───────────────────────────────
    if (rightTab != 0) {
      path.lineTo(w, h * 0.35);
      path.cubicTo(
        w + rightTab * bumpW, h * 0.35,
        w + rightTab * bumpW, h * 0.65,
        w, h * 0.65,
      );
    }
    path.lineTo(w, h);

    // ─── Bottom edge ──────────────────────────────
    if (bottomTab != 0) {
      path.lineTo(w * 0.65, h);
      path.cubicTo(
        w * 0.65, h + bottomTab * bumpH,
        w * 0.35, h + bottomTab * bumpH,
        w * 0.35, h,
      );
    }
    path.lineTo(0, h);

    // ─── Left edge ────────────────────────────────
    if (leftTab != 0) {
      path.lineTo(0, h * 0.65);
      path.cubicTo(
        leftTab * -bumpW, h * 0.65,
        leftTab * -bumpW, h * 0.35,
        0, h * 0.35,
      );
    }
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant JigsawPieceClipper oldClipper) {
    return row != oldClipper.row ||
        col != oldClipper.col ||
        rows != oldClipper.rows ||
        cols != oldClipper.cols;
  }

  /// Generates the tab configuration for a full grid.
  /// Matching edges: if piece A has a tab (+1) on its right,
  /// piece B (to its right) gets a blank (-1) on its left.
  static List<List<JigsawPieceClipper>> generateGrid(int rows, int cols) {
    // Pre-compute horizontal and vertical tab directions
    // horizontalTabs[r][c] = tab direction for the right edge of piece (r,c)
    //   and the left edge of piece (r, c+1) is the opposite.
    final horizontalTabs = List.generate(
      rows,
      (r) => List.generate(cols - 1, (c) => (c + r) % 2 == 0 ? 1 : -1),
    );
    final verticalTabs = List.generate(
      rows - 1,
      (r) => List.generate(cols, (c) => (r + c) % 2 == 0 ? 1 : -1),
    );

    return List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final top = r == 0 ? 0 : -verticalTabs[r - 1][c];
        final bottom = r == rows - 1 ? 0 : verticalTabs[r][c];
        final left = c == 0 ? 0 : -horizontalTabs[r][c - 1];
        final right = c == cols - 1 ? 0 : horizontalTabs[r][c];

        return JigsawPieceClipper(
          row: r,
          col: c,
          rows: rows,
          cols: cols,
          topTab: top,
          rightTab: right,
          bottomTab: bottom,
          leftTab: left,
        );
      });
    });
  }
}
