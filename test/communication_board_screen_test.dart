import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_presentation.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_seed_data.dart';
import 'package:pwdpwdpwd/features/communication_board/models/custom_board.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/board_test_doubles.dart';

/// Talk Board behaviour.
///
/// **No Hive anywhere in this file.** The board writes a phrase on every
/// spoken sentence, and one fire-and-forget `box.put` inside the fake-async
/// zone poisons the write queue for the rest of the run. Persistence is
/// covered in `test/board_phrases_test.dart`; here the store is in memory.

Widget _board({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CommunicationBoardScreen(),
    ),
  );
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  DisabilityType disability = DisabilityType.none,
  UserRole role = UserRole.student,
  FakeBoardPhraseStore? store,
  FakeCustomBoardStore? customStore,
  Size size = const Size(800, 1280),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_board(
    overrides: [
      ...boardProfileOverrides(role: role, disability: disability),
      overrideBoardPhrases(
        store ?? FakeBoardPhraseStore(),
        now: () => DateTime(2026, 4),
      ),
      overrideCustomBoard(
        customStore ?? FakeCustomBoardStore(),
        now: () => DateTime(2026, 4),
      ),
    ],
  ));
  // Settle the staggered tile entrance animations without waiting forever.
  await tester.pump(const Duration(milliseconds: 800));
}

/// Unmounts the screen so its GazeScope / TTS teardown runs inside the test.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Drains every pending framework exception, returning the first.
Object? _drainExceptions(WidgetTester tester) {
  Object? first;
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    first ??= e;
  }
  return first;
}

void main() {
  // The board only *reads* Hive (settings, profile); its own writes go to the
  // in-memory FakeBoardPhraseStore. Opening the boxes read-only keeps the
  // write queue clean, which is what stops teardown hanging.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/comm_board_screen');
    for (final name in const ['profiles', 'settings', 'progress', 'sessions']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
    // flutter_tts has no platform side under flutter_test, and the board calls
    // it on every spoken sentence. Without a stub the unawaited invocation
    // raises MissingPluginException and fails whichever test happens to be
    // running when it lands.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('the screen a learner arrives at', () {
    testWidgets('is titled to match the tile they tapped', (tester) async {
      await _pumpBoard(tester);
      // Every entry point says "Talk Board"; the screen used to say
      // "Communication Board".
      expect(find.text('Talk Board'), findsOneWidget);
      expect(find.text('Communication Board'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('opens on the first category its learner actually has',
        (tester) async {
      // A cognitive board has no Greetings tab at all, so the old hardcoded
      // `_activeCategory = greetings` would have rendered an empty grid.
      await _pumpBoard(tester, disability: DisabilityType.cognitive);
      final p = BoardPresentation.forType(DisabilityType.cognitive);

      expect(find.text('Greetings'), findsNothing);
      expect(find.text(p.categories.first.label), findsOneWidget);
      // …and the grid under it has tiles.
      expect(find.text(p.tilesFor(p.categories.first).first.label),
          findsOneWidget);
      await _unmount(tester);
    });
  });

  group('switching category (the duplicate-GlobalKey regression)', () {
    testWidgets('mid-animation does not reparent tiles', (tester) async {
      await _pumpBoard(tester);

      await tester.tap(find.text('Needs'));
      await tester.pump(); // begin the tiles' entrance animation
      await tester.pump(const Duration(milliseconds: 100)); // mid-flight

      // Tiles used to be keyed by grid *index*, so the outgoing and incoming
      // grids held the same GlobalKeys at once and the framework truncated
      // part of the tree on every single category tap.
      expect(_drainExceptions(tester), isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(_drainExceptions(tester), isNull);
      expect(find.text('I need help'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('survives switching through every tab in a row',
        (tester) async {
      // Wide enough that all eight tabs are laid out — a horizontal ListView
      // never builds the ones past its viewport, so they cannot be tapped.
      // Seed tabs only: this learner has no board of their own, so there is
      // no custom tab to tap.
      await _pumpBoard(tester, size: const Size(1400, 1000));
      for (final cat in BoardTileCategoryX.seedValues) {
        await tester.tap(find.text(cat.label));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(_drainExceptions(tester), isNull);
      await _unmount(tester);
    });

    testWidgets('between two tabs that share a tile does not collide',
        (tester) async {
      // A custom board can pull a seed tile forward, so `n01` lives on both
      // the learner's own tab and Needs. Keying the tile GlobalKeys by id
      // alone put the same key on two live widgets the moment those two tabs
      // cross-faded — the same truncation bug as the index-keyed version,
      // through a different door.
      await _pumpBoard(
        tester,
        customStore: FakeCustomBoardStore(sampleCustomBoard()),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Needs'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('My Board'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(_drainExceptions(tester), isNull);
      await _unmount(tester);
    });
  });

  group('building a sentence', () {
    testWidgets('a tapped tile joins the strip', (tester) async {
      await _pumpBoard(tester);
      expect(find.text('Tap tiles below to build a sentence'), findsOneWidget);

      await tester.tap(find.text('Hello'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tap tiles below to build a sentence'), findsNothing);
      // Once on the grid tile, once as a chip in the strip.
      expect(find.text('Hello'), findsNWidgets(2));
      await _unmount(tester);
    });

    testWidgets('the cap is enforced and explained, not silent',
        (tester) async {
      // A cognitive board caps the sentence at 4.
      await _pumpBoard(tester, disability: DisabilityType.cognitive);
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      final tiles = p.tilesFor(p.categories.first);

      for (var i = 0; i < p.maxSentenceLength; i++) {
        await tester.tap(find.text(tiles[i].label).first);
        await tester.pump(const Duration(milliseconds: 50));
      }
      // One more than the board allows.
      await tester.tap(find.text(tiles[p.maxSentenceLength].label).first);
      await tester.pump(const Duration(milliseconds: 400));

      // The board used to `return` silently, which reads as a dead screen.
      expect(
        find.textContaining('as long as a sentence can be'),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('backspace and clear only work on a non-empty sentence',
        (tester) async {
      await _pumpBoard(tester);
      // Nothing to remove yet — tapping must not throw.
      await tester.tap(find.bySemanticsLabel('Remove last tile'));
      await tester.tap(find.bySemanticsLabel('Clear all tiles'));
      await tester.pump();
      expect(_drainExceptions(tester), isNull);
      expect(find.text('Tap tiles below to build a sentence'), findsOneWidget);

      await tester.tap(find.text('Hello'));
      await tester.tap(find.text('Please'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Please'), findsNWidgets(2));

      await tester.tap(find.bySemanticsLabel('Remove last tile'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Please'), findsOneWidget); // grid only
      expect(find.text('Hello'), findsNWidgets(2)); // still in the strip

      await tester.tap(find.bySemanticsLabel('Clear all tiles'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Tap tiles below to build a sentence'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('per-accessibility presentation', () {
    testWidgets('a Deaf learner gets the large-type banner', (tester) async {
      await _pumpBoard(tester, disability: DisabilityType.hearing);
      await tester.tap(find.text('Hello'));
      await tester.tap(find.text('Thank you'));
      await tester.pump(const Duration(milliseconds: 300));

      // The banner joins the two labels with a separator, which is what makes
      // it findable distinctly from the individual chips.
      expect(find.textContaining('Hello · Thank you'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a sighted Player gets no banner', (tester) async {
      await _pumpBoard(tester, role: UserRole.player, size: const Size(1400, 1000));
      await tester.tap(find.text('Hello'));
      await tester.tap(find.text('Thank you'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Hello · Thank you'), findsNothing);
      // …but the full eight seed tabs are all there, and no custom tab: this
      // learner has not built a board.
      for (final cat in BoardTileCategoryX.seedValues) {
        expect(find.text(cat.label), findsOneWidget, reason: cat.label);
      }
      expect(find.text(BoardTileCategory.custom.label), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a cognitive board shows a trimmed, capped vocabulary',
        (tester) async {
      await _pumpBoard(tester, disability: DisabilityType.cognitive);
      final p = BoardPresentation.forType(DisabilityType.cognitive);

      // Trimmed tabs.
      expect(find.text('Greetings'), findsNothing);
      expect(find.text('Places'), findsNothing);
      for (final cat in p.categories) {
        expect(find.text(cat.label), findsOneWidget, reason: cat.label);
      }

      // Capped tiles: the seventh Needs tile is not on the board.
      final needs = BoardSeedData.forCategory(BoardTileCategory.needs);
      expect(needs.length, greaterThan(6));
      expect(find.text(needs[6].label), findsNothing);
      expect(find.text(needs[0].label), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('saved & recent phrases', () {
    testWidgets('the strip is absent until there is something to show',
        (tester) async {
      await _pumpBoard(tester);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a seeded phrase appears and loads back into the strip',
        (tester) async {
      final store = FakeBoardPhraseStore([
        SavedPhrase(
          id: 'n01+p01',
          tileIds: const ['n01', 'p01'],
          lastUsedAt: DateTime(2026, 3, 30),
          pinned: true,
        ),
      ]);
      await _pumpBoard(tester, store: store);

      // Rendered as a chip labelled with the whole phrase.
      final chip = find.bySemanticsLabel(
        RegExp('Saved phrase: I need help Teacher'),
      );
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 300));

      // Loaded into the sentence strip — "Teacher" is not in the Greetings
      // grid, so finding it at all means the phrase was restored.
      expect(find.text('Teacher'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await _unmount(tester);
    });

    testWidgets('speaking a sentence records it', (tester) async {
      final store = FakeBoardPhraseStore();
      await _pumpBoard(tester, store: store);

      await tester.tap(find.text('Hello'));
      await tester.tap(find.text('Thank you'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.bySemanticsLabel('Speak sentence'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(store.saveCount, greaterThan(0));
      expect(store.load().single.tileIds, ['g01', 'g05']);

      await tester.pump(const Duration(seconds: 3)); // drain the speak estimate
      await _unmount(tester);
    });

    testWidgets('the star pins the current sentence', (tester) async {
      final store = FakeBoardPhraseStore();
      await _pumpBoard(tester, store: store);

      await tester.tap(find.text('Hello'));
      await tester.tap(find.text('Thank you'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.bySemanticsLabel('Save this sentence'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.load(), hasLength(1));
      expect(store.load().single.pinned, isTrue);
      // The button flips to "already saved".
      expect(
        find.bySemanticsLabel('Remove this sentence from saved phrases'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await _unmount(tester);
    });

    testWidgets('the star saves a one-word sentence too', (tester) async {
      final store = FakeBoardPhraseStore();
      await _pumpBoard(tester, store: store);

      await tester.tap(find.text('Hello'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.bySemanticsLabel('Save this sentence'));
      await tester.pump(const Duration(milliseconds: 400));

      // A single tile is below the floor for automatic recents, but pinning is
      // explicit — the button must not claim a save it did not make.
      expect(store.load(), hasLength(1));
      expect(store.load().single.tileIds, ['g01']);
      expect(store.load().single.pinned, isTrue);
      await tester.pump(const Duration(seconds: 3));
      await _unmount(tester);
    });

    testWidgets('a phrase of retired tile ids is not rendered blank',
        (tester) async {
      final store = FakeBoardPhraseStore([
        SavedPhrase(
          id: 'ghost',
          tileIds: const ['retired-a', 'retired-b'],
          lastUsedAt: DateTime(2026, 3, 30),
          pinned: true,
        ),
      ]);
      await _pumpBoard(tester, store: store);

      expect(find.bySemanticsLabel(RegExp('Saved phrase:')), findsNothing);
      expect(_drainExceptions(tester), isNull);
      await _unmount(tester);
    });
  });

  group('the learner own board', () {
    testWidgets('no tab at all until one has been built', (tester) async {
      await _pumpBoard(tester);
      expect(find.text('My Board'), findsNothing);
      // An empty tab is worse than none: the gaze cursor can land on it.
      expect(find.text('Greetings'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('leads the tabs and opens first once it exists',
        (tester) async {
      await _pumpBoard(
        tester,
        customStore: FakeCustomBoardStore(sampleCustomBoard()),
      );

      expect(find.text('My Board'), findsOneWidget);
      // It is the opening tab, so its tiles are the ones on screen: a seed
      // reference and an authored word, in the order the adult chose.
      expect(find.text('I need help'), findsOneWidget);
      expect(find.text('Ate Maria'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('wears the name the adult gave it', (tester) async {
      await _pumpBoard(
        tester,
        customStore: FakeCustomBoardStore(sampleCustomBoard(name: 'Bahay')),
      );
      expect(find.text('Bahay'), findsOneWidget);
      expect(find.text('My Board'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('an authored word can be added and spoken', (tester) async {
      final store = FakeBoardPhraseStore();
      await _pumpBoard(
        tester,
        store: store,
        customStore: FakeCustomBoardStore(sampleCustomBoard()),
      );

      await tester.tap(find.text('Ate Maria'));
      await tester.tap(find.text('I need help'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.bySemanticsLabel('Speak sentence'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(store.load().single.tileIds, ['c_ate', 'n01']);
      await tester.pump(const Duration(seconds: 3));
      await _unmount(tester);
    });

    testWidgets('a saved phrase keeps the authored word', (tester) async {
      // The regression the vocabulary lookup exists to prevent: a seed-only
      // resolver renders the phrase one word shorter and nobody notices.
      final phrases = FakeBoardPhraseStore([
        SavedPhrase(
          id: 'n01+c_ate',
          tileIds: const ['n01', 'c_ate'],
          lastUsedAt: DateTime(2026, 3, 30),
          pinned: true,
        ),
      ]);
      await _pumpBoard(
        tester,
        store: phrases,
        customStore: FakeCustomBoardStore(sampleCustomBoard()),
      );

      expect(
        find.bySemanticsLabel(RegExp('Saved phrase: I need help Ate Maria')),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('a cognitive board keeps its cap on seed tabs but not on this',
        (tester) async {
      // maxTilesPerCategory trims a catalogue nobody curated; this board is
      // exactly what an adult chose for this learner.
      final board = CustomBoard(
        name: 'My Board',
        tileIds: const ['n01', 'n02', 'n03', 'n04', 'n05', 'n06', 'n07', 'n08'],
        customTiles: const [],
        updatedAt: DateTime(2026, 4),
      );
      await _pumpBoard(
        tester,
        disability: DisabilityType.cognitive,
        customStore: FakeCustomBoardStore(board),
      );

      final needs = BoardSeedData.forCategory(BoardTileCategory.needs);
      // All eight on the custom tab…
      expect(find.text(needs[7].label), findsOneWidget);

      // …but the Needs tab itself is still capped at six. Two pumps: the
      // AnimatedSwitcher keeps the outgoing grid mounted until its
      // controller reports completion, which lands one frame after the
      // animation ends — with a single pump every tile from the tab we
      // just left is still findable.
      await tester.tap(find.text('Needs'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(needs[7].label), findsNothing);
      expect(find.text(needs[0].label), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('there is a way in to build one', (tester) async {
      await _pumpBoard(tester);
      expect(find.bySemanticsLabel('Build my board'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the entry point says Edit once a board exists',
        (tester) async {
      await _pumpBoard(
        tester,
        customStore: FakeCustomBoardStore(sampleCustomBoard()),
      );
      expect(find.bySemanticsLabel('Edit my board'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('short viewports', () {
    testWidgets('drop the optional header rather than overflow',
        (tester) async {
      final store = FakeBoardPhraseStore([
        SavedPhrase(
          id: 'n01+p01',
          tileIds: const ['n01', 'p01'],
          lastUsedAt: DateTime(2026, 3, 30),
          pinned: true,
        ),
      ]);
      // A landscape phone: banner + phrase strip + sentence strip + tabs is
      // taller than the whole screen.
      await _pumpBoard(
        tester,
        disability: DisabilityType.hearing,
        store: store,
        size: const Size(640, 360),
      );

      expect(find.bySemanticsLabel(RegExp('Saved phrase:')), findsNothing);
      expect(_drainExceptions(tester), isNull);
      // The board itself is still usable.
      expect(find.text('Hello'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('leaving the board', () {
    testWidgets('unmounting mid-sentence is clean', (tester) async {
      await _pumpBoard(tester);
      await tester.tap(find.text('Hello'));
      await tester.pump(const Duration(milliseconds: 100));
      // dispose() stops the TTS so the board does not keep talking over the
      // next screen.
      await _unmount(tester);
      expect(_drainExceptions(tester), isNull);
    });
  });
}
