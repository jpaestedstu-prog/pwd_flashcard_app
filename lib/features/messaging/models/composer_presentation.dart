import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// A way of putting a message together.
///
/// Ordered by how the composer should present them, not by importance —
/// [ComposerPresentation.modes] decides which appear and in what order.
enum ComposerMode {
  /// Free typing. The most expressive channel and the least accessible one:
  /// it needs literacy, fine motor control and an on-screen keyboard.
  text,

  /// Role-aware phrase chips. The fallback that always works, including for a
  /// learner driving the screen with their head.
  quickReply,

  /// A picture. No reading required, which is the whole point.
  sticker,

  /// A Filipino Sign Language clip, sent as a word the recipient can play.
  sign,
}

/// How the message composer presents itself to one learner.
///
/// Messaging was the last learner surface that looked identical for everyone:
/// a text field and a row of phrase chips. For a Deaf learner whose first
/// language is FSL, and for a learner who cannot read yet, a text field is not
/// a channel — it is a wall, and the chips were doing all the work.
///
/// Pure, like its siblings ([RacePresentation], `ProgressPresentation`,
/// `LockPresentation`): no Flutter, no I/O, one factory, so the whole matrix is
/// unit-testable and the composer widgets read flags instead of branching on
/// [DisabilityType].
///
/// Rationale per category:
///
///   * **Hearing (Deaf / HoH)** — signs first. FSL is the language, so the
///     sign picker leads and the text field stays available underneath rather
///     than being the only door in.
///   * **Visual** — no stickers and no signs: both are picture-only channels
///     that a screen reader cannot convey, so offering them would be offering
///     nothing. Text and spoken phrase chips carry everything.
///   * **Cognitive / multiple** — pictures over words. Stickers lead, the chip
///     set stays short, and free text is dropped: an empty text field is a
///     demand for composition, and this learner already has the chips.
///   * **Motor** — every mode stays, because the barrier is *input*, not
///     comprehension; the chips and sticker grid are large targets and each
///     one is its own gaze cell, so nothing here depends on typing.
///   * **None** — everything, text first, as before.
class ComposerPresentation {
  /// Which composers are offered, in the order they should appear.
  final List<ComposerMode> modes;

  /// Cap on the phrase chips shown at once.
  ///
  /// A wall of chips is its own barrier for a learner who finds choice hard,
  /// and for a gaze learner every extra chip is another cell to walk past.
  final int maxQuickReplies;

  const ComposerPresentation({
    required this.modes,
    required this.maxQuickReplies,
  });

  bool get allowsText => modes.contains(ComposerMode.text);
  bool get allowsStickers => modes.contains(ComposerMode.sticker);
  bool get allowsSigns => modes.contains(ComposerMode.sign);

  /// The composer that should open first.
  ComposerMode get primary => modes.first;

  factory ComposerPresentation.forType(DisabilityType type) {
    return switch (type) {
      DisabilityType.hearing => const ComposerPresentation(
        modes: [
          ComposerMode.sign,
          ComposerMode.quickReply,
          ComposerMode.sticker,
          ComposerMode.text,
        ],
        maxQuickReplies: 8,
      ),
      DisabilityType.visual => const ComposerPresentation(
        modes: [ComposerMode.quickReply, ComposerMode.text],
        maxQuickReplies: 8,
      ),
      DisabilityType.motor => const ComposerPresentation(
        modes: [
          ComposerMode.quickReply,
          ComposerMode.sticker,
          ComposerMode.sign,
          ComposerMode.text,
        ],
        maxQuickReplies: 6,
      ),
      DisabilityType.cognitive || DisabilityType.multiple =>
        const ComposerPresentation(
          modes: [ComposerMode.sticker, ComposerMode.quickReply],
          maxQuickReplies: 4,
        ),
      DisabilityType.none => const ComposerPresentation(
        modes: [
          ComposerMode.text,
          ComposerMode.quickReply,
          ComposerMode.sticker,
          ComposerMode.sign,
        ],
        maxQuickReplies: 8,
      ),
    };
  }

  /// The policy for [profile].
  ///
  /// Educators always get the full composer regardless of their own profile:
  /// they are writing *to* a learner, and a teacher's own accessibility needs
  /// should not strip the sign picker they use to reach a Deaf child.
  factory ComposerPresentation.forProfile(UserProfile? profile) {
    if (profile == null) return ComposerPresentation.forType(DisabilityType.none);
    if (!profile.role.isEnrollableLearner) {
      return ComposerPresentation.forType(DisabilityType.none);
    }
    return ComposerPresentation.forType(profile.disabilityType);
  }
}

/// The composer policy for the signed-in profile.
final composerPresentationProvider = Provider<ComposerPresentation>((ref) {
  return ComposerPresentation.forProfile(ref.watch(profileProvider));
});

/// The picture vocabulary a sticker message can carry.
///
/// Deliberately a small, fixed, emoji-only set rather than the Star Shop's
/// cosmetic stickers: these have to render identically on the recipient's
/// device with no download, no unlock state and no purchase, because a message
/// that arrives as a missing asset is worse than no message.
class MessageStickers {
  const MessageStickers._();

  static const List<String> all = [
    '👍', '❤️', '😀', '😂', '🎉', '⭐', '🏆', '👏',
    '🤝', '💪', '🌈', '🌟', '📚', '✏️', '🎨', '⚽',
  ];
}
