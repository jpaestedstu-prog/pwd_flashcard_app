import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';

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

  const AccessibilityContentPolicy({
    required this.showFsl,
    required this.showAudioGame,
  });

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
  final type = ref.watch(
    profileProvider.select((p) => p?.disabilityType ?? DisabilityType.none),
  );
  return AccessibilityContentPolicy.forType(type);
});
