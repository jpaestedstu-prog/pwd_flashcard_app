import 'package:flutter/material.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// A pre-built bundle of bilingual flashcards an educator or parent can
/// clone into their custom deck in one tap. Mirrors the AAC
/// communication-board template pattern.
///
/// Templates ship as static seed data — no backend needed. Cloning a
/// template materializes its cards into the user's Hive custom-cards
/// box via `HiveService.saveCustomCard`, so they show up alongside
/// hand-authored cards.
class DeckTemplate {
  /// Stable slug used as the per-card id prefix when cloning.
  final String id;

  /// English template name (e.g. "Sight Words K-2").
  final String name;

  /// Filipino template name.
  final String nameFil;

  /// One-line description shown on the picker card.
  final String description;
  final String descriptionFil;

  /// Material icon shown on the picker card.
  final IconData icon;

  /// Tint colour for the picker card header.
  final Color color;

  /// Which existing [FlashcardCategory] cloned cards are filed under —
  /// reuses the existing category infrastructure (icons, sorting, game
  /// integration) instead of inventing a new taxonomy.
  final FlashcardCategory category;

  /// The bilingual card stubs that will be materialized when cloned.
  /// `id` is filled in at clone time so re-clones produce unique cards.
  final List<DeckTemplateCard> cards;

  const DeckTemplate({
    required this.id,
    required this.name,
    required this.nameFil,
    required this.description,
    required this.descriptionFil,
    required this.icon,
    required this.color,
    required this.category,
    required this.cards,
  });

  int get cardCount => cards.length;
}

/// A card stub inside a template — has no id until cloned.
class DeckTemplateCard {
  final String wordEnglish;
  final String wordFilipino;
  final String? exampleSentence;

  const DeckTemplateCard({
    required this.wordEnglish,
    required this.wordFilipino,
    this.exampleSentence,
  });

  /// Materialize this stub into a [Flashcard] with the supplied id.
  Flashcard toFlashcard({required String id, required FlashcardCategory category}) {
    return Flashcard(
      id: id,
      wordEnglish: wordEnglish,
      wordFilipino: wordFilipino,
      exampleSentence: exampleSentence,
      category: category,
      isCustom: true,
    );
  }
}
