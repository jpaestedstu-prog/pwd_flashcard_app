import 'dart:async';

import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../models/assessment_models.dart';

/// Makes sure every sign clip a test needs is on the tablet before it starts.
///
/// Clips stream from the cloud the first time and play offline after that. A
/// learner who met a sign item for the first time with no connection got the
/// "could not be loaded" placeholder and answered it blind — a wrong answer
/// the study would count as not knowing the sign. So the clips are fetched
/// ahead of time (when the assignment arrives, while the tablet is online) and
/// checked again before the first question: a test with a missing clip does
/// not start at all.
class SignClipReadiness {
  const SignClipReadiness._();

  /// How long one clip may take to download before it counts as missing.
  static const Duration perClip = Duration(seconds: 45);

  /// The flashcard ids behind [assessment]'s sign items, in order.
  static List<String> cardIdsIn(Assessment assessment) => [
    for (final q in assessment.questions)
      if (q.format == QuestionFormat.signVideo && q.signCardId != null)
        q.signCardId!,
  ];

  /// Downloads whatever of [cardIds] is not on the tablet yet and returns the
  /// ids that are still unavailable — empty means the test can start.
  ///
  /// [fetch] answers "is this card's clip playable offline now, downloading it
  /// if need be"; it defaults to [FslAssetsService] and is a test seam.
  static Future<List<String>> prepare(
    Iterable<String> cardIds, {
    Future<bool> Function(Flashcard card)? fetch,
  }) async {
    final get = fetch ?? _fetch;
    final missing = <String>[];
    for (final id in cardIds.toSet()) {
      final card = _cardFor(id);
      if (card == null) {
        missing.add(id);
        continue;
      }
      bool ok;
      try {
        ok = await get(card).timeout(perClip);
      } catch (_) {
        ok = false;
      }
      if (!ok) missing.add(id);
    }
    return missing;
  }

  /// Fetches the clips for every test in [assessments] in the background.
  /// Failures are ignored: the check before the test starts catches them.
  static Future<void> prefetch(Iterable<Assessment> assessments) async {
    final ids = {for (final a in assessments) ...cardIdsIn(a)};
    if (ids.isEmpty) return;
    await prepare(ids);
  }

  static Future<bool> _fetch(Flashcard card) async {
    if (await FslAssetsService.isCached(card)) return true;
    return await FslAssetsService.cachedVideoFile(card) != null;
  }

  static Flashcard? _cardFor(String id) {
    for (final card in SeedData.allFlashcards) {
      if (card.id == id) return card;
    }
    return null;
  }
}
