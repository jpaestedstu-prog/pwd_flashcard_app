import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';

/// A configurable support a learner's profile carries **in addition to** its
/// [DisabilityType].
///
/// The accessibility category answers "what is the barrier?"; these answer
/// "how does *this* learner get past it?". Two Deaf students in the same class
/// can sign in different systems, and one may not sign at all — the category
/// alone cannot express that, so the app used to treat every hearing-impaired
/// learner as an FSL signer.
///
/// Persisted by [Enum.name], never by index, so the enum can be reordered or
/// extended without rewriting stored profiles. An unrecognised id read back
/// from an older / newer install is dropped rather than fatal — see
/// [LearnerSupportCatalog.decode].
enum LearnerSupportOption {
  // ─── Hearing: primary communication / language system ───
  signFsl,
  signAsl,
  signSee,
  cuedSpeech,
  oralLipReading,
  writtenCaptions,

  // ─── Hearing: additional supports ───
  captionsAlwaysOn,
  visualAlerts,

  // ─── Visual: primary route to the screen ───
  audioFirst,
  largePrint,

  // ─── Visual: additional supports ───
  spokenAnswerChoices,

  // ─── Motor: primary input method ───
  inputTouch,
  inputGaze,
  inputSwitch,

  // ─── Cognitive: primary learning support ───
  simplifiedLanguage,
  picturePrompts,
  stepByStep,

  // ─── Cognitive: additional supports ───
  repeatInstructions,
  fewerChoices,

  // ─── Cross-cutting ───
  extendedTestTime,
}

extension LearnerSupportOptionX on LearnerSupportOption {
  String get label => switch (this) {
    LearnerSupportOption.signFsl => 'Filipino Sign Language (FSL)',
    LearnerSupportOption.signAsl => 'American Sign Language (ASL)',
    LearnerSupportOption.signSee => 'Signing Exact English (SEE)',
    LearnerSupportOption.cuedSpeech => 'Cued Speech',
    LearnerSupportOption.oralLipReading => 'Speech & Lip Reading',
    LearnerSupportOption.writtenCaptions => 'Written words only',
    LearnerSupportOption.captionsAlwaysOn => 'Captions always on',
    LearnerSupportOption.visualAlerts => 'Flash instead of sound',
    LearnerSupportOption.audioFirst => 'Listen first (screen reader)',
    LearnerSupportOption.largePrint => 'Large print',
    LearnerSupportOption.spokenAnswerChoices => 'Read the choices aloud',
    LearnerSupportOption.inputTouch => 'Touch',
    LearnerSupportOption.inputGaze => 'Eye gaze (hands-free)',
    LearnerSupportOption.inputSwitch => 'Switch or gamepad',
    LearnerSupportOption.simplifiedLanguage => 'Simple words',
    LearnerSupportOption.picturePrompts => 'Picture support',
    LearnerSupportOption.stepByStep => 'One step at a time',
    LearnerSupportOption.repeatInstructions => 'Repeat instructions',
    LearnerSupportOption.fewerChoices => 'Fewer answer choices',
    LearnerSupportOption.extendedTestTime => 'Extra time on tests',
  };

  String get description => switch (this) {
    LearnerSupportOption.signFsl =>
      'Signs used in Filipino Deaf schools. The app’s sign clips are in FSL.',
    LearnerSupportOption.signAsl => 'Signs used in American Deaf communities.',
    LearnerSupportOption.signSee =>
      'Signs that follow English word order, sign for sign.',
    LearnerSupportOption.cuedSpeech =>
      'Hand shapes near the mouth that make speech sounds visible.',
    LearnerSupportOption.oralLipReading =>
      'Learns by watching the mouth and using any remaining hearing.',
    LearnerSupportOption.writtenCaptions =>
      'Reads text instead of signing. Sign clips stay hidden.',
    LearnerSupportOption.captionsAlwaysOn =>
      'Every video and story shows its text. Noted on the profile for the '
          'teaching team.',
    LearnerSupportOption.visualAlerts =>
      'Screen flashes and badges stand in for chimes.',
    LearnerSupportOption.audioFirst =>
      'Everything is spoken; the screen is the second channel.',
    LearnerSupportOption.largePrint => 'Very large type, few items per screen.',
    LearnerSupportOption.spokenAnswerChoices =>
      'Each answer choice is spoken before the learner picks.',
    LearnerSupportOption.inputTouch => 'Taps the screen as usual.',
    LearnerSupportOption.inputGaze => 'Controls the app by looking at it.',
    LearnerSupportOption.inputSwitch =>
      'Uses a Bluetooth gamepad or switch instead of touch.',
    LearnerSupportOption.simplifiedLanguage =>
      'Short sentences and everyday words.',
    LearnerSupportOption.picturePrompts =>
      'A picture goes with every instruction. Noted on the profile for the '
          'teaching team.',
    LearnerSupportOption.stepByStep =>
      'One instruction at a time, with a clear next step.',
    LearnerSupportOption.repeatInstructions =>
      'Instructions can be replayed as often as needed. Noted on the profile '
          'for the teaching team.',
    LearnerSupportOption.fewerChoices =>
      'Questions offer two choices instead of four.',
    LearnerSupportOption.extendedTestTime =>
      'Timed assessments give this learner half again as long.',
  };

  String get emoji => switch (this) {
    LearnerSupportOption.signFsl => '🇵🇭',
    LearnerSupportOption.signAsl => '🤟',
    LearnerSupportOption.signSee => '✋',
    LearnerSupportOption.cuedSpeech => '👄',
    LearnerSupportOption.oralLipReading => '🗣️',
    LearnerSupportOption.writtenCaptions => '📝',
    LearnerSupportOption.captionsAlwaysOn => '💬',
    LearnerSupportOption.visualAlerts => '💡',
    LearnerSupportOption.audioFirst => '🔊',
    LearnerSupportOption.largePrint => '🔠',
    LearnerSupportOption.spokenAnswerChoices => '🎧',
    LearnerSupportOption.inputTouch => '👆',
    LearnerSupportOption.inputGaze => '👁️',
    LearnerSupportOption.inputSwitch => '🎮',
    LearnerSupportOption.simplifiedLanguage => '🔤',
    LearnerSupportOption.picturePrompts => '🖼️',
    LearnerSupportOption.stepByStep => '🪜',
    LearnerSupportOption.repeatInstructions => '🔁',
    LearnerSupportOption.fewerChoices => '✌️',
    LearnerSupportOption.extendedTestTime => '⏱️',
  };

  /// Localized [label], for the picker and the chips a family reads.
  ///
  /// Nullable l10n falling back to English, like `DisabilityTypeX.labelOf` —
  /// these appear inside semantics strings on screens that widget tests build
  /// without the delegate. [label] itself stays English because the research
  /// export prints it.
  String labelOf(AppLocalizations? l10n) =>
      l10n == null ? label : switch (this) {
        LearnerSupportOption.signFsl => l10n.supportSignFsl,
        LearnerSupportOption.signAsl => l10n.supportSignAsl,
        LearnerSupportOption.signSee => l10n.supportSignSee,
        LearnerSupportOption.cuedSpeech => l10n.supportCuedSpeech,
        LearnerSupportOption.oralLipReading => l10n.supportOralLipReading,
        LearnerSupportOption.writtenCaptions => l10n.supportWrittenCaptions,
        LearnerSupportOption.captionsAlwaysOn => l10n.supportCaptionsAlwaysOn,
        LearnerSupportOption.visualAlerts => l10n.supportVisualAlerts,
        LearnerSupportOption.audioFirst => l10n.supportAudioFirst,
        LearnerSupportOption.largePrint => l10n.supportLargePrint,
        LearnerSupportOption.spokenAnswerChoices => l10n.supportSpokenAnswerChoices,
        LearnerSupportOption.inputTouch => l10n.supportInputTouch,
        LearnerSupportOption.inputGaze => l10n.supportInputGaze,
        LearnerSupportOption.inputSwitch => l10n.supportInputSwitch,
        LearnerSupportOption.simplifiedLanguage => l10n.supportSimplifiedLanguage,
        LearnerSupportOption.picturePrompts => l10n.supportPicturePrompts,
        LearnerSupportOption.stepByStep => l10n.supportStepByStep,
        LearnerSupportOption.repeatInstructions => l10n.supportRepeatInstructions,
        LearnerSupportOption.fewerChoices => l10n.supportFewerChoices,
        LearnerSupportOption.extendedTestTime => l10n.supportExtendedTestTime,
      };

  /// Localized [description].
  String descriptionOf(AppLocalizations? l10n) =>
      l10n == null ? description : switch (this) {
        LearnerSupportOption.signFsl => l10n.supportSignFslDesc,
        LearnerSupportOption.signAsl => l10n.supportSignAslDesc,
        LearnerSupportOption.signSee => l10n.supportSignSeeDesc,
        LearnerSupportOption.cuedSpeech => l10n.supportCuedSpeechDesc,
        LearnerSupportOption.oralLipReading => l10n.supportOralLipReadingDesc,
        LearnerSupportOption.writtenCaptions => l10n.supportWrittenCaptionsDesc,
        LearnerSupportOption.captionsAlwaysOn => l10n.supportCaptionsAlwaysOnDesc,
        LearnerSupportOption.visualAlerts => l10n.supportVisualAlertsDesc,
        LearnerSupportOption.audioFirst => l10n.supportAudioFirstDesc,
        LearnerSupportOption.largePrint => l10n.supportLargePrintDesc,
        LearnerSupportOption.spokenAnswerChoices => l10n.supportSpokenAnswerChoicesDesc,
        LearnerSupportOption.inputTouch => l10n.supportInputTouchDesc,
        LearnerSupportOption.inputGaze => l10n.supportInputGazeDesc,
        LearnerSupportOption.inputSwitch => l10n.supportInputSwitchDesc,
        LearnerSupportOption.simplifiedLanguage => l10n.supportSimplifiedLanguageDesc,
        LearnerSupportOption.picturePrompts => l10n.supportPicturePromptsDesc,
        LearnerSupportOption.stepByStep => l10n.supportStepByStepDesc,
        LearnerSupportOption.repeatInstructions => l10n.supportRepeatInstructionsDesc,
        LearnerSupportOption.fewerChoices => l10n.supportFewerChoicesDesc,
        LearnerSupportOption.extendedTestTime => l10n.supportExtendedTestTimeDesc,
      };

  /// Short form for chips and roster rows, where the full label is too long.
  String get shortLabel => switch (this) {
    LearnerSupportOption.signFsl => 'FSL',
    LearnerSupportOption.signAsl => 'ASL',
    LearnerSupportOption.signSee => 'SEE',
    LearnerSupportOption.cuedSpeech => 'Cued Speech',
    LearnerSupportOption.oralLipReading => 'Lip reading',
    LearnerSupportOption.writtenCaptions => 'Written',
    LearnerSupportOption.audioFirst => 'Audio first',
    LearnerSupportOption.inputGaze => 'Gaze',
    LearnerSupportOption.inputSwitch => 'Switch',
    LearnerSupportOption.inputTouch => 'Touch',
    _ => label,
  };

  /// [shortLabel] in the reader's language. The names of signing systems and
  /// of switch access stay as they are — they are what people call them.
  String shortLabelOf(AppLocalizations? l10n) {
    if (l10n == null) return shortLabel;
    return switch (this) {
      LearnerSupportOption.signFsl ||
      LearnerSupportOption.signAsl ||
      LearnerSupportOption.signSee ||
      LearnerSupportOption.cuedSpeech ||
      LearnerSupportOption.inputSwitch => shortLabel,
      LearnerSupportOption.oralLipReading => l10n.supportShortLipReading,
      LearnerSupportOption.writtenCaptions => l10n.supportShortWritten,
      LearnerSupportOption.audioFirst => l10n.supportShortAudioFirst,
      LearnerSupportOption.inputGaze => l10n.supportShortGaze,
      LearnerSupportOption.inputTouch => l10n.supportShortTouch,
      _ => labelOf(l10n),
    };
  }

  /// True for the systems that are *signed*. The app ships FSL media, so a
  /// signing learner keeps the sign-video surfaces even when their own system
  /// is ASL or SEE — the surfaces say plainly that the clips are FSL. A learner
  /// who reads or lip-reads instead gets no sign video at all.
  bool get isSigningSystem =>
      this == LearnerSupportOption.signFsl ||
      this == LearnerSupportOption.signAsl ||
      this == LearnerSupportOption.signSee ||
      this == LearnerSupportOption.cuedSpeech;
}

/// One block of choices inside a learner's support setup.
///
/// A [singleChoice] group is the learner's *primary* mode — a communication
/// system, an input method — and always carries exactly one selection. The
/// multi-select groups are additive extras and may be empty.
class LearnerSupportGroup {
  final String id;
  final String title;
  final String description;
  final bool singleChoice;
  final List<LearnerSupportOption> options;

  const LearnerSupportGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.singleChoice,
    required this.options,
  });

  /// The option a new profile starts on. Single-choice groups always have one.
  LearnerSupportOption get defaultOption => options.first;

  /// Localized [title]. Keyed on [id] rather than on identity so the const
  /// group definitions stay plain data.
  String titleOf(AppLocalizations? l10n) =>
      l10n == null ? title : switch (id) {
        'communication' => l10n.supportGroupCommunication,
        'hearing_extras' => l10n.supportGroupHearingExtras,
        'visual_access' => l10n.supportGroupVisualAccess,
        'visual_extras' => l10n.supportGroupVisualExtras,
        'input' => l10n.supportGroupInput,
        'motor_extras' => l10n.supportGroupMotorExtras,
        'thinking' => l10n.supportGroupThinking,
        'cognitive_extras' => l10n.supportGroupCognitiveExtras,
        'multiple_extras' => l10n.supportGroupOther,
        'general' => l10n.supportGroupOptional,
        _ => title,
      };

  /// Localized [description].
  String descriptionOf(AppLocalizations? l10n) =>
      l10n == null ? description : switch (id) {
        'communication' => l10n.supportGroupCommunicationDesc,
        'visual_access' => l10n.supportGroupVisualAccessDesc,
        'input' => l10n.supportGroupInputDesc,
        'thinking' => l10n.supportGroupThinkingDesc,
        'general' => l10n.supportGroupNoneDesc,
        // Every extras group asks the same question, so they share a line.
        _ => l10n.supportGroupExtrasDesc,
      };
}

/// Which supports each accessibility category offers, and what a fresh profile
/// in that category starts with.
///
/// The defaults reproduce exactly what the app did before this existed — FSL
/// for Deaf learners, audio for blind ones, gaze for motor — so the feature
/// changes nothing until somebody configures it.
class LearnerSupportCatalog {
  const LearnerSupportCatalog._();

  // ─── Groups, by accessibility category ───────────────────

  static const _hearingCommunication = LearnerSupportGroup(
    id: 'communication',
    title: 'Communication & language',
    description: 'How this learner takes in language. Pick one.',
    singleChoice: true,
    options: [
      LearnerSupportOption.signFsl,
      LearnerSupportOption.signAsl,
      LearnerSupportOption.signSee,
      LearnerSupportOption.cuedSpeech,
      LearnerSupportOption.oralLipReading,
      LearnerSupportOption.writtenCaptions,
    ],
  );

  static const _hearingExtras = LearnerSupportGroup(
    id: 'hearing_extras',
    title: 'Hearing supports',
    description: 'Add anything else that helps.',
    singleChoice: false,
    options: [
      LearnerSupportOption.captionsAlwaysOn,
      LearnerSupportOption.visualAlerts,
      LearnerSupportOption.extendedTestTime,
    ],
  );

  static const _visualAccess = LearnerSupportGroup(
    id: 'visual_access',
    title: 'Reading the screen',
    description: 'How this learner gets at what is on screen. Pick one.',
    singleChoice: true,
    options: [
      LearnerSupportOption.audioFirst,
      LearnerSupportOption.largePrint,
    ],
  );

  static const _visualExtras = LearnerSupportGroup(
    id: 'visual_extras',
    title: 'Vision supports',
    description: 'Add anything else that helps.',
    singleChoice: false,
    options: [
      LearnerSupportOption.spokenAnswerChoices,
      LearnerSupportOption.extendedTestTime,
    ],
  );

  static const _input = LearnerSupportGroup(
    id: 'input',
    title: 'Controlling the app',
    description: 'How this learner moves around the app. Pick one.',
    singleChoice: true,
    options: [
      LearnerSupportOption.inputTouch,
      LearnerSupportOption.inputGaze,
      LearnerSupportOption.inputSwitch,
    ],
  );

  static const _motorExtras = LearnerSupportGroup(
    id: 'motor_extras',
    title: 'Movement supports',
    description: 'Add anything else that helps.',
    singleChoice: false,
    options: [LearnerSupportOption.extendedTestTime],
  );

  static const _thinking = LearnerSupportGroup(
    id: 'thinking',
    title: 'Learning support',
    description: 'How instructions should reach this learner. Pick one.',
    singleChoice: true,
    options: [
      LearnerSupportOption.simplifiedLanguage,
      LearnerSupportOption.picturePrompts,
      LearnerSupportOption.stepByStep,
    ],
  );

  static const _cognitiveExtras = LearnerSupportGroup(
    id: 'cognitive_extras',
    title: 'Understanding supports',
    description: 'Add anything else that helps.',
    singleChoice: false,
    options: [
      LearnerSupportOption.repeatInstructions,
      LearnerSupportOption.fewerChoices,
      LearnerSupportOption.extendedTestTime,
    ],
  );

  static const _multipleExtras = LearnerSupportGroup(
    id: 'multiple_extras',
    title: 'Other supports',
    description: 'Add anything else that helps.',
    singleChoice: false,
    options: [
      LearnerSupportOption.captionsAlwaysOn,
      LearnerSupportOption.visualAlerts,
      LearnerSupportOption.spokenAnswerChoices,
      LearnerSupportOption.repeatInstructions,
      LearnerSupportOption.fewerChoices,
      LearnerSupportOption.extendedTestTime,
    ],
  );

  static const _general = LearnerSupportGroup(
    id: 'general',
    title: 'Optional supports',
    description: 'Nothing here is required.',
    singleChoice: false,
    options: [LearnerSupportOption.extendedTestTime],
  );

  /// The groups offered for [type], in the order they should be shown.
  ///
  /// `multiple` deliberately offers every primary group: a learner who is both
  /// Deaf and has low vision needs a communication system *and* a route to the
  /// screen, and picking one category for them loses the other.
  static List<LearnerSupportGroup> groupsFor(DisabilityType type) {
    return switch (type) {
      DisabilityType.hearing => const [_hearingCommunication, _hearingExtras],
      DisabilityType.visual => const [_visualAccess, _visualExtras],
      DisabilityType.motor => const [_input, _motorExtras],
      DisabilityType.cognitive => const [_thinking, _cognitiveExtras],
      DisabilityType.multiple => const [
        _hearingCommunication,
        _visualAccess,
        _input,
        _thinking,
        _multipleExtras,
      ],
      // A learner with no flagged barrier still sits timed tests, so the one
      // accommodation that is not tied to a barrier stays available.
      DisabilityType.none => const [_general],
    };
  }

  /// Every option [type] offers, in any group.
  static Set<LearnerSupportOption> optionsFor(DisabilityType type) => {
    for (final g in groupsFor(type)) ...g.options,
  };

  /// What a freshly created profile of [type] starts with.
  ///
  /// Spelled out per category rather than derived from the group order,
  /// because these have to match what the app already did before anyone could
  /// configure anything: FSL for a Deaf learner, audio for a blind one, and
  /// hands-free gaze for a motor learner — which is precisely what
  /// `AccessibilityPresets.enablesGazeControl` switched on for them. Getting
  /// this wrong would quietly take gaze control away from every existing
  /// motor-impairment profile.
  static Set<LearnerSupportOption> defaultsFor(DisabilityType type) {
    return switch (type) {
      DisabilityType.hearing => const {LearnerSupportOption.signFsl},
      DisabilityType.visual => const {LearnerSupportOption.audioFirst},
      DisabilityType.motor => const {LearnerSupportOption.inputGaze},
      DisabilityType.cognitive => const {
        LearnerSupportOption.simplifiedLanguage,
      },
      DisabilityType.multiple => const {
        LearnerSupportOption.signFsl,
        LearnerSupportOption.audioFirst,
        LearnerSupportOption.inputGaze,
        LearnerSupportOption.simplifiedLanguage,
      },
      DisabilityType.none => const {},
    };
  }

  /// Clean [chosen] up for [type]: drop anything this category does not offer,
  /// keep exactly one option per single-choice group, and fill a missing
  /// primary choice from the group default.
  ///
  /// Called on every read and every write, so a learner whose accessibility
  /// category is changed later (Deaf → Multiple, say) never keeps a support
  /// that no longer applies, and never ends up with no primary mode at all.
  static Set<LearnerSupportOption> normalize(
    DisabilityType type,
    Iterable<LearnerSupportOption> chosen,
  ) {
    final picked = chosen.toSet();
    final fallbacks = defaultsFor(type);
    final result = <LearnerSupportOption>{};
    for (final group in groupsFor(type)) {
      final inGroup = group.options.where(picked.contains).toList();
      if (group.singleChoice) {
        result.add(
          inGroup.isNotEmpty
              ? inGroup.first
              : group.options.firstWhere(
                  fallbacks.contains,
                  orElse: () => group.defaultOption,
                ),
        );
      } else {
        result.addAll(inGroup);
      }
    }
    return result;
  }

  /// The learner's stored supports, or the category defaults when they have
  /// none — which is every profile created before this feature existed.
  static Set<LearnerSupportOption> effective(
    DisabilityType type,
    Iterable<LearnerSupportOption> stored,
  ) {
    final list = stored.toList();
    return list.isEmpty ? defaultsFor(type) : normalize(type, list);
  }

  /// Decode persisted ids, skipping anything this build does not know.
  static Set<LearnerSupportOption> decode(Iterable<dynamic>? raw) {
    if (raw == null) return const {};
    final byName = {for (final o in LearnerSupportOption.values) o.name: o};
    final result = <LearnerSupportOption>{};
    for (final entry in raw) {
      final option = byName[entry.toString()];
      if (option != null) result.add(option);
    }
    return result;
  }

  /// Encode for storage. Sorted by declaration order so the same set always
  /// writes the same list, and a no-op save cannot look like a change.
  static List<String> encode(Iterable<LearnerSupportOption> options) {
    final list = options.toList()..sort((a, b) => a.index.compareTo(b.index));
    return list.map((o) => o.name).toList();
  }

  /// The primary communication system in [options], if the learner has one.
  static LearnerSupportOption? communicationModeIn(
    Iterable<LearnerSupportOption> options,
  ) => _firstIn(options, _hearingCommunication.options);

  /// The primary input method in [options], if the learner has one.
  static LearnerSupportOption? inputModeIn(
    Iterable<LearnerSupportOption> options,
  ) => _firstIn(options, _input.options);

  static LearnerSupportOption? _firstIn(
    Iterable<LearnerSupportOption> options,
    List<LearnerSupportOption> group,
  ) {
    for (final option in group) {
      if (options.contains(option)) return option;
    }
    return null;
  }

  /// How long a learner with [supports] actually gets on a test the educator
  /// limited to [baseMinutes].
  ///
  /// Returns null — meaning untimed — when there is no limit to extend, so an
  /// accommodation can never *impose* a clock on a learner who had none. The
  /// extension is 50%, rounded up, which is the ratio Philippine SPED practice
  /// and most testing accommodations use.
  static int? timeLimitMinutes(
    int? baseMinutes,
    Iterable<LearnerSupportOption> supports,
  ) {
    if (baseMinutes == null || baseMinutes <= 0) return null;
    if (!supports.contains(LearnerSupportOption.extendedTestTime)) {
      return baseMinutes;
    }
    return (baseMinutes * 3 + 1) ~/ 2;
  }

  /// Colour for a support chip, matched to the category it came from so a
  /// roster row reads at a glance.
  static Color colorFor(LearnerSupportOption option) {
    if (_hearingCommunication.options.contains(option) ||
        _hearingExtras.options.contains(option)) {
      return DisabilityType.hearing.color;
    }
    if (_visualAccess.options.contains(option) ||
        _visualExtras.options.contains(option)) {
      return DisabilityType.visual.color;
    }
    if (_input.options.contains(option) ||
        _motorExtras.options.contains(option)) {
      return DisabilityType.motor.color;
    }
    return DisabilityType.cognitive.color;
  }
}
