import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/widgets/app_bar_title.dart';

import 'support/real_fonts.dart';

/// An app bar lays its title out with no limit on its height, so a title on
/// two lines at the largest Font Size ran out of the bar and was cut off at
/// its edge ("Spelling Bee • 1/10" on a phone, 8 Nov). AppBarTitle tells
/// FitText the bar's height.
void main() {
  setUpAll(loadRealFonts);

  for (final title in [
    'Spelling Bee  •  1/10',
    'Mga Landas ng Pagkatuto',
    'Pagsusulit: Isang Araw sa Bukid',
  ]) {
    testWidgets('"$title" stays whole and inside the bar at 1.5x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.pause)),
              ],
              title: AppBarTitle(title),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final rp = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(AppBarTitle),
          matching: find.byType(RichText),
        ),
      );
      expect(rp.didExceedMaxLines, isFalse, reason: 'cut with "…"');
      final text = MatrixUtils.transformRect(
        rp.getTransformTo(null),
        Offset.zero & rp.size,
      );
      final bar = tester.getRect(find.byType(AppBar));
      expect(text.top, greaterThanOrEqualTo(bar.top - 0.5));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
    });
  }
}
