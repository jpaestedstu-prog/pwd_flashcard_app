import 'package:confetti/confetti.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/core/services/celebration_style.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/features/shop/logic/shop_advice.dart';

/// The Star Shop was byte-identical for every learner, which is not the same
/// as fair. `main.dart`'s theme cascade puts High Contrast and Dyslexia-
/// friendly mode *above* a purchased shop theme, and Reduced Motion damps
/// every celebration — so a learner on one of those presets could spend real
/// stars on something their own settings suppress.
///
/// These tests pin the advice to the accessibility presets themselves, so if
/// a preset changes, the shop's advice is re-checked with it.

ShopItem _item(ShopItemType type) => ShopData.sellableByType(type).first;

void main() {
  group('adviceFor', () {
    test('warns when High Contrast will override a bought theme', () {
      const settings = AppSettings(highContrastMode: true);
      expect(
        adviceFor(_item(ShopItemType.theme), settings),
        ShopAdvice.themeOverriddenByContrast,
      );
    });

    test('warns when Dyslexia-friendly mode will override a bought theme', () {
      const settings = AppSettings(dyslexiaMode: true);
      expect(
        adviceFor(_item(ShopItemType.theme), settings),
        ShopAdvice.themeOverriddenByDyslexia,
      );
    });

    test('names high contrast first, matching the cascade in main.dart', () {
      const settings =
          AppSettings(highContrastMode: true, dyslexiaMode: true);
      expect(
        adviceFor(_item(ShopItemType.theme), settings),
        ShopAdvice.themeOverriddenByContrast,
      );
    });

    test('says nothing about themes when neither override is on', () {
      const settings = AppSettings();
      expect(adviceFor(_item(ShopItemType.theme), settings), ShopAdvice.none);
    });

    test('tells a reduced-motion learner effects will play gently', () {
      const settings = AppSettings(reducedMotion: true);
      expect(
        adviceFor(_item(ShopItemType.celebration), settings),
        ShopAdvice.effectPlaysGently,
      );
    });

    test('has nothing to say about avatars, borders or titles', () {
      const settings = AppSettings(
        highContrastMode: true,
        dyslexiaMode: true,
        reducedMotion: true,
      );
      for (final type in const [
        ShopItemType.avatar,
        ShopItemType.border,
        ShopItemType.title,
      ]) {
        expect(adviceFor(_item(type), settings), ShopAdvice.none,
            reason: '${type.name} is unaffected by these settings');
      }
    });
  });

  group('every accessibility preset gets honest advice', () {
    // The presets are the reason this exists: four of the six switch on a
    // setting that overrides a purchased theme.
    for (final type in DisabilityType.values) {
      test('${type.name} preset', () {
        final settings = AccessibilityPresets.presetFor(type);
        final themeAdvice = adviceFor(_item(ShopItemType.theme), settings);
        final overridden = settings.highContrastMode || settings.dyslexiaMode;

        expect(
          themeAdvice != ShopAdvice.none,
          overridden,
          reason: overridden
              ? '${type.name} overrides shop themes and must say so'
              : '${type.name} does not override themes, so stay quiet',
        );
      });
    }

    test('and four of the six really do override themes', () {
      final overriding = DisabilityType.values.where((t) {
        final s = AccessibilityPresets.presetFor(t);
        return s.highContrastMode || s.dyslexiaMode;
      }).toList();

      expect(overriding, hasLength(4),
          reason: 'visual, hearing, cognitive and multiple — if this changes, '
              'the advice rules should be revisited too');
    });
  });

  group('isRecommendedFor', () {
    test('points a reduced-motion learner at the calm effect', () {
      const settings = AppSettings(reducedMotion: true);
      final snow = ShopData.findById('celebration_snow')!;
      final fireworks = ShopData.findById('celebration_fireworks')!;

      expect(isRecommendedFor(snow, settings), isTrue);
      expect(isRecommendedFor(fireworks, settings), isFalse);
    });

    test('recommends nothing when no setting justifies it', () {
      const settings = AppSettings();
      for (final item in ShopData.allItems) {
        expect(isRecommendedFor(item, settings), isFalse);
      }
    });
  });

  group('reduced motion calms the confetti instead of deleting it', () {
    test('a calmed effect keeps its colours but loses its force', () {
      final rainbow = CelebrationStyle.forItemId('celebration_rainbow');
      final calm = rainbow.calmed();

      // The purchase must stay visible — this is the whole reason reduced
      // motion damps rather than suppresses.
      expect(calm.colors, rainbow.colors);
      expect(calm.numberOfParticles, lessThan(rainbow.numberOfParticles));
      expect(calm.maxBlastForce, lessThan(rainbow.maxBlastForce));
      expect(calm.gravity, lessThan(rainbow.gravity));
      expect(calm.directionality, BlastDirectionality.directional);
    });

    test('calming changes the id, so the particle system is rebuilt', () {
      final style = CelebrationStyle.forItemId('celebration_fireworks');
      expect(style.calmed().id, isNot(style.id));
    });

    test('every style can be calmed, including the default', () {
      for (final id in const [
        null,
        'celebration_fireworks',
        'celebration_rainbow',
        'celebration_snow',
      ]) {
        final calm = CelebrationStyle.forItemId(id).calmed();
        expect(calm.numberOfParticles, lessThanOrEqualTo(10));
        expect(calm.colors, isNotEmpty);
      }
    });
  });
}
