import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/accessibility/game_catalog.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'multiplayer_models.dart';

/// How "Play Together" presents itself to one learner.
///
/// Every other learner surface in the app already adapts to the profile's
/// [DisabilityType] — the Games hub curates a per-category roster
/// ([GameCatalog]), the companion picks calm vs. playful
/// (`CompanionPresentation`), the time-up lock picks its announcement channels
/// (`LockPresentation`). Play Together was the one learner feature that looked
/// and scored identically for everybody, which quietly made it the *least*
/// accessible thing in the app: a silent, image-only, speed-scored race.
///
/// This policy closes that gap. Like its siblings it is **pure** — no Flutter,
/// no I/O, one factory — so the whole adaptive matrix is unit-testable, and the
/// race widgets read flags instead of branching on [DisabilityType].
///
/// Two kinds of decision live here, and the distinction matters:
///
///   * **Per-device channels** — TTS, haptics, target size, self-pacing. Each
///     racer plays their own copy of the shared content, so these can differ
///     between the two players without making the match unfair. A blind
///     learner hearing every prompt does not slow their sighted opponent down.
///
///   * **Shared fairness** — [timeScoring]. A speed bonus is only fair when
///     *both* racers can go fast. The moment either side needs an untimed
///     score, the whole match drops the clock (see [GameRoom.fairPlay]), which
///     is why this one flag is negotiated into the room rather than applied
///     per-device.
///
/// Rationale per category (kept deliberately consistent with [GameCatalog], so
/// a learner never meets a mini-game in Play Together that their own Games tab
/// judged unsuitable):
///
///   * **Visual** — audio is the primary channel: prompts and options are
///     spoken, the round is announced to the screen reader, targets grow, and
///     the clock comes off because listening takes as long as it takes. Picture
///     Quiz is dropped for the same reason Picture-Word is dropped from their
///     Games tab — the prompt *is* an image with no text to narrate.
///   * **Hearing** — nothing in a race depends on sound, so the full roster and
///     the timed score stay. Haptics carry the right/wrong cue that other
///     profiles get from audio.
///   * **Motor** — single taps only, larger targets, self-paced advance and no
///     speed bonus. Racing a sibling on a stopwatch is the exact shape of
///     unfairness this profile hits everywhere else in games.
///   * **Cognitive** — shorter matches, one step at a time, no clock, no word
///     spelling (Word Scramble carries the same literacy load that keeps
///     Spelling Bee out of their Games tab).
///   * **Multiple** — the union: motor input limits, cognitive length, and
///     every alternative channel kept on.
///   * **None** — exactly today's behaviour. Player profiles (guest and
///     with-progress) resolve to this, so nothing they already enjoy changes.
class RacePresentation {
  /// Advance only when the player taps "Next" — no post-answer timer.
  ///
  /// Safe to differ between the two racers: each plays their own copy, so one
  /// side taking their time never blocks the other.
  final bool selfPaced;

  /// Whether the final score includes a speed bonus. **Shared** across both
  /// racers — see the class doc.
  final bool timeScoring;

  /// Read each prompt (and its options) aloud as the round opens.
  final bool speakPrompts;

  /// Offer a manual "hear it again" control. Implied by [speakPrompts], but
  /// also true for profiles that can use TTS on demand without wanting every
  /// round narrated automatically.
  final bool canSpeak;

  /// Tactile right/wrong feedback. The primary answer cue for a hearing
  /// profile, where it deliberately ignores the (off) sound setting.
  final bool haptics;

  /// Announce round changes and results through the semantics layer so
  /// TalkBack speaks them without the learner hunting for the card.
  final bool announce;

  /// Grow hit targets and thin out grids for profiles that need a bigger,
  /// calmer tap area.
  final bool bigTargets;

  /// Offer the Filipino Sign Language clip for the word a round is about.
  ///
  /// Delegated to [AccessibilityContentPolicy] rather than decided here, so
  /// Play Together can never disagree with the Cards tab, the FSL dictionary
  /// or Stories about whether this learner signs.
  final bool showFsl;

  /// Rounds in the three question modes (Word Quiz / Picture / True-False).
  final int rounds;

  /// Pairs on the memory board (the board holds `pairs * 2` cards).
  final int memoryPairs;

  /// Words in a scramble match.
  final int scrambleCount;

  /// The mini-games this learner is offered, in lobby order.
  final List<MpGameMode> modes;

  const RacePresentation({
    required this.selfPaced,
    required this.timeScoring,
    required this.speakPrompts,
    required this.canSpeak,
    required this.haptics,
    required this.announce,
    required this.bigTargets,
    required this.showFsl,
    required this.rounds,
    required this.memoryPairs,
    required this.scrambleCount,
    required this.modes,
  });

  /// Today's behaviour, unchanged: timed, six rounds, every mode, no extra
  /// channels. The default for the race widgets so a caller that knows nothing
  /// about accessibility (tests, previews) gets exactly what it got before.
  static const RacePresentation standard = RacePresentation(
    selfPaced: false,
    timeScoring: true,
    speakPrompts: false,
    canSpeak: false,
    haptics: false,
    announce: false,
    bigTargets: false,
    showFsl: false,
    rounds: 6,
    memoryPairs: 6,
    scrambleCount: 5,
    modes: MpGameMode.values,
  );

  /// How long the correct/wrong feedback stays up before the next round when
  /// the match is *not* self-paced. Zero when it is — the player advances.
  Duration get answerDelay =>
      selfPaced ? Duration.zero : const Duration(milliseconds: 900);

  /// How long an unmatched pair stays face-up on the memory board. Always a
  /// timer (the board would lock otherwise), but a much longer look for
  /// profiles that need processing time.
  Duration get flipBackDelay => selfPaced
      ? const Duration(milliseconds: 1800)
      : const Duration(milliseconds: 700);

  /// Memory-board columns at a given screen tier, thinned for [bigTargets].
  int columnsFrom(int tierColumns) =>
      bigTargets ? (tierColumns - 1).clamp(2, tierColumns) : tierColumns;

  /// Whether this learner forces the whole match off the clock. Written into
  /// the room as [GameRoom.fairPlay] so both devices agree.
  bool get needsFairPlay => !timeScoring;

  /// This policy with the clock forced off — how a device applies a room whose
  /// *opponent* needs untimed scoring.
  RacePresentation withoutTimeScoring() =>
      timeScoring ? copyWith(timeScoring: false) : this;

  RacePresentation copyWith({
    bool? selfPaced,
    bool? timeScoring,
    bool? speakPrompts,
    bool? canSpeak,
    bool? haptics,
    bool? announce,
    bool? bigTargets,
    bool? showFsl,
    int? rounds,
    int? memoryPairs,
    int? scrambleCount,
    List<MpGameMode>? modes,
  }) =>
      RacePresentation(
        selfPaced: selfPaced ?? this.selfPaced,
        timeScoring: timeScoring ?? this.timeScoring,
        speakPrompts: speakPrompts ?? this.speakPrompts,
        canSpeak: canSpeak ?? this.canSpeak,
        haptics: haptics ?? this.haptics,
        announce: announce ?? this.announce,
        bigTargets: bigTargets ?? this.bigTargets,
        showFsl: showFsl ?? this.showFsl,
        rounds: rounds ?? this.rounds,
        memoryPairs: memoryPairs ?? this.memoryPairs,
        scrambleCount: scrambleCount ?? this.scrambleCount,
        modes: modes ?? this.modes,
      );

  /// Derive the policy for a learner from their accessibility category and
  /// their live [AppSettings]. Pure.
  factory RacePresentation.forProfile(DisabilityType type, AppSettings s) {
    // Self-pacing (and therefore an untimed score) for every profile whose
    // barrier is movement, processing, or reading the screen. Hearing and
    // "no needs" keep the race a race.
    final untimed = type == DisabilityType.visual ||
        type == DisabilityType.motor ||
        type == DisabilityType.cognitive ||
        type == DisabilityType.multiple;

    // Slow-Motion is an explicit "give me more time" from the learner, so it
    // takes the clock off for anyone who switches it on.
    final selfPaced = untimed || s.slowMotionEnabled;

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

    final announce = s.ttsEnabled ||
        type == DisabilityType.visual ||
        type == DisabilityType.multiple;

    final bigTargets = type == DisabilityType.motor ||
        type == DisabilityType.visual ||
        type == DisabilityType.multiple;

    // Shorter matches where sustained attention is the barrier.
    final short =
        type == DisabilityType.cognitive || type == DisabilityType.multiple;

    return RacePresentation(
      selfPaced: selfPaced,
      timeScoring: !selfPaced,
      speakPrompts: speakPrompts,
      canSpeak: canSpeak,
      haptics: haptics,
      announce: announce,
      bigTargets: bigTargets,
      // Delegated, never re-derived — see [showFsl].
      showFsl: AccessibilityContentPolicy.forType(type).showFsl,
      rounds: short ? 4 : 6,
      memoryPairs: short ? 4 : 6,
      scrambleCount: 5,
      modes: modesFor(type),
    );
  }

  /// The mini-games offered to [type]. Curated, not merely filtered — the
  /// exclusions mirror [GameCatalog]'s reasoning for the equivalent
  /// single-player game (see the class doc).
  static List<MpGameMode> modesFor(DisabilityType type) => switch (type) {
        // Picture Quiz is an image prompt with nothing to narrate — the same
        // call that keeps Picture-Word out of the visual Games roster.
        DisabilityType.visual => const [
            MpGameMode.quizRace,
            MpGameMode.trueFalseRace,
            MpGameMode.memoryRace,
            MpGameMode.scrambleRace,
          ],
        // Nothing in a race depends on hearing.
        DisabilityType.hearing => MpGameMode.values,
        // All five are single-tap games; [bigTargets] handles the rest.
        DisabilityType.motor => MpGameMode.values,
        // Word Scramble carries the literacy load that keeps Spelling Bee out
        // of the cognitive Games roster.
        DisabilityType.cognitive => const [
            MpGameMode.quizRace,
            MpGameMode.pictureRace,
            MpGameMode.trueFalseRace,
            MpGameMode.memoryRace,
          ],
        DisabilityType.multiple => const [
            MpGameMode.quizRace,
            MpGameMode.pictureRace,
            MpGameMode.trueFalseRace,
            MpGameMode.memoryRace,
          ],
        DisabilityType.none => MpGameMode.values,
      };

  /// One short line telling the learner what was adapted for them, or null
  /// when nothing was. Shown in the lobby so the change is visible rather than
  /// mysterious — an accessibility feature nobody notices is a feature nobody
  /// trusts.
  String? adaptationNote({required bool isFilipino}) {
    final parts = <String>[];
    if (!timeScoring) {
      parts.add(isFilipino ? 'walang orasan' : 'no timer');
    }
    if (speakPrompts) {
      parts.add(isFilipino ? 'may boses' : 'read aloud');
    }
    if (bigTargets) {
      parts.add(isFilipino ? 'malalaking pindutan' : 'bigger buttons');
    }
    if (rounds < standard.rounds) {
      parts.add(isFilipino ? 'mas maikli' : 'shorter match');
    }
    if (parts.isEmpty) return null;
    final list = parts.join(', ');
    return isFilipino ? 'Inayos para sa iyo: $list.' : 'Set up for you: $list.';
  }
}

/// How well a proposed match fits the friend being invited.
///
/// The host picks the game *before* the guest ever sees the invite, so without
/// this a learner can send a Word Scramble challenge to a friend whose own
/// Games tab excludes spelling — the invite arrives unplayable, and the guest
/// has no way to say so. This resolves the guest's published accessibility
/// category into the two things the host needs to know up front.
///
/// A **preview, not the contract**: the directory publishes the category only,
/// so a guest whose own settings take the clock off (Slow Motion, say) can
/// still flip [GameRoom.fairPlay] when they join. The room stays the authority;
/// this just stops the host from choosing badly.
class InviteFit {
  /// Games both learners are offered, in the host's roster order. Never empty
  /// — every category shares the word quiz.
  final List<MpGameMode> sharedModes;

  /// The game the host currently has selected is one the guest also plays.
  final bool selectedIsShared;

  /// Inviting this friend will take the speed bonus off the match.
  final bool dropsTheClock;

  const InviteFit({
    required this.sharedModes,
    required this.selectedIsShared,
    required this.dropsTheClock,
  });

  /// The game to actually host: the host's pick when the guest can play it,
  /// otherwise the closest game both are offered.
  MpGameMode resolve(MpGameMode selected) =>
      selectedIsShared ? selected : sharedModes.first;

  static InviteFit between({
    required DisabilityType host,
    required DisabilityType? guest,
    required MpGameMode selected,
    required bool hostNeedsFairPlay,
  }) {
    final hostModes = RacePresentation.modesFor(host);
    // An older peer publishes no category. Assume nothing rather than
    // guessing: they keep the full roster and the host's own clock rule.
    if (guest == null) {
      return InviteFit(
        sharedModes: hostModes,
        selectedIsShared: hostModes.contains(selected),
        dropsTheClock: hostNeedsFairPlay,
      );
    }
    final guestModes = RacePresentation.modesFor(guest);
    final shared = hostModes.where(guestModes.contains).toList();
    final guestNeedsFairPlay =
        RacePresentation.forProfile(guest, const AppSettings()).needsFairPlay;
    return InviteFit(
      sharedModes: shared,
      selectedIsShared: shared.contains(selected),
      dropsTheClock: hostNeedsFairPlay || guestNeedsFairPlay,
    );
  }
}

/// The race policy for the active learner. Educator previews and profile-less
/// states fall back to [RacePresentation.standard]'s category (`none`).
final racePresentationProvider = Provider<RacePresentation>((ref) {
  final type = ref.watch(
    profileProvider.select((p) => p?.disabilityType ?? DisabilityType.none),
  );
  final settings = ref.watch(settingsProvider);
  return RacePresentation.forProfile(type, settings);
});
