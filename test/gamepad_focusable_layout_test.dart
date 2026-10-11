import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_screen_registrar.dart';

/// GamepadFocusable wraps every answer of the controller-ready games. It used
/// to lay its ring out with StackFit.expand, which fills a grid cell but turns
/// a list row (unbounded height) into an infinitely tall box: Word → Sign, the
/// one game with a list of answers, broke the moment its videos loaded (found
/// by the small-iPhone simulator walkthrough).

Widget _app(Widget body) => MaterialApp(home: Scaffold(body: body));

void main() {
  testWidgets('a list row sizes to its child', (tester) async {
    await tester.pumpWidget(_app(ListView(
      children: [
        for (var i = 0; i < 3; i++)
          GamepadFocusable(
            index: i,
            child: SizedBox(key: ValueKey('row$i'), height: 120),
          ),
      ],
    )));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('row0'))).height, 120);
    expect(tester.getSize(find.byType(GamepadFocusable).first).height, 120);
  });

  testWidgets('a grid cell is still filled edge to edge', (tester) async {
    await tester.pumpWidget(_app(GridView.count(
      crossAxisCount: 2,
      children: [
        for (var i = 0; i < 4; i++)
          GamepadFocusable(
            index: i,
            // Smaller than the cell on purpose: the cell decides the size.
            child: SizedBox(key: ValueKey('cell$i'), width: 10, height: 10),
          ),
      ],
    )));

    expect(tester.takeException(), isNull);
    final cell = tester.getSize(find.byType(GamepadFocusable).first);
    final child = tester.getSize(find.byKey(const ValueKey('cell0')));
    expect(child, cell);
    expect(cell.width, greaterThan(100));
  });
}
