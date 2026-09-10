import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_pack.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/services/celebration_style.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';
import 'package:pwdpwdpwd/features/shop/screens/shop_screen.dart';
import 'package:pwdpwdpwd/features/shop/widgets/shop_item_preview.dart';
import 'package:pwdpwdpwd/widgets/celebration_confetti.dart';
import 'package:pwdpwdpwd/widgets/shop_badge.dart';
import 'package:pwdpwdpwd/widgets/theme_preview_card.dart';
import 'package:pwdpwdpwd/widgets/profile_avatar.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/readability.dart';
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
  int refundWithdrawnPurchases({Set<String>? withdrawnIds}) {
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
  SoundService? sound,
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
        if (sound != null) soundServiceProvider.overrideWithValue(sound),
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

/// The English tab label for [type], mirroring the shop's own `_labelFor`.
String _labelOf(ShopItemType type) => switch (type) {
      ShopItemType.avatar => 'Avatars',
      ShopItemType.theme => 'Themes',
      ShopItemType.border => 'Borders',
      ShopItemType.title => 'Titles',
      ShopItemType.soundPack => 'Sounds',
      ShopItemType.celebration => 'Effects',
    };

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

    // Filipino is where the narrow cell bites: "Salamangkero ng Salita" and
    // "Temang Paglubog ng Araw" run half as long again as their English names,
    // and the shelves now fit three or four cards across a tablet instead of
    // two. Same matrix as above, in the language with the longest words.
    testWidgets('the Filipino shelves fit their cells too', (tester) async {
      for (final device in kNarrowPortrait) {
        for (final scale in kLargeTextScales) {
          await _pumpShop(
            tester,
            totalStars: 30,
            locale: 'fil',
            size: device.size,
            devicePixelRatio: device.devicePixelRatio,
            textScale: scale,
          );

          for (final type in ShopData.sellableTypes) {
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index =
                ShopData.sellableTypes.indexOf(type);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            expect(
              _overflowingFlexes(tester),
              isEmpty,
              reason: 'Overflowing Filipino ${type.name} shelf '
                  'at $device, textScale ${scale}x',
            );
            expect(_firstException(tester), isNull,
                reason: 'Layout exception on the Filipino ${type.name} shelf '
                    'at $device, textScale ${scale}x');
            // Fitting is not the same as being readable: a narrower cell can
            // break "Salamangkero" in half without overflowing anything.
            expectReadable(tester,
                at: 'the Filipino ${type.name} shelf, $device, ${scale}x');
          }
        }
      }
      await _flushEntranceTimers(tester);
    });

    // The shipped bug: the corner markers (Recommended / advice) put the card
    // body inside a `Stack`, and a Stack lays its non-positioned children out
    // *loosely* and aligns them to its own top start. The padded Column
    // therefore shrank to the width of its widest word and parked against the
    // left edge — picture, name and price all hugging one side of a 315 dp
    // card, vertically centred because the Column still filled the height.
    // Nothing overflowed, so the matrix above saw nothing wrong.
    testWidgets('an item card centres its picture, name and price',
        (tester) async {
      for (final device in kTabletMatrix) {
        for (final scale in kTextScales) {
          await _pumpShop(
            tester,
            totalStars: 30,
            size: device.size,
            devicePixelRatio: device.devicePixelRatio,
            textScale: scale,
          );
          await _selectTab(tester, ShopItemType.avatar);

          final card = find
              .ancestor(of: find.text('Unicorn'), matching: find.byType(Card))
              .first;
          final cardCentre = tester.getRect(card).center.dx;

          // The three things a learner reads on the card, in order.
          for (final part in <(String, Finder)>[
            ('picture', find.text('🦄')),
            ('name', find.text('Unicorn')),
            // The pill, not the number inside it: the badge centres itself,
            // and its label sits to the right of the star icon by design.
            ('price', find.byType(ShopBadge)),
          ]) {
            final piece =
                find.descendant(of: card, matching: part.$2).first;
            final centre = tester.getRect(piece).center.dx;
            expect(
              (centre - cardCentre).abs(),
              lessThan(1.0),
              reason: 'the ${part.$1} sits ${(centre - cardCentre).abs()} px '
                  'off centre at $device, textScale ${scale}x',
            );
          }
        }
      }
      await _flushEntranceTimers(tester);
    });
  });

  group('Star Shop behaviour', () {
    testWidgets('offers every category that has something to sell',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      for (final label in const [
        'Avatars',
        'Themes',
        'Borders',
        'Titles',
        'Sounds',
        'Effects',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await _flushEntranceTimers(tester);
    });

    testWidgets('the Sounds shelf is stocked again', (tester) async {
      await _pumpShop(tester, totalStars: 100);
      await _selectTab(tester, ShopItemType.soundPack);

      // This shelf was withdrawn for want of audio: every pack played the same
      // files, so equipping one changed nothing an ear could detect. It is
      // back because each pack now has its own folder of effects — the files
      // themselves are guarded by test/sound_pack_test.dart.
      expect(ShopData.sellableByType(ShopItemType.soundPack), hasLength(3));
      for (final item in ShopData.sellableByType(ShopItemType.soundPack)) {
        expect(find.text(item.name), findsOneWidget);
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

    testWidgets('an unaffordable item shows what it is and how far off it is',
        (tester) async {
      await _pumpShop(tester, totalStars: 5);

      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // This used to be a snackbar and nothing else, which meant the items
      // worth saving for were the only ones a learner could never look at:
      // the preview lives in this dialog and the dialog only opened once you
      // could already pay.
      expect(find.byType(ShopItemPreview), findsOneWidget);
      expect(find.text('10 more stars to go'), findsOneWidget); // 15 - 5
      expect(find.text('Buy!'), findsNothing,
          reason: 'nothing to confirm when the stars are not there');

      await tester.tap(find.text('Keep earning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('5'), findsOneWidget, reason: 'no stars were spent');

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

    // Material's default density gave the one button that spends stars a 58 dp
    // box, barely taller than the Cancel beside it. Learners aiming with a head
    // pointer, a switch or gaze use this dialog too.
    testWidgets('the button that spends the stars is big enough to hit',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);

      await tester.tap(find.text('Unicorn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final buy = tester.getSize(find.widgetWithText(FilledButton, 'Buy!'));
      final cancel = tester.getSize(find.widgetWithText(TextButton, 'Cancel'));

      expect(buy.height, greaterThanOrEqualTo(52.0),
          reason: 'Buy! is only ${buy.height} dp tall');
      expect(cancel.height, greaterThanOrEqualTo(52.0),
          reason: 'Cancel is only ${cancel.height} dp tall');
      // The confirming action must also read as the bigger of the two.
      expect(buy.width, greaterThan(cancel.width));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('10 pang bituin ang kailangan'), findsOneWidget);
      expect(find.text('Ipagpatuloy ang pagkolekta'), findsOneWidget);
      expect(find.textContaining('more stars'), findsNothing);

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

  group('What you are buying, before you buy it', () {
    // Every one of these was a purchase made blind: the dialog showed the
    // item's emoji at 56 px and nothing else, so a rainbow emoji stood in for
    // a profile frame, a firework emoji for a motion effect, and a gamepad
    // emoji for a whole set of sounds.

    testWidgets('a border is drawn on the learner own avatar', (tester) async {
      await _pumpShop(tester, totalStars: 100);
      await _selectTab(tester, ShopItemType.border);

      await tester.tap(find.text('Rainbow Border'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final preview = tester.widget<CosmeticAvatar>(
        find.descendant(
          of: find.byType(ShopItemPreview),
          matching: find.byType(CosmeticAvatar),
        ),
      );
      expect(preview.equippedBorderId, 'border_rainbow',
          reason: 'the point of a frame is what it looks like around a face');

      await _flushEntranceTimers(tester);
    });

    testWidgets('an avatar preview keeps the frame the learner already wears',
        (tester) async {
      await _pumpShop(
        tester,
        totalStars: 100,
        progress: () => FakeShopProgressNotifier(
          totalStars: 100,
          spentStars: 0,
          owned: {'border_crown'},
          equipped: {ShopItemType.border: 'border_crown'},
        ),
      );

      await tester.tap(find.text('Dragon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final preview = tester.widget<CosmeticAvatar>(
        find.descendant(
          of: find.byType(ShopItemPreview),
          matching: find.byType(CosmeticAvatar),
        ),
      );
      expect(preview.equippedAvatarId, 'avatar_dragon');
      expect(preview.equippedBorderId, 'border_crown',
          reason: 'a preview of a combination the learner will never see is '
              'not a preview');

      await _flushEntranceTimers(tester);
    });

    testWidgets('a title is previewed as the badge it becomes', (tester) async {
      await _pumpShop(tester, totalStars: 100);
      await _selectTab(tester, ShopItemType.title);

      await tester.tap(find.text('Word Wizard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(ShopItemPreview),
          matching: find.text('Word Wizard'),
        ),
        findsOneWidget,
      );

      await _flushEntranceTimers(tester);
    });

    testWidgets('an effect plays its own confetti, not the equipped one',
        (tester) async {
      await _pumpShop(tester, totalStars: 100);
      await _selectTab(tester, ShopItemType.celebration);

      await tester.tap(find.text('Snowfall'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final confetti = tester.widget<CelebrationConfetti>(
        find.descendant(
          of: find.byType(ShopItemPreview),
          matching: find.byType(CelebrationConfetti),
        ),
      );
      expect(confetti.style?.id, 'snowfall',
          reason: 'the preview must show the effect being sold, not whatever '
              'the learner has equipped today');

      await tester.tap(find.text('See it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_firstException(tester), isNull);

      await _flushEntranceTimers(tester);
    });

    testWidgets('reduced motion previews the calmed effect, not the burst',
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

      final confetti = tester.widget<CelebrationConfetti>(
        find.descendant(
          of: find.byType(ShopItemPreview),
          matching: find.byType(CelebrationConfetti),
        ),
      );
      expect(confetti.style?.id, 'fireworks-calm',
          reason: 'previewing a burst this learner will never be shown would '
              'be a lie the stars are spent on');

      await _flushEntranceTimers(tester);
    });

    testWidgets('a sound pack can be heard before it is bought',
        (tester) async {
      final sound = RecordingSoundService();
      await _pumpShop(tester, totalStars: 100, sound: sound);
      await _selectTab(tester, ShopItemType.soundPack);

      await tester.tap(find.text('Nature Pack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Hear it'));
      await tester.pump();
      // Two effects a beat apart: one sound is not enough to tell one pack
      // from another.
      await tester.pump(const Duration(milliseconds: 600));

      expect(sound.played, [
        (SoundEffect.correct, SoundPack.nature),
        (SoundEffect.starEarned, SoundPack.nature),
      ], reason: 'the preview must play the pack on the shelf, not the one '
          'the learner already owns');

      await _flushEntranceTimers(tester);
    });

    testWidgets('with Sound Effects off, the pack says so and stays silent',
        (tester) async {
      final sound = RecordingSoundService(enabled: false);
      await _pumpShop(
        tester,
        totalStars: 100,
        sound: sound,
        // The Hearing preset switches Sound Effects off, so this is the state
        // a Deaf learner opens the shop in.
        settings: const AppSettings(soundEffects: false),
      );
      await _selectTab(tester, ShopItemType.soundPack);

      await tester.tap(find.text('Chiptune Pack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Sound Effects are off'), findsOneWidget,
          reason: 'the same courtesy High Contrast gets about themes');

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Hear it'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull,
          reason: 'a button that plays nothing must look like one');
      expect(sound.played, isEmpty);

      await _flushEntranceTimers(tester);
    });
  });


  group('Hands free, every shelf can be reached', () {
    // Gaze and the Bluetooth D-pad fall back to Flutter's focus traversal on
    // any route that publishes no gaze grid, and the Star Shop is one. A card
    // with no focus node is therefore not merely awkward for a learner who
    // cannot touch the screen — it does not exist.

    /// Whether traversal has landed inside a card of type [T].
    bool focusedInside<T extends Widget>() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<T>() !=
        null;

    /// Steps traversal until [done], or gives up — bounded so a genuinely
    /// unreachable card fails the test instead of hanging it.
    Future<bool> traverseUntil(
      WidgetTester tester,
      bool Function() done, {
      int maxSteps = 40,
    }) async {
      if (!GazeFocusDriver.moveFirst()) return false;
      await tester.pump();
      for (var i = 0; i < maxSteps; i++) {
        if (done()) return true;
        if (!GazeFocusDriver.move(TraversalDirection.down)) return done();
        await tester.pump();
      }
      return done();
    }

    testWidgets('a theme card takes focus and equips on activate',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, owned: {'theme_ocean'});
      await _selectTab(tester, ShopItemType.theme);

      // Themes were the one shelf built from a bare GestureDetector, so this
      // walk used to run its full budget without ever landing on a card.
      final reached =
          await traverseUntil(tester, focusedInside<ThemePreviewCard>);
      expect(reached, isTrue,
          reason: 'focus traversal never reached a theme card, so gaze and '
              'the D-pad cannot either');

      expect(GazeFocusDriver.activate(), isTrue);
      await tester.pump();
      expect(find.text('Equipped'), findsOneWidget,
          reason: 'reaching a card is only half of it — it has to fire');

      await _flushEntranceTimers(tester);
    });

    testWidgets('the item shelves stay reachable too', (tester) async {
      await _pumpShop(tester, totalStars: 100, owned: {'avatar_unicorn'});

      final reached = await traverseUntil(tester, () => focusedInside<Card>());
      expect(reached, isTrue);

      expect(GazeFocusDriver.activate(), isTrue);
      await tester.pump();
      expect(find.text('Equipped'), findsOneWidget);

      await _flushEntranceTimers(tester);
    });
  });


  testWidgets('the item dialog survives the worst case on every shelf',
      (tester) async {
    // The dialog grew a preview, and for an item the learner cannot afford a
    // shortfall line under the price as well. AlertDialog does not scroll its
    // content by default, so every one of those additions is a chance to
    // overflow at the accessible font sizes — which is exactly where the
    // learners this shop is built for read it.
    await _pumpShop(
      tester,
      totalStars: 0,
      size: const Size(360, 640),
      devicePixelRatio: 3.0,
      textScale: 2.0,
      // Every advice line switched on at once: each adds a paragraph to the
      // dialog, and this is the tallest the content ever gets.
      settings: const AppSettings(
        highContrastMode: true,
        reducedMotion: true,
        soundEffects: false,
      ),
    );

    for (final type in ShopData.sellableTypes) {
      await _selectTab(tester, type);
      final item = ShopData.sellableByType(type).first;

      await tester.tap(find.text(item.name).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: '${item.id} did not open its dialog');

      expect(_overflowingFlexes(tester), isEmpty,
          reason: 'the ${type.name} dialog overflows at 2.0x on a 360x640 '
              'phone');
      expect(_firstException(tester), isNull);

      await tester.tap(find.text('Keep earning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await _flushEntranceTimers(tester);
  });


  testWidgets('buying an effect fires the effect you just bought',
      (tester) async {
    await _pumpShop(tester, totalStars: 100);
    await _selectTab(tester, ShopItemType.celebration);

    // The shop's own burst reads the *equipped* style, and buying does not
    // equip — so the one moment the app had to show a learner what 25 stars
    // bought them showed the standard confetti instead.
    final before = tester.widget<CelebrationConfetti>(
      find.descendant(
        of: find.byType(Align),
        matching: find.byType(CelebrationConfetti),
      ),
    );
    expect(before.style, isNull);

    await tester.tap(find.text('Rainbow Burst'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Buy!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final after = tester.widget<CelebrationConfetti>(
      find.descendant(
        of: find.byType(Align),
        matching: find.byType(CelebrationConfetti),
      ),
    );
    expect(after.style?.id, 'rainbow');

    await _flushEntranceTimers(tester);
  });


  group('The tab strip fits the bar it is in', () {
    /// Every tab label's painted rect.
    List<Rect> tabRects(WidgetTester tester) => [
          for (final type in ShopData.sellableTypes)
            tester.getRect(find.text(_labelOf(type)).first),
        ];

    testWidgets('no shelf is sliced off the edge on a tablet', (tester) async {
      // The Honor's 1200x1920 at dpr 1.75 — the device the regression was
      // found on, where a sixth shelf pushed "Effects" half off the screen.
      await _pumpShop(
        tester,
        totalStars: 100,
        size: const Size(686, 1097),
        devicePixelRatio: 1.75,
      );

      for (final rect in tabRects(tester)) {
        expect(rect.left, greaterThanOrEqualTo(-0.5),
            reason: 'a tab starts off the left edge');
        expect(rect.right, lessThanOrEqualTo(686.5),
            reason: 'a tab runs past the right edge — this is what sliced '
                '"Effects" in half once the Sounds shelf made six');
      }

      await _flushEntranceTimers(tester);
    });

    testWidgets('the six shelves share the bar evenly and sit centred',
        (tester) async {
      await _pumpShop(tester, totalStars: 100, size: const Size(686, 1097));

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.isScrollable, isFalse,
          reason: 'they fit, so they should fill the bar rather than scroll');
      expect(bar.tabAlignment, TabAlignment.fill);

      // Each tab's icon-plus-label sits centred in its own equal share of the
      // bar. Measured against the share rather than against the label edges:
      // the icon comes first, so a label's own rect always sits right of its
      // tab's centre by half an icon — that is the layout working, not a
      // misalignment.
      final shelves = ShopData.sellableTypes;
      final share = 686 / shelves.length;
      for (var i = 0; i < shelves.length; i++) {
        final content = tester.getRect(
          find
              .ancestor(
                of: find.text(_labelOf(shelves[i])),
                matching: find.byType(Row),
              )
              .first,
        );
        expect((content.center.dx - (i + 0.5) * share).abs(), lessThan(1.0),
            reason: '${_labelOf(shelves[i])} is not centred in its tab');
      }

      await _flushEntranceTimers(tester);
    });

    testWidgets('a font too big to fit scrolls instead of squeezing',
        (tester) async {
      await _pumpShop(
        tester,
        totalStars: 100,
        size: const Size(360, 640),
        devicePixelRatio: 3.0,
        textScale: 2.0,
      );

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.isScrollable, isTrue,
          reason: 'six shelves cannot fit 360 dp at 2.0x, and shrinking the '
              'text a learner enlarged is the wrong way to make them');
      expect(bar.tabAlignment, TabAlignment.start);
      expect(_firstException(tester), isNull);

      await _flushEntranceTimers(tester);
    });
  });

}
