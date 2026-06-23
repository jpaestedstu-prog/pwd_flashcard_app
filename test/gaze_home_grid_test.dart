import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';

GazeTileCell _cell(String label, [List<String>? log]) =>
    GazeTileCell(label: label, onActivate: () => log?.add(label));

void main() {
  group('GazeHomeGrid — publishing', () {
    test('starts empty and inert', () {
      final g = GazeHomeGrid();
      expect(g.hasGrid, isFalse);
      expect(g.rowLengths, isEmpty);
      expect(g.focusRow, isNull);
      expect(g.focusCol, isNull);
    });

    test('publishGrid exposes the row shape', () {
      final g = GazeHomeGrid();
      g.publishGrid([
        [_cell('a'), _cell('b')],
        [_cell('c'), _cell('d'), _cell('e')],
      ]);
      expect(g.hasGrid, isTrue);
      expect(g.rowLengths, [2, 3]);
    });

    test('only notifies when the shape changes', () {
      final g = GazeHomeGrid();
      var notifications = 0;
      g.addListener(() => notifications++);

      g.publishGrid([
        [_cell('a'), _cell('b')],
      ]);
      expect(notifications, 1);

      // Same shape, fresh callbacks → no extra notification (avoids thrashing
      // the shell on every Home rebuild).
      g.publishGrid([
        [_cell('a2'), _cell('b2')],
      ]);
      expect(notifications, 1);

      // Shape change → notifies.
      g.publishGrid([
        [_cell('a'), _cell('b'), _cell('c')],
      ]);
      expect(notifications, 2);
    });

    test('clearGrid empties the grid and resets focus, once', () {
      final g = GazeHomeGrid();
      var notifications = 0;
      g.publishGrid([
        [_cell('a')],
      ]);
      g.setFocus(0, 0);
      g.addListener(() => notifications++);

      g.clearGrid();
      expect(g.hasGrid, isFalse);
      expect(g.focusRow, isNull);
      expect(g.focusCol, isNull);
      expect(notifications, 1);

      // Already clear → no further notification.
      g.clearGrid();
      expect(notifications, 1);
    });

    test('a stale owner cannot clear a grid a newer owner published', () {
      final g = GazeHomeGrid();
      final outgoing = Object();
      final incoming = Object();

      // Outgoing hub publishes, then the incoming hub takes over (e.g. mid tab
      // fade, both briefly mounted).
      g.publishGrid([
        [_cell('old')],
      ], owner: outgoing);
      g.publishGrid([
        [_cell('new1'), _cell('new2')],
      ], owner: incoming);

      // The outgoing screen disposing now must NOT wipe the incoming grid.
      g.clearGrid(owner: outgoing);
      expect(g.hasGrid, isTrue);
      expect(g.rowLengths, [2]);

      // The current owner can still clear it.
      g.clearGrid(owner: incoming);
      expect(g.hasGrid, isFalse);
    });
  });

  group('GazeHomeGrid — focus', () {
    test('setFocus publishes the focused cell and notifies on change only', () {
      final g = GazeHomeGrid();
      var notifications = 0;
      g.addListener(() => notifications++);

      g.setFocus(1, 2);
      expect(g.focusRow, 1);
      expect(g.focusCol, 2);
      expect(g.isFocused(1, 2), isTrue);
      expect(g.isFocused(0, 0), isFalse);
      expect(notifications, 1);

      g.setFocus(1, 2); // unchanged → no notification
      expect(notifications, 1);

      g.setFocus(null, null); // cursor moved onto the nav bar
      expect(g.focusRow, isNull);
      expect(g.isFocused(1, 2), isFalse);
      expect(notifications, 2);
    });
  });

  group('GazeHomeGrid — cellAt', () {
    test('returns the cell and runs its callback', () {
      final log = <String>[];
      final g = GazeHomeGrid();
      g.publishGrid([
        [_cell('a', log), _cell('b', log)],
        [_cell('c', log)],
      ]);
      g.cellAt(0, 1)!.onActivate();
      g.cellAt(1, 0)!.onActivate();
      expect(log, ['b', 'c']);
    });

    test('is bounds-safe', () {
      final g = GazeHomeGrid();
      g.publishGrid([
        [_cell('a')],
      ]);
      expect(g.cellAt(-1, 0), isNull);
      expect(g.cellAt(0, -1), isNull);
      expect(g.cellAt(5, 0), isNull);
      expect(g.cellAt(0, 5), isNull);
      expect(g.cellAt(0, 0), isNotNull);
    });
  });
}
