import 'package:flutter/material.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../widgets/fsl_video_sheet.dart';

/// Resolves and presents the Filipino Sign Language clip for [card] from a
/// tutor surface.
///
/// Both the full AI Tutor screen and the floating companion need this, and it
/// is the same sequence the Flashcards viewer already uses — resolve, then
/// either play or explain the absence — so it lives here once rather than
/// being copied a third time and drifting.
///
/// Every clip is a network fetch (nothing is bundled: `hasVideo` is false for
/// the entire seed set), so an offline learner reaches [showFslUnavailableSheet]
/// rather than a spinner that never resolves. That path matters more than the
/// happy one for a Deaf learner, which is why the failure is a full sheet and
/// not a SnackBar they might miss.
///
/// The caller owns the "resolving" indicator — see `FslLoadingOverlay` — and
/// must guard against re-entry while a resolve is in flight.
///
/// [context] must sit under a [Navigator]. The companion panel lives in its
/// own nested `Overlay` above the app's Navigator, so it passes the root
/// navigator's context instead of its own.
Future<void> showSignForCard(
  BuildContext context, {
  required Flashcard card,
  String? profileId,
}) async {
  await FslAssetsService.load();
  final source = await FslAssetsService.videoSourceFor(card);
  if (!context.mounted) return;

  if (source == null) {
    // A registered clip that would not resolve means it could not be fetched,
    // not that the sign is missing — say so, rather than telling a Deaf
    // learner their primary channel does not exist.
    showFslUnavailableSheet(
      context,
      wordEnglish: card.wordEnglish,
      unreachable: FslAssetsService.hasAnyVideoSource(card),
    );
    return;
  }

  if (profileId != null) {
    HiveService.recordFslVideoView(
      profileId,
      card.category.label,
      card.wordEnglish,
    );
  }
  showFslVideoSheet(
    context,
    videoSource: source,
    wordEnglish: card.wordEnglish,
    wordFilipino: card.wordFilipino,
  );
}
