import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/celebration_style.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/features/shop/screens/shop_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/shop_test_doubles.dart';

/// First widget-test coverage for the Star Shop.
///
/// The headline case is the overflow matrix. The shop grid sized its cells as a
/// fixed fraction of their width while everything inside the card — emoji, name,
/// status chip — scales with the learner's Font Size setting, so at the XL font
/// on a small phone every card overflowed (23 px on the item tabs, 5.7 px on
/// Themes, confirmed on the Honor tablet via `wm size 630x1120`). That is a
/// regression the accessibility profiles hit first, which is exactly why it
/// needs a test rather than a fix alone.

const String _kStoreDir = './build/test_cache/shop_screen';

/// Records the refund call instead of performing it.
///
/// A `box.put` started inside `testWidgets`' fake-async zone never drains, and
/// Hive serialises writes, so a widget test that triggers the *real* refund
/// wedges the whole file until the per-test timeout — and takes the tests after
/// it down with it. The refund logic is covered against real Hive in
/// `shop_refund_test.dart`, which has no widget tests and so runs in the real
/// zone; this spy only proves the screen asks for it and reports the result.
class _SpyProgressNotifier extends FakeShopProgressNotifier {
  _SpyProgressNotifier({
    required super.totalStars,
    required super.spentStars,
    required this.refundAmount,
  });

  final int refundAmount;
  int refundCalls = 0;

  @override
  int refundWithdrawnPurchases() {
    refundCalls++;
    return refundAmount;
  }
}

Future<void> _pumpShop(
  WidgetTester tester, {
  required int totalStars,
  int spentStars = 0,
  Set<String> owned = const {},
  String locale = 'en',
  AppSettings? settings,
  ProgressNotifier Function()? progress,
  Size size = const Size(800, 1280),
  double devicePixelRatio = 2.0,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(StubProfileNotifier.new),
        settingsProvider.overrideWith(
          () => StubSettingsNotifier(locale: locale, settings: settings),
        ),
        progressProvider.overrideWith(
          progress ??
              () => FakeShopProgressNotifier(
                    totalStars: totalStars,
                    spentStars: spentStars,
                    owned: owned,
                  ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The scaler has to go inside `MaterialApp.builder` — a MediaQuery
        // wrapped around MaterialApp is rebuilt away from the FlutterView.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ShopScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Jumps the shop to [type]'s tab without tapping: the tab strip scrolls, so at
/// the narrow end of the matrix the later tabs are off-screen and untappable.
///
/// Asserts the tab's own first item is on screen afterwards. Without that check
/// a jump that silently failed to warp `TabBarView` would leave every caller
/// inspecting the Avatars tab six times over and passing.
Future<void> _selectTab(WidgetTester tester, ShopItemType type) async {
  // Index within the *sellable* tabs, which is what the shop actually builds —
  // a withdrawn category has no tab, so ShopItemType.index would be wrong.
  tester.widget<TabBar>(find.byType(TabBar)).controller!.index =
      ShopData.sellableTypes.indexOf(type);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(
    find.text(ShopData.sellableByType(type).first.name),
    findsOneWidget,
    reason: 'the ${type.name} tab did not come to the front',
  );
}

/// Drains the exception queue — an overflowing box re-reports every frame.
Object? _firstException(WidgetTester tester) {
  Object? first;
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    first ??= e;
  }
  return first;
}

/// Every `RenderFlex` on screen whose children need more main-axis room than
/// its constraints allow, described for a failure message.
///
/// Measured rather than read off `tester.takeException()` on purpose. Flutter
/// only *reports* a RenderFlex overflow from `paint()`, and these cards sit
/// behind a staggered entrance fade inside a `TabBarView`, so the frames the
/// harness pumps never paint them — the shipped 23 px card overflow raised no
/// test exception at all. Children under `Expanded`/`Flexible` are already
/// shrunk to fit by the time they are measured, so a fixed layout that fits
/// reports nothing here either.
List<String> _overflowingFlexes(WidgetTester tester) {
  final offenders = <String>[];

  for (final node in tester.allRenderObjects.whereType<RenderFlex>()) {
    if (!node.hasSize || node.debugNeedsLayout) continue;

    final vertical = node.direction == Axis.vertical;
    final available =
        vertical ? node.constraints.maxHeight : node.constraints.maxWidth;
    // An unbounded flex (inside a scroll view) grows instead of overflowing.
    if (!available.isFinite) continue;

    var needed = 0.0;
    for (RenderBox? child = node.firstChild;
        child != null;
        child = node.childAfter(child)) {
      needed += vertical ? child.size.height : child.size.width;
    }

    // Sub-pixel rounding is not an overflow.
    if (needed - available > 0.5) {
      offenders.add(
        '  ${vertical ? "Column" : "Row"} needs '
        '${needed.toStringAsFixed(1)} px in ${available.toStringAsFixed(1)} px '
        '(over by ${(needed - available).toStringAsFixed(1)})',
      );
    }
  }

  return offenders;
}

/// Lets flutter_animate's staggered `delay:` timers fire before the tree is
/// torn down, so teardown doesn't trip the "Timer is still pending" invariant.
Future<void> _flushEntranceTimers(WidgetTester tester) async {
  const step = Duration(milliseconds: 100);
  for (Duration elapsed = Duration.zero;
      elapsed < const Duration(seconds: 3);
      elapsed += step) {
    await tester.pump(step);
  }
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  setUpAll(() async {
    // Self-healing store: a previous hang can leave a flutter_tester holding
    // the lock file, which fails every later run at `Hive.init`.
    try {
      final dir = Directory(_kStoreDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}

    Hive.init(_kStoreDir);
    for (final name in const <String>['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        // Auto-compaction renames the box file mid-write on Windows and throws
        // PathAccessException; these stores are disposable, so skip it.
        await Hive.openBox(
          name,
          compactionStrategy: (entries, deleted) => false,
        );
      }
    }
  });

  setUp(() async {
    // Real zone here, so awaiting the write is normally safe — but a test that
    // fails partway can leave a fake-async `box.put` pending, and Hive
    // serialises writes, so an unguarded clear would then block until the
    // 10-minute per-test timeout and report the *next* test as the hang.
    await Hive.box('progress')
        .clear()
        .timeout(const Duration(seconds: 5), onTimeout: () => 0);
  });

  // Equipping writes through `HiveService.saveEquippedItem`, and a `box.put`
  // started inside the fake-async zone leaves a Future that never completes —
  // an unguarded teardown waits on it until the 12-minute timeout.
  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('Star Shop layout', () {
    testWidgets('no tab overflows on any device size or accessibility font',
        (tester) async {
      for (final device in kTabletMatrix) {
        for (final scale in kTextScales) {
          // Mid-range wallet so the grid renders a mix of affordable and
          // unaffordable cards — both chip styles are on screen at once.
          await _pumpShop(
            tester,
            totalStars: 30,
            size: device.size,
            devicePixelRatio: device.devicePixelRatio,
            textScale: scale,
          );

          for (final type in ShopData.sellableTypes) {
            await _selectTab(tester, type);

            expect(
              _overflowingFlexes(tester),
              isEmpty,
              reason: 'Overflowing layout on the ${type.name} tab '
                  'at $device, textScale ${scale}x',
            );

            final error = _firstException(tester);
            expect(
              error,
              isNull,
              reason: 'Layout exception on the ${type.name} tab '
                  'at $device, textScale ${scale}x:\n$error',
            );
          }
        }
      }
      await _flushEntranceTimers(tester);
    });

    testWidgets('item names stay readable rather than clipping to one glyph',
        (tester) async {
      // The worst case from the matrix: smallest phone, largest font. "Ocean
      // Theme" used to ellipsize to "Ocea…" here.
      await _pumpShop(
        tester,
        totalStars: 30,
        size: const Size(360, 640),
        devicePixelRatio: 3.0,
        textScale: 2.0,
      );
      await _selectTab(tester, ShopItemType.theme);

      final name = tester.widget<Text>(
        find.text('Ocean Theme'),
      );
      expect(name.maxLines, greaterThan(1),
          reason: 'a wrapped name beats a truncated one at accessible fonts');
      expect(_firstException(tester), isNull);

      await _flushEntranceTimers(tester);
    });
  });

  group('Star Shop behaviour', () {
    testWidgets('offers every category that has something to sell',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      for (final label in const ['Avatars', 'Themes', 'Borders', 'Titles', 'Effects']) {
        expect(find.text(label), findsOneWidget);
      }

      await _flushEntranceTimers(tester);
    });

    testWidgets('a withdrawn category is not on the shelf at all',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      // Sound packs have no per-pack audio, so they are not for sale — and an
      // empty shelf would be as confusing as a broken one.
      expect(find.text('Sounds'), findsNothing);
      expect(ShopData.sellableTypes, isNot(contains(ShopItemType.soundPack)));
      expect(ShopData.sellableByType(ShopItemType.soundPack), isEmpty);
      for (final item in ShopData.byType(ShopItemType.soundPack)) {
        expect(find.text(item.name), findsNothing);
      }

      await _flushEntranceTimers(tester);
    });

    testWidgets('the wallet shows spendable balance, not total stars earned',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, spentStars: 40);

      expect(find.text('60'), findsOneWidget);
      expect(find.text('100'), findsNothing,
          reason: 'total earned is not what the learner can spend');

      await _flushEntranceTimers(tester);
    });

    testWidgets('an unaffordable item explains itself instead of opening a dialog',
        (tester) async {
      await _pumpShop(tester, totalStars: 5);

      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Not enough stars'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });

    testWidgets('an affordable item confirms before spending, and Cancel is safe',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      // Not pumpAndSettle: AnimatedGradientBackground loops forever, so
      // "settled" never arrives. Fixed pumps clear the dialog transition.
      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Buy Unicorn?'), findsOneWidget);
      expect(find.text('A magical unicorn avatar!'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('100'), findsOneWidget,
          reason: 'cancelling must not spend stars');

      await _flushEntranceTimers(tester);
    });

    testWidgets('an owned item equips on tap and unequips on the next tap',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, owned: {'avatar_unicorn'});

      expect(find.text('Tap to Equip'), findsOneWidget);
      expect(find.text('Equipped'), findsNothing);

      await tester.tap(find.text('Unicorn'));
      await tester.pump();

      expect(find.text('Equipped'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'an owned item equips; it must never re-charge the learner');

      await tester.tap(find.text('Unicorn'));
      await tester.pump();

      expect(find.text('Tap to Equip'), findsOneWidget);
      expect(find.text('Equipped'), findsNothing);

      await _flushEntranceTimers(tester);
    });
  });

  group('The shop asks for the refund', () {
    testWidgets('on open, and tells the learner what changed', (tester) async {
      final spy = _SpyProgressNotifier(
        totalStars: 100,
        spentStars: 20,
        refundAmount: 20,
      );
      await _pumpShop(
        tester,
        totalStars: 100,
        spentStars: 20,
        progress: () => spy,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(spy.refundCalls, 1);
      expect(find.textContaining('20 stars are back'), findsOneWidget,
          reason: 'a balance that changes silently is its own bug');

      await _flushEntranceTimers(tester);
    });

    testWidgets('and stays quiet when there is nothing to refund',
        (tester) async {
      final spy = _SpyProgressNotifier(
        totalStars: 100,
        spentStars: 0,
        refundAmount: 0,
      );
      await _pumpShop(tester, totalStars: 100, progress: () => spy);
      await tester.pump(const Duration(milliseconds: 400));

      expect(spy.refundCalls, 1);
      expect(find.textContaining('stars are back'), findsNothing);

      await _flushEntranceTimers(tester);
    });
  });

  group('Celebration effects reach the confetti', () {
    /// The confetti the shop is currently rendering.
    ConfettiWidget confetti(WidgetTester tester) =>
        tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));

    testWidgets('an unequipped learner gets the standard burst',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      expect(confetti(tester).gravity, CelebrationStyle.standard.gravity);
      expect(confetti(tester).colors, CelebrationStyle.standard.colors);

      await _flushEntranceTimers(tester);
    });

    testWidgets('equipping Snowfall changes how the confetti falls',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, owned: {'celebration_snow'});
      await _selectTab(tester, ShopItemType.celebration);
      final standardKey = confetti(tester).key;

      await tester.tap(find.text('Snowfall'));
      await tester.pump();
      expect(find.text('Equipped'), findsOneWidget);

      // This is the whole point of the purchase: the celebration is visibly
      // different afterwards, not just a row in a Hive box.
      final snow = confetti(tester);
      expect(snow.gravity, lessThan(CelebrationStyle.standard.gravity));
      expect(snow.colors, contains(Colors.white));
      expect(snow.blastDirectionality, BlastDirectionality.directional);
      expect(snow.colors, isNot(CelebrationStyle.standard.colors));

      // …and the widget is a *new* one, not the old particle system wearing
      // new properties. ConfettiWidget reads its palette and physics once in
      // initState, so without a changing key every assertion above passes
      // while the confetti on screen stays exactly as it was — which is what
      // shipped to the tablet before this key existed.
      expect(
        snow.key,
        isNot(standardKey),
        reason: 'equipping must rebuild the confetti, not just re-describe it',
      );

      await _flushEntranceTimers(tester);
    });

    testWidgets('unequipping puts the standard burst back', (tester) async {
      await _pumpShop(tester, totalStars: 100, owned: {'celebration_rainbow'});
      await _selectTab(tester, ShopItemType.celebration);

      await tester.tap(find.text('Rainbow Burst'));
      await tester.pump();
      expect(confetti(tester).colors, isNot(CelebrationStyle.standard.colors));

      await tester.tap(find.text('Rainbow Burst'));
      await tester.pump();
      expect(confetti(tester).colors, CelebrationStyle.standard.colors);

      await _flushEntranceTimers(tester);
    });
  });

  group('Filipino', () {
    testWidgets('tabs, item names and descriptions are all translated',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, locale: 'fil');

      // Tab labels came from ARB keys that did not exist before — Titles,
      // Sounds and Effects were hardcoded English in a bilingual app.
      expect(find.text('Mga Avatar'), findsOneWidget);
      expect(find.text('Mga Titulo'), findsOneWidget);
      expect(find.text('Mga Epekto'), findsOneWidget);
      expect(find.text('Avatars'), findsNothing);
      expect(find.text('Titles'), findsNothing);

      // Item names are catalogue data, not ARB entries.
      expect(find.text('Pating'), findsOneWidget);
      expect(find.text('Shark'), findsNothing);

      await _flushEntranceTimers(tester);
    });

    testWidgets('the buy dialog is translated end to end', (tester) async {
      await _pumpShop(tester, totalStars: 100, locale: 'fil');

      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bilhin ang Unicorn?'), findsOneWidget);
      expect(find.text('Isang mahiwagang unicorn avatar!'), findsOneWidget);
      expect(find.text('Bilhin!'), findsOneWidget);

      await tester.tap(find.text('Bilhin!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Nakuha mo ang Unicorn'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });

    testWidgets('running out of stars is explained in Filipino',
        (tester) async {
      await _pumpShop(tester, totalStars: 5, locale: 'fil');

      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Kulang ang mga bituin'), findsOneWidget);
      expect(find.textContaining('Not enough stars'), findsNothing);

      await _flushEntranceTimers(tester);
    });

    testWidgets('the refund notice is translated', (tester) async {
      final spy = _SpyProgressNotifier(
        totalStars: 100,
        spentStars: 20,
        refundAmount: 20,
      );
      await _pumpShop(
        tester,
        totalStars: 100,
        spentStars: 20,
        locale: 'fil',
        progress: () => spy,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Naibalik ang 20 bituin'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });

    testWidgets('English is untouched', (tester) async {
      await _pumpShop(tester, totalStars: 100);

      expect(find.text('Avatars'), findsOneWidget);
      expect(find.text('Titles'), findsOneWidget);
      expect(find.text('Shark'), findsOneWidget);
      expect(find.text('Pating'), findsNothing);

      await _flushEntranceTimers(tester);
    });
  });

  group('The catalogue answers to the learner own settings', () {
    testWidgets('a theme a learner cannot see is flagged before they buy it',
        (tester) async {
      // main.dart puts High Contrast above the shop theme in its cascade, so
      // this purchase would change nothing until the setting is turned off.
      await _pumpShop(
        tester,
        totalStars: 100,
        settings: const AppSettings(highContrastMode: true),
      );
      await _selectTab(tester, ShopItemType.theme);

      await tester.tap(find.text('Ocean Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('High Contrast is on'), findsOneWidget,
          reason: 'the warning has to land before the stars are spent');

      await _flushEntranceTimers(tester);
    });

    testWidgets('dyslexia mode gets its own wording', (tester) async {
      await _pumpShop(
        tester,
        totalStars: 100,
        settings: const AppSettings(dyslexiaMode: true),
      );
      await _selectTab(tester, ShopItemType.theme);

      await tester.tap(find.text('Ocean Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Dyslexia-friendly'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });

    testWidgets('a learner with neither setting on sees no warning',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);
      await _selectTab(tester, ShopItemType.theme);

      await tester.tap(find.text('Ocean Theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('High Contrast'), findsNothing);
      expect(find.textContaining('Dyslexia'), findsNothing);

      await _flushEntranceTimers(tester);
    });

    testWidgets('reduced motion is told effects will play gently',
        (tester) async {
      await _pumpShop(
        tester,
        totalStars: 100,
        settings: const AppSettings(reducedMotion: true),
      );
      await _selectTab(tester, ShopItemType.celebration);

      await tester.tap(find.text('Fireworks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Reduced Motion is on'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });

    testWidgets('reduced motion calms the confetti without silencing it',
        (tester) async {
      await _pumpShop(
        tester,
        totalStars: 100,
        owned: {'celebration_rainbow'},
        settings: const AppSettings(reducedMotion: true),
      );

      final confetti =
          tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));

      // Still drawn — a purchased effect must not become inert for the
      // learners whose presets switch reduced motion on.
      expect(confetti.colors, isNotEmpty);
      expect(confetti.gravity, lessThan(CelebrationStyle.standard.gravity));
      expect(confetti.numberOfParticles,
          lessThan(CelebrationStyle.standard.numberOfParticles));

      await _flushEntranceTimers(tester);
    });

    testWidgets('nothing is ever hidden from anyone', (tester) async {
      // Advice informs; it must never gate. Every sellable item stays on the
      // shelf no matter how the learner has the app set up.
      await _pumpShop(
        tester,
        totalStars: 100,
        settings: const AppSettings(
          highContrastMode: true,
          reducedMotion: true,
        ),
      );

      for (final type in ShopData.sellableTypes) {
        await _selectTab(tester, type);
        // The grid builds lazily, so assert over what the first screen holds —
        // enough to catch advice quietly filtering the shelf, without
        // scrolling every tab.
        for (final item in ShopData.sellableByType(type).take(4)) {
          expect(find.text(item.name), findsOneWidget,
              reason: '${item.id} must stay purchasable');
        }
      }

      await _flushEntranceTimers(tester);
    });
  });
}
