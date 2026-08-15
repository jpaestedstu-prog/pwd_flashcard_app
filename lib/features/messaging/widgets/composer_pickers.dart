import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../models/composer_presentation.dart';

/// Picture and sign pickers for the message composer.
///
/// Both are plain modal sheets returning the chosen value, so the screen keeps
/// all the sending logic and these stay testable on their own.

/// Lets the learner pick a picture to send.
///
/// Every tile is a large tap target with its own semantics label — this is the
/// composer for learners who are not typing, including gaze users driving the
/// screen with their head.
Future<String?> showMessageStickerPicker(
  BuildContext context, {
  required bool isFilipino,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final hc = HCColor.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFilipino ? 'Pumili ng sticker' : 'Pick a sticker',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sticker in MessageStickers.all)
                    Semantics(
                      button: true,
                      label: sticker,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(sticker),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hc.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: hc.border),
                          ),
                          child: Text(
                            sticker,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Lets the learner pick a word to send as a Filipino Sign Language message.
///
/// The list is the vocabulary the app already teaches, so a sign message is
/// always a word the recipient can look up — and, for a Deaf learner, this is
/// the composer that speaks their own language rather than asking them to
/// write in a second one.
Future<String?> showMessageSignPicker(
  BuildContext context, {
  required bool isFilipino,
}) async {
  // Only words that actually have a clip are offered. 34 of the 177 seed cards
  // have no sign recorded yet, and letting a Deaf learner pick one only to be
  // told "no video available" turns their own language into a dead end.
  await FslAssetsService.load();
  if (!context.mounted) return null;

  final signable = <Flashcard>[];
  final seen = <String>{};
  for (final card in SeedData.allFlashcards) {
    if (card.wordEnglish.isEmpty) continue;
    if (!FslAssetsService.hasAnyVideoSource(card)) continue;
    if (!seen.add(card.wordEnglish.toLowerCase())) continue;
    signable.add(card);
  }
  signable.sort((a, b) => a.wordEnglish.compareTo(b.wordEnglish));

  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final hc = HCColor.of(context);

      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFilipino ? 'Magpadala ng senyas' : 'Send a sign',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFilipino
                      ? 'Pipiliin ang salita, at makikita ng kaibigan mo ang senyas.'
                      : 'Pick a word — your friend sees the sign for it.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: signable.length,
                    itemBuilder: (context, index) {
                      final card = signable[index];
                      return ListTile(
                        leading: const Icon(Icons.sign_language_rounded),
                        title: Text(
                          card.wordEnglish,
                          style: AppTypography.bodyMedium,
                        ),
                        subtitle: Text(
                          card.wordFilipino,
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(context).pop(card.wordEnglish),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
