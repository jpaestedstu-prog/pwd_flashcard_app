import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/daily_challenge.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/daily_challenge/screens/daily_challenge_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/word_of_day/services/word_of_day_service.dart';
import 'package:pwdpwdpwd/features/word_of_day/screens/word_of_day_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/all_screens.dart';
import 'support/readability.dart';
import 'support/real_fonts.dart';

/// A day's words change at midnight, and a word too long for its button only
/// fails on its own day: at 00:00 on 5 Nov "Magandang" broke into "Magandan / g"
/// in the middle of a test run. So every word, on the worst screen for it, not
/// just today's.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('every_daily_word_fits');
  });
  tearDown(() => DailyChallenge.debugTodaysWords = null);

  _everyWord();
}

void _everyWord() {
  Future<void> pump(WidgetTester tester, Widget screen, String locale) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sweepProfileOverride(UserRole.student)],
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> check(WidgetTester tester, Widget screen, int count) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = SeedData.allFlashcards.toList()
      ..sort((a, b) => b.wordFilipino.length.compareTo(a.wordFilipino.length));
    final problems = <String>[];
    for (final card in cards.take(count)) {
      DailyChallenge.debugTodaysWords = [card];
      for (final locale in const ['en', 'fil']) {
        await pump(tester, screen, locale);
        for (final issue in findReadabilityIssues(tester)) {
          problems.add('$locale ${card.wordFilipino}: $issue');
        }
        final error = tester.takeException();
        if (error != null) problems.add('$locale ${card.wordFilipino}: $error');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pump(const Duration(minutes: 1));
    expect(problems, isEmpty);
  }

  testWidgets('every Word of the Day keeps its words whole', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => WordOfDayService.debugCardIndex = null);

    final problems = <String>[];
    for (var i = 0; i < SeedData.allFlashcards.length; i++) {
      WordOfDayService.debugCardIndex = i;
      for (final locale in const ['en', 'fil']) {
        await pump(tester, const WordOfDayScreen(), locale);
        for (final issue in findReadabilityIssues(tester)) {
          problems.add('$locale $i: $issue');
        }
        final error = tester.takeException();
        if (error != null) problems.add('$locale $i: $error');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pump(const Duration(minutes: 1));
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('every word in the Daily Mission keeps its words whole',
      (tester) async {
    await check(tester, const DailyChallengeScreen(), 1000);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('the longest words in Home\'s Daily Challenge keep theirs whole',
      (tester) async {
    await check(tester, const HomeScreen(), 12);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
