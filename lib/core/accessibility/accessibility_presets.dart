import '../../data/models/enums.dart';
import 'learner_support.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';

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
        // High-contrast takes priority for visual disabilities; the
        // dyslexia palette would override the bright accessible
        // colours so we don't toggle it here even though the preset
        // summary mentions it for visual+cognitive overlap.
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
        // Dyslexia palette (cream surfaces + Lexend font) is the
        // single highest-impact change for cognitive-spectrum
        // learners — pair it with adaptive difficulty + reduced
        // motion. High-contrast is OFF so it doesn't override.
        dyslexiaMode: true,
        highContrastMode: false,
        darkMode: false,
      ),
      DisabilityType.multiple => current.copyWith(
        fontScale: 1.3,
        // For multi-disability profiles we default to high-contrast
        // (bigger win for mixed visual/motor needs) and leave the
        // dyslexia toggle for the user to switch on if reading is
        // the bigger pain point — they are mutually exclusive.
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

  /// Layer a learner's own supports on top of the category preset.
  ///
  /// The preset answers "what does this category need?"; this answers "and
  /// what did *this* learner ask for?". Only ever applied straight after
  /// [presetFor], so the learner's answer wins where the two disagree.
  ///
  /// Deliberately narrow. Every support listed here changes something a person
  /// can see; the rest are recorded on the profile for the teaching team and
  /// say so in their own description, rather than pretending to be switches.
  static AppSettings applySupports(
    AppSettings settings,
    Iterable<LearnerSupportOption> supports,
  ) {
    var next = settings;
    for (final support in supports) {
      next = switch (support) {
        // Blind / very low vision: the screen is the second channel.
        LearnerSupportOption.audioFirst => next.copyWith(
          ttsEnabled: true,
          voiceNavigation: true,
        ),
        // Usable vision, but only at size — and then TTS is a distraction
        // rather than the main road in, so it is left as the preset had it.
        LearnerSupportOption.largePrint => next.copyWith(
          fontScale: next.fontScale < 1.6 ? 1.6 : next.fontScale,
        ),
        LearnerSupportOption.spokenAnswerChoices =>
          next.copyWith(ttsEnabled: true),
        // A chime this learner cannot hear is not feedback; the visual
        // channel has to carry it alone.
        LearnerSupportOption.visualAlerts => next.copyWith(soundEffects: false),
        // Fewer things at once, and slow enough to follow.
        LearnerSupportOption.stepByStep => next.copyWith(
          slowMotionEnabled: true,
          dailyMissionSize: 3,
        ),
        LearnerSupportOption.simplifiedLanguage => next.copyWith(
          learningAssistEnabled: true,
        ),
        _ => next,
      };
    }
    return next;
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
        SettingChange('Gaze Control', 'On (hands-free)', '👁️'),
      ],
      DisabilityType.cognitive => const [
        SettingChange('Dyslexia-friendly', 'On', '📝'),
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
        SettingChange('Voice Navigation', 'On', '🧭'),
        SettingChange('Gaze Control', 'On (hands-free)', '👁️'),
      ],
      DisabilityType.none => const [],
    };
  }

  /// Whether this category should have hands-free Gaze Control switched on
  /// with the rest of its preset.
  ///
  /// Gaze lives outside [AppSettings] (its own provider and Hive key), so
  /// [presetFor] cannot set it — the caller applies this alongside the preset.
  /// It is limited to the categories whose defining barrier is *reaching the
  /// screen*; for everyone else the front camera stays off unless they ask for
  /// it. The learner sees "Gaze Control — On (hands-free)" in the preview and
  /// confirms before anything is applied, and it can be switched off again in
  /// Settings → Accessibility.
  static bool enablesGazeControl(DisabilityType type) =>
      type == DisabilityType.motor || type == DisabilityType.multiple;
}

/// Describes a single setting change for preview purposes.
class SettingChange {
  final String name;
  final String value;
  final String emoji;

  const SettingChange(this.name, this.value, this.emoji);

  /// [name] in the reader's language. The list stays in English as data.
  String nameOf(AppLocalizations? l10n) {
    if (l10n == null) return name;
    return switch (name) {
      'Adaptive Difficulty' => l10n.apAdaptive,
      'Dyslexia-friendly' => l10n.apDyslexia,
      'FSL Videos' => l10n.apFslVideos,
      'Font Size' => l10n.apFontSize,
      'Gaze Control' => l10n.apGaze,
      'High Contrast' => l10n.apHighContrast,
      'Reduced Motion' => l10n.apReducedMotion,
      'Sound Effects' => l10n.apSoundEffects,
      'Text-to-Speech' => l10n.apTts,
      'Voice Navigation' => l10n.apVoiceNav,
      _ => name,
    };
  }

  /// [value] in the reader's language.
  String valueOf(AppLocalizations? l10n) {
    if (l10n == null) return value;
    return switch (value) {
      'On' => l10n.apOn,
      'Off' => l10n.apOff,
      'Prioritized' => l10n.apPrioritized,
      'Extra Large (130%)' => l10n.apXl130,
      'Extra Large (140%)' => l10n.apXl140,
      'Large (120%)' => l10n.apLarge120,
      'On (hands-free)' => l10n.apHandsFree,
      'On (Slow)' => l10n.apSlow,
      'On (Very Slow)' => l10n.apVerySlow,
      _ => value,
    };
  }
}
