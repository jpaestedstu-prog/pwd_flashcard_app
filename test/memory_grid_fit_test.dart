import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';

/// The Memory Match grid does not scroll. On a phone held sideways the
/// portrait-shaped cards in four or five columns left only the first row on
/// screen, and the cards below could not be reached: the game could not be
/// finished. (A clipped grid raises no layout error, so the overflow matrix
/// never saw it; the landscape walkthrough's screenshot did.)

bool _allFit((int, double) grid, int count, double w, double h, double gap) {
  final (cols, ratio) = grid;
  final rows = (count / cols).ceil();
  final cellW = (w - gap * (cols - 1)) / cols;
  return rows * (cellW / ratio) + gap * (rows - 1) <= h + 0.5;
}

void main() {
  test('a layout that already fits is left exactly as it was', () {
    // Portrait phone, 12 cards: four columns of portrait cards fit.
    final grid = fitMemoryGrid(
      count: 12,
      width: 340,
      height: 520,
      spacing: 10,
      columns: 4,
      ratio: 0.78,
    );
    expect(grid, (4, 0.78));
  });

  test('a phone held sideways gets every card on screen', () {
    const w = 880.0, h = 300.0, gap = 10.0;
    final grid = fitMemoryGrid(
      count: 12,
      width: w,
      height: h,
      spacing: gap,
      columns: 5,
      ratio: 0.78,
    );
    expect(_allFit(grid, 12, w, h, gap), isTrue, reason: '$grid');
    expect(grid.$2, lessThanOrEqualTo(1.6), reason: 'still card-shaped');
    expect(grid.$1, greaterThanOrEqualTo(5), reason: 'wider rows instead');
  });

  test('every size and card count fits', () {
    for (final count in [8, 12, 16, 20]) {
      for (final (w, h) in [
        (340.0, 520.0), (880.0, 300.0), (600.0, 260.0), (1200.0, 640.0),
        (560.0, 360.0), (300.0, 200.0), (1300.0, 280.0),
      ]) {
        final grid = fitMemoryGrid(
          count: count,
          width: w,
          height: h,
          spacing: 10,
          columns: 4,
          ratio: 0.78,
        );
        expect(_allFit(grid, count, w, h, 10), isTrue,
            reason: '$count cards in ${w}x$h -> $grid');
      }
    }
  });
}
