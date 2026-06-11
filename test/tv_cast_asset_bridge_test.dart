import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_asset_bridge.dart';

/// Guards the category-visual fields the redesigned TV flashcard reads. The
/// TV-side `renderFlashcards` in `app.js` paints the accent strip, badge, and
/// picture tile from `catColor` / `catColorDark` (applied inline because the
/// TV CSS avoids `var()`), plus `catLabel` / `catEmoji` — so a missing or
/// malformed field silently breaks the card on every connected TV.
void main() {
  group('TvCastAssetBridge.categoryVisual', () {
    final hex = RegExp(r'^#[0-9a-f]{6}$');

    test('every category yields all four keys', () {
      for (final cat in FlashcardCategory.values) {
        final v = TvCastAssetBridge.categoryVisual(cat);
        expect(v.keys, containsAll(['catLabel', 'catEmoji', 'catColor', 'catColorDark']));
        expect(v['catLabel'], isNotEmpty);
        expect(v['catEmoji'], isNotEmpty);
      }
    });

    test('colours are lowercase #RRGGBB hex', () {
      for (final cat in FlashcardCategory.values) {
        final v = TvCastAssetBridge.categoryVisual(cat);
        expect(v['catColor'], matches(hex), reason: '$cat catColor');
        expect(v['catColorDark'], matches(hex), reason: '$cat catColorDark');
      }
    });

    test('label matches the in-app category label', () {
      expect(
        TvCastAssetBridge.categoryVisual(FlashcardCategory.animals)['catLabel'],
        FlashcardCategory.animals.label,
      );
    });

    test('hex conversion is exact for a known category colour', () {
      // Animals = Color(0xFFFFCC80) pastel, darkColor = Color(0xFFE65100).
      final v = TvCastAssetBridge.categoryVisual(FlashcardCategory.animals);
      expect(v['catColor'], '#ffcc80');
      expect(v['catColorDark'], '#e65100');
    });
  });
}
