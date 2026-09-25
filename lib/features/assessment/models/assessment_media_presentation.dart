import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/accessibility/learner_support.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import 'assessment_media.dart';

/// How the media an educator attached is shown to one learner.
///
/// The house `*Presentation` pattern — pure, no Flutter, one factory — so the
/// whole matrix is unit-testable and the widgets read flags instead of
/// branching on [DisabilityType]. Siblings: `RoutinePresentation`,
/// `BoardPresentation`, `ProgressPresentation`.
///
/// The educator attaches media once; this decides, per learner, which piece
/// they meet first and how much of it is on screen:
///
///   * **Visual** — sound first, and the written description is offered as a
///     "Read it to me" button, since a picture's alt text is otherwise only
///     heard by a learner running a screen reader. No sign video: signs are
///     visual (`AccessibilityContentPolicy`). Big controls.
///   * **Hearing** — the FSL version leads and plays by itself, a video plays
///     by itself too, and the description is shown as a caption under the
///     media, because sound is exactly what this learner cannot get. The sound
///     slot is kept but sits last — a hard-of-hearing learner may use it.
///   * **Motor** — pictures first, and videos start themselves so nothing
///     needs a small, precise tap. Big controls.
///   * **Cognitive** — one thing at a time: the lead picture is shown and the
///     rest wait behind "Show more", with captions and read-aloud on. No sign
///     video by default, the same call the content policy makes elsewhere.
///   * **Multiple** — every alternative on: the FSL version plays, captions
///     show, read-aloud is offered, controls are big.
///   * **None** — everything, in a plain order, nothing automatic.
///
/// The learner's own supports then adjust that (see [forLearner]), so a Deaf
/// learner on "Written words only" loses the sign video and gains captions, a
/// learner on gaze gets autoplay, and one on "Step by step" sees one thing at
/// a time whatever their category.
class AssessmentMediaPresentation {
  /// Which filled slot the learner meets first. Every visible slot is shown —
  /// this only orders them.
  final List<AssessmentMediaKind> order;

  /// Show the sign-language version at all.
  final bool showSign;

  /// The sign-language version starts playing (and loops) by itself.
  final bool autoplaySign;

  /// An ordinary video starts playing by itself.
  final bool autoplayVideo;

  /// Show the educator's description as a caption under the media.
  final bool showCaptions;

  /// Offer a button that reads the description aloud.
  final bool offerReadAloud;

  /// Show only the lead item; the rest wait behind "Show more".
  final bool leadOnly;

  /// Bigger play, replay and read-aloud controls.
  final bool largeControls;

  /// The learner signs in a system other than FSL, so the sign video says
  /// which language it was filmed in rather than implying it is theirs.
  final bool signSystemDiffers;

  const AssessmentMediaPresentation({
    required this.order,
    required this.showSign,
    required this.autoplaySign,
    required this.autoplayVideo,
    required this.showCaptions,
    required this.offerReadAloud,
    required this.leadOnly,
    required this.largeControls,
    this.signSystemDiffers = false,
  });

  /// The slots of [media] this learner sees, lead first.
  List<AssessmentMediaKind> kindsFor(AssessmentMedia media) => [
    for (final kind in order)
      if (media.has(kind) && (kind != AssessmentMediaKind.sign || showSign))
        kind,
  ];

  /// Whether [media] has anything this learner will be shown.
  bool showsAnything(AssessmentMedia media) => kindsFor(media).isNotEmpty;

  AssessmentMediaPresentation copyWith({
    List<AssessmentMediaKind>? order,
    bool? showSign,
    bool? autoplaySign,
    bool? autoplayVideo,
    bool? showCaptions,
    bool? offerReadAloud,
    bool? leadOnly,
    bool? largeControls,
    bool? signSystemDiffers,
  }) => AssessmentMediaPresentation(
    order: order ?? this.order,
    showSign: showSign ?? this.showSign,
    autoplaySign: autoplaySign ?? this.autoplaySign,
    autoplayVideo: autoplayVideo ?? this.autoplayVideo,
    showCaptions: showCaptions ?? this.showCaptions,
    offerReadAloud: offerReadAloud ?? this.offerReadAloud,
    leadOnly: leadOnly ?? this.leadOnly,
    largeControls: largeControls ?? this.largeControls,
    signSystemDiffers: signSystemDiffers ?? this.signSystemDiffers,
  );

  static const _p = AssessmentMediaKind.photo;
  static const _g = AssessmentMediaKind.gif;
  static const _v = AssessmentMediaKind.video;
  static const _a = AssessmentMediaKind.audio;
  static const _s = AssessmentMediaKind.sign;

  /// The category decision alone. [forLearner] is what screens should ask.
  factory AssessmentMediaPresentation.forType(DisabilityType type) {
    final showSign = AccessibilityContentPolicy.forType(type).showFsl;
    return switch (type) {
      DisabilityType.visual => AssessmentMediaPresentation(
        order: const [_a, _p, _g, _v, _s],
        showSign: showSign,
        autoplaySign: false,
        autoplayVideo: false,
        showCaptions: false,
        offerReadAloud: true,
        leadOnly: false,
        largeControls: true,
      ),
      DisabilityType.hearing => AssessmentMediaPresentation(
        order: const [_s, _v, _g, _p, _a],
        showSign: showSign,
        autoplaySign: true,
        autoplayVideo: true,
        showCaptions: true,
        offerReadAloud: false,
        leadOnly: false,
        largeControls: false,
      ),
      DisabilityType.motor => AssessmentMediaPresentation(
        order: const [_p, _g, _v, _s, _a],
        showSign: showSign,
        autoplaySign: true,
        autoplayVideo: true,
        showCaptions: false,
        offerReadAloud: false,
        leadOnly: false,
        largeControls: true,
      ),
      DisabilityType.cognitive => AssessmentMediaPresentation(
        order: const [_p, _g, _v, _a, _s],
        showSign: showSign,
        autoplaySign: false,
        autoplayVideo: false,
        showCaptions: true,
        offerReadAloud: true,
        leadOnly: true,
        largeControls: true,
      ),
      DisabilityType.multiple => AssessmentMediaPresentation(
        order: const [_p, _s, _v, _g, _a],
        showSign: showSign,
        autoplaySign: true,
        autoplayVideo: false,
        showCaptions: true,
        offerReadAloud: true,
        leadOnly: false,
        largeControls: true,
      ),
      DisabilityType.none => AssessmentMediaPresentation(
        order: const [_p, _g, _v, _s, _a],
        showSign: showSign,
        autoplaySign: false,
        autoplayVideo: false,
        showCaptions: false,
        offerReadAloud: false,
        leadOnly: false,
        largeControls: false,
      ),
    };
  }

  /// The category decision, then narrowed or widened by the learner's own
  /// supports. Also what an educator's screen asks about a learner they are
  /// looking at.
  factory AssessmentMediaPresentation.forLearner(
    DisabilityType type,
    Iterable<LearnerSupportOption> supports,
  ) {
    final base = AssessmentMediaPresentation.forType(type);
    final policy = AccessibilityContentPolicy.forLearner(type, supports);
    final effective = LearnerSupportCatalog.effective(type, supports);
    bool has(LearnerSupportOption o) => effective.contains(o);

    var order = base.order;
    if (has(LearnerSupportOption.picturePrompts)) {
      order = _promote(order, const [_p, _g]);
    }
    if (has(LearnerSupportOption.audioFirst)) {
      order = _promote(order, const [_a]);
    }
    final handsFree =
        has(LearnerSupportOption.inputGaze) ||
        has(LearnerSupportOption.inputSwitch);

    return base.copyWith(
      order: order,
      // The policy already folds in the communication mode: a learner who
      // reads or lip-reads gets no sign video whatever their category.
      showSign: policy.showFsl,
      signSystemDiffers: policy.signSystemDiffersFromMedia,
      showCaptions:
          base.showCaptions ||
          has(LearnerSupportOption.captionsAlwaysOn) ||
          has(LearnerSupportOption.writtenCaptions),
      offerReadAloud:
          base.offerReadAloud ||
          has(LearnerSupportOption.audioFirst) ||
          has(LearnerSupportOption.repeatInstructions),
      leadOnly: base.leadOnly || has(LearnerSupportOption.stepByStep),
      // A learner steering with their eyes or a switch should not have to
      // land on a small play button to see the question.
      autoplaySign: base.autoplaySign || handsFree,
      autoplayVideo: base.autoplayVideo || handsFree,
      largeControls:
          base.largeControls ||
          handsFree ||
          has(LearnerSupportOption.largePrint),
    );
  }

  /// What an educator sees when previewing their own work: every slot,
  /// including the sign video and the caption, with nothing starting itself.
  static const AssessmentMediaPresentation educatorPreview =
      AssessmentMediaPresentation(
        order: [_s, _p, _g, _v, _a],
        showSign: true,
        autoplaySign: false,
        autoplayVideo: false,
        showCaptions: true,
        offerReadAloud: false,
        leadOnly: false,
        largeControls: false,
      );

  /// The presentation for the signed-in [profile]. An educator gets the
  /// preview whatever their own category: they are checking the work *for*
  /// their learners, and their own settings must not hide a slot from them.
  factory AssessmentMediaPresentation.forProfile(UserProfile? profile) {
    if (profile == null) {
      return AssessmentMediaPresentation.forType(DisabilityType.none);
    }
    if (profile.role.isEducator) return educatorPreview;
    return AssessmentMediaPresentation.forLearner(
      profile.disabilityType,
      profile.supports,
    );
  }

  static List<AssessmentMediaKind> _promote(
    List<AssessmentMediaKind> order,
    List<AssessmentMediaKind> first,
  ) => [...first, ...order.where((k) => !first.contains(k))];
}

/// The kind of media that reaches a learner best — the one-line tip an
/// educator sees while attaching media for them.
enum AssessmentMediaAdvice {
  /// Add an FSL video, and put any sound into words.
  signAndCaption,

  /// Add a sound, and describe pictures in words (they are read aloud).
  soundAndDescription,

  /// One clear photo — they see one thing at a time.
  onePhoto,

  /// Videos play by themselves for them; no small buttons needed.
  playsItself,

  /// An FSL video and a photo, both described in words.
  signPhotoAndDescription,

  /// Put everything into words — it is shown as a caption. For a Deaf
  /// learner who reads rather than signs.
  captionEverything,
}

extension AssessmentMediaAdviceX on AssessmentMediaAdvice {
  /// The tip for a learner of [type] with [supports], or null when nothing in
  /// particular would help more than anything else.
  static AssessmentMediaAdvice? forLearner(
    DisabilityType type,
    Iterable<LearnerSupportOption> supports,
  ) {
    final p = AssessmentMediaPresentation.forLearner(type, supports);
    return switch (type) {
      DisabilityType.hearing =>
        p.showSign
            ? AssessmentMediaAdvice.signAndCaption
            // Written words only: a caption is what reaches them.
            : AssessmentMediaAdvice.captionEverything,
      DisabilityType.visual => AssessmentMediaAdvice.soundAndDescription,
      DisabilityType.cognitive => AssessmentMediaAdvice.onePhoto,
      DisabilityType.motor => AssessmentMediaAdvice.playsItself,
      DisabilityType.multiple => AssessmentMediaAdvice.signPhotoAndDescription,
      DisabilityType.none => null,
    };
  }
}

/// The media presentation for whoever is signed in.
final assessmentMediaPresentationProvider =
    Provider<AssessmentMediaPresentation>((ref) {
      return AssessmentMediaPresentation.forProfile(ref.watch(profileProvider));
    });
