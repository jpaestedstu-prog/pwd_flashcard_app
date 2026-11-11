import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/ai_tutor/screens/ai_tutor_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// A chip tapped twice before the AI Tutor has answered asks once.
///
/// A hand that shakes taps twice. The tutor answered both — two topic pickers
/// under two "Favorites" bubbles, which a screen reader read out twice in a
/// row (the reader crawl, 9 Nov). Asked again once the tutor has answered, the
/// question is a new one, and it is sent.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('tutor_double_tap');
  });

  testWidgets('a double tap on a chip asks once', (tester) async {
    tester.view.physicalSize = const Size(686, 1097);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sweepProfileOverride(UserRole.student)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiTutorScreen(),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The chip's own label, then one more for each "Favorites" bubble.
    final favorites = find.text('Favorites');
    expect(favorites, findsOneWidget, reason: 'the chip, nothing asked yet');
    final chip = favorites.first;

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(chip);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(favorites, findsNWidgets(2),
        reason: 'the chip and one question: the second tap came before the '
            'answer');

    // Answered: the same chip again is a new question.
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(chip);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(favorites, findsNWidgets(3),
        reason: 'asked again after the answer, it is asked');
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .controller
          ?.text,
      isEmpty,
      reason: 'nothing left typed in the box',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
