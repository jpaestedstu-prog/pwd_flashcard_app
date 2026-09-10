import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'routine_models.dart';

/// How a daily routine presents itself to one learner.
///
/// The house `*Presentation` pattern — pure, no Flutter, no I/O, one factory —
/// so the whole matrix is unit-testable and the routine widgets read flags
/// instead of branching on [DisabilityType] in a dozen places. Siblings:
/// `BoardPresentation`, `RacePresentation`, `ProgressPresentation`,
/// `LockPresentation`.
///
/// A routine is unusual among this app's learner surfaces in that it is
/// *about* structure — the accessibility question is not only "can this
/// learner perceive it" but "how much of the day should be on screen at
/// once". Rationale per category:
///
///   * **Visual** — nothing on this screen is legible without the screen
///     reader, so [speakOnOpen] narrates each step as it opens and
///     [announceProgress] speaks the tick-off out loud. The media strip is
///     reordered to put [RoutineMediaKind.audio] first, and photos/GIFs are
///     kept (a low-vision learner may still use them, and a sighted helper
///     often shares the device) but never the *only* channel. Timers are
///     spoken at their milestones rather than only drawn.
///   * **Hearing (Deaf / HoH)** — [showFsl] is the point of this whole
///     feature for them: every step gets a Signs button, and a step carrying
///     a video gets an FSL button *on the video itself*, which is what the
///     brief asked for. [speakOnOpen] stays off — speech the learner cannot
///     hear is feedback only to the room — and the audio slot is demoted to
///     last so it never sits where the primary content should be.
///   * **Motor** — one step at a time, big targets, and no drag: reordering
///     is a menu action, not a long-press-and-drag, because a drag is the
///     single hardest gesture for an unsteady hand or a gaze cursor. Steps
///     are ticked from a full-width button rather than a small checkbox.
///   * **Cognitive / multiple** — the day is the barrier. [stepsPerView] of
///     one, [showOnlyNextStep] so the child sees *now* rather than a wall of
///     fourteen rows, instructions always expanded, and the timer shown as a
///     shrinking bar rather than a number. This is the configuration the
///     visual-schedule literature actually describes.
///   * **None** — the full day at a glance. Students without an assigned
///     accessibility category, Players and educator previews land here.
class RoutinePresentation {
  /// How many steps are visible at once in the learner's list. A large number
  /// means "the whole day"; one means "now, and nothing else".
  final int stepsPerView;

  /// Collapse the day to the next incomplete step, with the rest behind a
  /// "show the whole day" affordance.
  final bool showOnlyNextStep;

  /// Speak the step's title and cue the moment it opens.
  final bool speakOnOpen;

  /// Speak a short confirmation when a step is ticked off.
  final bool announceProgress;

  /// Offer the Filipino Sign Language button on steps and on step videos.
  final bool showFsl;

  /// Play the app's sound effects for tick-off and completion.
  final bool playSoundCues;

  /// Expand the visual instruction list by default instead of behind a tap.
  final bool instructionsExpanded;

  /// Show the countdown as a shrinking bar (concrete) rather than a
  /// mm:ss readout (abstract).
  final bool timerAsBar;

  /// Reorder steps by dragging. Off for motor: a drag is the hardest gesture
  /// on this screen, and the same reorder is always available from the menu.
  final bool allowDragReorder;

  /// Order the media strip puts its channels in. Every supplied channel is
  /// always shown — this decides which one the learner meets *first*.
  final List<RoutineMediaKind> mediaOrder;

  /// Tick a step off with a full-width button rather than a checkbox.
  final bool largeCompleteTarget;

  const RoutinePresentation({
    required this.stepsPerView,
    required this.showOnlyNextStep,
    required this.speakOnOpen,
    required this.announceProgress,
    required this.showFsl,
    required this.playSoundCues,
    required this.instructionsExpanded,
    required this.timerAsBar,
    required this.allowDragReorder,
    required this.mediaOrder,
    required this.largeCompleteTarget,
  });

  /// Media channels present on [step], in this learner's preferred order.
  ///
  /// Filters first, then orders: a learner never sees a slot for media that
  /// was never supplied, and the placeholder is the *editor's* concern, not
  /// the learner's. (The learner-facing placeholder appears only when a step
  /// has no media at all — see `RoutineMediaStrip`.)
  List<RoutineMediaKind> mediaFor(RoutineStep step) =>
      mediaOrder.where(step.hasMedia).toList();

  /// The steps this learner sees now, given what they have already finished.
  ///
  /// Never returns empty while work remains: when every step is done the
  /// caller gets the full list back so the child can see the finished day
  /// (and un-tick a mistake) rather than an empty screen that reads as a bug.
  List<RoutineStep> visibleSteps(
    List<RoutineStep> ordered,
    Set<String> completedIds,
  ) {
    if (ordered.isEmpty) return ordered;
    if (!showOnlyNextStep) {
      if (stepsPerView >= ordered.length) return ordered;
      return ordered.sublist(0, stepsPerView);
    }
    final nextIndex = ordered.indexWhere((s) => !completedIds.contains(s.id));
    if (nextIndex == -1) return ordered;
    final end = (nextIndex + stepsPerView).clamp(0, ordered.length);
    return ordered.sublist(nextIndex, end);
  }

  factory RoutinePresentation.forType(DisabilityType type) {
    return switch (type) {
      DisabilityType.visual => const RoutinePresentation(
          stepsPerView: 99,
          showOnlyNextStep: false,
          speakOnOpen: true,
          announceProgress: true,
          showFsl: false,
          playSoundCues: true,
          instructionsExpanded: true,
          timerAsBar: false,
          allowDragReorder: false,
          mediaOrder: [
            RoutineMediaKind.audio,
            RoutineMediaKind.photo,
            RoutineMediaKind.gif,
            RoutineMediaKind.video,
          ],
          largeCompleteTarget: true,
        ),
      DisabilityType.hearing => const RoutinePresentation(
          stepsPerView: 99,
          showOnlyNextStep: false,
          speakOnOpen: false,
          announceProgress: false,
          showFsl: true,
          playSoundCues: false,
          instructionsExpanded: true,
          timerAsBar: true,
          allowDragReorder: true,
          mediaOrder: [
            RoutineMediaKind.video,
            RoutineMediaKind.gif,
            RoutineMediaKind.photo,
            RoutineMediaKind.audio,
          ],
          largeCompleteTarget: false,
        ),
      DisabilityType.motor => const RoutinePresentation(
          stepsPerView: 1,
          showOnlyNextStep: true,
          speakOnOpen: false,
          announceProgress: false,
          showFsl: true,
          playSoundCues: true,
          instructionsExpanded: true,
          timerAsBar: true,
          allowDragReorder: false,
          mediaOrder: [
            RoutineMediaKind.photo,
            RoutineMediaKind.gif,
            RoutineMediaKind.video,
            RoutineMediaKind.audio,
          ],
          largeCompleteTarget: true,
        ),
      DisabilityType.cognitive => const RoutinePresentation(
          stepsPerView: 1,
          showOnlyNextStep: true,
          speakOnOpen: true,
          announceProgress: true,
          // FSL adds a second symbol system for a learner already working
          // hard on the first — the same call `AccessibilityContentPolicy`
          // already makes for the Cards and Games surfaces.
          showFsl: false,
          playSoundCues: true,
          instructionsExpanded: true,
          timerAsBar: true,
          allowDragReorder: false,
          mediaOrder: [
            RoutineMediaKind.photo,
            RoutineMediaKind.gif,
            RoutineMediaKind.video,
            RoutineMediaKind.audio,
          ],
          largeCompleteTarget: true,
        ),
      // Mixed needs — the calm one-step-at-a-time shape, but every alternative
      // modality stays switched on, including FSL.
      DisabilityType.multiple => const RoutinePresentation(
          stepsPerView: 1,
          showOnlyNextStep: true,
          speakOnOpen: true,
          announceProgress: true,
          showFsl: true,
          playSoundCues: true,
          instructionsExpanded: true,
          timerAsBar: true,
          allowDragReorder: false,
          mediaOrder: [
            RoutineMediaKind.photo,
            RoutineMediaKind.gif,
            RoutineMediaKind.video,
            RoutineMediaKind.audio,
          ],
          largeCompleteTarget: true,
        ),
      DisabilityType.none => const RoutinePresentation(
          stepsPerView: 99,
          showOnlyNextStep: false,
          speakOnOpen: false,
          announceProgress: false,
          showFsl: true,
          playSoundCues: true,
          instructionsExpanded: false,
          timerAsBar: false,
          allowDragReorder: true,
          mediaOrder: [
            RoutineMediaKind.photo,
            RoutineMediaKind.gif,
            RoutineMediaKind.video,
            RoutineMediaKind.audio,
          ],
          largeCompleteTarget: false,
        ),
    };
  }

  /// The routine policy for [profile].
  ///
  /// Educators always get the full-day view regardless of their own profile: a
  /// teacher opening a learner's routine is checking or modelling it *for*
  /// them, and their own accessibility category must not hide steps they are
  /// trying to see. Mirrors `BoardPresentation.forProfile`.
  factory RoutinePresentation.forProfile(UserProfile? profile) {
    if (profile == null) {
      return RoutinePresentation.forType(DisabilityType.none);
    }
    if (!profile.role.isEnrollableLearner) {
      return RoutinePresentation.forType(DisabilityType.none);
    }
    return RoutinePresentation.forType(profile.disabilityType);
  }
}

/// The routine policy for the signed-in profile.
final routinePresentationProvider = Provider<RoutinePresentation>((ref) {
  return RoutinePresentation.forProfile(ref.watch(profileProvider));
});
