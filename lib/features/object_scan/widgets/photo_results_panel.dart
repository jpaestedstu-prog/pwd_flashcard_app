import 'package:flutter/material.dart';

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../models/object_scan_models.dart';

/// Bottom panel shown over a captured photo: the vocabulary words found in
/// it as large tap targets, or a friendly "nothing found" message, plus a
/// big Retake button. Purely presentational (no camera/ML dependencies) so
/// it is widget- and overflow-testable.
///
/// Sized for PWD students: word rows are ≥72 dp tall with large type, and
/// the retake button is ≥56 dp.
class PhotoResultsPanel extends StatelessWidget {
  final List<WordMatch> matches;

  /// True while the photo is still being analyzed.
  final bool searching;
  final void Function(WordMatch) onWordTap;
  final VoidCallback onRetake;

  const PhotoResultsPanel({
    super.key,
    required this.matches,
    required this.searching,
    required this.onWordTap,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (searching) ...[
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.white),
            ),
            Text(
              l10n.wordHuntLooking,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              matches.isEmpty ? l10n.wordHuntNoneFound : l10n.wordHuntFoundWords,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final match in matches) ...[
              _WordCard(match: match, onTap: onWordTap),
              const SizedBox(height: 8),
            ],
            Semantics(
              button: true,
              label: l10n.wordHuntRetake,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bannerWordHuntStart,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onRetake,
                  icon: const Icon(Icons.camera_alt_rounded, size: 26),
                  label: Text(l10n.wordHuntRetake),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final WordMatch match;
  final void Function(WordMatch) onTap;
  const _WordCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = match.card;
    return Semantics(
      button: true,
      label: '${card.wordEnglish}, ${card.wordFilipino}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(match),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  FlashcardEmojis.forId(card.id),
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.wordEnglish,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        card.wordFilipino,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
