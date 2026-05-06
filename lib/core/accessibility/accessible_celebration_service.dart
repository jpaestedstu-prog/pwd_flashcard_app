import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../services/celebration_service.dart';

/// Provides disability-specific celebration adaptations.
///
/// Different disability types benefit from different feedback modalities:
/// - **Visual impairment**: Prioritize haptic + audio feedback, skip animations
/// - **Hearing impairment**: Prioritize haptic + visual feedback, skip sounds
/// - **Motor impairment**: Prioritize visual + audio, gentle haptics only
/// - **Cognitive**: Simplified celebrations, no overwhelming effects
///
/// This service adapts the celebration pipeline based on the user's
/// [DisabilityType] to ensure gamification rewards are accessible.
class AccessibleCelebrationService {
  final CelebrationService _base;
  final DisabilityType _disabilityType;
  final bool _soundEnabled;
  final bool _reducedMotion;

  AccessibleCelebrationService({
    required CelebrationService base,
    required DisabilityType disabilityType,
    required bool soundEnabled,
    required bool reducedMotion,
  })  : _base = base,
        _disabilityType = disabilityType,
        _soundEnabled = soundEnabled,
        _reducedMotion = reducedMotion;

  DisabilityType get disabilityType => _disabilityType;

  /// Trigger an accessible celebration that adapts to the user's disability.
  Future<void> celebrate(CelebrationType type) async {
    await _base.celebrate(type);
  }

  /// Whether to show visual confetti / Lottie animations.
  bool get shouldShowVisualCelebration {
    if (_reducedMotion) return false;
    if (_disabilityType == DisabilityType.cognitive) return false;
    // Visual impairment: skip visual celebrations
    if (_disabilityType == DisabilityType.visual) return false;
    return true;
  }

  /// Whether to play celebration sounds.
  bool get shouldPlaySound {
    if (!_soundEnabled) return false;
    // Hearing impairment: skip sounds
    if (_disabilityType == DisabilityType.hearing) return false;
    return true;
  }

  /// Whether to use extended/stronger haptic patterns.
  bool get shouldUseEnhancedHaptics {
    // Visual and hearing impairment benefit from stronger haptics
    return _disabilityType == DisabilityType.visual ||
        _disabilityType == DisabilityType.hearing;
  }

  /// Whether to use gentle (short) haptics only.
  bool get shouldUseGentleHaptics {
    // Motor impairment: device vibration can be uncomfortable
    return _disabilityType == DisabilityType.motor;
  }

  /// Whether to show text-based reward feedback (always on for accessibility).
  bool get shouldShowTextFeedback => true;

  /// Get the Lottie asset path, respecting accessibility.
  String? lottieAssetFor(CelebrationType type) {
    if (!shouldShowVisualCelebration) return null;
    return _base.lottieAssetFor(type);
  }

  /// Get a descriptive text for the celebration type (for screen readers
  /// and text-based feedback).
  String textFor(CelebrationType type, {bool isFilipino = false}) {
    if (isFilipino) {
      return switch (type) {
        CelebrationType.correctAnswer => 'Tama! Magaling! ✓',
        CelebrationType.starEarned => 'Nakakuha ka ng bituin! ⭐',
        CelebrationType.gameComplete => 'Natapos mo ang laro! 🎮',
        CelebrationType.perfectScore => 'Perpektong iskor! Kahanga-hanga! 🌟',
        CelebrationType.achievementUnlocked => 'Nagbukas ka ng bagong tagumpay! 🏆',
        CelebrationType.streakMilestone => 'Streak milestone na-abot! 🔥',
        CelebrationType.levelUp => 'Nag-level up ka! 🚀',
        CelebrationType.purchase => 'Matagumpay na nabili! 🛍️',
      };
    }
    return switch (type) {
      CelebrationType.correctAnswer => 'Correct! Great job! ✓',
      CelebrationType.starEarned => 'You earned a star! ⭐',
      CelebrationType.gameComplete => 'Game complete! 🎮',
      CelebrationType.perfectScore => 'Perfect score! Amazing! 🌟',
      CelebrationType.achievementUnlocked => 'Achievement unlocked! 🏆',
      CelebrationType.streakMilestone => 'Streak milestone reached! 🔥',
      CelebrationType.levelUp => 'Level up! 🚀',
      CelebrationType.purchase => 'Purchase successful! 🛍️',
    };
  }

  /// Get the celebration display duration (longer for some disabilities).
  Duration durationFor(CelebrationType type) {
    final base = switch (type) {
      CelebrationType.correctAnswer => const Duration(milliseconds: 1200),
      CelebrationType.starEarned => const Duration(milliseconds: 1500),
      CelebrationType.gameComplete => const Duration(seconds: 3),
      CelebrationType.perfectScore => const Duration(seconds: 4),
      CelebrationType.achievementUnlocked => const Duration(seconds: 3),
      CelebrationType.streakMilestone => const Duration(seconds: 2),
      CelebrationType.levelUp => const Duration(seconds: 3),
      CelebrationType.purchase => const Duration(milliseconds: 1500),
    };

    // Give more time for cognitive disability to process
    if (_disabilityType == DisabilityType.cognitive) {
      return base * 1.5;
    }
    // Give more time for visual impairment (relies on audio/haptic)
    if (_disabilityType == DisabilityType.visual) {
      return base * 1.3;
    }
    return base;
  }
}

/// Global accessible celebration provider.
final accessibleCelebrationProvider =
    Provider<AccessibleCelebrationService>((ref) {
  final base = ref.watch(celebrationServiceProvider);
  final profile = ref.watch(profileProvider);
  final settings = ref.watch(settingsProvider);
  return AccessibleCelebrationService(
    base: base,
    disabilityType: profile?.disabilityType ?? DisabilityType.none,
    soundEnabled: settings.soundEffects,
    reducedMotion: settings.reducedMotion,
  );
});
