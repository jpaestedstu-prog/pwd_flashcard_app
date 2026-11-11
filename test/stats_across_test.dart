import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/stats_across.dart';

/// Four stat tiles in a row left each about 60 px on a very narrow phone, and
/// a caption such as "Katumpakan" was drawn at 8 px (the UI survey, 9 Nov).
void main() {
  Future<List<Rect>> rects(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsAcross(
            children: [
              for (final name in ['a', 'b', 'c', 'd'])
                Expanded(child: SizedBox(key: ValueKey(name), height: 40)),
            ],
          ),
        ),
      ),
    );
    return [
      for (final name in ['a', 'b', 'c', 'd'])
        tester.getRect(find.byKey(ValueKey(name))),
    ];
  }

  testWidgets('four across on an ordinary phone', (tester) async {
    final r = await rects(tester, const Size(360, 640));
    expect({for (final x in r) x.top}.length, 1);
    expect(r[0].width, 90);
  });

  testWidgets('two above two on a very narrow screen, in reading order', (
    tester,
  ) async {
    final r = await rects(tester, const Size(320, 568));
    expect(r[0].top, r[1].top);
    expect(r[2].top, r[3].top);
    expect(r[2].top, greaterThan(r[0].bottom));
    expect(r[0].width, 160);
    expect(r[1].left, greaterThan(r[0].left));
    expect(r[3].left, greaterThan(r[2].left));
  });
}
