import 'package:flutter/foundation.dart';

import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../models/object_scan_models.dart';

/// Maps raw ML Kit image-labeling output to vocabulary flashcards.
///
/// Resolution order:
/// 1. Case-insensitive match against a card's `wordEnglish` ("Chair" → Chair).
/// 2. Curated alias table for ML Kit label names that differ from our
///    vocabulary ("Footwear" → Shoes, "Mobile phone" → Phone).
///
/// Pure Dart on top of [SeedData] — no camera or ML Kit imports — so the
/// mapping is fully unit-testable.
class LabelWordMapper {
  LabelWordMapper._();

  /// Lowercased `wordEnglish` → seed card. Built once. When two seed cards
  /// share a word (e.g. Chicken appears in Animals and Food), the earlier
  /// category wins — for a camera pointed at the world, the animal reading
  /// is the more likely one.
  static final Map<String, Flashcard> _byEnglish = {
    for (final card in SeedData.allFlashcards.reversed)
      card.wordEnglish.toLowerCase(): card,
  };

  /// ML Kit base-model label (lowercased) → vocabulary `wordEnglish`.
  /// Unknown keys are harmless; they simply never fire.
  @visibleForTesting
  static const Map<String, String> aliases = {
    // ── Clothing ──
    'footwear': 'Shoes',
    'shoe': 'Shoes',
    'sandal': 'Shoes',
    'sneakers': 'Shoes',
    'boot': 'Shoes',
    'jeans': 'Pants',
    'trousers': 'Pants',
    'hat': 'Cap',
    'sun hat': 'Cap',
    'sunglasses': 'Glasses',
    'eyewear': 'Glasses',
    'goggles': 'Glasses',
    'glove': 'Gloves',
    'jersey': 'T-shirt',
    'shirt': 'T-shirt',
    'outerwear': 'Jacket',
    'blazer': 'Jacket',
    'sweater': 'Jacket',
    'hoodie': 'Jacket',
    'gown': 'Dress',
    'sock': 'Socks',
    'bag': 'Backpack',
    'handbag': 'Backpack',
    'luggage and bags': 'Backpack',
    'satchel': 'Backpack',
    // ── Animals ──
    'puppy': 'Dog',
    'kitten': 'Cat',
    'cattle': 'Cow',
    'dairy cow': 'Cow',
    'rooster': 'Chicken',
    'hen': 'Chicken',
    'bunny': 'Rabbit',
    'moths and butterflies': 'Butterfly',
    'pony': 'Horse',
    'goldfish': 'Fish',
    // ── Transportation ──
    'vehicle': 'Car',
    'van': 'Car',
    'sports car': 'Car',
    'aircraft': 'Airplane',
    'plane': 'Airplane',
    'watercraft': 'Boat',
    'bike': 'Bicycle',
    'moped': 'Motorcycle',
    // ── Food, drinks & tableware ──
    'water bottle': 'Bottle',
    'plastic bottle': 'Bottle',
    'mug': 'Cup',
    'coffee cup': 'Cup',
    'teacup': 'Cup',
    'drinkware': 'Cup',
    'cutlery': 'Spoon',
    'tableware': 'Plate',
    'dishware': 'Plate',
    'vegetable': 'Vegetables',
    'salad': 'Vegetables',
    'loaf': 'Bread',
    'baked goods': 'Bread',
    'bun': 'Bread',
    // ── Classroom & household objects ──
    'desk': 'Table',
    'publication': 'Book',
    'novel': 'Book',
    'paper product': 'Paper',
    'football': 'Ball',
    'soccer ball': 'Ball',
    'basketball': 'Ball',
    'volleyball': 'Ball',
    'tennis ball': 'Ball',
    'mobile phone': 'Phone',
    'telephone': 'Phone',
    'smartphone': 'Phone',
    'cellphone': 'Phone',
    'television set': 'Television',
    'tv': 'Television',
    'petal': 'Flower',
    'bouquet': 'Flower',
    'watch': 'Clock',
    'wall clock': 'Clock',
    'alarm clock': 'Clock',
    // ── Body & weather ──
    'hand': 'Hands',
    'rain': 'Rainy',
    'rainbow': 'Rainbow',
  };

  /// ML Kit base-model labels that already *are* one of our vocabulary words,
  /// so they need no alias entry. They exist as an explicit list anyway
  /// because [huntableCards] — the "words the camera knows" the collection
  /// screen counts against and draws its hunt targets from — cannot be
  /// derived from [aliases] alone.
  ///
  /// Deliberately conservative: a word listed here that the model never emits
  /// becomes an unreachable hunt target, which is worse than omitting it. Every
  /// entry must resolve to a seed card (enforced by test).
  @visibleForTesting
  static const List<String> selfLabels = [
    // ── Animals ──
    'Bird', 'Butterfly', 'Cat', 'Chicken', 'Cow', 'Dog',
    'Elephant', 'Fish', 'Frog', 'Horse', 'Pig', 'Rabbit',
    // ── Food & drinks ──
    'Apple', 'Banana', 'Bread', 'Juice', 'Soup',
    // ── Classroom & household ──
    'Ball', 'Book', 'Chair', 'Door', 'Paper', 'Pencil',
    'Scissors', 'Table', 'Television', 'Window',
    // ── Tableware ──
    'Bottle', 'Cup', 'Fork', 'Plate', 'Spoon',
    // ── Transportation ──
    'Airplane', 'Bicycle', 'Boat', 'Bus', 'Car',
    'Helicopter', 'Motorcycle', 'Ship', 'Taxi', 'Train',
    // ── Clothing ──
    'Backpack', 'Dress', 'Glasses', 'Jacket', 'Shorts',
    // ── Nature & time ──
    'Clock', 'Flower', 'Lightning', 'Rainbow',
  ];

  /// Every vocabulary card Word Hunt can actually produce: the [aliases]
  /// targets plus [selfLabels], deduped and kept in seed order so the
  /// collection reads the same way as the rest of the app.
  ///
  /// This is the honest denominator for "N of M found" — the app's full
  /// vocabulary includes words no camera can see (Monday, Sorry, Proud).
  static final List<Flashcard> huntableCards = _buildHuntable();

  static List<Flashcard> _buildHuntable() {
    final ids = <String>{};
    for (final word in [...aliases.values, ...selfLabels]) {
      final card = _byEnglish[word.toLowerCase()];
      if (card != null) ids.add(card.id);
    }
    return [
      for (final card in SeedData.allFlashcards)
        if (ids.remove(card.id)) card,
    ];
  }

  /// Ids of [huntableCards], for membership tests.
  static final Set<String> huntableCardIds = {
    for (final card in huntableCards) card.id,
  };

  /// True when the camera is taught to recognize this card at all — used to
  /// keep a discovery made before a vocabulary change from inflating the
  /// collection's denominator.
  static bool isHuntable(String cardId) => huntableCardIds.contains(cardId);

  /// Resolves one raw label to a flashcard, or null when the object is not
  /// part of the vocabulary.
  static WordMatch? match(String label, {double confidence = 1.0}) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final card =
        _byEnglish[normalized] ??
        _byEnglish[aliases[normalized]?.toLowerCase()];
    if (card == null) return null;
    return WordMatch(card: card, sourceLabel: label, confidence: confidence);
  }

  /// Resolves a frame's labels to vocabulary matches, deduped per card
  /// (highest confidence wins) and sorted by confidence, best first.
  static List<WordMatch> matchAll(Iterable<RecognizedLabel> labels) {
    final best = <String, WordMatch>{};
    for (final raw in labels) {
      final m = match(raw.label, confidence: raw.confidence);
      if (m == null) continue;
      final existing = best[m.card.id];
      if (existing == null || m.confidence > existing.confidence) {
        best[m.card.id] = m;
      }
    }
    return best.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }
}
