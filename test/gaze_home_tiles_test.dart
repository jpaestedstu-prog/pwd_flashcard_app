import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_home_tiles.dart';

List<GazeTileEntry> _entries(String prefix, int n) => [
      for (var i = 0; i < n; i++)
        (
          tile: Text('$prefix$i'),
          cell: GazeTileCell(label: '$prefix$i', onActivate: () {}),
        ),
    ];

void main() {
  group('GazeTileGridBuilder — inactive (pass-through)', () {
    test('returns the tiles untouched and publishes no rows', () {
      final b = GazeTileGridBuilder(active: false);
      final widgets = b.section(columns: 2, entries: _entries('t', 5));
      expect(b.rows, isEmpty);
      expect(widgets.length, 5);
      expect(widgets.first, isA<Text>()); // not wrapped
    });
  });

  group('GazeTileGridBuilder — active (row-major chunking)', () {
    test('chunks one section into rows matching the grid columns', () {
      final b = GazeTileGridBuilder(active: true);
      final widgets = b.section(columns: 2, entries: _entries('t', 5));

      // 5 tiles in a 2-wide grid → rows of 2, 2, 1.
      expect([for (final r in b.rows) r.length], [2, 2, 1]);

      GazeFocusable at(int i) => widgets[i] as GazeFocusable;
      expect((at(0).row, at(0).col), (0, 0));
      expect((at(1).row, at(1).col), (0, 1));
      expect((at(2).row, at(2).col), (1, 0));
      expect((at(3).row, at(3).col), (1, 1));
      expect((at(4).row, at(4).col), (2, 0));
    });

    test('offsets later sections by the rows already added', () {
      final b = GazeTileGridBuilder(active: true);
      b.section(columns: 2, entries: _entries('a', 5)); // rows 0,1,2
      final more = b.section(columns: 3, entries: _entries('b', 4)); // rows 3,4

      expect([for (final r in b.rows) r.length], [2, 2, 1, 3, 1]);
      expect((more[0] as GazeFocusable).row, 3);
      expect((more[2] as GazeFocusable).row, 3);
      expect((more[3] as GazeFocusable).row, 4);
    });

    test('preserves each cell so the D-pad opens the right tile', () {
      final opened = <String>[];
      final b = GazeTileGridBuilder(active: true);
      b.section(columns: 2, entries: [
        (tile: const Text('x'), cell: GazeTileCell(label: 'X', onActivate: () => opened.add('X'))),
        (tile: const Text('y'), cell: GazeTileCell(label: 'Y', onActivate: () => opened.add('Y'))),
      ]);
      b.rows[0][1].onActivate();
      expect(opened, ['Y']);
      expect(b.rows[0][0].label, 'X');
    });
  });
}
