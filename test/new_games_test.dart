import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/games/screens/first_letter_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/odd_one_out_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/yes_or_no_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// Round-generation and interaction contracts for the three games added so
/// that every accessibility category can be offered a full roster of ten.
///
/// Each test stops well before the final round, so no result is ever written
/// to Hive from inside `testWidgets`.

final _letter = RegExp(r'^[A-Z]$');

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Every string currently painted on screen.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

/// The score shown in the app bar badge.
int _score(WidgetTester tester) {
  final digits = _texts(tester).where((t) => int.tryParse(t) != null);
  return digits.isEmpty ? -1 : int.parse(digits.first);
}

/// Clears the pending "advance to next round" timer so the test can end.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/new_games');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('Yes or No', () {
    testWidgets('offers exactly two answers, Yes always before No',
        (tester) async {
      await _pump(tester, const YesOrNoScreen(difficulty: GameDifficulty.easy));

      // The stable left/right placement is the accessibility promise of this
      // game: the target never moves between rounds, so a learner with limited
      // motor control can commit to a position. Check it holds across rounds,
      // not just on the first.
      for (var round = 0; round < 3; round++) {
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
        final texts = _texts(tester);
        expect(
          texts.indexOf('Yes'),
          lessThan(texts.indexOf('No')),
          reason: 'Yes must stay on the left in round ${round + 1}',
        );

        await tester.tap(find.text('Yes'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1300));
      }

      await _settle(tester);
    });

    testWidgets('asks about a real vocabulary word', (tester) async {
      await _pump(tester, const YesOrNoScreen(difficulty: GameDifficulty.easy));

      final words = {for (final c in SeedData.allFlashcards) c.wordEnglish};
      expect(
        _texts(tester).any(words.contains),
        isTrue,
        reason: 'the prompt must name a word from the deck',
      );

      await _settle(tester);
    });
  });

  group('Odd One Out', () {
    testWidgets('easy shows three words, exactly one from another category',
        (tester) async {
      await _pump(
        tester,
        const OddOneOutScreen(difficulty: GameDifficulty.easy),
      );

      expect(find.text('Which one does not belong?'), findsOneWidget);

      final byWord = {
        for (final c in SeedData.allFlashcards) c.wordEnglish: c.category,
      };
      final shown = _texts(tester).where(byWord.containsKey).toSet().toList();
      expect(shown.length, 3);

      // Exactly one word must sit outside the shared category — otherwise the
      // question has two defensible answers.
      final counts = <FlashcardCategory, int>{};
      for (final w in shown) {
        counts[byWord[w]!] = (counts[byWord[w]] ?? 0) + 1;
      }
      expect(counts.length, 2);
      expect(counts.values.toList()..sort(), [1, 2]);

      await _settle(tester);
    });

    testWidgets('medium shows four words and scores the odd one correct',
        (tester) async {
      // Medium is the default difficulty.
      await _pump(tester, const OddOneOutScreen());

      final byWord = {
        for (final c in SeedData.allFlashcards) c.wordEnglish: c.category,
      };
      final shown = _texts(tester).where(byWord.containsKey).toSet().toList();
      expect(shown.length, 4);

      final counts = <FlashcardCategory, int>{};
      for (final w in shown) {
        counts[byWord[w]!] = (counts[byWord[w]] ?? 0) + 1;
      }
      final oddCategory =
          counts.entries.firstWhere((e) => e.value == 1).key;
      final odd = shown.firstWhere((w) => byWord[w] == oddCategory);

      expect(_score(tester), 0);
      await tester.tap(find.text(odd).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_score(tester), 1, reason: 'the odd word must be the right answer');

      await _settle(tester);
    });

    testWidgets('hard drops the category hint', (tester) async {
      await _pump(
        tester,
        const OddOneOutScreen(difficulty: GameDifficulty.hard),
      );

      expect(find.text('Which one does not belong?'), findsOneWidget);
      expect(
        _texts(tester).any((t) => t.startsWith('3 are ')),
        isFalse,
        reason: 'the hint belongs to Easy only',
      );

      await _settle(tester);
    });
  });

  group('First Letter', () {
    testWidgets('easy offers two letters, one of them the right one',
        (tester) async {
      await _pump(
        tester,
        const FirstLetterScreen(difficulty: GameDifficulty.easy),
      );

      final letters =
          _texts(tester).where((t) => _letter.hasMatch(t)).toList();
      expect(letters.length, 2);
      expect(letters.toSet().length, 2, reason: 'no repeated letter');
      expect(
        letters,
        orderedEquals(letters.toList()..sort()),
        reason: 'letters are shown in alphabetical order',
      );

      await _settle(tester);
    });

    testWidgets('scores the word\'s own first letter as correct',
        (tester) async {
      // Medium is the default difficulty.
      await _pump(tester, const FirstLetterScreen());

      final words = {for (final c in SeedData.allFlashcards) c.wordEnglish};
      final texts = _texts(tester);
      final word = texts.firstWhere(words.contains);
      final expected = word[0].toUpperCase();

      final letters = texts.where((t) => _letter.hasMatch(t)).toList();
      expect(letters.length, 4);
      expect(letters, contains(expected));

      expect(_score(tester), 0);
      await tester.tap(find.text(expected).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_score(tester), 1);

      await _settle(tester);
    });

    testWidgets('hard offers six letters, all of them on screen',
        (tester) async {
      await _pump(
        tester,
        const FirstLetterScreen(difficulty: GameDifficulty.hard),
      );

      final letters = _texts(tester).where((t) => _letter.hasMatch(t)).toList();
      expect(letters.length, 6);
      // A non-scrolling grid clips rows that don't fit instead of reporting an
      // overflow, so the overflow matrix can't see this: six tiles once laid
      // out three rows deep and put the last two past the bottom edge, where
      // they could never be tapped.
      _expectAllOnScreen(tester, letters);

      await _settle(tester);
    });
  });

  group('answer buttons stay reachable', () {
    testWidgets('Odd One Out keeps all four choices on screen',
        (tester) async {
      await _pump(tester, const OddOneOutScreen());

      final byWord = {
        for (final c in SeedData.allFlashcards) c.wordEnglish: c.category,
      };
      final shown = _texts(tester).where(byWord.containsKey).toSet().toList();
      expect(shown.length, 4);
      _expectAllOnScreen(tester, shown);

      await _settle(tester);
    });

    testWidgets('Yes or No keeps both buttons on screen', (tester) async {
      await _pump(tester, const YesOrNoScreen(difficulty: GameDifficulty.hard));
      _expectAllOnScreen(tester, ['Yes', 'No']);

      await _settle(tester);
    });
  });
}

/// Fails if any of [labels] is laid out beyond the visible surface.
void _expectAllOnScreen(WidgetTester tester, List<String> labels) {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final label in labels) {
    final rect = tester.getRect(find.text(label).first);
    expect(
      rect.bottom <= screen.height && rect.top >= 0,
      isTrue,
      reason: '"$label" is off-screen (${rect.top}–${rect.bottom} '
          'vs 0–${screen.height})',
    );
  }
}
