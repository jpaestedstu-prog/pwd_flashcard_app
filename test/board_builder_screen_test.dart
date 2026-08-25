import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/communication_board/models/custom_board.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/board_template_builder_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/board_test_doubles.dart';

/// The board builder's behaviour.
///
/// **No Hive writes.** Save is a `box.put`, and one started inside the
/// fake-async zone poisons the box's write queue for the rest of the file; the
/// store here is in memory and the real round-trip lives in
/// `test/custom_board_test.dart`.

/// The builder navigates with `context.popOrGo`, so it needs a real router —
/// a bare `MaterialApp` home would throw the moment Save or Back ran. The
/// builder is *pushed* on top of a Talk Board stand-in, which is the real
/// stack shape and lets the pop path be asserted.
Future<void> _pumpBuilder(
  WidgetTester tester, {
  FakeCustomBoardStore? store,
  Size size = const Size(900, 1400),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/communication-board',
    routes: [
      GoRoute(
        path: '/communication-board',
        builder: (_, _) => const Scaffold(body: Text('talk board')),
        routes: [
          GoRoute(
            path: 'builder',
            builder: (_, _) => const BoardTemplateBuilderScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...boardProfileOverrides(),
        overrideCustomBoard(
          store ?? FakeCustomBoardStore(),
          now: () => DateTime(2026, 4),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  router.push('/communication-board/builder');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

/// The board-name field's current text.
String _boardName(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// The seed tile labelled [label] in the "available tiles" grid.
///
/// Scoped to the GridView rather than matched by semantics label: once a tile
/// is added its word also appears on a Chip above, and the grid copy is the
/// one that is tappable.
Finder _gridTile(String label) => find.descendant(
      of: find.byType(GridView),
      matching: find.text(label),
    );

Future<void> _addSeed(WidgetTester tester, String label) async {
  await tester.tap(_gridTile(label));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/board_builder_screen');
    for (final name in const ['profiles', 'settings', 'progress', 'sessions']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
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

  group('opening the builder', () {
    testWidgets('a first-time board starts empty with the default name',
        (tester) async {
      await _pumpBuilder(tester);
      expect(find.text('Tap tiles below, or make your own word'),
          findsOneWidget);
      expect(_boardName(tester), CustomBoard.defaultName);
      expect(find.textContaining('0 / $kMaxCustomBoardTiles'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('an existing board is loaded for editing, not blanked',
        (tester) async {
      // The builder used to open empty every time, so "editing" your board
      // meant rebuilding it from scratch.
      final store = FakeCustomBoardStore(sampleCustomBoard(name: 'Bahay'));
      await _pumpBuilder(tester, store: store);

      expect(_boardName(tester), 'Bahay');
      expect(find.textContaining('2 / $kMaxCustomBoardTiles'), findsOneWidget);
      // Both kinds of entry come back: a seed reference and an authored tile.
      expect(find.widgetWithText(Chip, 'I need help'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Ate Maria'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('saving', () {
    testWidgets('Save actually persists — it used to only claim to',
        (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await _addSeed(tester, 'Hello');
      await _addSeed(tester, 'Thank you');

      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.saveCount, greaterThan(0));
      expect(store.load().tileIds, ['g01', 'g05']);
      expect(store.load().name, CustomBoard.defaultName);
      await _unmount(tester);
    });

    testWidgets('the board name is stored and becomes the tab label',
        (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await tester.enterText(
          find.byType(TextField).first, 'Bahay ni Ana');
      await _addSeed(tester, 'Hello');
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.load().name, 'Bahay ni Ana');
      await _unmount(tester);
    });

    testWidgets('a blank name is refused rather than saved', (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await _addSeed(tester, 'Hello');
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.saveCount, 0);
      expect(find.textContaining('give the board a name'),
          findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('saving an empty board says it cleared, not that it saved',
        (tester) async {
      final store = FakeCustomBoardStore(sampleCustomBoard());
      await _pumpBuilder(tester, store: store);

      await tester.tap(find.text('Clear All'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.load().isEmpty, isTrue);
      expect(find.textContaining('Board cleared'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });
  });

  group('seed tiles', () {
    testWidgets('an already-added tile is marked and cannot be added twice',
        (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await _addSeed(tester, 'Hello');
      // The added marker appears on exactly the tile that was added.
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );

      // Tapping it again is inert — onTap is null once added.
      await _addSeed(tester, 'Hello');
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.load().tileIds, ['g01']);
      await _unmount(tester);
    });

    testWidgets('removing a tile takes it back out of the board',
        (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await _addSeed(tester, 'Hello');
      await _addSeed(tester, 'Please');
      expect(find.textContaining('2 / $kMaxCustomBoardTiles'), findsOneWidget);

      // The chip's delete affordance.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, 'Hello'),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('1 / $kMaxCustomBoardTiles'), findsOneWidget);
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.load().tileIds, ['g06']);
      await _unmount(tester);
    });
  });

  group('authoring a word', () {
    testWidgets('creates a tile and puts it on the board', (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await tester.tap(find.text('Make my own word'));
      await tester.pumpAndSettle();
      expect(find.text('Make my own word'), findsNWidgets(2)); // button + title

      await tester.enterText(
        find.widgetWithText(TextField, 'Word (English)'),
        'Ate Maria',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Ate Maria'), findsOneWidget);

      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      final saved = store.load();
      expect(saved.customTiles, hasLength(1));
      expect(saved.customTiles.single.label, 'Ate Maria');
      // Blank Filipino falls back to the English word rather than storing an
      // empty string the board would render as nothing.
      expect(saved.customTiles.single.labelFil, 'Ate Maria');
      expect(saved.customTiles.single.isCustom, isTrue);
      expect(saved.tileIds.single, saved.customTiles.single.id);
      expect(isCustomTileId(saved.tileIds.single), isTrue);
      await _unmount(tester);
    });

    testWidgets('a blank word is refused with a reason, not silently',
        (tester) async {
      await _pumpBuilder(tester);

      await tester.tap(find.text('Make my own word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Still open, and it says why.
      expect(find.textContaining('Enter the word in English'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _unmount(tester);
    });

    testWidgets('Cancel adds nothing', (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await tester.tap(find.text('Make my own word'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Word (English)'),
        'Ate Maria',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Ate Maria'), findsNothing);
      expect(find.textContaining('0 / $kMaxCustomBoardTiles'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a Filipino word is kept when given', (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await tester.tap(find.text('Make my own word'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Word (English)'), 'Big sister');
      await tester.enterText(
        find.widgetWithText(TextField, 'Word (Filipino) — optional'),
        'Ate',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.load().customTiles.single.label, 'Big sister');
      expect(store.load().customTiles.single.labelFil, 'Ate');
      await _unmount(tester);
    });

    testWidgets('editing an authored tile keeps its id', (tester) async {
      // Saved phrases reference the id, so a new one on every edit would
      // silently drop the word out of every phrase that used it.
      final store = FakeCustomBoardStore(sampleCustomBoard());
      await _pumpBuilder(tester, store: store);

      // Reorder/remove mode is where authored tiles become editable.
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ate Maria'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Word (English)'), 'Ate Marya');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Board'));
      await tester.pump(const Duration(milliseconds: 400));

      final saved = store.load();
      expect(saved.customTiles.single.id, 'c_ate');
      expect(saved.customTiles.single.label, 'Ate Marya');
      await _unmount(tester);
    });

    testWidgets('a seed tile is not editable', (tester) async {
      final store = FakeCustomBoardStore(sampleCustomBoard());
      await _pumpBuilder(tester, store: store);

      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('I need help'));
      await tester.pumpAndSettle();

      // No dialog: a seed tile's wording belongs to the app.
      expect(find.text('Edit word'), findsNothing);
      await _unmount(tester);
    });
  });

  group('unsaved changes', () {
    testWidgets('Back warns instead of discarding silently', (tester) async {
      final store = FakeCustomBoardStore();
      await _pumpBuilder(tester, store: store);

      await _addSeed(tester, 'Hello');
      await tester.tap(find.byTooltip('Go back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      // Still here, still holding the edit.
      expect(find.widgetWithText(Chip, 'Hello'), findsOneWidget);
      expect(store.saveCount, 0);
      await _unmount(tester);
    });

    testWidgets('Back leaves quietly when nothing changed', (tester) async {
      await _pumpBuilder(tester, store: FakeCustomBoardStore());
      await tester.tap(find.byTooltip('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      await _unmount(tester);
    });
  });
}
