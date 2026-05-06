import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/games/jigsaw/jigsaw_piece_clipper.dart';

void main() {
  group('JigsawPieceClipper.generateGrid', () {
    test('2×2 grid produces 4 clippers', () {
      final grid = JigsawPieceClipper.generateGrid(2, 2);
      expect(grid.length, 2);
      expect(grid[0].length, 2);
      expect(grid[1].length, 2);
    });

    test('3×3 grid produces 9 clippers', () {
      final grid = JigsawPieceClipper.generateGrid(3, 3);
      final count = grid.expand((row) => row).length;
      expect(count, 9);
    });

    test('4×4 grid produces 16 clippers', () {
      final grid = JigsawPieceClipper.generateGrid(4, 4);
      final count = grid.expand((row) => row).length;
      expect(count, 16);
    });

    test('top-left corner has flat top and flat left', () {
      final grid = JigsawPieceClipper.generateGrid(3, 3);
      final topLeft = grid[0][0];
      expect(topLeft.topTab, 0, reason: 'Top edge should be flat');
      expect(topLeft.leftTab, 0, reason: 'Left edge should be flat');
    });

    test('bottom-right corner has flat bottom and flat right', () {
      final grid = JigsawPieceClipper.generateGrid(3, 3);
      final bottomRight = grid[2][2];
      expect(bottomRight.bottomTab, 0, reason: 'Bottom edge should be flat');
      expect(bottomRight.rightTab, 0, reason: 'Right edge should be flat');
    });

    test('adjacent pieces have matching tab/blank pairs', () {
      final grid = JigsawPieceClipper.generateGrid(3, 3);
      // Horizontal adjacency: piece[r][c].rightTab + piece[r][c+1].leftTab should be 0
      // (one is +1 tab, other is -1 blank)
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          expect(
            grid[r][c].rightTab + grid[r][c + 1].leftTab,
            0,
            reason:
                'Piece ($r,$c) right and ($r,${c + 1}) left should be matching tab/blank',
          );
        }
      }
      // Vertical adjacency
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 3; c++) {
          expect(
            grid[r][c].bottomTab + grid[r + 1][c].topTab,
            0,
            reason:
                'Piece ($r,$c) bottom and (${r + 1},$c) top should be matching tab/blank',
          );
        }
      }
    });

    test('interior piece has no flat edges', () {
      final grid = JigsawPieceClipper.generateGrid(3, 3);
      final center = grid[1][1];
      expect(center.topTab, isNot(0));
      expect(center.rightTab, isNot(0));
      expect(center.bottomTab, isNot(0));
      expect(center.leftTab, isNot(0));
    });
  });

  group('JigsawPieceClipper constructor', () {
    test('stores row/col/rows/cols correctly', () {
      const clipper = JigsawPieceClipper(
        row: 1,
        col: 2,
        rows: 3,
        cols: 4,
        topTab: 1,
        rightTab: -1,
        bottomTab: 1,
        leftTab: -1,
      );
      expect(clipper.row, 1);
      expect(clipper.col, 2);
      expect(clipper.rows, 3);
      expect(clipper.cols, 4);
      expect(clipper.topTab, 1);
      expect(clipper.rightTab, -1);
    });
  });
}
