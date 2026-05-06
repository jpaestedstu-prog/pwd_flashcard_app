import 'package:flutter/material.dart';
import '../core/constants/flashcard_emojis.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';

/// A reusable widget that renders a visual representation of a flashcard.
///
/// Priority order:
/// 1. If [Flashcard.imageAsset] is set → show the asset image
/// 2. Otherwise → show the mapped emoji in a styled container
///
/// Use this everywhere a flashcard "picture" is needed: viewer, games,
/// daily challenge, smart review, etc.
class FlashcardImage extends StatelessWidget {
  /// The flashcard to visualise.
  final Flashcard card;

  /// Emoji / icon size. The container will be slightly larger.
  final double size;

  /// Background colour override (defaults to category colour at 10% opacity).
  final Color? backgroundColor;

  /// Border radius of the container.
  final double borderRadius;

  /// Whether to show a subtle border around the container.
  final bool showBorder;

  const FlashcardImage({
    super.key,
    required this.card,
    this.size = 72,
    this.backgroundColor,
    this.borderRadius = 24,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    // If an actual image asset is provided, use it.
    if (card.imageAsset != null && card.imageAsset!.isNotEmpty) {
      // Decode at 2× the logical size to look sharp on high-DPI screens
      // while preventing the decoder from allocating a full-resolution
      // bitmap for small thumbnails (saves significant GPU memory).
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheExtent = (size * 1.6 * devicePixelRatio).ceil();

      return RepaintBoundary(
        child: Semantics(
          image: true,
          label: '${card.wordEnglish}, ${card.wordFilipino}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            // Clip.hardEdge is cheaper than antiAlias and
            // indistinguishable at 1920×1200 density.
            clipBehavior: Clip.hardEdge,
            child: Image.asset(
              card.imageAsset!,
              width: size * 1.6,
              height: size * 1.6,
              fit: BoxFit.cover,
              cacheWidth: cacheExtent,
              cacheHeight: cacheExtent,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => _buildEmoji(),
            ),
          ),
        ),
      );
    }

    return Semantics(
      image: true,
      label: '${card.wordEnglish}, ${card.wordFilipino}',
      child: _buildEmoji(),
    );
  }

  Widget _buildEmoji() {
    final emoji = FlashcardEmojis.forId(card.id);
    final catColor = card.category.color;
    final bg = backgroundColor ?? catColor.withValues(alpha: 0.12);
    final containerSize = size * 1.6;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: catColor.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size, height: 1.15),
      ),
    );
  }
}

/// A compact variant for use in grids, game tiles, and smaller contexts.
class FlashcardImageSmall extends StatelessWidget {
  final Flashcard card;
  final double size;

  const FlashcardImageSmall({
    super.key,
    required this.card,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return FlashcardImage(
      card: card,
      size: size,
      borderRadius: 12,
    );
  }
}

/// Just the emoji text, no container. Useful inline.
class FlashcardEmoji extends StatelessWidget {
  final String cardId;
  final double fontSize;

  const FlashcardEmoji({
    super.key,
    required this.cardId,
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      FlashcardEmojis.forId(cardId),
      style: TextStyle(fontSize: fontSize, height: 1.15),
    );
  }
}
