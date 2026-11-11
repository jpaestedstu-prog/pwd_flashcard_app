import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/widgets/beside_or_below.dart';
import 'package:pwdpwdpwd/core/widgets/fit_label.dart';
import 'package:pwdpwdpwd/core/widgets/fit_text.dart';

import 'support/real_fonts.dart';

/// The three ways a text was cut on a phone at the largest Font Size (the
/// survey of 3 Nov): a greeting squeezed between buttons, a field's label,
/// and a field's hint.
const _long = 'Kumusta, Josefina Maria Dela Cruz-Reyes! 👋';
const _style = TextStyle(fontSize: 26, fontWeight: FontWeight.w700);

Widget _app(Widget child, {double scale = 1.5, double width = 360}) =>
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 640),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

/// The greeting row as Home builds it: the learner's picture, the
/// greeting, and two buttons.
Widget _header(String greeting) => Builder(
      builder: (context) => BesideOrBelow(
        fits: FitText.measurer(context, greeting, style: _style, maxLines: 3),
        leading: const SizedBox(key: Key('face'), width: 56, height: 56),
        title: FitText(
          greeting,
          key: const Key('greeting'),
          style: _style,
          maxLines: 3,
        ),
        trailing: const SizedBox(key: Key('buttons'), width: 96, height: 48),
      ),
    );

/// Every paragraph that was cut short.
List<String> _cut(WidgetTester tester) => [
      for (final p in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      ))
        if (p.didExceedMaxLines) p.text.toPlainText(),
    ];

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a short greeting stays beside the buttons', (tester) async {
    await tester.pumpWidget(_app(_header('Hi, Ana! 👋'), scale: 1.0));
    final row = tester.renderObject<RenderBesideOrBelow>(
      find.byType(BesideOrBelow),
    );
    expect(row.titleBeside, isTrue);
    final face = tester.getRect(find.byKey(const Key('face')));
    final greeting = tester.getRect(find.byKey(const Key('greeting')));
    expect(greeting.left, face.right + 12);
    expect(greeting.top, lessThan(face.bottom), reason: 'on the same row');
    expect(_cut(tester), isEmpty);
  });

  testWidgets('a long name goes under them, whole, on a phone at 1.5x',
      (tester) async {
    await tester.pumpWidget(_app(_header(_long)));
    final row = tester.renderObject<RenderBesideOrBelow>(
      find.byType(BesideOrBelow),
    );
    expect(row.titleBeside, isFalse);
    final face = tester.getRect(find.byKey(const Key('face')));
    final buttons = tester.getRect(find.byKey(const Key('buttons')));
    final greeting = tester.getRect(find.byKey(const Key('greeting')));
    expect(greeting.top, greaterThanOrEqualTo(face.bottom));
    expect(greeting.width, 360, reason: 'the width of the screen');
    expect(buttons.right, 360, reason: 'the buttons stay at the end');
    expect(_cut(tester), isEmpty);
  });

  testWidgets('and back beside them on a tablet', (tester) async {
    await tester.pumpWidget(_app(_header(_long), width: 800));
    expect(
      tester
          .renderObject<RenderBesideOrBelow>(find.byType(BesideOrBelow))
          .titleBeside,
      isTrue,
    );
    expect(_cut(tester), isEmpty);
  });

  testWidgets('a badge goes under a heading that needs the room',
      (tester) async {
    const title = 'Mapa ng Aktibidad sa Pagbabalik-aral';
    await tester.pumpWidget(_app(Builder(
      builder: (context) => BesideOrBelow(
        fits: FitText.measurer(context, title),
        drop: BesideOrBelowSlot.trailing,
        gap: 8,
        trailingGap: 8,
        leading: const SizedBox(key: Key('icon'), width: 22, height: 22),
        title: const FitText(title, key: Key('title')),
        trailing: const Text('12 aktibong araw', key: Key('badge')),
      ),
    ), width: 240));
    final icon = tester.getRect(find.byKey(const Key('icon')));
    final heading = tester.getRect(find.byKey(const Key('title')));
    final badge = tester.getRect(find.byKey(const Key('badge')));
    expect(heading.left, icon.right + 8, reason: 'the heading by its icon');
    expect(badge.top, greaterThan(heading.top), reason: 'the badge under it');
    expect(badge.left, heading.left, reason: 'lined up with the heading');
    expect(_cut(tester), isEmpty);
  });

  testWidgets('the measurer agrees with what FitText draws', (tester) async {
    late bool Function(double) fits;
    for (final width in [80.0, 120.0, 160.0, 240.0, 400.0]) {
      await tester.pumpWidget(_app(
        Builder(builder: (context) {
          fits = FitText.measurer(context, _long, style: _style, maxLines: 3);
          // Aligned, so that the box is as narrow as it says.
          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const FitText(_long, style: _style, maxLines: 3),
            ),
          );
        }),
      ));
      final drawn = tester.renderObject<RenderParagraph>(find.byType(RichText));
      // Whole at every width: where even its smallest size does not fit,
      // FitText draws it smaller as a whole rather than cut or split.
      expect(drawn.didExceedMaxLines, isFalse, reason: 'at $width px');
      final scaled = find
          .descendant(of: find.byType(FitText), matching: find.byType(FittedBox))
          .evaluate()
          .isNotEmpty;
      expect(fits(width), !scaled, reason: 'at $width px');
    }
  });

  group('a field', () {
    Widget field({String? label, String? hint, double width = 200}) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TextField(
              decoration: InputDecoration(
                label: label == null ? null : FitLabel(label),
                hintText: hint,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: const Icon(Icons.visibility),
              ),
            ),
          ),
        );

    /// The box the label is drawn in: scaled down, or not.
    RenderFittedBox labelBox(WidgetTester tester) =>
        tester.renderObject<RenderFittedBox>(find.byType(FitLabel));

    testWidgets('label is whole, smaller, where the field is narrow',
        (tester) async {
      await tester.pumpWidget(_app(field(label: 'Kumpirmahin ang password')));
      expect(_cut(tester), isEmpty);
      final label = tester.getRect(find.text('Kumpirmahin ang password'));
      final box = tester.getRect(find.byType(TextField));
      expect(label.right, lessThanOrEqualTo(box.right),
          reason: 'drawn inside the field');
      final fitted = labelBox(tester);
      expect(fitted.size.width, lessThan(fitted.child!.size.width),
          reason: 'scaled down to fit');
    });

    testWidgets('label is at full size where it fits', (tester) async {
      await tester.pumpWidget(_app(field(label: 'PIN', width: 300)));
      final fitted = labelBox(tester);
      final child = fitted.child!;
      expect(fitted.size.width, closeTo(child.size.width, 0.01),
          reason: 'not scaled');
    });

    testWidgets('label can sit in a dialog, which measures it first',
        (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              content: field(label: 'Kumpirmahin ang password', width: 180),
            ),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_cut(tester), isEmpty);
    });

    testWidgets('hint wraps rather than being cut', (tester) async {
      // A search field on a phone, between its two icons.
      await tester.pumpWidget(
        _app(field(hint: 'Maghanap ng mag-aaral...', width: 240)),
      );
      expect(_cut(tester), isEmpty);
      final hint = tester.renderObject<RenderParagraph>(
        find.text('Maghanap ng mag-aaral...'),
      );
      expect(hint.maxLines, greaterThan(1));
    });
  });
}
