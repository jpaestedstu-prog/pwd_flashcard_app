import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import 'learner_support.dart';

/// Which optional learning modalities a learner's accessibility category
/// should surface.
///
/// The `AccessibilityPresets` already drive *settings* (TTS, sound, contrast,
/// reduced motion) — those toggles, e.g. `ttsEnabled`, gate spoken narration
/// app-wide. This policy adds the orthogonal **content-visibility** decisions
/// the presets can't express: whether to show Filipino Sign Language (FSL)
/// video surfaces, and whether to show the audio-only "listen & pick"
/// Pronunciation game.
///
/// Rationale (per the accessibility brief):
///   • Deaf / hard-of-hearing learners rely on FSL and gain nothing from an
///     audio-only listening game.
///   • Learners on the cognitive/autism spectrum can be confused by FSL clips
///     that aren't relevant to them.
///   • Visual-impairment learners can't make use of FSL video at all.
class AccessibilityContentPolicy {
  /// Show Filipino Sign Language video entry points (FSL Practice / Dictionary
  /// tiles, the Cards FSL button, the Stories "Watch in FSL" buttons).
  final bool showFsl;

  /// Show the audio-only Pronunciation ("listen & pick") game in the hub.
  final bool showAudioGame;

  /// The sign system this learner actually uses, when they sign at all.
  ///
  /// Null for learners whose category has no communication choice, and for the
  /// ones who read or lip-read instead of signing. The app's clips are filmed
  /// in FSL, so an ASL or SEE signer still gets the sign surfaces — the
  /// surfaces just say which system they are watching, rather than implying it
  /// is theirs.
  final LearnerSupportOption? signSystem;

  const AccessibilityContentPolicy({
    required this.showFsl,
    required this.showAudioGame,
    this.signSystem,
  });

  /// True when the learner signs in something other than FSL, so a sign
  /// surface should name the system it is showing.
  bool get signSystemDiffersFromMedia =>
      signSystem != null && signSystem != LearnerSupportOption.signFsl;

  /// Value equality so the provider below can hand out a fresh instance on
  /// every profile edit without repainting the screens that watch it. It reads
  /// the whole profile now (not just the category), so a name change would
  /// otherwise rebuild every FSL-gated surface on the home screen.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilityContentPolicy &&
          other.showFsl == showFsl &&
          other.showAudioGame == showAudioGame &&
          other.signSystem == signSystem;

  @override
  int get hashCode => Object.hash(showFsl, showAudioGame, signSystem);

  /// Policy for a whole profile: the category decision above, then narrowed by
  /// the learner's own configured supports.
  ///
  /// This is what the app should ask. [forType] remains for the callers that
  /// only have a category to hand (a class being set up before anyone has
  /// joined it, an educator previewing a category).
  static AccessibilityContentPolicy forProfile(UserProfile? profile) {
    if (profile == null) return forType(DisabilityType.none);
    return forLearner(profile.disabilityType, profile.supports);
  }

  /// Same decision for a learner an *educator* is looking at, where the
  /// category and supports are to hand but the whole profile is not.
  ///
  /// `accessibilityContentPolicyProvider` reads the signed-in profile, which
  /// on an educator's screen is the educator — so their surfaces must ask
  /// this, not the provider.
  static AccessibilityContentPolicy forLearner(
    DisabilityType type,
    Iterable<LearnerSupportOption> supports,
  ) {
    final base = forType(type);
    final mode = LearnerSupportCatalog.communicationModeIn(
      LearnerSupportCatalog.effective(type, supports),
    );
    if (mode == null) return base;
    // A learner who reads or lip-reads gets no sign video, whatever their
    // category would have shown — that was the whole point of asking.
    return AccessibilityContentPolicy(
      showFsl: base.showFsl && mode.isSigningSystem,
      showAudioGame: base.showAudioGame,
      signSystem: mode.isSigningSystem ? mode : null,
    );
  }

  static AccessibilityContentPolicy forType(DisabilityType type) {
    return switch (type) {
      // Signs are visual → useless; rely on audio / TTS.
      DisabilityType.visual =>
        const AccessibilityContentPolicy(showFsl: false, showAudioGame: true),
      // Deaf → FSL is the primary path; hide audio-only content.
      DisabilityType.hearing =>
        const AccessibilityContentPolicy(showFsl: true, showAudioGame: false),
      // FSL adds confusion (autism example); keep audio / TTS support.
      DisabilityType.cognitive =>
        const AccessibilityContentPolicy(showFsl: false, showAudioGame: true),
      // Both modalities are perceivable.
      DisabilityType.motor =>
        const AccessibilityContentPolicy(showFsl: true, showAudioGame: true),
      // Mixed needs — keep every alternative modality available.
      DisabilityType.multiple =>
        const AccessibilityContentPolicy(showFsl: true, showAudioGame: true),
      // Full experience.
      DisabilityType.none =>
        const AccessibilityContentPolicy(showFsl: true, showAudioGame: true),
    };
  }
}

/// Content policy for the active learner, derived from their assigned
/// accessibility category. Defaults to the full experience when there is no
/// active profile (e.g. educator preview).
final accessibilityContentPolicyProvider =
    Provider<AccessibilityContentPolicy>((ref) {
  return AccessibilityContentPolicy.forProfile(ref.watch(profileProvider));
});
