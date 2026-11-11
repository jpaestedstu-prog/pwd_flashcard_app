import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/widgets/pro_surface.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/progress_section_header.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/shared_widgets.dart';

import 'support/all_screens.dart';

/// A screen reader can jump from section to section.
///
/// A person using a screen reader moves through a long screen by its
/// headings. With NVDA on the web app, "next heading" found only the greeting
/// on Home, and "no next heading" after it (4 Nov): "Daily Challenge", "Play
/// & Learn" and the rest looked like headings and were not marked as ones.
void main() {
  setUpAll(() => openSweepBoxes('section_headings'));
  tearDownAll(closeSweepBoxes);

  /// Every heading a screen reader is told about on the screen.
  List<String> headingsOf(WidgetTester tester) {
    final found = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.flagsCollection.isHeader && data.label.trim().isNotEmpty) {
        found.add(data.label.trim());
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    return found;
  }

  Widget app(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('the shared section titles are headings', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const Column(
      children: [
        SectionHeader(title: 'Play & Learn'),
        ProgressSectionHeader(title: 'Mastery'),
        ProSectionHeader(title: 'Mga Klase'),
      ],
    )));
    await tester.pump();
    expect(
      headingsOf(tester),
      containsAll(['Play & Learn', 'Mastery', 'Mga Klase']),
    );
    semantics.dispose();
  });

  testWidgets('a title drawn in capitals is told in its own spelling',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const ProSectionHeader(title: 'Mga Klase')));
    await tester.pump();
    expect(find.text('MGA KLASE'), findsOneWidget, reason: 'drawn in capitals');
    expect(headingsOf(tester), ['Mga Klase']);
    semantics.dispose();
  });

  // Each hub a learner or an educator lands on, and how many sections it has
  // at the very least, on a screen tall enough to build them.
  const hubs = {
    'HomeScreen': 3,
    'EducatorHomeScreen': 2,
    'DeckListScreen': 1,
    'GameHubScreen': 1,
    'StoryListScreen': 1,
    'ProgressScreen': 2,
    'SettingsScreen': 3,
  };
  for (final hub in hubs.entries) {
    testWidgets('${hub.key} has headings to jump between', (tester) async {
      final (build, role) = kAllScreens[hub.key]!;
      final semantics = tester.ensureSemantics();
      const size = Size(1200, 4000);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [sweepProfileOverride(role)],
        child: app(build()),
      ));
      for (var t = 0; t < 25; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final headings = headingsOf(tester);
      expect(headings.length, greaterThanOrEqualTo(hub.value),
          reason: '${hub.key}: $headings');
      for (var t = 0; t < 30; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      semantics.dispose();
    });
  }
}
