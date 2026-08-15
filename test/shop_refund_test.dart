import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/shop_test_doubles.dart';

/// Refund behaviour for shop items that have been withdrawn from sale.
///
/// Sound Packs were sold for 20–30 stars while `assets/sounds/` held no
/// per-pack audio, so equipping one changed nothing. Withdrawing them without
/// refunding would just delete something a learner had earned; this is the
/// code that makes the correction whole.
///
/// Deliberately a plain `test()` suite with no widget tests in the file. Hive
/// serialises writes, and a `box.put` started inside `testWidgets`' fake-async
/// zone never drains — one widget test in here would wedge every `await
/// box.put` below it until the per-test timeout. See
/// `test/support/shop_test_doubles.dart`.
const String _kStoreDir = './build/test_cache/shop_refund';

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
    await Hive.box('progress').clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  ProviderContainer containerWith({
    required int totalStars,
    required int spentStars,
  }) {
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(StubProfileNotifier.new),
        progressProvider.overrideWith(
          () => StubProgressNotifier(
            totalStars: totalStars,
            spentStars: spentStars,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Withdrawn items', () {
    test('sound packs are the withdrawn set, and nothing else is', () {
      expect(ShopData.withdrawnIds, {
        'sound_chiptune',
        'sound_nature',
        'sound_space',
      });
      for (final type in ShopData.sellableTypes) {
        for (final item in ShopData.sellableByType(type)) {
          expect(item.available, isTrue);
        }
      }
    });

    test('a category with nothing on sale is not a sellable category', () {
      expect(ShopData.sellableTypes, isNot(contains(ShopItemType.soundPack)));
      expect(ShopData.sellableTypes, contains(ShopItemType.celebration));
      expect(ShopData.byType(ShopItemType.soundPack), hasLength(3),
          reason: 'withdrawn items stay in the catalogue so owners can be '
              'refunded by id and re-enabling is a one-word change');
    });
  });

  group('refundWithdrawnPurchases', () {
    test('returns the stars, drops the item and unequips it', () async {
      final box = Hive.box('progress');
      await box.put('purchases_$kShopProfileId', ['sound_chiptune']); // 20★
      await box.put('equipped_soundPack_$kShopProfileId', 'sound_chiptune');

      // 100 earned, 20 spent on a pack that has since been withdrawn.
      final container = containerWith(totalStars: 100, spentStars: 20);
      final notifier = container.read(progressProvider.notifier);

      expect(notifier.refundWithdrawnPurchases(), 20);
      expect(container.read(progressProvider).starBalance, 100);
      expect(notifier.hasPurchased('sound_chiptune'), isFalse);
      expect(
        notifier.getEquippedItemId(ShopItemType.soundPack),
        isNull,
        reason:
            'a profile must not keep pointing at something it no longer owns',
      );
    });

    test('moves spentStars only, never lifetime earnings', () async {
      await Hive.box('progress')
          .put('purchases_$kShopProfileId', ['sound_chiptune']);

      final container = containerWith(totalStars: 100, spentStars: 20);
      container.read(progressProvider.notifier).refundWithdrawnPurchases();

      // totalStars drives XP and levels, so refunding through it would hand
      // out free progress and could de-level a learner on the way back.
      expect(container.read(progressProvider).totalStars, 100);
      expect(container.read(progressProvider).spentStars, 0);
    });

    test('refunds every withdrawn item at once, leaving the rest alone',
        () async {
      await Hive.box('progress').put(
        'purchases_$kShopProfileId',
        ['sound_chiptune', 'sound_space', 'avatar_unicorn'],
      );

      final container = containerWith(totalStars: 100, spentStars: 65);
      final notifier = container.read(progressProvider.notifier);

      expect(notifier.refundWithdrawnPurchases(), 50); // 20 + 30
      expect(notifier.hasPurchased('avatar_unicorn'), isTrue,
          reason: 'items still on sale are untouched');
      expect(notifier.hasPurchased('sound_space'), isFalse);
    });

    test('is a no-op for a learner who owns nothing withdrawn', () async {
      await Hive.box('progress')
          .put('purchases_$kShopProfileId', ['avatar_unicorn']);

      final container = containerWith(totalStars: 100, spentStars: 15);
      expect(
        container.read(progressProvider.notifier).refundWithdrawnPurchases(),
        0,
      );
      expect(container.read(progressProvider).starBalance, 85);
    });

    test('is a no-op for a learner who owns nothing at all', () {
      final container = containerWith(totalStars: 40, spentStars: 0);
      expect(
        container.read(progressProvider.notifier).refundWithdrawnPurchases(),
        0,
      );
      expect(container.read(progressProvider).starBalance, 40);
    });

    test('running twice refunds once', () async {
      await Hive.box('progress')
          .put('purchases_$kShopProfileId', ['sound_chiptune']);

      final container = containerWith(totalStars: 100, spentStars: 20);
      final notifier = container.read(progressProvider.notifier);

      expect(notifier.refundWithdrawnPurchases(), 20);
      expect(notifier.refundWithdrawnPurchases(), 0,
          reason: 'the shop calls this on every visit');
      expect(container.read(progressProvider).starBalance, 100);
    });
  });
}
