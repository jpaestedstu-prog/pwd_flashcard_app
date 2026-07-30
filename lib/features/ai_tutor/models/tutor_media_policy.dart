import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Which extra channels a tutor question should carry for this learner.
///
/// The tutor's questions are text ("What is the Filipino for 'Soup'?"), which
/// assumes a reader who can see. This policy decides what to put *alongside*
/// that text so the same question is answerable through a different sense:
/// a photograph of the thing, a Filipino Sign Language clip, or the prompt
/// spoken aloud.
///
/// It is deliberately a thin decision layer, not a media loader:
///   * the FSL / audio rules already live in [AccessibilityContentPolicy] and
///     are delegated to, so there is exactly one place that decides a Deaf
///     learner gets signs and a learner on the autism spectrum does not;
///   * whether a *particular* card actually has a photo or a clip is a
///     separate question answered at render time by `FlashcardPhotoService`
///     and `FslAssetsService` — this policy only says what the learner should
///     be offered when the asset exists.
///
/// Kept pure (no I/O, no context, no providers) so the whole matrix is
/// unit-testable, mirroring `CompanionPresentation`.
class TutorMediaPolicy {
  /// Show the card's photograph beside the question. The concrete referent is
  /// what makes a vocabulary question answerable for a pre-reader.
  final bool photo;

  /// Offer a "Watch the sign" control for the card's FSL clip.
  final bool sign;

  /// Speak the question aloud automatically as it arrives. The manual "Listen"
  /// control on each bubble is independent of this and stays available to
  /// anyone with Text-to-Speech on.
  final bool speak;

  const TutorMediaPolicy({
    required this.photo,
    required this.sign,
    required this.speak,
  });

  /// Nothing extra — used for non-learner surfaces and as a safe default.
  static const none = TutorMediaPolicy(photo: false, sign: false, speak: false);

  /// True when this policy adds nothing to the plain text question.
  bool get isTextOnly => !photo && !sign && !speak;

  factory TutorMediaPolicy.forLearner(
    DisabilityType type,
    UserRole? role,
    AppSettings settings,
  ) {
    final content = AccessibilityContentPolicy.forType(type);

    // A picture helps every learner who can see it, and is the primary channel
    // for a pre-reader. It is the one modality a visual profile cannot use.
    final photo = type != DisabilityType.visual;

    // Signs follow the app-wide content policy: primary for a Deaf learner,
    // hidden where they confuse (cognitive) or cannot be seen (visual).
    final sign = content.showFsl;

    // Auto-speaking every question is help for a learner who cannot read the
    // screen, and noise for one who can — so it is limited to the profiles
    // that depend on it: a visual learner (audio is their channel) and a Child
    // (typically a pre-reader, and already the read-aloud persona). Always
    // subject to the learner's Text-to-Speech setting, which a hearing preset
    // turns off.
    final speak = settings.ttsEnabled &&
        (type == DisabilityType.visual || role == UserRole.child);

    return TutorMediaPolicy(photo: photo, sign: sign, speak: speak);
  }
}
