import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/widgets/auto_fit.dart';
import 'package:pwdpwdpwd/core/widgets/fit_text.dart';

import 'support/real_fonts.dart';

/// Pumps [button] at [width] under the app's theme.
Future<void> _pump(
  WidgetTester tester,
  Widget button, {
  required double width,
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: button),
        ),
      ),
    ),
  );
  await tester.pump();
}

RenderParagraph _label(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        matching: find.text(text, findRichText: true),
      ),
    );

double _drawnFont(RenderParagraph rp) {
  final span = rp.text as TextSpan;
  final size = (span.style?.fontSize ?? 14) * rp.textScaler.scale(1);
  final drawn = MatrixUtils.transformRect(
    rp.getTransformTo(null),
    Offset.zero & rp.size,
  );
  return size * drawn.width / rp.size.width;
}

int _lines(RenderParagraph rp) {
  final text = rp.text.toPlainText();
  final boxes = rp.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return {for (final b in boxes) b.top.round()}.length;
}

/// Every word of the paragraph's text is on one line (none was split).
void _expectWholeWords(RenderParagraph rp, String text) {
  final plain = rp.text.toPlainText();
  for (final m in RegExp(r'\S+').allMatches(plain)) {
    final boxes = rp.getBoxesForSelection(
      TextSelection(baseOffset: m.start, extentOffset: m.end),
    );
    final tops = {for (final b in boxes) b.top.round()};
    expect(tops.length, 1, reason: '"${m.group(0)}" was split in "$text"');
  }
}

void main() {
  setUpAll(loadRealFonts);

  group('every button shape keeps its label whole', () {
    const labels = {
      'short': 'OK',
      'word': 'Magpatuloy',
      'phrase': 'Magdagdag ng Bagong Profile',
      'long word': 'Pinakamahabangsalitangito',
    };
    const widths = [64.0, 88.0, 120.0, 160.0, 240.0];
    const scales = [0.85, 1.0, 1.3, 1.5];

    final buttons = <String, Widget Function(String)>{
      'FilledButton': (t) => FilledButton(onPressed: () {}, child: Text(t)),
      'ElevatedButton': (t) => ElevatedButton(onPressed: () {}, child: Text(t)),
      'OutlinedButton': (t) => OutlinedButton(onPressed: () {}, child: Text(t)),
      'TextButton': (t) => TextButton(onPressed: () {}, child: Text(t)),
      'FilledButton.icon': (t) => FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: Text(t),
      ),
      'OutlinedButton.icon': (t) => OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: Text(t),
      ),
      'TextButton.icon': (t) => TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: Text(t),
      ),
    };

    for (final MapEntry(key: name, value: build) in buttons.entries) {
      for (final MapEntry(key: labelName, value: label) in labels.entries) {
        for (final width in widths) {
          for (final scale in scales) {
            testWidgets('$name, $labelName, ${width}dp, ${scale}x', (
              tester,
            ) async {
              await _pump(
                tester,
                build(label),
                width: width,
                textScale: scale,
              );
              expect(tester.takeException(), isNull);
              final rp = _label(tester, label);
              _expectWholeWords(rp, label);
              final button = tester.renderObject<RenderBox>(
                find.byWidgetPredicate((w) => w is ButtonStyleButton),
              );
              // Nothing outside the button.
              final labelRect = MatrixUtils.transformRect(
                rp.getTransformTo(null),
                Offset.zero & rp.size,
              );
              final buttonRect =
                  button.localToGlobal(Offset.zero) & button.size;
              expect(
                labelRect.left >= buttonRect.left - 0.5 &&
                    labelRect.right <= buttonRect.right + 0.5,
                isTrue,
                reason: 'label $labelRect, button $buttonRect',
              );
              expect(button.size.height, greaterThanOrEqualTo(48));
            });
          }
        }
      }
    }
  });

  group('how a label gives way', () {
    testWidgets('a label that fits is left alone', (tester) async {
      await _pump(
        tester,
        FilledButton(onPressed: () {}, child: const Text('OK')),
        width: 200,
      );
      final rp = _label(tester, 'OK');
      expect(_drawnFont(rp), closeTo(16, 0.01));
      expect(_lines(rp), 1);
    });

    testWidgets('a little too wide: smaller, on one line', (tester) async {
      // As wide as the label's own width at full size allows, less a tenth.
      await _pump(
        tester,
        FilledButton(onPressed: () {}, child: const Text('Magsimula na')),
        width: 400,
      );
      final natural = _label(tester, 'Magsimula na').size.width;
      await _pump(
        tester,
        FilledButton(onPressed: () {}, child: const Text('Magsimula na')),
        width: 64 + natural * 0.9,
      );
      final rp = _label(tester, 'Magsimula na');
      expect(_lines(rp), 1);
      expect(_drawnFont(rp), lessThan(16));
      expect(_drawnFont(rp), greaterThanOrEqualTo(13));
    });

    testWidgets('much too wide: wraps, centred, at full size', (tester) async {
      await _pump(
        tester,
        FilledButton(
          onPressed: () {},
          child: const Text('Magdagdag ng Bagong Profile'),
        ),
        width: 180,
      );
      final rp = _label(tester, 'Magdagdag ng Bagong Profile');
      expect(_lines(rp), greaterThanOrEqualTo(2));
      expect(_drawnFont(rp), closeTo(16, 0.01));
      expect(rp.textAlign, TextAlign.center);
    });

    testWidgets('large text wraps before it shrinks', (tester) async {
      await _pump(
        tester,
        FilledButton(onPressed: () {}, child: const Text('Magsimula na')),
        width: 200,
        textScale: 1.5,
      );
      final rp = _label(tester, 'Magsimula na');
      expect(_drawnFont(rp), closeTo(24, 0.01));
      expect(_lines(rp), 2);
    });

    testWidgets('never below the floor for a label that can wrap', (
      tester,
    ) async {
      await _pump(
        tester,
        FilledButton(
          onPressed: () {},
          child: const Text('Magdagdag ng Bagong Profile Ngayon Din'),
        ),
        width: 150,
      );
      final rp = _label(tester, 'Magdagdag ng Bagong Profile Ngayon Din');
      expect(_drawnFont(rp), greaterThanOrEqualTo(kMinReadableFontSize));
    });

    testWidgets('an icon button stays centred when its label wraps', (
      tester,
    ) async {
      await _pump(
        tester,
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded),
          label: const Text('Magdagdag ng Bagong Profile'),
        ),
        width: 240,
        textScale: 1.5,
      );
      final row = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Row),
        ),
      );
      final button = tester.renderObject<RenderBox>(find.byType(FilledButton));
      final rowCentre = row.localToGlobal(row.size.center(Offset.zero)).dx;
      final buttonCentre = button
          .localToGlobal(button.size.center(Offset.zero))
          .dx;
      expect((rowCentre - buttonCentre).abs(), lessThan(1));
    });
  });

  group('under a parent that asks intrinsic sizes', () {
    Widget measured(Widget child) => IntrinsicWidth(
      child: IntrinsicHeight(child: child),
    );

    testWidgets('a button in IntrinsicWidth and IntrinsicHeight', (
      tester,
    ) async {
      await _pump(
        tester,
        measured(
          FilledButton(
            onPressed: () {},
            child: const Text('Magdagdag ng Bagong Profile'),
          ),
        ),
        width: 180,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a button in a Wrap and a Row', (tester) async {
      await _pump(
        tester,
        Wrap(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Isa')),
              ],
            ),
          ],
        ),
        width: 180,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('a label that does its own fitting', () {
    testWidgets('a FitText inside a button does not assert', (tester) async {
      await _pump(
        tester,
        FilledButton(onPressed: () {}, child: const FitText('Magpatuloy')),
        width: 120,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Magpatuloy'), findsOneWidget);
    });

    testWidgets('and through an icon button too', (tester) async {
      await _pump(
        tester,
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded),
          label: const FitText('Magpatuloy'),
        ),
        width: 160,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('a paragraph with its own line limit', () {
    // The game result's hint: two lines allowed, three needed at the largest
    // Font Size. Its own limit cut it; AutoFit must make it smaller instead.
    testWidgets('is never cut at its limit', (tester) async {
      const hint = "You're learning! Review the words you missed.";
      await _pump(
        tester,
        const AutoFit(
          child: Text(
            hint,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ),
        width: 150,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      final rp = tester.renderObject<RenderParagraph>(find.text(hint));
      expect(rp.didExceedMaxLines, isFalse);
      _expectWholeWords(rp, hint);
    });

    testWidgets('and left alone when it fits', (tester) async {
      const hint = 'Well done!';
      await _pump(
        tester,
        const AutoFit(child: Text(hint, maxLines: 2)),
        width: 300,
      );
      expect(
        tester.renderObject<RenderAutoFit>(find.byType(AutoFit)).debugScale,
        1,
      );
    });
  });

  group('AutoFit around a label that may not wrap', () {
    Future<void> oneLine(WidgetTester tester, double width) => _pump(
      tester,
      const AutoFit(
        child: Text(
          'Lv.1 Beginner',
          maxLines: 1,
          style: TextStyle(fontSize: 16),
        ),
      ),
      width: width,
    );

    testWidgets('fits: untouched', (tester) async {
      await oneLine(tester, 300);
      expect(
        tester.renderObject<RenderAutoFit>(find.byType(AutoFit)).debugScale,
        1,
      );
    });

    testWidgets('does not fit: drawn smaller, still one line', (tester) async {
      await oneLine(tester, 60);
      expect(tester.takeException(), isNull);
      expect(
        tester.renderObject<RenderAutoFit>(find.byType(AutoFit)).debugScale,
        lessThan(1),
      );
    });
  });
}
