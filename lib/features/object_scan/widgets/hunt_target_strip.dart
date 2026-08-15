import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/flashcard_image.dart';

/// "Try to find: 🪑 Chair · 📖 Book · 🍎 Apple" — a short list of words the
/// learner has not collected yet, shown over the camera and again when a photo
/// turns up nothing.
///
/// Word Hunt used to be open-ended: point the camera anywhere and hope. That
/// is hard to act on — especially for a learner who needs a concrete next
/// step — and a "nothing found" result was a dead end. These targets turn the
/// feature into a scavenger hunt with a visible goal.
///
/// Purely presentational (no camera, no ML), so it is widget- and
/// overflow-testable. It always renders on a dark backdrop, so the type is
/// white either way.
class HuntTargetStrip extends StatelessWidget {
  final List<Flashcard> targets;

  const HuntTargetStrip({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.wordHuntTargets,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Wrap, not Row: at a large text scale three words do not fit on one
          // line, and a Row would overflow rather than reflow.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final card in targets) _TargetChip(card: card)],
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final Flashcard card;
  const _TargetChip({required this.card});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${card.wordEnglish}, ${card.wordFilipino}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlashcardPicture(card: card, extent: 26, borderRadius: 8),
            const SizedBox(width: 8),
            Text(
              card.wordEnglish,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
