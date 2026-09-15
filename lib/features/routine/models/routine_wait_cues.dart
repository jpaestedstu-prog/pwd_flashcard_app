import '../../../data/models/enums.dart';
import 'routine_catalog.dart';

/// What the "Please wait" part of a routine lock shows and says, per
/// accessibility category.
///
/// A learner held on a step until its time ends needs to understand two
/// things: *wait*, and *for how long*. Words alone carry neither to every
/// learner, so each category gets the channels that reach it:
///
///  * **Visual** — the shrinking timer drawn large and in strong colour for
///    low vision, and the time left spoken at the milestones (five minutes,
///    one minute), because a screen they cannot read cannot tell them.
///  * **Hearing** — a picture timer and Filipino Sign Language: *PLEASE* and
///    *CALM*, real signs from the app's own dictionary (there is no clip for
///    "wait"). Nothing is spoken — it would only reach the room.
///  * **Motor** — the picture timer, large. The wait needs no input at all,
///    which is exactly right for this learner.
///  * **Cognitive** — the biggest timer, a *First / Then* card ("First:
///    brushing teeth. Then: breakfast.") — the visual support this learner
///    already uses in class — and the milestones spoken in short sentences.
///  * **Multiple** — every channel: timer, First / Then, signs and speech.
///  * **None** — the timer beside the words.
///
/// Pure and Flutter-free, like `LockPresentation`, so the matrix is tested
/// once.
class RoutineWaitCues {
  /// Draw the shrinking picture timer.
  final bool showTimer;

  /// Its diameter in logical pixels.
  final double timerSize;

  /// Show a First / Then card naming what comes after this step.
  final bool firstThen;

  /// FSL signs offered with the wait, in signing order. Empty offers none.
  final List<FslSignCue> signs;

  /// Say the time left out loud at [milestones].
  final bool speakMilestones;

  const RoutineWaitCues({
    required this.showTimer,
    required this.timerSize,
    required this.firstThen,
    required this.signs,
    required this.speakMilestones,
  });

  /// Minutes left at which [speakMilestones] speaks, largest first.
  static const List<int> milestones = [5, 1];

  /// "Please", "calm" — the signs for waiting patiently.
  static const List<FslSignCue> waitSigns = [
    FslSignCue('Please'),
    FslSignCue('Calm'),
  ];

  factory RoutineWaitCues.forType(DisabilityType type) => switch (type) {
        DisabilityType.visual => const RoutineWaitCues(
            showTimer: true,
            timerSize: 132,
            firstThen: false,
            signs: [],
            speakMilestones: true,
          ),
        DisabilityType.hearing => const RoutineWaitCues(
            showTimer: true,
            timerSize: 120,
            firstThen: false,
            signs: waitSigns,
            speakMilestones: false,
          ),
        DisabilityType.motor => const RoutineWaitCues(
            showTimer: true,
            timerSize: 120,
            firstThen: false,
            signs: [],
            speakMilestones: false,
          ),
        DisabilityType.cognitive => const RoutineWaitCues(
            showTimer: true,
            timerSize: 148,
            firstThen: true,
            signs: [],
            speakMilestones: true,
          ),
        DisabilityType.multiple => const RoutineWaitCues(
            showTimer: true,
            timerSize: 148,
            firstThen: true,
            signs: waitSigns,
            speakMilestones: true,
          ),
        DisabilityType.none => const RoutineWaitCues(
            showTimer: true,
            timerSize: 104,
            firstThen: false,
            signs: [],
            speakMilestones: false,
          ),
      };

  /// The milestone [minutesLeft] has just reached, or null — only milestones
  /// shorter than the step itself, so a five-minute step does not announce
  /// "five minutes left" the moment it starts.
  static int? milestoneFor({
    required int minutesLeft,
    required int totalMinutes,
  }) {
    for (final m in milestones) {
      if (minutesLeft == m && totalMinutes > m) return m;
    }
    return null;
  }
}
