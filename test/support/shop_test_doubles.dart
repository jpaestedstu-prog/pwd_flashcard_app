import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Shared fixtures for the Star Shop suites.
///
/// Split across two files on purpose: `shop_screen_test.dart` drives the
/// widget, and `shop_refund_test.dart` exercises the refund against real Hive.
/// They cannot live together — a `box.put` started inside `testWidgets`'
/// fake-async zone never drains, and Hive serialises writes, so any later
/// `await box.put` in the same file blocks until the per-test timeout.
const String kShopProfileId = 'shop-test-profile';

/// Fixed profile so `ProgressNotifier.profileId` — the key every purchase and
/// equipped-item row hangs off — is stable across pumps.
class StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: kShopProfileId,
        name: 'Test Learner',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

/// Controls the star wallet without going through `HiveService.getProgress`
/// (and its memo cache). Everything else — `hasPurchased`, `equipItem`,
/// `purchaseItem`, `refundWithdrawnPurchases` — stays the real implementation
/// reading the real box, so the states under test are the ones the app
/// computes.
class StubProgressNotifier extends ProgressNotifier {
  StubProgressNotifier({required this.totalStars, required this.spentStars});

  final int totalStars;
  final int spentStars;

  @override
  LearningProgress build() {
    profileId = kShopProfileId;
    return LearningProgress(
      profileId: kShopProfileId,
      lastActivityDate: DateTime(2026),
      totalStars: totalStars,
      spentStars: spentStars,
    );
  }
}

/// Pins the app language so the shop's item names (catalogue data, not ARB)
/// resolve to the locale under test.
class StubSettingsNotifier extends SettingsNotifier {
  StubSettingsNotifier({this.locale = 'en', this.settings});

  final String locale;

  /// Accessibility flags to apply on top of the locale, for the shop's
  /// settings-driven advice.
  final AppSettings? settings;

  @override
  AppSettings build() =>
      (settings ?? const AppSettings()).copyWith(locale: locale);
}

/// A progress notifier whose inventory lives in memory instead of Hive.
///
/// Widget tests must not write to Hive. A `box.put` started inside
/// `testWidgets`' fake-async zone never drains, and Hive serialises writes, so
/// the first equip in a file blocks every later `await box.put` — including the
/// seed of the next test, which then hangs until the per-test timeout. Keeping
/// the widget tests off storage entirely removes the hazard rather than
/// tiptoeing around it; persistence is covered for real, in the real async
/// zone, by `shop_refund_test.dart`.
///
/// The logic mirrors [ProgressNotifier]: you cannot equip what you do not own,
/// buying costs stars, and a state bump on equip is what makes dependent
/// providers (e.g. the celebration style) re-read.
class FakeShopProgressNotifier extends StubProgressNotifier {
  FakeShopProgressNotifier({
    required super.totalStars,
    required super.spentStars,
    Set<String>? owned,
    Map<ShopItemType, String>? equipped,
  })  : _owned = {...?owned},
        _equipped = {...?equipped};

  final Set<String> _owned;
  final Map<ShopItemType, String> _equipped;

  @override
  bool hasPurchased(String itemId) => _owned.contains(itemId);

  @override
  Set<String> get purchasedItems => _owned;

  @override
  bool purchaseItem(String itemId, int cost) {
    if (_owned.contains(itemId)) return false;
    if (state.starBalance < cost) return false;
    _owned.add(itemId);
    state = state.copyWith(spentStars: state.spentStars + cost);
    return true;
  }

  @override
  bool equipItem(String itemId, ShopItemType type) {
    if (!hasPurchased(itemId)) return false;
    _equipped[type] = itemId;
    state = state.copyWith();
    return true;
  }

  @override
  void unequipItem(ShopItemType type) {
    _equipped.remove(type);
    state = state.copyWith();
  }

  @override
  String? getEquippedItemId(ShopItemType type) => _equipped[type];

  @override
  int refundWithdrawnPurchases() {
    final toRefund = _owned.intersection(ShopData.withdrawnIds);
    var refunded = 0;
    for (final id in toRefund) {
      final item = ShopData.findById(id);
      if (item == null) continue;
      refunded += item.cost;
      _owned.remove(id);
      if (_equipped[item.type] == id) _equipped.remove(item.type);
    }
    if (refunded == 0) return 0;
    state = state.copyWith(
      spentStars: (state.spentStars - refunded).clamp(0, state.spentStars),
    );
    return refunded;
  }
}
