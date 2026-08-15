import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/object_scan/models/object_scan_models.dart';
import 'package:pwdpwdpwd/features/object_scan/screens/word_hunt_collection_screen.dart';
import 'package:pwdpwdpwd/features/object_scan/services/label_word_mapper.dart';
import 'package:pwdpwdpwd/features/object_scan/services/object_scan_discovery_service.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/hunt_target_strip.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/photo_results_panel.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// "My Finds" turns Word Hunt's previously invisible discovery log into the
/// feature's payoff: what you have collected, and what is still out there.
/// These tests pin the two things that make that honest — the denominator
/// ("words the camera knows", not the whole vocabulary) and the found /
/// not-found split — plus the NEW badge and hunt targets that carry the same
/// idea back onto the camera screen.

class _StubProgressNotifier extends ProgressNotifier {
  @override
  LearningProgress build() {
    profileId = 'p-collection';
    return LearningProgress(
      profileId: 'p-collection',
      lastActivityDate: DateTime(2026),
    );
  }

  @override
  void recordDailyActivity() {}
}

class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => null; // guest bucket, matching the seeded ids below
}

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(ttsEnabled: false);
}

class _FakeTtsService extends TtsService {
  final spoken = <String>[];
  @override
  Future<void> speakEnglish(String text) async => spoken.add(text);
  @override
  Future<void> speakFilipino(String text) async => spoken.add(text);
}

Flashcard _card(String id) =>
    SeedData.allFlashcards.firstWhere((c) => c.id == id);

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // The huntable vocabulary
  // ─────────────────────────────────────────────────────────────────────
  group('LabelWordMapper.huntableCards', () {
    test('every self-label resolves to a real seed card', () {
      final words = {
        for (final c in SeedData.allFlashcards) c.wordEnglish.toLowerCase(),
      };
      for (final label in LabelWordMapper.selfLabels) {
        expect(
          words.contains(label.toLowerCase()),
          isTrue,
          reason: 'selfLabel "$label" is not a seed word',
        );
      }
    });

    test('every huntable card is reachable from a camera label', () {
      // The whole point of the list: a target the camera can never produce
      // would be an impossible hunt.
      final reachable = {
        for (final key in LabelWordMapper.aliases.keys)
          LabelWordMapper.match(key)?.card.id,
        for (final label in LabelWordMapper.selfLabels)
          LabelWordMapper.match(label)?.card.id,
      };
      for (final card in LabelWordMapper.huntableCards) {
        expect(
          reachable.contains(card.id),
          isTrue,
          reason: '${card.wordEnglish} is huntable but no label maps to it',
        );
      }
    });

    test('is deduped and stays in seed order', () {
      final ids = LabelWordMapper.huntableCards.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate cards');

      final seedOrder = SeedData.allFlashcards.map((c) => c.id).toList();
      final positions = [for (final id in ids) seedOrder.indexOf(id)];
      expect(
        positions,
        orderedEquals([...positions]..sort()),
        reason: 'huntable cards should keep seed order',
      );
    });

    test('excludes vocabulary no camera can see', () {
      // Days, greetings and emotions are real words in the app but they are
      // not objects — counting them would make the collection unfinishable.
      for (final word in const ['Monday', 'Sorry', 'Proud', 'Hello', 'Seven']) {
        final card = SeedData.allFlashcards
            .firstWhere((c) => c.wordEnglish == word);
        expect(
          LabelWordMapper.isHuntable(card.id),
          isFalse,
          reason: '$word should not be a hunt target',
        );
      }
    });

    test('includes the everyday objects the feature was built around', () {
      for (final word in const ['Chair', 'Table', 'Cup', 'Dog', 'Shoes']) {
        final card = SeedData.allFlashcards
            .firstWhere((c) => c.wordEnglish == word);
        expect(LabelWordMapper.isHuntable(card.id), isTrue, reason: word);
      }
      // Big enough to be a collection, small enough to be finishable.
      expect(LabelWordMapper.huntableCards.length, greaterThan(30));
      expect(
        LabelWordMapper.huntableCards.length,
        lessThan(SeedData.allFlashcards.length),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // The collection screen
  // ─────────────────────────────────────────────────────────────────────
  group('WordHuntCollectionScreen', () {
    const storeDir = './build/test_cache/word_hunt_collection';

    setUpAll(() async {
      // Wipe any leftover store before Hive touches it: a run that died mid
      // test leaves a `.lock` behind that blocks the next `openBox`.
      final dir = Directory(storeDir);
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Held by another process — Hive will reuse it; the seeds below
          // overwrite whatever is in there anyway.
        }
      }
      Hive.init(storeDir);
      if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
    });

    tearDownAll(() async => Hive.deleteFromDisk());

    late _FakeTtsService tts;

    /// [discovered] is written through [WidgetTester.runAsync] because a Hive
    /// write *awaited inside* the FakeAsync zone never drains the box's write
    /// queue — the test simply hangs until the 10-minute timeout.
    Future<void> pumpScreen(
      WidgetTester tester, {
      List<String> discovered = const [],
      Map<String, Object>? streak,
      Map<String, Object>? findsToday,
    }) async {
      await tester.runAsync(() async {
        final box = Hive.box('progress');
        await box.put('object_scan_discoveries_guest', discovered);
        // Always write, so a streak seeded by an earlier test in this file
        // cannot leak into one that expects none.
        streak == null
            ? await box.delete('object_scan_streak_guest')
            : await box.put('object_scan_streak_guest', streak);
        findsToday == null
            ? await box.delete('object_scan_finds_day_guest')
            : await box.put('object_scan_finds_day_guest', findsToday);
      });
      // The service prefers its own session mirror over the box; drop it so
      // these raw seeds are what the screen reads.
      ObjectScanDiscoveryService.resetWriteCache();
      tts = _FakeTtsService();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const WordHuntCollectionScreen()),
          GoRoute(path: '/object-scan', builder: (_, _) => const Text('camera')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressProvider.overrideWith(_StubProgressNotifier.new),
            profileProvider.overrideWith(_StubProfileNotifier.new),
            settingsProvider.overrideWith(_StubSettingsNotifier.new),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // Two frames, not `pumpAndSettle`: the empty state's decorative rings
      // animate forever, so settling would never return. The second pump
      // flushes flutter_animate's zero-duration start timers.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Unmounts so the empty state's repeating tickers are disposed before the
    /// test ends.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets('with nothing found it counts zero and invites a hunt',
        (tester) async {
      await pumpScreen(tester);

      final total = LabelWordMapper.huntableCards.length;
      expect(find.text('0 of $total words found'), findsOneWidget);
      expect(
        find.textContaining("haven't found any words yet"),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('counts the found words and splits them from the rest',
        (tester) async {
      await pumpScreen(tester, discovered: const ['cr13', 'f14']);

      final total = LabelWordMapper.huntableCards.length;
      expect(find.text('2 of $total words found'), findsOneWidget);
      // Categories with a find sort to the top, so Cup's section is on screen
      // straight away; every category also lists what is still out there.
      expect(find.text('Cup'), findsOneWidget);
      expect(find.text('Still to find'), findsWidgets);
      // Table's section is the other one with a find — reachable by scrolling
      // rather than buried at the bottom of the untouched categories.
      await tester.scrollUntilVisible(
        find.text('Table'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Table'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the daily camera-star budget is visible', (tester) async {
      await pumpScreen(tester, discovered: const ['cr13']);
      expect(
        find.text('0 of ${ObjectScanDiscoveryService.dailyStarCap} '
            'camera stars today'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets("shows the hunt streak and today's tally when there is one",
        (tester) async {
      final today = DateTime.now();
      String dayKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}'
          '-${d.day.toString().padLeft(2, '0')}';
      await pumpScreen(
        tester,
        discovered: const ['cr13', 'f14'],
        streak: {'lastDay': dayKey(today), 'streak': 4},
        findsToday: {'day': dayKey(today), 'count': 2},
      );

      expect(find.text('4-day hunt streak'), findsOneWidget);
      expect(find.text('2 found today'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('nudges toward the next badge with the real remaining count',
        (tester) async {
      // 2 found, so the next rung is Word Spotter at 10 → 8 to go.
      await pumpScreen(tester, discovered: const ['cr13', 'f14']);
      expect(
        find.text('8 more to unlock ${huntFindMilestones[1].title}'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('hides the streak chip when the streak is broken',
        (tester) async {
      await pumpScreen(
        tester,
        discovered: const ['cr13'],
        // Last find three days ago — the streak is over, so no chip.
        streak: const {'lastDay': '2020-01-01', 'streak': 9},
      );
      expect(find.textContaining('hunt streak'), findsNothing);
      await unmount(tester);
    });

    testWidgets('tapping a found word reopens its discovery sheet',
        (tester) async {
      await pumpScreen(tester, discovered: const ['cr13']);

      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // The sheet's own bridges are back — this is a full revisit, not a
      // read-only list.
      expect(find.text('Spelling Bee'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a discovery is never re-logged from the collection',
        (tester) async {
      await pumpScreen(tester, discovered: const ['cr13']);
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // No "+1 ⭐" banner: revisiting is not a new find, so no star.
      expect(find.textContaining('New word found'), findsNothing);
      expect(
        ObjectScanDiscoveryService.starsAwardedToday(null),
        0,
        reason: 'browsing the collection must not award stars',
      );
      await unmount(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // NEW badge + hunt targets on the camera screen
  // ─────────────────────────────────────────────────────────────────────
  group('PhotoResultsPanel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required List<WordMatch> matches,
      Set<String> newWordIds = const {},
      List<Flashcard> targets = const [],
      List<Flashcard> targetsHit = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PhotoResultsPanel(
                matches: matches,
                searching: false,
                newWordIds: newWordIds,
                targets: targets,
                targetsHit: targetsHit,
                onWordTap: (_) {},
                onRetake: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    WordMatch match(String id) =>
        WordMatch(card: _card(id), sourceLabel: 'x', confidence: 1);

    testWidgets('badges only the words the learner has never collected',
        (tester) async {
      await pumpPanel(
        tester,
        matches: [match('cr13'), match('f14')],
        newWordIds: const {'cr13'},
      );
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('no badge when every match is already collected',
        (tester) async {
      await pumpPanel(tester, matches: [match('cr13')]);
      expect(find.text('NEW'), findsNothing);
    });

    testWidgets('a photo that found nothing suggests what to look for',
        (tester) async {
      await pumpPanel(
        tester,
        matches: const [],
        targets: [_card('cr13'), _card('f14')],
      );
      expect(find.byType(HuntTargetStrip), findsOneWidget);
      expect(find.text('Try to find:'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
    });

    testWidgets('landing a hunt target says so, by name', (tester) async {
      await pumpPanel(
        tester,
        matches: [match('cr13')],
        targetsHit: [_card('cr13')],
      );
      // The win is explicit: without this the target just vanished from the
      // strip and nothing marked the success.
      expect(find.textContaining('Found it!'), findsOneWidget);
      expect(find.textContaining('Table was on your list'), findsOneWidget);
    });

    testWidgets('two targets at once read as plural', (tester) async {
      await pumpPanel(
        tester,
        matches: [match('cr13'), match('f14')],
        targetsHit: [_card('cr13'), _card('f14')],
      );
      expect(find.textContaining('Found them!'), findsOneWidget);
    });

    testWidgets('no banner for a find that was not on the list',
        (tester) async {
      await pumpPanel(tester, matches: [match('cr13')]);
      expect(find.textContaining('Found it!'), findsNothing);
    });

    testWidgets('targets stay out of the way when words were found',
        (tester) async {
      await pumpPanel(
        tester,
        matches: [match('cr13')],
        targets: [_card('f14')],
      );
      expect(find.byType(HuntTargetStrip), findsNothing);
    });
  });
}
