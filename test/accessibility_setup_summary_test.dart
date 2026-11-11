import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/accessibility_setup_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// Accessibility Setup's summary step ("Recommended Settings").
///
/// Its sentence was English on a Filipino screen, and a screen reader said the
/// learner's type twice in a row: in the sentence, then on the badge under it
/// (found by the reader crawl, 9 Nov). The sentence is translated now and the
/// badge, which only repeats the type, is not read; for "no needs" the sentence
/// doesn't name the type, so there the badge is still read.

/// Every label a screen reader can land on, in tree order.
List<String> _spoken(WidgetTester tester) {
  final out = <String>[];
  bool visit(SemanticsNode node) {
    if (node.label.isNotEmpty) out.add(node.label);
    node.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return out;
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('accessibility_setup_summary');
  });

  Future<void> openSummary(
    WidgetTester tester,
    AppLocalizations l10n,
    String language,
    DisabilityType type,
  ) async {
    tester.view.physicalSize = const Size(686, 1097);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sweepProfileOverride(UserRole.student)],
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccessibilitySetupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final card = find.text(type.labelOf(l10n));
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(card);
    await tester.pump();
    final next = find.text(l10n.continueButton);
    await tester.ensureVisible(next);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(next);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l10n.recommendedSettings), findsOneWidget,
        reason: 'on the summary step');
  }

  Future<void> closeUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final language in const ['en', 'fil']) {
    testWidgets('$language: the sentence in the screen language, the type '
        'said once', (tester) async {
      final semantics = tester.ensureSemantics();
      final l10n = lookupAppLocalizations(Locale(language));
      await openSummary(tester, l10n, language, DisabilityType.visual);

      final name = DisabilityType.visual.labelOf(l10n);
      final sentence = l10n.weWillApplySettings(name);
      expect(find.text(sentence), findsOneWidget,
          reason: 'the sentence, in ${language == 'fil' ? 'Filipino' : 'English'}');
      final spoken = _spoken(tester);
      expect(spoken, contains(sentence),
          reason: 'a screen reader reads the sentence');
      expect(spoken.where((l) => l == name), isEmpty,
          reason: 'and not the badge under it, which only repeats "$name": '
              '$spoken');

      await closeUp(tester);
      semantics.dispose();
    });
  }

  testWidgets('"no needs": the badge still says the type', (tester) async {
    final semantics = tester.ensureSemantics();
    final l10n = lookupAppLocalizations(const Locale('en'));
    await openSummary(tester, l10n, 'en', DisabilityType.none);

    final name = DisabilityType.none.labelOf(l10n);
    final spoken = _spoken(tester);
    expect(spoken, contains(l10n.asNoSpecial),
        reason: 'the sentence, which does not name the type');
    expect(spoken, contains(name),
        reason: 'so the badge says "$name": $spoken');

    await closeUp(tester);
    semantics.dispose();
  });
}
