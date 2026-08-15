import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';

void main() {
  group('ShopData', () {
    test('allItems is not empty', () {
      expect(ShopData.allItems, isNotEmpty);
    });

    test('all items have unique IDs', () {
      final ids = ShopData.allItems.map((i) => i.id).toSet();
      expect(ids.length, ShopData.allItems.length);
    });

    test('all items have non-empty names', () {
      for (final item in ShopData.allItems) {
        expect(item.name, isNotEmpty, reason: '${item.id} missing name');
      }
    });

    test('all items have positive cost', () {
      for (final item in ShopData.allItems) {
        expect(item.cost, greaterThan(0),
            reason: '${item.id} should have positive cost');
      }
    });

    test('byType filters correctly', () {
      final avatars = ShopData.byType(ShopItemType.avatar);
      for (final a in avatars) {
        expect(a.type, ShopItemType.avatar);
      }

      final themes = ShopData.byType(ShopItemType.theme);
      for (final t in themes) {
        expect(t.type, ShopItemType.theme);
      }

      final borders = ShopData.byType(ShopItemType.border);
      for (final b in borders) {
        expect(b.type, ShopItemType.border);
      }
    });

    test('byType covers all items', () {
      int total = 0;
      for (final type in ShopItemType.values) {
        total += ShopData.byType(type).length;
      }
      expect(total, ShopData.allItems.length);
    });

    test('findById returns correct item', () {
      for (final item in ShopData.allItems) {
        final found = ShopData.findById(item.id);
        expect(found, isNotNull);
        expect(found!.id, item.id);
        expect(found.name, item.name);
      }
    });

    test('findById returns null for unknown ID', () {
      expect(ShopData.findById('nonexistent_id'), isNull);
    });

    test('all avatar items have emoji', () {
      for (final item in ShopData.byType(ShopItemType.avatar)) {
        expect(item.emoji, isNotEmpty,
            reason: '${item.id} should have an emoji');
      }
    });

    test('all theme items have color', () {
      for (final item in ShopData.byType(ShopItemType.theme)) {
        expect(item.color, isNotNull,
            reason: '${item.id} should have a color');
      }
    });
  });

  group('ShopData — Filipino', () {
    test('every item is translated', () {
      for (final item in ShopData.allItems) {
        expect(item.nameFilipino, isNotEmpty,
            reason: '${item.id} has no Filipino name');
        expect(item.descriptionFilipino, isNotEmpty,
            reason: '${item.id} has no Filipino description');
      }
    });

    test('localizedName and localizedDescription follow the language', () {
      final shark = ShopData.findById('avatar_shark')!;
      expect(shark.localizedName(false), 'Shark');
      expect(shark.localizedName(true), 'Pating');
      expect(shark.localizedDescription(true), startsWith('Isang'));
    });

    test('an untranslated item falls back to English rather than blank', () {
      const untranslated = ShopItem(
        id: 'test_item',
        name: 'Test Item',
        description: 'A test item',
        cost: 10,
        type: ShopItemType.avatar,
        emoji: '🧪',
        color: Color(0xFF000000),
      );

      expect(untranslated.localizedName(true), 'Test Item');
      expect(untranslated.localizedDescription(true), 'A test item');
    });
  });
}
