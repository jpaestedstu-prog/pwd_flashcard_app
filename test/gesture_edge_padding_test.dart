import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/widgets/gesture_edge_padding.dart';

/// Drawing and dragging games keep clear of the screen edges where the back
/// gesture starts: on a phone with gesture navigation a tracing stroke begun
/// there paused the game instead of drawing.
void main() {
  Future<EdgeInsets> paddingWith(
    WidgetTester tester,
    EdgeInsets gestureInsets, {
    double minimum = 16,
  }) async {
    late EdgeInsets result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(systemGestureInsets: gestureInsets),
        child: Builder(builder: (context) {
          result = gestureSafeHorizontal(context, minimum: minimum);
          return const SizedBox();
        }),
      ),
    );
    return result;
  }

  testWidgets('gesture navigation: clear of each strip, with a gap',
      (tester) async {
    final p = await paddingWith(
      tester,
      const EdgeInsets.only(left: 30, right: 30, bottom: 32),
    );
    expect(p.left, 34);
    expect(p.right, 34);
    expect(p.top, 0);
    expect(p.bottom, 0);
  });

  testWidgets('the three-button bar: just the usual margin', (tester) async {
    final p = await paddingWith(tester, EdgeInsets.zero);
    expect(p, const EdgeInsets.symmetric(horizontal: 16));
  });

  testWidgets('a narrow strip never shrinks the usual margin', (tester) async {
    final p = await paddingWith(
      tester,
      const EdgeInsets.only(left: 6),
      minimum: 20,
    );
    expect(p.left, 20);
    expect(p.right, 20);
  });
}
