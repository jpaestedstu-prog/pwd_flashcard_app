import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accessibility/sound_service.dart';
import '../accessibility/haptic_service.dart';
import '../utils/error_handler.dart';
import '../../providers/app_providers.dart';
import '../../features/experiment/models/experiment_models.dart';
import '../../features/experiment/services/experiment_service.dart';

/// Types of celebratory moments across the app.
///
/// Each type maps to a specific combination of sound effect, haptic pattern,
/// and Lottie animation asset — all orchestrated by [CelebrationService].
enum CelebrationType {
  /// Light positive feedback — correct answer in a quiz/game
  correctAnswer,

  /// Star earned — star pick-up sound + sparkle animation
  starEarned,

  /// End-of-game celebration — full trophy animation + confetti
  gameComplete,

  /// Perfect score (≥90%) — extra-grand celebration
  perfectScore,

  /// Achievement badge unlocked
  achievementUnlocked,

  /// Streak milestone reached (e.g. 7-day streak)
  streakMilestone,

  /// Level / learning path progression
  levelUp,

  /// Shop purchase confirmed
  purchase,
}

/// Unified celebration service that orchestrates sound, haptic, and visual
/// feedback for rewarding moments.
///
/// Instead of each screen manually calling `haptic.celebration()`,
/// `soundService.playStar()`, and managing `ConfettiController` separately,
/// screens can call:
///
/// ```dart
/// ref.read(celebrationServiceProvider).celebrate(CelebrationType.gameComplete);
/// ```
///
/// The visual (Lottie) component is handled separately by the
/// [LottieCelebrationOverlay] widget, which reads [lottieAssetFor] to decide
/// which animation to play.
///
/// ## Migration guide
///
/// **Before (manual, scattered):**
/// ```dart
/// _confettiController.play();
/// ref.read(soundServiceProvider).playStar();
/// ref.read(hapticServiceProvider).celebration();
/// ```
///
/// **After (unified):**
/// ```dart
/// ref.read(celebrationServiceProvider).celebrate(CelebrationType.purchase);
/// ```
class CelebrationService {
  final SoundService _sound;
  final HapticService _haptic;
  final bool _reducedMotion;
  final bool _enabled;

  CelebrationService({
    required SoundService sound,
    required HapticService haptic,
    required bool reducedMotion,
    bool enabled = true,
  })  : _sound = sound,
        _haptic = haptic,
        _reducedMotion = reducedMotion,
        _enabled = enabled;

  /// Whether the user has enabled reduced-motion mode.
  /// Widgets should check this to skip or simplify visual animations.
  bool get isReducedMotion => _reducedMotion;

  /// Trigger all non-visual celebration feedback (sound + haptic) for the
  /// given [type]. Visual animations are handled by widgets using
  /// [lottieAssetFor].
  ///
  /// No-op when celebrations are disabled by experiment config.
  /// Safe to call at any time — errors are caught and reported, never thrown.
  Future<void> celebrate(CelebrationType type) async {
    if (!_enabled) return;
    try {
      await Future.wait([
        _playSound(type),
        _playHaptic(type),
      ]);
    } catch (e, stack) {
      // Celebrations are non-critical — log but never interrupt UX
      ErrorHandler.report(e, stack, 'CelebrationService');
    }
  }

  /// Returns the Lottie animation asset path for the given [type],
  /// or `null` if no animation is associated.
  ///
  /// Returns `null` when [isReducedMotion] is `true` or celebrations are
  /// disabled by experiment config, to signal widgets should skip the
  /// animation entirely.
  String? lottieAssetFor(CelebrationType type) {
    if (_reducedMotion || !_enabled) return null;

    return switch (type) {
      CelebrationType.correctAnswer => 'assets/animations/thumbs_up.json',
      CelebrationType.starEarned => 'assets/animations/celebration_stars.json',
      CelebrationType.gameComplete => 'assets/animations/trophy.json',
      CelebrationType.perfectScore => 'assets/animations/celebration_fireworks.json',
      CelebrationType.achievementUnlocked => 'assets/animations/trophy.json',
      CelebrationType.streakMilestone => 'assets/animations/streak_flame.json',
      CelebrationType.levelUp => 'assets/animations/level_up.json',
      CelebrationType.purchase => 'assets/animations/celebration_fireworks.json',
    };
  }

  /// Play the appropriate sound effect for the celebration type.
  Future<void> _playSound(CelebrationType type) async {
    switch (type) {
      case CelebrationType.correctAnswer:
        await _sound.playCorrect();
      case CelebrationType.starEarned:
        await _sound.playStar();
      case CelebrationType.gameComplete:
        await _sound.playComplete();
      case CelebrationType.perfectScore:
        await _sound.playComplete();
      case CelebrationType.achievementUnlocked:
        await _sound.playStar();
      case CelebrationType.streakMilestone:
        await _sound.playStar();
      case CelebrationType.levelUp:
        await _sound.playComplete();
      case CelebrationType.purchase:
        await _sound.playStar();
    }
  }

  /// Play the appropriate haptic pattern for the celebration type.
  Future<void> _playHaptic(CelebrationType type) async {
    switch (type) {
      case CelebrationType.correctAnswer:
        await _haptic.success();
      case CelebrationType.starEarned:
        await _haptic.celebration();
      case CelebrationType.gameComplete:
        await _haptic.gameComplete();
      case CelebrationType.perfectScore:
        await _haptic.gameComplete();
      case CelebrationType.achievementUnlocked:
        await _haptic.celebration();
      case CelebrationType.streakMilestone:
        await _haptic.celebration();
      case CelebrationType.levelUp:
        await _haptic.gameComplete();
      case CelebrationType.purchase:
        await _haptic.celebration();
    }
  }
}

/// Global celebration service provider — stays in sync with settings.
///
/// Depends on [soundServiceProvider], [hapticServiceProvider], and
/// [settingsProvider] for `reducedMotion`.
///
/// Respects experiment mode: when celebrations are disabled for the
/// current student, `celebrate()` becomes a no-op and `lottieAssetFor()`
/// returns null.
final celebrationServiceProvider = Provider<CelebrationService>((ref) {
  final sound = ref.watch(soundServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final settings = ref.watch(settingsProvider);

  // Check if celebrations are enabled for the current profile
  final profile = ref.watch(profileProvider);
  final celebrationsEnabled = profile == null ||
      ExperimentService.getConfig(profile.id)
          .isFeatureEnabled(GamificationFeature.celebrations);

  return CelebrationService(
    sound: sound,
    haptic: haptic,
    reducedMotion: settings.reducedMotion,
    enabled: celebrationsEnabled,
  );
});
