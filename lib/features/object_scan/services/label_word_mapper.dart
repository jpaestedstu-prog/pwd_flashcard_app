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

  /// Resolves one raw label to a flashcard, or null when the object is not
  /// part of the vocabulary.
  static WordMatch? match(String label, {double confidence = 1.0}) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final card =
        _byEnglish[normalized] ?? _byEnglish[aliases[normalized]?.toLowerCase()];
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
