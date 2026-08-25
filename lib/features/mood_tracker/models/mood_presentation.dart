import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'mood_models.dart';

/// How the wellbeing check-in presents itself to a given learner.
///
/// Every other adaptive surface in this app already has one of these — the
/// games roster (`GameCatalog`), the AI companion (`CompanionPresentation`),
/// the Progress tab (`ProgressPresentation`), Talk Board
/// (`BoardPresentation`), Play Together (`RacePresentation`). Mood Check-In
/// was a holdout: it rendered a six-way emoji grid, a free-text field and a
/// numeric "Avg 2.0/6" identically for every learner.
///
/// What that cost, concretely:
///   * A learner with a cognitive/learning disability was asked to
///     discriminate between six feelings — *tired* vs *sad* vs *frustrated* is
///     a fine distinction — and then shown their feelings as a decimal.
///   * A blind learner met a grid whose entire meaning is emoji glyphs, and
///     screen-reader labels that stayed English even in Filipino mode.
///   * A learner with a motor impairment was offered an optional free-text
///     note as the only way to say anything beyond the six faces.
///
/// Kept pure (no I/O, no BuildContext) so the whole matrix is unit-testable,
/// exactly like [ProgressPresentation].
class MoodPresentation {
  /// The moods actually offered, in display order. Shortened where six
  /// near-synonymous faces are themselves the barrier.
  final List<MoodType> choices;

  /// Offer the optional free-text note field.
  final bool showNote;

  /// Offer the mood trend chart and the "Avg x.x/6" figures. Off wherever a
  /// number is a worse answer to "how have I been?" than a row of faces.
  final bool showNumericAverage;

  /// Speak the selected mood aloud on confirmation.
  final bool speakSelection;

  /// Run the entrance animations.
  final bool animate;

  const MoodPresentation({
    required this.choices,
    required this.showNote,
    required this.showNumericAverage,
    required this.speakSelection,
    required this.animate,
  });

  /// The three-way core set. Every learner can answer "good / okay / bad",
  /// and these three are the ones whose faces are unmistakable.
  static const List<MoodType> simpleChoices = [
    MoodType.happy,
    MoodType.neutral,
    MoodType.sad,
  ];

  /// The full six-way set, in the order the screen has always shown them.
  static const List<MoodType> fullChoices = MoodType.values;

  bool get isSimplified => choices.length < MoodType.values.length;

  factory MoodPresentation.forProfile(DisabilityType type, AppSettings s) {
    // Fewer, clearly-distinct faces where discriminating six shades of
    // feeling is the barrier rather than the point.
    final simplified =
        type == DisabilityType.cognitive || type == DisabilityType.multiple;

    // Typing a note is a keyboard task. Off where the keyboard is the
    // obstacle (motor) or the reading/writing load is (cognitive, multiple).
    final canType = !simplified && type != DisabilityType.motor;

    // Speak the choice back for anyone already using text-to-speech, and
    // always for visual / multiple where the emoji carries all the meaning.
    // Mirrors `ProgressPresentation.speakSummary`.
    final speak = s.ttsEnabled ||
        type == DisabilityType.visual ||
        type == DisabilityType.multiple;

    return MoodPresentation(
      choices: simplified ? simpleChoices : fullChoices,
      showNote: canType,
      showNumericAverage: !simplified,
      speakSelection: speak,
      animate: !s.reducedMotion,
    );
  }
}

/// Mood presentation for the active learner.
final moodPresentationProvider = Provider<MoodPresentation>((ref) {
  final profile = ref.watch(profileProvider);
  final settings = ref.watch(settingsProvider);
  return MoodPresentation.forProfile(
    profile?.disabilityType ?? DisabilityType.none,
    settings,
  );
});
