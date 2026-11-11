import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/fit_text.dart';

import 'support/real_fonts.dart';

/// [FitText] in the app's own fonts: whole words, and the whole text, rather
/// than "…".
///
/// Found at the largest Font Size (1.5x) in Filipino (30 Oct): it checked only
/// that the longest word fitted a line, so "Mga Salita" was cut to "Mga Sal…"
/// in one line and the Games hub's descriptions after three.
void main() {
  setUpAll(loadRealFonts);

  const style = TextStyle(fontFamily: 'Nunito_regular', fontSize: 14);

  Future<RenderParagraph> pump(
    WidgetTester tester,
    String text, {
    required double width,
    int? maxLines = 2,
    double scale = 1.5,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              child: FitText(text, style: style, maxLines: maxLines),
            ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.byType(RichText));
  }

  double sizeOf(RenderParagraph rp) => rp.text.style!.fontSize!;

  testWidgets('a label that fits keeps its size', (tester) async {
    final rp = await pump(tester, 'Words', width: 300, maxLines: 1);
    expect(sizeOf(rp), 14);
    expect(rp.didExceedMaxLines, isFalse);
  });

  testWidgets('one line too short for the label: smaller, not cut',
      (tester) async {
    final rp = await pump(tester, 'Mga Salita', width: 100, maxLines: 1);
    expect(sizeOf(rp), lessThan(14));
    expect(rp.didExceedMaxLines, isFalse);
  });

  testWidgets('two lines too short for the text: smaller, not cut',
      (tester) async {
    final rp = await pump(tester, 'Lubos na Hindi Sang-ayon', width: 120);
    expect(sizeOf(rp), lessThan(14));
    expect(rp.didExceedMaxLines, isFalse);
  });

  testWidgets('its font never goes below the floor', (tester) async {
    final rp = await pump(
      tester,
      'Ayusin ang mga letra para mabaybay ang salita!',
      width: 60,
      maxLines: 3,
    );
    expect(sizeOf(rp), closeTo(14 * 0.7, 0.001));
  });

  testWidgets('one line past the floor: the whole label, scaled to fit',
      (tester) async {
    final rp = await pump(tester, 'Nasasabik', width: 30, maxLines: 1);
    expect(sizeOf(rp), closeTo(14 * 0.7, 0.001));
    expect(rp.didExceedMaxLines, isFalse);
    expect(
      find.ancestor(of: find.byType(RichText), matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(30));
  });

  // Two lines past the floor used to wrap at the floor, splitting the word
  // that did not fit: "Kamak / ailang" and "Experi / ment" at 2x (3 Nov).
  testWidgets('two lines past the floor: every word whole, drawn smaller',
      (tester) async {
    const text = 'Mga Kamakailang Mag-aaral';
    final rp = await pump(tester, text, width: 70, scale: 2.0);
    expect(rp.didExceedMaxLines, isFalse);
    expect(sizeOf(rp), closeTo(14 * 0.5, 0.001), reason: 'the floor at 2x');
    // Laid out at least as wide as its longest word, at its own size.
    final word = TextPainter(
      text: TextSpan(text: 'Kamakailang', style: rp.text.style),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(2.0),
    )..layout();
    expect(rp.size.width, greaterThanOrEqualTo(word.width));
    word.dispose();
    expect(tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(70), reason: 'and drawn within its column');
  });

  // The search for that width once never ended in a column of a fractional
  // width (a deep-scroll test hung on it, 4 Nov).
  testWidgets('and it settles in any column, whole or fractional',
      (tester) async {
    for (final width in [70.4, 81.7, 99.99, 120.5, 151.3]) {
      final rp = await pump(
        tester,
        'Ayusin ang mga letra para mabaybay ang salita!',
        width: width,
        scale: 2.0,
      );
      expect(rp.didExceedMaxLines, isFalse, reason: 'at $width px');
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a paragraph is never shrunk for its length', (tester) async {
    final rp = await pump(
      tester,
      'Ayusin ang mga letra para mabaybay ang salita!',
      width: 200,
      maxLines: null,
    );
    expect(sizeOf(rp), 14);
  });
}
