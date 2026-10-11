import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/games/widgets/fitting_grid.dart';

/// Word Match, Picture-Word and Pronunciation answer grids do not scroll. On
/// a phone held sideways their fixed cell shape left the second row of
/// answers off screen, out of reach (a clipped grid raises no layout error,
/// so only the landscape walkthrough's screenshots showed it).

double _ratio({
  required double width,
  required double height,
  int items = 4,
  int columns = 2,
  double preferred = 2.5,
}) =>
    fittingAspectRatio(
      width: width,
      height: height,
      itemCount: items,
      columns: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      preferred: preferred,
    );

void main() {
  test('a grid that fits keeps its own shape', () {
    // Portrait phone: two rows of 2.5:1 answers need ~140 of 300 dp.
    expect(_ratio(width: 320, height: 300), 2.5);
  });

  test('a short space flattens the cells until both rows fit', () {
    const width = 860.0, height = 120.0;
    final r = _ratio(width: width, height: height);
    const cellWidth = (width - 12) / 2;
    expect(2 * (cellWidth / r) + 12, closeTo(height, 0.01));
    expect(r, greaterThan(2.5));
  });

  test('an unbounded height (inside a scroll view) is left alone', () {
    expect(_ratio(width: 320, height: double.infinity), 2.5);
  });

  test('odd counts and single columns', () {
    final r = _ratio(width: 400, height: 200, items: 5);
    const rows = 3;
    expect(rows * (((400 - 12) / 2) / r) + 2 * 12, lessThanOrEqualTo(200.01));
    // Three 300 dp squares fit in 1000 dp: left square.
    expect(_ratio(width: 300, height: 1000, items: 3, columns: 1, preferred: 1),
        1.0);
    // ...but not in 600 dp: flattened until all three fit.
    final r1 = _ratio(width: 300, height: 600, items: 3, columns: 1, preferred: 1);
    expect(3 * (300 / r1) + 2 * 12, closeTo(600, 0.01));
  });
}
