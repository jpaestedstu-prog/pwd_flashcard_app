import '../../../data/models/models.dart';
import '../../../data/models/shop_data.dart';

/// What a learner's own accessibility settings mean for a shop item.
///
/// The Star Shop used to be byte-identical for every learner, which sounds
/// fair and isn't: the app's own theme cascade puts High Contrast and
/// Dyslexia-friendly mode *above* a purchased shop theme (see `main.dart`), so
/// a learner with either switched on can spend 50 stars on Galaxy Theme and
/// watch nothing change. Four of the six accessibility presets turn one of
/// them on. Reduced Motion, likewise, damps every Celebration Effect.
///
/// So the shop says so, before the stars are spent.
///
/// Two rules govern this file:
///
///  * **Nothing is ever hidden.** Almost every item in the catalogue is
///    visual; filtering by disability would empty the shop for the learners it
///    claims to serve, and a setting the learner can turn off at any moment is
///    no basis for withholding something they earned. Advice informs, it does
///    not gate.
///  * **The trigger is a setting, never a diagnosis.** What matters is that
///    High Contrast is on right now — not which preset happened to switch it
///    on, and not what the profile's disability type says about the person.
enum ShopAdvice {
  /// Nothing worth saying.
  none,

  /// A theme that the learner's High Contrast setting will override.
  themeOverriddenByContrast,

  /// A theme that the learner's Dyslexia-friendly setting will override.
  themeOverriddenByDyslexia,

  /// A celebration effect that Reduced Motion will play gently.
  effectPlaysGently,
}

/// The advice for [item] given [settings], or [ShopAdvice.none].
ShopAdvice adviceFor(ShopItem item, AppSettings settings) {
  switch (item.type) {
    case ShopItemType.theme:
      // Order matches the cascade in main.dart: high contrast wins first.
      if (settings.highContrastMode) return ShopAdvice.themeOverriddenByContrast;
      if (settings.dyslexiaMode) return ShopAdvice.themeOverriddenByDyslexia;
      return ShopAdvice.none;

    case ShopItemType.celebration:
      return settings.reducedMotion
          ? ShopAdvice.effectPlaysGently
          : ShopAdvice.none;

    case ShopItemType.avatar:
    case ShopItemType.border:
    case ShopItemType.title:
    case ShopItemType.soundPack:
      return ShopAdvice.none;
  }
}

/// Whether [item] is a particularly good fit for how this learner has the app
/// set up — surfaced as a quiet "Recommended" badge, never as a filter.
///
/// Kept to cases the settings actually justify. Snowfall is the one effect
/// designed to be calm, so it is the one worth pointing at when a learner has
/// asked the whole app to move less.
bool isRecommendedFor(ShopItem item, AppSettings settings) =>
    settings.reducedMotion && item.id == 'celebration_snow';
