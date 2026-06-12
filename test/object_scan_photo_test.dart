import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/object_scan/models/object_scan_models.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/photo_results_panel.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/screen_matrix.dart';

WordMatch _match(String english, double confidence) => WordMatch(
      card: SeedData.allFlashcards
          .firstWhere((c) => c.wordEnglish == english),
      sourceLabel: english,
      confidence: confidence,
    );

Future<void> _pump(WidgetTester tester, PhotoResultsPanel panel) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: panel),
      ),
    ),
  );
}

void main() {
  testWidgets('shows large tappable cards for every found word',
      (tester) async {
    final matches = [
      _match('Television', 0.92),
      _match('Bottle', 0.81),
      _match('Book', 0.74),
    ];
    WordMatch? tapped;
    await _pump(
      tester,
      PhotoResultsPanel(
        matches: matches,
        searching: false,
        onWordTap: (m) => tapped = m,
        onRetake: () {},
      ),
    );
    await tester.pump();

    expect(find.text('I found these words — tap one!'), findsOneWidget);
    for (final m in matches) {
      expect(find.text(m.card.wordEnglish), findsOneWidget);
      expect(find.text(m.card.wordFilipino), findsOneWidget);
    }
    // PWD-friendly tap targets: each card is at least 72 dp tall.
    final cardSize = tester.getSize(
      find.ancestor(
        of: find.text('Television'),
        matching: find.byType(InkWell),
      ),
    );
    expect(cardSize.height, greaterThanOrEqualTo(72));

    await tester.tap(find.text('Bottle'));
    expect(tapped?.card.wordEnglish, 'Bottle');
  });

  testWidgets('empty result shows the friendly retry message and retake',
      (tester) async {
    var retaken = false;
    await _pump(
      tester,
      PhotoResultsPanel(
        matches: const [],
        searching: false,
        onWordTap: (_) {},
        onRetake: () => retaken = true,
      ),
    );
    await tester.pump();

    expect(
      find.text(
          "I couldn't find a word in this photo. Get closer and try again!"),
      findsOneWidget,
    );
    await tester.tap(find.text('New photo'));
    expect(retaken, isTrue);
  });

  testWidgets('searching state shows the looking indicator', (tester) async {
    await _pump(
      tester,
      PhotoResultsPanel(
        matches: const [],
        searching: true,
        onWordTap: (_) {},
        onRetake: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Looking at your photo…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('New photo'), findsNothing);
  });

  testWidgets('results panel survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: SingleChildScrollView(
          reverse: true,
          child: PhotoResultsPanel(
            matches: [
              _match('Television', 0.92),
              _match('Grandmother', 0.81),
              _match('Butterfly', 0.74),
            ],
            searching: false,
            onWordTap: (_) {},
            onRetake: () {},
          ),
        ),
      ),
    );
  });
}
