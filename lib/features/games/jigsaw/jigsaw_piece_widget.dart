import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'jigsaw_piece_clipper.dart';

/// A single draggable jigsaw piece that displays a clipped portion
/// of the source image (or emoji fallback).
///
/// When [isPlaced] is true the piece sits in its correct grid slot
/// and is no longer draggable. Otherwise it can be dragged from the
/// piece tray onto the grid.
class JigsawPieceWidget extends StatelessWidget {
  final int row;
  final int col;
  final int rows;
  final int cols;
  final JigsawPieceClipper clipper;
  final Widget sourceImage;
  final double pieceWidth;
  final double pieceHeight;
  final bool isPlaced;
  final VoidCallback? onTap;

  const JigsawPieceWidget({
    super.key,
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
    required this.clipper,
    required this.sourceImage,
    required this.pieceWidth,
    required this.pieceHeight,
    this.isPlaced = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Each piece is laid out at its CORE size (pieceWidth × pieceHeight); the
    // jigsaw tabs are drawn by the clipper and overflow outside that box. The
    // OverflowBox lets the full-size source image render unconstrained (a plain
    // SizedBox here would be squished by the tight piece-size constraints), so
    // we can translate it and reveal just the (row, col) fragment — plus the
    // tab strips that bleed into neighbours. This is seamless because every
    // piece samples the same source image with complementary tab/blank edges.
    final offsetX = -col * pieceWidth;
    final offsetY = -row * pieceHeight;

    Widget piece = SizedBox(
      width: pieceWidth,
      height: pieceHeight,
      child: ClipPath(
        clipper: clipper,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: SizedBox(
              width: pieceWidth * cols,
              height: pieceHeight * rows,
              child: sourceImage,
            ),
          ),
        ),
      ),
    );

    if (isPlaced) {
      return Semantics(
        label: 'Puzzle piece row ${row + 1}, column ${col + 1}, placed correctly',
        child: piece.animate().scale(
          begin: const Offset(1.05, 1.05),
          end: const Offset(1.0, 1.0),
          duration: 250.ms,
        ),
      );
    }

    // Unplaced pieces get a subtle shadow and are tappable
    return Semantics(
      label: 'Puzzle piece row ${row + 1}, column ${col + 1}, tap to place',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: piece,
        ),
      ),
    );
  }
}
