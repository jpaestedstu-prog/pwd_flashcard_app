import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/progress/widgets/charts/category_radar_chart.dart';
import 'package:pwdpwdpwd/features/progress/widgets/charts/star_pie_chart.dart';
import 'package:pwdpwdpwd/features/progress/widgets/charts/study_time_chart.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// The analytics charts are the one surface a Filipino teacher or parent reads
/// for evidence, and they were the last corner of the app still hardcoded to
/// English while everything around them — the app, the website, the Teacher's
/// Guide — shipped bilingual.
void main() {
  Widget host(Widget child, Locale locale) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('chart titles follow the locale', (tester) async {
    await tester.pumpWidget(
      host(const StarPieChart(totalStars: 10, spentStars: 4), const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Stars Overview'), findsOneWidget);

    await tester.pumpWidget(
      host(
        const StarPieChart(totalStars: 10, spentStars: 4),
        const Locale('fil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bituin'), findsOneWidget);
    expect(find.textContaining('Stars Overview'), findsNothing);
  });

  testWidgets('radar chart headings follow the locale', (tester) async {
    // The axis labels themselves are painted to canvas by fl_chart, not built
    // as Text widgets, so they cannot be found by the widget finder — the
    // structural guard at the bottom is what protects those. The card's own
    // heading and subtitle are real widgets and are asserted here.
    final progress = {
      for (final c in FlashcardCategory.values) c.label: 0.5,
    };

    await tester.pumpWidget(
      host(CategoryRadarChart(categoryProgress: progress), const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Category Mastery'), findsOneWidget);

    await tester.pumpWidget(
      host(CategoryRadarChart(categoryProgress: progress), const Locale('fil')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Kategorya'), findsOneWidget);
    expect(find.textContaining('Category Mastery'), findsNothing);
  });

  testWidgets('axis units follow the locale', (tester) async {
    await tester.pumpWidget(
      host(
        const StudyTimeChart(dailyMinutes: {'2026-08-15': 20}),
        const Locale('fil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Oras ng Pag-aaral'), findsOneWidget);
  });

  test('no chart widget carries a hardcoded English sentence', () {
    // A cheap structural guard: the charts should reach their words through
    // `l10n.`, so a new hardcoded title is caught here rather than by a
    // Filipino reader six months from now.
    final dir = Directory('lib/features/progress/widgets/charts');
    final offenders = <String>[];

    // Literals that are pure punctuation, interpolation or short symbols are
    // not prose and are allowed to stay inline.
    final prose = RegExp(r"'[A-Z][a-z]+ [a-z]{3,}[^']*'");

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (trimmed.startsWith('import ')) continue;
        final match = prose.firstMatch(line);
        if (match != null) {
          offenders.add('${file.uri.pathSegments.last}: ${match.group(0)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these chart strings never reach a Filipino reader:\n'
          '${offenders.join('\n')}',
    );
  });
}
