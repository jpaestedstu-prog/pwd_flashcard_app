import 'package:flutter/material.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../widgets/fsl_video_sheet.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';

/// Resolves and presents the Filipino Sign Language clips for a routine step.
///
/// A routine activity is a phrase and the FSL corpus is a vocabulary of single
/// words, so what a learner gets here is a short **sequence** of real signs
/// (see [FslSignCue]) rather than one clip that does not exist. The sheet is
/// shown once per cue, in order, and the caller is told how many played.
///
/// This is the sibling of `showSignForCard` (AI Tutor) and
/// `showSignForRaceWord` (Play Together): same resolve-then-explain sequence,
/// same failure sheet, so the "watch this in FSL" gesture behaves identically
/// everywhere in the app.
class RoutineSignLauncher {
  RoutineSignLauncher._();

  /// The flashcard behind [cue], or null when nothing matches.
  ///
  /// A cue with a category is looked up inside that category first — the
  /// project has words that appear on two seed cards ("Walk" is Transportation
  /// as well as an action; "Chicken" is both an animal and a food), and taking
  /// whichever the seed list yields first would show a Deaf learner a chicken
  /// when they asked about lunch.
  static Flashcard? cardFor(FslSignCue cue) {
    final want = cue.word.trim().toLowerCase();
    if (want.isEmpty) return null;
    final all = SeedData.allFlashcards;
    if (cue.category != null) {
      for (final c in all) {
        if (c.category == cue.category &&
            c.wordEnglish.toLowerCase() == want) {
          return c;
        }
      }
    }
    for (final c in all) {
      if (c.wordEnglish.toLowerCase() == want) return c;
    }
    // Last resort for an educator-typed word: match the Filipino side too, so
    // "tubig" finds Water.
    for (final c in all) {
      if (c.wordFilipino.toLowerCase() == want) return c;
    }
    return null;
  }

  /// Every cue on [step] that resolves to a card with a registered clip.
  ///
  /// The Signs button is hidden when this is empty rather than shown and
  /// failing: for a Deaf learner this is the primary channel, and a dead
  /// button on the primary channel is worse than no button.
  static List<Flashcard> playableCards(RoutineStep step) {
    final cards = <Flashcard>[];
    for (final cue in RoutineCatalog.signCuesFor(step)) {
      final card = cardFor(cue);
      if (card != null && FslAssetsService.hasAnyVideoSource(card)) {
        cards.add(card);
      }
    }
    return cards;
  }

  /// True when [step] has at least one sign a learner can actually watch.
  ///
  /// Requires [FslAssetsService.load] to have completed; call it before
  /// building a surface that branches on this, or the answer is "no clips"
  /// for the first frame.
  static bool hasSigns(RoutineStep step) => playableCards(step).isNotEmpty;

  /// Plays every sign for [step], one sheet after another.
  ///
  /// Returns the number of clips actually shown. Zero means nothing resolved —
  /// the caller has already been shown the "not available" sheet, so it should
  /// not show a second failure of its own.
  ///
  /// [profileId] records the view against the learner's FSL history, the same
  /// way the Cards and Dictionary surfaces do, so signs met inside a routine
  /// count towards the practice hub.
  static Future<int> showSignsFor(
    BuildContext context, {
    required RoutineStep step,
    required bool filipino,
    String? profileId,
  }) async {
    await FslAssetsService.load();
    if (!context.mounted) return 0;

    final cues = RoutineCatalog.signCuesFor(step);
    if (cues.isEmpty) {
      await showFslUnavailableSheet(
        context,
        wordEnglish: RoutineCatalog.titleFor(step, filipino: false),
      );
      return 0;
    }

    var played = 0;
    for (final cue in cues) {
      if (!context.mounted) break;
      final card = cardFor(cue);
      if (card == null) continue;
      final source = await FslAssetsService.videoSourceFor(card);
      if (!context.mounted) break;
      if (source == null) {
        // A clip that IS registered but would not resolve means it could not
        // be fetched, not that the sign is missing. Skip it and keep going —
        // one unreachable clip should not end a three-sign sequence.
        continue;
      }
      if (profileId != null) {
        HiveService.recordFslVideoView(
          profileId,
          card.category.label,
          card.wordEnglish,
        );
      }
      await showFslVideoSheet(
        context,
        videoSource: source,
        wordEnglish: card.wordEnglish,
        wordFilipino: card.wordFilipino,
      );
      played++;
    }

    if (played == 0 && context.mounted) {
      final first = cardFor(cues.first);
      await showFslUnavailableSheet(
        context,
        wordEnglish: first?.wordEnglish ??
            RoutineCatalog.titleFor(step, filipino: false),
        // Registered-but-unreachable is the offline case; say that rather
        // than telling a Deaf learner the sign does not exist.
        unreachable:
            first != null && FslAssetsService.hasAnyVideoSource(first),
      );
    }
    return played;
  }

  /// Human-readable list of the signs a step will play, e.g. "Teeth · Water".
  /// Shown under the Signs button so a learner knows what they are about to
  /// get before the first sheet opens.
  static String cueSummary(RoutineStep step) =>
      RoutineCatalog.signCuesFor(step).map((c) => c.word).join(' · ');
}
