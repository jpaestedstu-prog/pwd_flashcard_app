import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/daily_challenge.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// Midnight with Home open: the Daily Challenge shows the new day's word.
///
/// The card picked its word once, when Home was built. A classroom tablet left
/// on Home overnight kept yesterday's word, already answered, until Home was
/// opened again, and an answer then counted for today with yesterday's
/// question. The app moves [currentDayProvider] at midnight; Home follows it.
final _today = StateProvider<DateTime>((ref) => DateTime(2026, 11, 9));

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('home_new_day');
  });
  tearDown(() => DailyChallenge.debugTodaysWords = null);

  testWidgets('a new day brings a new Daily Challenge word', (tester) async {
    tester.view.physicalSize = const Size(686, 1097);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = SeedData.allFlashcards
        .where((c) => c.wordEnglish.length > 3)
        .toList();
    final yesterday = cards.first;
    final today = cards.firstWhere(
      (c) => c.wordEnglish != yesterday.wordEnglish,
    );

    DailyChallenge.debugTodaysWords = [yesterday];
    final container = ProviderContainer(
      overrides: [
        sweepProfileOverride(UserRole.student),
        currentDayProvider.overrideWith((ref) => ref.watch(_today)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(yesterday.wordEnglish), findsWidgets,
        reason: "the day's word is shown");

    // Midnight.
    DailyChallenge.debugTodaysWords = [today];
    container.read(_today.notifier).state = DateTime(2026, 11, 10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(today.wordEnglish), findsWidgets,
        reason: "the new day's word, without leaving Home");
    expect(find.text(yesterday.wordEnglish), findsNothing,
        reason: "yesterday's word is gone");

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose(); // its providers' timers go with it
    await tester.pump(const Duration(minutes: 1));
  });
}
