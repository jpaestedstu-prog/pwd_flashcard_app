import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// Provides the list of hard words (accuracy < 60%) for the current profile.
final hardWordsProvider =
    Provider<List<(Flashcard, WordAccuracy)>>((ref) {
  final profile = ref.watch(profileProvider);
  final allCards = ref.watch(allFlashcardsProvider);
  if (profile == null) return [];
  return SpacedRepetitionService.getWeakWords(
    profileId: profile.id,
    allCards: allCards,
  );
});

/// Summary stats for the spaced repetition data.
final srSummaryProvider =
    Provider<({int totalAttempted, int totalCorrect, int wordsStruggling})>(
        (ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) {
    return (totalAttempted: 0, totalCorrect: 0, wordsStruggling: 0);
  }
  return SpacedRepetitionService.getSummary(profile.id);
});
