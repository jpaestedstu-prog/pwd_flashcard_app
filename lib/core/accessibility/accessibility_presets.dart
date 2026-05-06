import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Maps each [DisabilityType] to an optimized [AppSettings] preset.
///
/// These presets auto-configure accessibility features so PWD students
/// don't need to manually discover and toggle 15+ individual settings.
class AccessibilityPresets {
  const AccessibilityPresets._();

  /// Returns the recommended [AppSettings] for the given [DisabilityType].
  ///
  /// The preset is merged on top of the current settings so non-accessibility
  /// fields (locale, reminder time, etc.) are preserved.
  static AppSettings presetFor(
    DisabilityType type, {
    AppSettings current = const AppSettings(),
  }) {
    return switch (type) {
      DisabilityType.visual => current.copyWith(
          fontScale: 1.4,
          highContrastMode: true,
          darkMode: false,
          ttsEnabled: true,
          ttsSpeed: 0.4,
          voiceNavigation: true,
          soundEffects: true,
          adaptiveDifficulty: true,
        ),
      DisabilityType.hearing => current.copyWith(
          ttsEnabled: false,
          soundEffects: false,
          voiceNavigation: false,
          highContrastMode: true,
          fontScale: 1.2,
          adaptiveDifficulty: true,
          // Visual feedback emphasis — FSL videos prioritized
        ),
      DisabilityType.motor => current.copyWith(
          reducedMotion: true,
          fontScale: 1.2,
          ttsEnabled: true,
          ttsSpeed: 0.5,
          adaptiveDifficulty: true,
          soundEffects: true,
          // Larger tap targets via font scale; drag-and-drop may be skipped
        ),
      DisabilityType.cognitive => current.copyWith(
          adaptiveDifficulty: true,
          ttsEnabled: true,
          ttsSpeed: 0.35,
          reducedMotion: true,
          fontScale: 1.2,
          soundEffects: true,
          voiceNavigation: false,
        ),
      DisabilityType.multiple => current.copyWith(
          fontScale: 1.3,
          highContrastMode: true,
          ttsEnabled: true,
          ttsSpeed: 0.4,
          reducedMotion: true,
          voiceNavigation: true,
          adaptiveDifficulty: true,
          soundEffects: true,
        ),
      DisabilityType.none => current, // Keep defaults
    };
  }

  /// Returns a human-readable list of settings that will be changed
  /// when applying the preset for [type].
  static List<SettingChange> changeSummary(DisabilityType type) {
    return switch (type) {
      DisabilityType.visual => const [
          SettingChange('Font Size', 'Extra Large (140%)', '🔤'),
          SettingChange('High Contrast', 'On', '🎨'),
          SettingChange('Text-to-Speech', 'On (Slow)', '🗣️'),
          SettingChange('Voice Navigation', 'On', '🧭'),
          SettingChange('Dyslexia Font', 'On', '📝'),
        ],
      DisabilityType.hearing => const [
          SettingChange('Text-to-Speech', 'Off', '🔇'),
          SettingChange('Sound Effects', 'Off', '🔕'),
          SettingChange('High Contrast', 'On', '🎨'),
          SettingChange('Font Size', 'Large (120%)', '🔤'),
          SettingChange('FSL Videos', 'Prioritized', '🤟'),
        ],
      DisabilityType.motor => const [
          SettingChange('Reduced Motion', 'On', '🎬'),
          SettingChange('Font Size', 'Large (120%)', '🔤'),
          SettingChange('Text-to-Speech', 'On', '🗣️'),
          SettingChange('Adaptive Difficulty', 'On', '🎯'),
        ],
      DisabilityType.cognitive => const [
          SettingChange('Dyslexia Font', 'On', '📝'),
          SettingChange('Adaptive Difficulty', 'On', '🎯'),
          SettingChange('Text-to-Speech', 'On (Very Slow)', '🗣️'),
          SettingChange('Reduced Motion', 'On', '🎬'),
          SettingChange('Font Size', 'Large (120%)', '🔤'),
        ],
      DisabilityType.multiple => const [
          SettingChange('Font Size', 'Extra Large (130%)', '🔤'),
          SettingChange('High Contrast', 'On', '🎨'),
          SettingChange('Text-to-Speech', 'On (Slow)', '🗣️'),
          SettingChange('Reduced Motion', 'On', '🎬'),
          SettingChange('Dyslexia Font', 'On', '📝'),
          SettingChange('Voice Navigation', 'On', '🧭'),
        ],
      DisabilityType.none => const [],
    };
  }
}

/// Describes a single setting change for preview purposes.
class SettingChange {
  final String name;
  final String value;
  final String emoji;

  const SettingChange(this.name, this.value, this.emoji);
}
