import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/scan_cycler.dart';

void main() {
  group('ScanCycler', () {
    test('advances and wraps around', () {
      final c = ScanCycler(count: 3);
      expect(c.current, 0);
      expect(c.advance(), 1);
      expect(c.advance(), 2);
      expect(c.advance(), 0); // wraps
      expect(c.advance(), 1);
    });

    test('empty set yields -1 and never advances', () {
      final c = ScanCycler(count: 0);
      expect(c.current, -1);
      expect(c.advance(), -1);
    });

    test('reset returns to the first item', () {
      final c = ScanCycler(count: 4);
      c.advance();
      c.advance();
      c.reset();
      expect(c.current, 0);
    });

    test('current clamps when count shrinks', () {
      final c = ScanCycler(count: 4);
      c.advance(); // 1
      c.advance(); // 2
      c.advance(); // 3
      c.count = 2; // fewer items now
      expect(c.current, lessThan(2));
    });
  });
}
