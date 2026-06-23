import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';

void main() {
  group('wrapBoardIndex (gaze cursor over the tile grid)', () {
    test('stays put inside the range', () {
      expect(wrapBoardIndex(0, 6), 0);
      expect(wrapBoardIndex(3, 6), 3);
      expect(wrapBoardIndex(5, 6), 5);
    });

    test('wraps off the right edge to the start', () {
      expect(wrapBoardIndex(6, 6), 0);
      expect(wrapBoardIndex(7, 6), 1);
    });

    test('wraps off the left edge to the end (look-left from first tile)', () {
      expect(wrapBoardIndex(-1, 6), 5);
      expect(wrapBoardIndex(-2, 6), 4);
    });

    test('empty grid is safe', () {
      expect(wrapBoardIndex(0, 0), 0);
      expect(wrapBoardIndex(-1, 0), 0);
      expect(wrapBoardIndex(3, 0), 0);
    });

    test('handles large jumps', () {
      expect(wrapBoardIndex(20, 8), 4);
      expect(wrapBoardIndex(-20, 8), 4);
    });
  });
}
