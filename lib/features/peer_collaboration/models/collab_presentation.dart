import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'collab_models.dart';

/// How "Peer Collab" presents itself to one learner.
///
/// Peer Collab is the app's **cooperative** two-players-one-tablet surface —
/// the counterpart to Play Together, which is competitive. Both sit in the same
/// Social section, so the accessibility bar has to be the same, and every other
/// learner surface already adapts to the profile's [DisabilityType]: the Games
/// hub curates a roster (`GameCatalog`), the race adapts pacing and channels
/// (`RacePresentation`), the talk board adapts its grid (`BoardPresentation`).
/// Peer Collab adapted to nobody.
///
/// Like its siblings this policy is **pure** — no Flutter, no I/O, one factory
/// — so the whole adaptive matrix is unit-testable and the screen reads flags
/// instead of branching on [DisabilityType].
///
/// The decision that matters most here is [tapToSelect]. Peer Collab used to
/// accept answers *only* as free text, which is precisely the input a gaze or
/// switch learner cannot produce — it made the one feature named for including
/// a peer the one feature that excluded the learner. Every activity now has a
/// tap-to-answer surface; free text is an extra, offered only where typing is
/// not itself the barrier.
///
/// Rationale per category, kept deliberately consistent with `RacePresentation`
/// and `GameCatalog` so a learner never meets an activity here that their own
/// Games tab judged unsuitable:
///
///   * **Visual** — audio is the primary channel: prompts spoken, rounds
///     announced, targets grown. Picture Guess is dropped for the same reason
///     Picture Quiz is dropped from their race roster — the prompt *is* an
///     image with nothing to narrate — and Sign Challenge for the same reason
///     [AccessibilityContentPolicy] hides every other FSL surface from them.
///   * **Hearing** — the full roster, and the one category where Sign Challenge
///     is the *point*. Nothing here depends on sound; haptics carry the cue
///     other profiles get from audio.
///   * **Motor** — tap-only, larger targets, no typing anywhere. The full
///     roster survives because every activity now has a tap surface.
///   * **Cognitive** — shorter sessions, fewer choices, no FSL (the same call
///     the content policy makes), and no Word Relay: spelling carries the
///     literacy load that keeps Spelling Bee out of their Games tab.
///   * **Multiple** — the union: motor's input limits, cognitive's length and
///     choice count, every alternative channel left on.
///   * **None** — the full experience. Player profiles (guest and
///     with-progress) resolve here, so nothing they enjoy today is taken away.
class CollabPresentation {
  /// Answer by tapping a choice rather than typing it.
  ///
  /// The choices are always built; this decides whether a keyboard is offered
  /// *as well*. See the class doc — this is the flag the whole rewrite turns
  /// on.
  final bool tapToSelect;

  /// Offer the free-text field beside the choices. False wherever typing is
  /// itself the barrier (motor, multiple) or the reading load is (cognitive).
  final bool allowFreeText;

  /// How many answer choices a guessing round offers, including the right one.
  final int choiceCount;

  /// Read the prompt aloud as a turn opens.
  final bool speakPrompts;

  /// Offer a manual "hear it again" control. Implied by [speakPrompts], but
  /// also true for profiles that can use TTS on demand without wanting every
  /// turn narrated.
  final bool canSpeak;

  /// Tactile right/wrong feedback — the primary answer cue for a hearing
  /// profile, where it deliberately ignores the (off) sound setting.
  final bool haptics;

  /// Announce turn and round changes through the semantics layer so TalkBack
  /// speaks them without the learner hunting for the card.
  final bool announce;

  /// Grow hit targets and thin out choice rows.
  final bool bigTargets;

  /// Offer the Filipino Sign Language clip for the round's word.
  ///
  /// Delegated to [AccessibilityContentPolicy] rather than decided here, so
  /// Peer Collab can never disagree with the Cards tab, the FSL dictionary or
  /// Play Together about whether this learner signs.
  final bool showFsl;

  /// Show the round's flashcard picture. Off only where sight is the barrier.
  final bool showPictures;

  /// Rounds in a session.
  final int rounds;

  /// The activities this learner is offered, in picker order.
  final List<CollabActivityType> activities;

  const CollabPresentation({
    required this.tapToSelect,
    required this.allowFreeText,
    required this.choiceCount,
    required this.speakPrompts,
    required this.canSpeak,
    required this.haptics,
    required this.announce,
    required this.bigTargets,
    required this.showFsl,
    required this.showPictures,
    required this.rounds,
    required this.activities,
  });

  /// The full experience — the default for callers that know nothing about
  /// accessibility (tests, previews), and what `DisabilityType.none` resolves
  /// to.
  static const standard = CollabPresentation(
    tapToSelect: true,
    allowFreeText: true,
    choiceCount: 4,
    speakPrompts: false,
    canSpeak: false,
    haptics: false,
    announce: false,
    bigTargets: false,
    showFsl: true,
    showPictures: true,
    rounds: 5,
    activities: CollabActivityType.values,
  );

  /// Derive the policy for a learner from their accessibility category and
  /// their live [AppSettings]. Pure.
  factory CollabPresentation.forProfile(DisabilityType type, AppSettings s) {
    // Typing is the barrier wherever fine motor control is.
    final noTyping =
        type == DisabilityType.motor || type == DisabilityType.multiple;
    // Shorter sessions and fewer choices where sustained attention is.
    final short =
        type == DisabilityType.cognitive || type == DisabilityType.multiple;

    // Narration is the primary channel where sight is the barrier. Never for a
    // hearing profile, and always subject to the learner's TTS setting.
    final canSpeak = s.ttsEnabled && type != DisabilityType.hearing;
    final speakPrompts = canSpeak &&
        (type == DisabilityType.visual || type == DisabilityType.multiple);

    // Non-audio right/wrong cue: on whenever the learner allows feedback, and
    // *always* for hearing / multiple where it substitutes for sound.
    final haptics = s.soundEffects ||
        type == DisabilityType.hearing ||
        type == DisabilityType.multiple;

    return CollabPresentation(
      tapToSelect: true,
      // Cognitive keeps typing off too: an open text box is a heavier ask than
      // a row of choices, the same reasoning that keeps spelling off its
      // roster.
      allowFreeText: !noTyping && !short,
      choiceCount: short ? 3 : 4,
      speakPrompts: speakPrompts,
      canSpeak: canSpeak,
      haptics: haptics,
      announce: s.ttsEnabled ||
          type == DisabilityType.visual ||
          type == DisabilityType.multiple,
      bigTargets: type == DisabilityType.motor ||
          type == DisabilityType.visual ||
          type == DisabilityType.multiple,
      // Delegated, never re-derived — see [showFsl].
      showFsl: AccessibilityContentPolicy.forType(type).showFsl,
      showPictures: type != DisabilityType.visual,
      rounds: short ? 3 : 5,
      activities: activitiesFor(type),
    );
  }

  /// The activities offered to [type]. Curated, not merely filtered — the
  /// exclusions mirror the reasoning `GameCatalog` and `RacePresentation` use
  /// for the equivalent single-player game (see the class doc).
  ///
  /// Never empty: Story Builder has no right answer, no picture and no sign, so
  /// every category can play it.
  static List<CollabActivityType> activitiesFor(DisabilityType type) =>
      switch (type) {
        // Picture Guess is an image prompt with nothing to narrate; Sign
        // Challenge is video this learner cannot use.
        DisabilityType.visual => const [
            CollabActivityType.wordRelay,
            CollabActivityType.storyBuilder,
          ],
        // Nothing in Peer Collab depends on hearing, and signing is the point.
        DisabilityType.hearing => CollabActivityType.values,
        // Every activity has a tap surface now, so nothing needs dropping —
        // [bigTargets] and [allowFreeText] carry this profile.
        DisabilityType.motor => CollabActivityType.values,
        // Word Relay is spelling, letter by letter; Sign Challenge is the FSL
        // surface the content policy already hides from this category.
        DisabilityType.cognitive => const [
            CollabActivityType.pictureGuess,
            CollabActivityType.storyBuilder,
          ],
        // The union of the motor and cognitive exclusions.
        DisabilityType.multiple => const [
            CollabActivityType.pictureGuess,
            CollabActivityType.storyBuilder,
          ],
        DisabilityType.none => CollabActivityType.values,
      };

  /// What was adapted for this learner, or empty when nothing was.
  ///
  /// Returns the *reasons*, not a sentence: this class is pure and has no
  /// `BuildContext`, so the screen looks each one up in `AppLocalizations` and
  /// composes the line. Same shape as `DifficultyExplanation`, and for the same
  /// reason — a sentence built by string concatenation inside a service cannot
  /// be translated.
  ///
  /// It is surfaced on the picker at all so the change is visible rather than
  /// mysterious: an accessibility feature nobody notices is a feature nobody
  /// trusts.
  List<CollabAdaptation> get adaptations => [
        if (!allowFreeText) CollabAdaptation.tapToAnswer,
        if (speakPrompts) CollabAdaptation.readAloud,
        if (bigTargets) CollabAdaptation.biggerButtons,
        if (rounds < standard.rounds) CollabAdaptation.shorterSession,
      ];
}

/// One thing [CollabPresentation] changed for a learner, for the picker's
/// "Set up for you: …" line.
enum CollabAdaptation {
  tapToAnswer,
  readAloud,
  biggerButtons,
  shorterSession,
}

/// The collab policy for the active learner. Educator previews and profile-less
/// states fall back to [CollabPresentation.standard]'s category (`none`).
final collabPresentationProvider = Provider<CollabPresentation>((ref) {
  final type = ref.watch(
    profileProvider.select((p) => p?.disabilityType ?? DisabilityType.none),
  );
  final settings = ref.watch(settingsProvider);
  return CollabPresentation.forProfile(type, settings);
});
