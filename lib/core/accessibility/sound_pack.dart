import '../../data/models/shop_data.dart';

/// Which set of sound effects the app plays.
///
/// This is what a Sound Pack from the Star Shop actually buys. The three packs
/// shipped withdrawn from sale (`ShopItem.available == false`) because
/// `assets/sounds/` held exactly one set of effects: equipping a pack changed
/// nothing an ear could detect, so the stars bought silence and
/// `refundWithdrawnPurchases` had to give them back.
///
/// Each pack now has its own folder of all eight effects, synthesised by
/// `tool/generate_sounds.dart` in a timbre nobody could mistake for another —
/// square-wave arpeggios, bird glides and water, detuned sweeps with an echo
/// tail. Which matters most for a learner with a visual impairment: every
/// other shelf in the shop sells something they cannot see, and this is the
/// one that answers to them.
enum SoundPack {
  /// The effects every learner starts with, straight out of `assets/sounds/`.
  classic(itemId: null, folder: null),

  chiptune(itemId: 'sound_chiptune', folder: 'chiptune'),
  nature(itemId: 'sound_nature', folder: 'nature'),
  space(itemId: 'sound_space', folder: 'space');

  const SoundPack({required this.itemId, required this.folder});

  /// The [ShopItem.id] that equips this pack, or null for [classic] — which is
  /// not purchasable, it is what you have before you buy anything.
  final String? itemId;

  /// Subfolder of `assets/sounds/`, or null for the files at its root.
  final String? folder;

  /// The pack equipped by [itemId], or [classic] for null and for any id this
  /// build does not know.
  ///
  /// An unknown id is reachable in normal use: equipped rows sync between a
  /// learner's devices, so an older build can be handed the id of a pack added
  /// later. Falling back to [classic] means it plays the standard effects
  /// rather than pointing at a folder that isn't there and playing nothing.
  static SoundPack forItemId(String? itemId) {
    if (itemId == null) return classic;
    for (final pack in values) {
      if (pack.itemId == itemId) return pack;
    }
    return classic;
  }

  /// The catalogue entry that sells this pack, or null for [classic].
  ShopItem? get shopItem => itemId == null ? null : ShopData.findById(itemId!);
}
