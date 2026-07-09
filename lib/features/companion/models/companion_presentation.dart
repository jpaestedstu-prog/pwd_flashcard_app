import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Overall "feel" of the companion surface.
///
///   * [calm] — still, predictable, minimal. Chosen for profiles where motion,
///     surprise sound, or a moving hit-target are barriers (visual, motor,
///     cognitive, multiple). No idle animation, no artificial typing delay.
///   * [playful] — the lively "buddy": gentle idle motion, animated typing
///     dots, a draggable floating avatar. Chosen where liveliness helps and
///     does no harm (no accessibility need, or a hearing profile that gets the
///     full *visual* liveliness precisely *because* it never depends on sound).
enum CompanionStyle { calm, playful }

/// The presentation policy for the floating AI Companion, derived from the
/// learner's accessibility profile ([DisabilityType]) and their concrete
/// [AppSettings].
///
/// This is the core of the companion's accessibility story: the *brain*
/// ([TutorEngine]) is identical for everyone, but **how the companion presents
/// itself adapts to the person**. One lively floating buddy for everyone would
/// be actively hostile to several disability groups (Clippy is the cautionary
/// tale) — so instead the same assistant renders calm-and-still for one learner
/// and lively-and-spoken for another.
///
/// Design rules encoded below:
///   * Motion is gated by `reducedMotion` and by [CompanionStyle]. Reduced
///     motion always wins.
///   * The "typing indicator" is a deliberately *animated* affordance, so it
///     only shows when animation is allowed. The reply itself is never delayed
///     for a calm profile — instant is an accessibility win, not a regression.
///   * Anything conveyed by sound has a visible + tactile equivalent. Captions
///     are inherent (it's a chat), haptics act as the non-audio arrival cue,
///     and screen-reader users get a live semantics announcement.
///   * Voice input is offered where it *reduces* effort (motor, visual) or the
///     learner opted in — but never to a hearing profile, and always alongside
///     text so a non-verbal / speech-impaired learner is never blocked.
class CompanionPresentation {
  /// Idle avatar motion + animated typing dots. Off under reduced motion and
  /// for every [CompanionStyle.calm] profile.
  final bool animate;

  /// Show the animated "typing…" bubble before a reply appears. Never delays
  /// the reply for a calm profile (they get it immediately).
  final bool typingIndicator;

  /// Play the app's short sound cues on send / arrival. Follows the learner's
  /// Sound Effects setting (already off for a hearing profile).
  final bool soundEffects;

  /// Auto-read each companion reply aloud via on-device TTS. Follows the
  /// Text-to-Speech setting (off for hearing; on for visual).
  final bool speakReplies;

  /// Offer the microphone (speech-to-text) as an input method, in addition to
  /// the always-present text field.
  final bool voiceInput;

  /// Fire a tactile arrival cue when a reply lands. For a hearing profile this
  /// is the *primary* "new message" signal, so it is intentionally independent
  /// of the (off) sound setting.
  final bool haptics;

  /// Announce companion replies through the semantics layer so TalkBack /
  /// screen readers speak them without the learner hunting for the bubble.
  final bool announce;

  /// Whether the floating launcher can be dragged around the screen. Off for
  /// calm profiles — a moving hit-target is a barrier for motor and a
  /// distraction for cognitive learners; the launcher stays docked & fixed.
  final bool draggable;

  /// Calm vs. playful overall feel.
  final CompanionStyle style;

  /// Base diameter (logical px) of the floating launcher. Larger for profiles
  /// that benefit from a bigger touch target.
  final double launcherSize;

  const CompanionPresentation({
    required this.animate,
    required this.typingIndicator,
    required this.soundEffects,
    required this.speakReplies,
    required this.voiceInput,
    required this.haptics,
    required this.announce,
    required this.draggable,
    required this.style,
    required this.launcherSize,
  });

  bool get isCalm => style == CompanionStyle.calm;

  /// How long the animated typing indicator lingers before the reply is shown.
  /// Zero for calm/reduced-motion profiles — no artificial latency.
  Duration get typingDelay =>
      typingIndicator ? const Duration(milliseconds: 750) : Duration.zero;

  /// Derives the presentation for a learner from their disability category and
  /// their live settings. Kept pure (no I/O, no context) so the whole adaptive
  /// matrix is unit-testable.
  factory CompanionPresentation.forProfile(
    DisabilityType type,
    AppSettings s,
  ) {
    // Hearing and "no needs" get the lively visual buddy; everyone whose
    // barrier is motion, precision, or over-stimulation gets the calm one.
    // A hearing learner deliberately keeps the *visual* liveliness — the
    // animation and typing dots — because none of it depends on sound.
    final style = (type == DisabilityType.hearing || type == DisabilityType.none)
        ? CompanionStyle.playful
        : CompanionStyle.calm;

    // Reduced motion always wins; playful is the only style that animates.
    final animate = !s.reducedMotion && style == CompanionStyle.playful;

    // Voice input helps most where typing is effortful (motor) or the screen is
    // hard to read (visual); otherwise honour the learner's opt-in. Never for a
    // hearing profile, and text is always available too.
    final voiceInput = type != DisabilityType.hearing &&
        (s.speechToText ||
            s.voiceNavigation ||
            type == DisabilityType.motor ||
            type == DisabilityType.visual);

    // Non-audio arrival cue: on whenever the learner allows haptics, and
    // *always* for hearing / multiple where it substitutes for sound.
    final haptics = s.soundEffects ||
        type == DisabilityType.hearing ||
        type == DisabilityType.multiple;

    // Screen-reader announcement: for anyone using TTS, and always for visual /
    // multiple where reading the bubble visually may not be possible.
    final announce = s.ttsEnabled ||
        type == DisabilityType.visual ||
        type == DisabilityType.multiple;

    // Bigger launcher for profiles that benefit from a larger target.
    final launcherSize = (type == DisabilityType.motor ||
            type == DisabilityType.visual ||
            type == DisabilityType.multiple)
        ? 68.0
        : 60.0;

    return CompanionPresentation(
      animate: animate,
      typingIndicator: animate,
      soundEffects: s.soundEffects,
      speakReplies: s.ttsEnabled,
      voiceInput: voiceInput,
      haptics: haptics,
      announce: announce,
      draggable: style == CompanionStyle.playful && !s.reducedMotion,
      style: style,
      launcherSize: launcherSize,
    );
  }
}
