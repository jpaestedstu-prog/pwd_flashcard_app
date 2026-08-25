import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/fsl_video_sheet.dart';

/// Opens the Filipino Sign Language clip for the flashcard a round is about.
///
/// Named for the races it was written for; it is not race-specific.
///
/// Shared by the local and online race screens — and by Peer Collab's Sign
/// Challenge, which is the one activity where watching the sign *is* the round
/// — so every social signing path is indistinguishable from Cards → FSL and
/// Stories' "Watch in FSL": the same resolver, the same friendly bottom sheet
/// when a clip is missing (never a SnackBar — easy to miss for the Deaf
/// learners who rely on this path), and the same analytics record, so signs
/// collected during a match or a collab round count toward the learner's FSL
/// progress like any other.
///
/// Returns when the sheet closes, so the caller can hold the round's timers
/// suspended for exactly as long as the clip is on screen.
Future<void> showRaceSign(
  BuildContext context,
  WidgetRef ref,
  String cardId,
) async {
  final card = _cardFor(ref, cardId);
  if (card == null) return;

  await FslAssetsService.load();
  final source = await FslAssetsService.videoSourceFor(card);
  if (!context.mounted) return;

  if (source == null) {
    await showFslUnavailableSheet(context, wordEnglish: card.wordEnglish);
    return;
  }

  final profile = ref.read(profileProvider);
  if (profile != null) {
    // ignore: discarded_futures
    HiveService.recordFslVideoView(
      profile.id,
      card.category.label,
      card.wordEnglish,
    );
  }

  if (!context.mounted) return;
  await showFslVideoSheet(
    context,
    videoSource: source,
    wordEnglish: card.wordEnglish,
    wordFilipino: card.wordFilipino,
  );
}

/// The flashcard behind a round, or null when the pool no longer holds it —
/// an online guest can be sent a card id their own deck doesn't contain.
Flashcard? _cardFor(WidgetRef ref, String cardId) {
  for (final c in ref.read(allFlashcardsProvider)) {
    if (c.id == cardId) return c;
  }
  return null;
}
