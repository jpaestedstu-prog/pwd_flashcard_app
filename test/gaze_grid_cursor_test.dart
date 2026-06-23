import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_grid_cursor.dart';

void main() {
  group('GazeGridCursor — single row (nav-only, behaves like NavGazeCursor)', () {
    test('horizontal wraps across the one row', () {
      final c = GazeGridCursor(rowLengths: const [5]);
      c.moveHoriz(1);
      expect(c.col, 1);
      c.moveHoriz(4); // 1 + 4 = 5 → wraps to 0
      expect(c.col, 0);
      c.moveHoriz(-1); // wraps left to the last tab
      expect(c.col, 4);
      expect(c.row, 0);
    });

    test('vertical movement is a no-op with a single row', () {
      final c = GazeGridCursor(rowLengths: const [4], col: 2);
      c.moveVert(1);
      c.moveVert(-3);
      expect(c.row, 0);
      expect(c.col, 2);
    });
  });

  group('GazeGridCursor — multi-row ragged grid', () {
    // Home tile rows of 2, 2, 3 with a bottom-nav row of 5.
    List<int> shape() => const [2, 2, 3, 5];

    test('clamps the initial position into range', () {
      // Initial placement clamps (it doesn't wrap) — wrapping is reserved for
      // explicit moves so look-up from the top row can reach the bottom.
      expect(GazeGridCursor(rowLengths: shape(), row: 9, col: 9).row, 3);
      expect(GazeGridCursor(rowLengths: shape(), row: 9, col: 9).col, 4);
      expect(GazeGridCursor(rowLengths: shape(), row: -1, col: -1).row, 0);
      expect(GazeGridCursor(rowLengths: shape(), row: -1, col: -1).col, 0);
    });

    test('vertical wraps top↔bottom', () {
      final c = GazeGridCursor(rowLengths: shape());
      c.moveVert(-1); // up from the top row wraps to the bottom (nav) row
      expect(c.row, 3);
      c.moveVert(1); // down from the bottom row wraps to the top
      expect(c.row, 0);
    });

    test('vertical clamps the column into a shorter destination row', () {
      // Start on the 5-wide nav row at col 4, then move up into the 2-wide row.
      final c = GazeGridCursor(rowLengths: shape(), row: 3, col: 4);
      c.moveVert(-1); // → row 2 (length 3): col clamps 4 → 2
      expect(c.row, 2);
      expect(c.col, 2);
      c.moveVert(-1); // → row 1 (length 2): col clamps 2 → 1
      expect(c.row, 1);
      expect(c.col, 1);
    });

    test('horizontal wraps within the current row only', () {
      final c = GazeGridCursor(rowLengths: shape()); // top row is 2-wide
      c.moveHoriz(1);
      expect(c.col, 1);
      c.moveHoriz(1); // wraps within the 2-wide row
      expect(c.col, 0);
      expect(c.row, 0);
    });

    test('moveTo re-syncs to a known cell, clamped', () {
      final c = GazeGridCursor(rowLengths: shape());
      c.moveTo(3, 2); // nav row, tab 2
      expect(c.row, 3);
      expect(c.col, 2);
      c.moveTo(1, 9); // 2-wide row, col clamps to 1
      expect(c.row, 1);
      expect(c.col, 1);
    });

    test('currentRowLength reflects the row the cursor is on', () {
      final c = GazeGridCursor(rowLengths: shape(), row: 3);
      expect(c.currentRowLength, 5);
      c.moveVert(-1);
      expect(c.currentRowLength, 3);
    });
  });

  group('GazeGridCursor — setRows (layout / role changes)', () {
    test('collapsing to nav-only keeps the cursor valid', () {
      final c = GazeGridCursor(rowLengths: const [2, 2, 5], col: 1);
      c.setRows(const [5]); // Home grid disappeared (navigated away)
      expect(c.rowCount, 1);
      expect(c.row, 0);
      expect(c.col, 1); // col still in range for the 5-wide nav row
    });

    test('growing into a grid keeps the cursor in range', () {
      final c = GazeGridCursor(rowLengths: const [5], col: 4);
      c.setRows(const [2, 2, 5]); // Home grid appeared
      expect(c.rowCount, 3);
      expect(c.row, 0);
      expect(c.col, 1); // clamped into the 2-wide top row
    });

    test('shrinking the nav row keeps the column in range (role switch)', () {
      final c = GazeGridCursor(rowLengths: const [5], col: 4);
      c.setRows(const [4]);
      expect(c.col, 3);
    });
  });

  group('GazeGridCursor — empty / degenerate', () {
    test('empty grid never throws and stays at origin', () {
      final c = GazeGridCursor(rowLengths: const []);
      c.moveHoriz(1);
      c.moveVert(1);
      c.moveTo(2, 2);
      expect(c.row, 0);
      expect(c.col, 0);
      expect(c.rowCount, 0);
      expect(c.currentRowLength, 0);
    });

    test('a row with zero cells is safe', () {
      final c = GazeGridCursor(rowLengths: const [0, 3]);
      c.moveHoriz(1); // empty row → no move
      expect(c.col, 0);
      c.moveVert(1); // into the 3-wide row
      expect(c.row, 1);
      expect(c.currentRowLength, 3);
    });
  });
}
