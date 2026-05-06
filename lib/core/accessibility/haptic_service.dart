import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

/// Haptic feedback service — provides tactile vibration cues for PWD students.
///
/// Complements audio and visual feedback by giving users physical confirmation
/// of correct/incorrect answers, button presses, and achievements.
/// Respects the system accessibility settings automatically.
class HapticService {
  bool _enabled;

  HapticService({bool enabled = true}) : _enabled = enabled;

  set enabled(bool value) => _enabled = value;
  bool get isEnabled => _enabled;

  /// Light tap — for button presses, card flips, navigation
  Future<void> lightTap() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium tap — for selections, toggles
  Future<void> mediumTap() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for important actions (submit, confirm)
  Future<void> heavyTap() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Success pattern — correct answer, achievement unlocked
  /// Double light vibration for a "positive" feel
  Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Error pattern — wrong answer
  /// Single heavy vibration for a "negative" feel
  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection changed — scroll snap, picker change
  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Achievement / star earned — celebratory triple pulse
  Future<void> celebration() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Game complete — strong double pulse
  Future<void> gameComplete() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }
}

/// Global haptic provider — stays in sync with the sound effects toggle.
/// (If the user has sound/feedback disabled, haptics are also disabled.)
final hapticServiceProvider = Provider<HapticService>((ref) {
  final settings = ref.watch(settingsProvider);
  return HapticService(enabled: settings.soundEffects);
});
