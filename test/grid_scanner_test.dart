import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/grid_scanner.dart';

/// Scanning mode's row–column scanner — the selection method for learners who
/// can blink but cannot move their head, now used on the hubs, the tab bar,
/// the flashcard viewer and every other D-pad screen.
void main() {
  group('a single row scans one control at a time', () {
    test('starts on the first control, wraps, and a blink picks it', () {
      final s = GridScanner([3]);
      expect(s.onWholeRow, isFalse, reason: 'no row phase for one row');
      expect((s.row, s.col), (0, 0));
      s.step();
      s.step();
      expect(s.col, 2);
      s.step();
      expect(s.col, 0, reason: 'wraps back to the first control');
      s.step();
      expect(s.select(), (row: 0, col: 1));
    });

    test('a pick leaves the highlight where it is, for a repeat press', () {
      final s = GridScanner([4])
        ..step()
        ..step();
      expect(s.select(), (row: 0, col: 2));
      expect(s.select(), (row: 0, col: 2));
    });
  });

  group('several rows scan rows first, then the chosen row', () {
    test('lights whole rows top to bottom and wraps', () {
      final s = GridScanner([2, 3, 5]);
      expect(s.onWholeRow, isTrue);
      expect(s.row, 0);
      s.step();
      expect((s.row, s.col), (1, null));
      s.step();
      expect(s.row, 2);
      s.step();
      expect(s.row, 0, reason: 'wraps to the top row');
    });

    test('a blink on a one-control row picks it straight away', () {
      final s = GridScanner([1, 3])..step();
      expect(s.row, 1);
      s.step();
      expect(s.row, 0);
      expect(s.select(), (row: 0, col: 0));
    });

    test('a blink on a longer row steps into it, a second picks', () {
      final s = GridScanner([1, 3])..step();
      expect(s.select(), isNull, reason: 'stepping into the row');
      expect((s.row, s.col), (1, 0));
      s.step();
      expect(s.col, 1);
      expect(s.select(), (row: 1, col: 1));
    });

    test('a full pass with no blink hands back to the same row', () {
      final s = GridScanner([1, 3])..step();
      s.select(); // into row 1 at control 0
      s.step(); // control 1
      s.step(); // control 2
      s.step(); // pass complete
      expect(s.onWholeRow, isTrue);
      expect(s.row, 1, reason: 'the same row, so it can be re-entered');
      s.step();
      expect(s.row, 0, reason: 'then scanning moves on');
    });

    test('a pick restarts the pass, so a repeat press is possible', () {
      final s = GridScanner([1, 3])..step();
      s.select();
      s.step();
      s.step();
      expect(s.select(), (row: 1, col: 2));
      // A full fresh pass is available after the pick.
      s.step();
      expect(s.col, 0);
      s.step();
      expect(s.col, 1);
      expect(s.onWholeRow, isFalse);
    });
  });

  group('shape changes and empty rows', () {
    test('empty rows are never lit', () {
      final s = GridScanner([0, 2, 0, 1]);
      expect(s.row, 1, reason: 'starts on the first row with controls');
      s.step();
      expect(s.row, 3);
      s.step();
      expect(s.row, 1);
    });

    test('a single non-empty row among empties scans controls directly', () {
      final s = GridScanner([0, 3, 0]);
      expect((s.row, s.col), (1, 0));
      expect(s.select(), (row: 1, col: 0));
    });

    test('nothing to scan is safe', () {
      final s = GridScanner([]);
      expect(s.isEmpty, isTrue);
      s.step();
      expect(s.select(), isNull);
      final zeros = GridScanner([0, 0]);
      expect(zeros.isEmpty, isTrue);
      expect(zeros.select(), isNull);
    });

    test('the same shape re-published keeps the highlight', () {
      final s = GridScanner([2, 2])..step();
      s.setRows([2, 2]);
      expect(s.row, 1);
    });

    test('a new shape starts over from the top', () {
      final s = GridScanner([2, 2])
        ..step()
        ..select();
      s.setRows([3, 1, 5]);
      expect((s.row, s.col), (0, null));
    });
  });
}
