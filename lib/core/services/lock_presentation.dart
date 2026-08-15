import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// How the "Time's up" lock announces itself to one learner.
///
/// The lock has to reach a child whose barrier might be sight, hearing,
/// movement, or processing — so a single "play a sound and show text"
/// implementation reaches none of them reliably. This policy resolves the
/// learner's [DisabilityType] plus their live [AppSettings] into the exact
/// mix of channels the lock screen should use.
///
/// Mirrors the shape of `CompanionPresentation.forProfile` deliberately:
/// pure (no Flutter, no I/O), one factory, everything unit-testable as a
/// matrix. The lock screen reads the flags; it never branches on
/// [DisabilityType] itself.
///
/// Channel design, per profile:
///   • **Visual** — audio is the primary channel: alarm plays longer, the
///     spoken message repeats, and the whole screen is announced through
///     the semantics layer for TalkBack. Text is scaled up hard.
///   • **Hearing** — the spoken message is useless, so the FSL clip and a
///     large caption carry the message; haptics are the arrival cue. The
///     alarm sound still plays, because it is aimed at the *adult in the
///     room* as much as the child.
///   • **Motor** — same channels as a hearing-and-sight-typical learner,
///     but no time pressure and larger hit targets on every control.
///   • **Cognitive** — one short sentence, spoken slowly, no flashing, no
///     repeats; over-stimulation is the barrier here.
///   • **Multiple** — the union of the above, minus the flashing.
///   • **None** — alarm, spoken message, standard layout.
///
/// Every profile also gets a moving image paired with the hand-off
/// picture — see [LockClipKind].

/// Which moving image the lock's hand-off card carries, opposite the still
/// picture of the adult the tablet goes to.
///
/// The card leads with this clip and a tap turns it over to the picture (and
/// back). The two kinds are not interchangeable and must never be labelled
/// alike — one is a person signing, the other is a cartoon clock.
enum LockClipKind {
  /// No second face. The card is the picture alone, and a tap does
  /// nothing. Used by [LockPresentation.warningVariant]: a full sentence
  /// of video is too much for a notice the learner sees again in five
  /// minutes.
  none,

  /// Filipino Sign Language clip of *whom to hand the device to* —
  /// Ma'am / Sir / Mommy / Daddy, matching the picture on the front.
  ///
  /// For a deaf learner this is the message, not a supplement: the spoken
  /// hand-off never reaches them, so the sign has to name the adult.
  fsl,

  /// The animated alarm clock — a wordless "time is up" for learners who
  /// don't sign. Every profile except [DisabilityType.hearing].
  ///
  /// Carries no *who*, which is fine: these profiles get that from the
  /// spoken message and from the picture one tap away. It is the opening
  /// cue precisely because it needs no language at all.
  alarm,
}

class LockPresentation {
  /// Play the alarm tone when the lock appears.
  final bool playAlarmSound;

  /// How many times the alarm tone repeats before the voice message.
  /// Kept small everywhere — this is a hand-off cue, not a fire alarm.
  final int alarmRepeats;

  /// Speak the hand-off message with on-device TTS after the alarm.
  final bool speakMessage;

  /// Speak the message a second time (after a pause). Only for profiles
  /// where audio is the primary channel.
  final bool repeatSpokenMessage;

  /// What the hand-off picture flips over to for this learner.
  final LockClipKind clip;

  /// Offer the Filipino Sign Language clip of the hand-off message.
  ///
  /// Derived rather than stored so "does this learner get FSL?" has one
  /// answer — the alarm animation is a clip too, and callers that mean
  /// *sign language* (the educator's clip-URL field, the PIN autofocus
  /// rule) must not be fooled by it.
  bool get showFslVideo => clip == LockClipKind.fsl;

  /// Whether the card has a second face at all.
  bool get showClip => clip != LockClipKind.none;

  /// Lead with the moving image rather than the still picture.
  ///
  /// True for every learner on the lock itself: motion is what pulls a
  /// child's eye away from the activity they were mid-way through, and the
  /// picture is one tap behind it either way. Only the warning variant
  /// turns it off, because that has no clip at all.
  final bool clipFirst;

  /// Fire a tactile pulse when the lock appears.
  final bool haptics;

  /// Announce the lock through the semantics layer (TalkBack / VoiceOver).
  final bool announce;

  /// Pulse the screen border so a learner who can't hear the alarm still
  /// notices it. Never combined with a fast flash — see [flashPeriod].
  final bool visualAlert;

  /// Use the short, one-idea-per-sentence wording.
  final bool simplifiedWording;

  /// Extra multiplier applied on top of the learner's font scale for the
  /// lock's headline and message.
  final double messageScale;

  /// Minimum height for the lock's buttons, in logical pixels.
  final double minTouchTarget;

  /// Suppress the entrance animation entirely.
  final bool reduceMotion;

  const LockPresentation({
    required this.playAlarmSound,
    required this.alarmRepeats,
    required this.speakMessage,
    required this.repeatSpokenMessage,
    required this.clip,
    required this.clipFirst,
    required this.haptics,
    required this.announce,
    required this.visualAlert,
    required this.simplifiedWording,
    required this.messageScale,
    required this.minTouchTarget,
    required this.reduceMotion,
  });

  /// Period of the visual-alert pulse. Deliberately slow (≥ 1 s) — fast
  /// flashing between 3 Hz and 55 Hz is a seizure risk (WCAG 2.3.1), and
  /// this screen can appear unannounced mid-game.
  Duration get flashPeriod => const Duration(milliseconds: 1200);

  /// Gap between the alarm finishing and the voice message starting, so
  /// the two cues don't overlap into mush.
  Duration get voiceDelay => const Duration(milliseconds: 400);

  /// Derives the presentation for a learner from their accessibility
  /// category and their live settings.
  ///
  /// [settings] is consulted for the learner's own overrides — a learner
  /// who turned Text-to-Speech off never gets a spoken message, and
  /// Reduced Motion always wins over a profile default that would animate.
  /// The alarm *tone* deliberately does NOT follow the game Sound Effects
  /// toggle: that switch is about gameplay feedback, while the alarm is a
  /// safety/hand-off cue also aimed at the adult in the room. Educators
  /// turn it off per child on the Time Limits screen instead.
  factory LockPresentation.forProfile(
    DisabilityType type,
    AppSettings settings,
  ) {
    final base = switch (type) {
      DisabilityType.visual => const LockPresentation(
        playAlarmSound: true,
        alarmRepeats: 3,
        speakMessage: true,
        repeatSpokenMessage: true,
        // No FSL: this learner hears the message. The alarm animation
        // is here for residual vision and for the adult glancing over.
        clip: LockClipKind.alarm,
        clipFirst: true,
        haptics: true,
        announce: true,
        visualAlert: false,
        simplifiedWording: false,
        messageScale: 1.35,
        minTouchTarget: 64,
        reduceMotion: false,
      ),
      DisabilityType.hearing => const LockPresentation(
        playAlarmSound: true,
        alarmRepeats: 2,
        // No spoken message — the FSL clip and the caption carry it.
        speakMessage: false,
        repeatSpokenMessage: false,
        // The signed hand-off names the adult, so it replaces the alarm
        // animation outright: a ringing clock says "time is up" but not
        // "give this to Ma'am", and that second half is the whole point.
        clip: LockClipKind.fsl,
        clipFirst: true,
        haptics: true,
        announce: false,
        visualAlert: true,
        simplifiedWording: false,
        messageScale: 1.2,
        minTouchTarget: 56,
        reduceMotion: false,
      ),
      DisabilityType.motor => const LockPresentation(
        playAlarmSound: true,
        alarmRepeats: 2,
        speakMessage: true,
        repeatSpokenMessage: false,
        clip: LockClipKind.alarm,
        clipFirst: true,
        haptics: true,
        announce: true,
        visualAlert: false,
        simplifiedWording: false,
        messageScale: 1.15,
        // Generous targets: PIN entry and Switch Account must be
        // reachable without fine motor control.
        minTouchTarget: 72,
        reduceMotion: true,
      ),
      DisabilityType.cognitive => const LockPresentation(
        playAlarmSound: true,
        // One gentle chime — repeats read as urgency and escalate
        // distress for learners on the cognitive spectrum.
        alarmRepeats: 1,
        speakMessage: true,
        repeatSpokenMessage: false,
        // A gently looping clock, not a flash — it leads here like it
        // does everywhere else. The protections this profile needs are
        // against *flashing* and repetition (`visualAlert` stays off,
        // one chime, one sentence), not against motion as such.
        clip: LockClipKind.alarm,
        clipFirst: true,
        haptics: true,
        announce: false,
        visualAlert: false,
        simplifiedWording: true,
        messageScale: 1.25,
        minTouchTarget: 64,
        reduceMotion: true,
      ),
      DisabilityType.multiple => const LockPresentation(
        playAlarmSound: true,
        alarmRepeats: 2,
        speakMessage: true,
        repeatSpokenMessage: true,
        // The alarm animation, not FSL. This profile already gets the
        // spoken message, the caption and the picture; a signed clip
        // assumes a fluency the "multiple" category cannot assume, and
        // the wordless clock reads for every combination of barriers.
        clip: LockClipKind.alarm,
        clipFirst: true,
        haptics: true,
        announce: true,
        visualAlert: false,
        simplifiedWording: true,
        messageScale: 1.3,
        minTouchTarget: 72,
        reduceMotion: true,
      ),
      DisabilityType.none => const LockPresentation(
        playAlarmSound: true,
        alarmRepeats: 2,
        speakMessage: true,
        repeatSpokenMessage: false,
        clip: LockClipKind.alarm,
        clipFirst: true,
        haptics: true,
        announce: false,
        visualAlert: false,
        simplifiedWording: false,
        messageScale: 1.0,
        minTouchTarget: 48,
        reduceMotion: false,
      ),
    };

    return base.copyWith(
      // A learner who switched TTS off doesn't get surprised by a voice.
      speakMessage: base.speakMessage && settings.ttsEnabled,
      repeatSpokenMessage: base.repeatSpokenMessage && settings.ttsEnabled,
      // Reduced Motion is a hard opt-out for both the entrance animation
      // and the border pulse.
      visualAlert: base.visualAlert && !settings.reducedMotion,
      reduceMotion: base.reduceMotion || settings.reducedMotion,
    );
  }

  LockPresentation copyWith({
    bool? playAlarmSound,
    int? alarmRepeats,
    bool? speakMessage,
    bool? repeatSpokenMessage,
    LockClipKind? clip,
    bool? clipFirst,
    bool? haptics,
    bool? announce,
    bool? visualAlert,
    bool? simplifiedWording,
    double? messageScale,
    double? minTouchTarget,
    bool? reduceMotion,
  }) {
    return LockPresentation(
      playAlarmSound: playAlarmSound ?? this.playAlarmSound,
      alarmRepeats: alarmRepeats ?? this.alarmRepeats,
      speakMessage: speakMessage ?? this.speakMessage,
      repeatSpokenMessage: repeatSpokenMessage ?? this.repeatSpokenMessage,
      clip: clip ?? this.clip,
      clipFirst: clipFirst ?? this.clipFirst,
      haptics: haptics ?? this.haptics,
      announce: announce ?? this.announce,
      visualAlert: visualAlert ?? this.visualAlert,
      simplifiedWording: simplifiedWording ?? this.simplifiedWording,
      messageScale: messageScale ?? this.messageScale,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  /// The same channel mix, softened for the "nearly time" warning.
  ///
  /// A warning is not a cut-off: it interrupts a learner who is still
  /// mid-activity, so it gets one chime, one reading, and no repeats
  /// whatever the profile. What it keeps is *which* channels reach this
  /// learner — a deaf learner still gets the caption and the haptic, a
  /// blind learner still gets speech and a screen-reader announcement.
  ///
  /// The clip is dropped, whichever kind it is: the FSL one is a full
  /// sentence of video for a notice the learner will see again in five
  /// minutes, and the alarm animation is a *cut-off* cue that would
  /// contradict "you still have time". Both would cover the activity the
  /// learner is being given time to finish.
  LockPresentation get warningVariant => copyWith(
    alarmRepeats: 1,
    repeatSpokenMessage: false,
    clip: LockClipKind.none,
    // Nothing to lead with once the clip is gone.
    clipFirst: false,
    // Never pulse the screen for a warning — the learner is still
    // working, and a breathing border over a live activity is a
    // distraction rather than a cue.
    visualAlert: false,
  );

  /// One-line, educator-facing summary of what the child will actually
  /// experience. Rendered on the Time Limits screen so a parent/teacher
  /// can see the per-profile behaviour without reading this file.
  List<String> get educatorSummary {
    return [
      'Advance warning banner',
      if (playAlarmSound)
        alarmRepeats > 1
            ? 'Alarm chime ×$alarmRepeats'
            : 'One gentle alarm chime',
      if (speakMessage)
        repeatSpokenMessage ? 'Spoken message (said twice)' : 'Spoken message',
      // Shown for every profile — see `_HandoffFlipCard`.
      'Picture of who to hand it to',
      if (clip == LockClipKind.fsl)
        clipFirst
            ? 'FSL video first (tap to flip to the picture)'
            : 'FSL video on the back of the picture',
      if (clip == LockClipKind.alarm)
        clipFirst
            ? 'Alarm animation first (tap to flip to the picture)'
            : 'Alarm animation on the back of the picture (tap to flip)',
      if (visualAlert) 'Pulsing visual alert',
      if (haptics) 'Vibration cue',
      if (announce) 'Screen-reader announcement',
      if (simplifiedWording) 'Short, simple wording',
      'Large "Switch account" button',
    ];
  }
}

/// Per-accessibility-profile starting points for the daily limit and the
/// break cadence.
///
/// These are *recommendations the educator can accept or override*, not
/// enforcement. The numbers follow the same reasoning as the accessibility
/// presets: shorter continuous sessions where fatigue (visual strain,
/// motor effort) or attention span is the limiting factor, standard
/// sessions elsewhere.
class LockPolicyDefaults {
  const LockPolicyDefaults._();

  /// Suggested minutes of app use per day for [type].
  static int dailyMinutesFor(DisabilityType type) => switch (type) {
    // Audio-led learning is slower per item and eye strain is real
    // even with residual vision.
    DisabilityType.visual => 45,
    // Visual channel is unimpaired; standard session length.
    DisabilityType.hearing => 60,
    // Sustained input effort tires quickly — shorter day, more breaks.
    DisabilityType.motor => 45,
    // Attention span is the binding constraint.
    DisabilityType.cognitive => 30,
    DisabilityType.multiple => 30,
    DisabilityType.none => 60,
  };

  /// Suggested allowed window (24-h clock) for [type]. Cognitive and
  /// multiple-disability profiles get a tighter, more predictable window
  /// because routine itself is part of the support.
  static (int start, int end) scheduleFor(DisabilityType type) =>
      switch (type) {
        DisabilityType.cognitive => (8, 18),
        DisabilityType.multiple => (8, 18),
        _ => (8, 20),
      };

  /// Human-readable rationale shown next to the "Apply" button so the
  /// educator understands what they're accepting.
  static String rationaleFor(DisabilityType type) => switch (type) {
    DisabilityType.visual =>
      'Shorter day and frequent breaks — audio-led learning takes longer '
          'per item and reduces eye strain.',
    DisabilityType.hearing =>
      'Standard session length; the hand-off is delivered as an FSL video '
          'and a large caption instead of speech.',
    DisabilityType.motor =>
      'Shorter day and frequent breaks — sustained tapping and holding is '
          'tiring. All lock buttons are extra large.',
    DisabilityType.cognitive =>
      'Short, predictable sessions with a fixed daily window. The lock '
          'uses one chime and one short sentence.',
    DisabilityType.multiple =>
      'The most supportive settings of every profile combined: short '
          'sessions, simple wording, the spoken message said twice, and '
          'large buttons.',
    DisabilityType.none =>
      'Standard session length with an alarm and a spoken hand-off '
          'message.',
  };
}
