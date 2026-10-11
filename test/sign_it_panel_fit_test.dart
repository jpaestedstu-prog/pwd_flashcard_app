import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/features/fsl_interpreter/screens/sign_it_screen.dart';

/// Sign It's panels on a 10" tablet with a working camera.
///
/// The live preview and the sign video are AspectRatios, and their natural
/// height (width over ratio) pushed "Record" and "Replay" below the fold of a
/// panel that scrolled without looking scrollable, upright and sideways.
/// Widget tests and the CI emulators have no live camera, so only the tablet
/// showed it. Panel sizes below are the tablet's (1200 x 1920 at 1.75).

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Size panel,
  required double ratio,
  String footer = 'Record',
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1200, 1200),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: panel,
              child: SignItPanel(
                label: 'You',
                icon: Icons.videocam_rounded,
                accent: const Color(0xFF00BFA5),
                footer: TextButton(onPressed: () {}, child: Text(footer)),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: const ColoredBox(
                    key: ValueKey('media'),
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectFooterInView(WidgetTester tester, String footer, double ratio) {
  expect(tester.takeException(), isNull);
  final panel = tester.getRect(find.byType(SignItPanel));
  expect(tester.getRect(find.text(footer)).bottom,
      lessThanOrEqualTo(panel.bottom));
  // Reachable by a tap where it is drawn, not scrolled out of the panel.
  expect(find.text(footer).hitTestable(), findsOneWidget);
  // The picture shrinks to fit but keeps its shape.
  final media = tester.getSize(find.byKey(const ValueKey('media')));
  expect(media.width / media.height, closeTo(ratio, 0.01));
}

void main() {
  testWidgets('sideways: a 4:3 camera leaves Record in view', (tester) async {
    await _pumpPanel(tester, panel: const Size(526, 394), ratio: 4 / 3);
    _expectFooterInView(tester, 'Record', 4 / 3);
  });

  testWidgets('upright: a 3:4 camera leaves Record in view', (tester) async {
    await _pumpPanel(tester, panel: const Size(654, 394), ratio: 3 / 4);
    _expectFooterInView(tester, 'Record', 3 / 4);
  });

  testWidgets('upright: a 16:9 sign video leaves Replay in view',
      (tester) async {
    await _pumpPanel(
      tester,
      panel: const Size(654, 394),
      ratio: 16 / 9,
      footer: 'Replay',
    );
    _expectFooterInView(tester, 'Replay', 16 / 9);
  });

  testWidgets('the largest text on a short panel still scrolls to Record',
      (tester) async {
    await _pumpPanel(
      tester,
      panel: const Size(400, 200),
      ratio: 4 / 3,
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Record'));
    await tester.pump();
    expect(find.text('Record').hitTestable(), findsOneWidget);
  });
}
