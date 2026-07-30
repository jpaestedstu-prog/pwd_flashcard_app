import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../widgets/flashcard_image.dart';
import '../models/tutor_media_policy.dart';
import '../models/tutor_models.dart';
import 'tutor_persona.dart';

/// Presentational chat widgets for the AI Tutor. Kept public + provider-free so
/// they can be rendered directly in the cross-device overflow matrix
/// (test/ai_tutor_overflow_test.dart) without Hive or Riverpod setup.

/// A compact, horizontally-scrolling strip of cumulative tutor stats. Scrolls
/// rather than wraps so it can never cause a vertical/RenderFlex overflow.
class TutorStatsStrip extends StatelessWidget {
  final TutorStats stats;
  final double padding;
  final bool isFilipino;

  const TutorStatsStrip({
    super.key,
    required this.stats,
    required this.padding,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.questionsAsked == 0 &&
        stats.quizzesAnswered == 0 &&
        stats.lessonsCompleted == 0) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
      child: Row(
        children: [
          _StatPill(
            emoji: '❓',
            label: isFilipino
                ? '${stats.questionsAsked} tanong'
                : '${stats.questionsAsked} asked',
          ),
          const SizedBox(width: 8),
          _StatPill(
            emoji: '✅',
            label: '${stats.quizzesCorrect}/${stats.quizzesAnswered} '
                '${isFilipino ? 'quiz' : 'quizzes'}',
          ),
          const SizedBox(width: 8),
          _StatPill(
            emoji: '🎯',
            label: isFilipino
                ? '${stats.lessonsCompleted} aralin'
                : '${stats.lessonsCompleted} lessons',
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;

  const _StatPill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bannerAiTutorStart.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.bannerAiTutorStart.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: hc.textPrimary)),
        ],
      ),
    );
  }
}

/// A single quick-action chip ("Lesson", "Quiz", "Hint"…).
///
/// Deliberately *not* an [ActionChip]: under Material 3 a themed
/// `ChipThemeData` wins over the widget's `backgroundColor`, so these rendered
/// with the theme's light label colour on a near-white M3 chip surface —
/// invisible in the high-contrast themes, which is exactly where the tutor's
/// main action row must stay legible. Painting the surface and the label from
/// the same [HCColor] set keeps them in step in every theme.
class TutorQuickChip extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const TutorQuickChip({
    super.key,
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hc.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style:
                    AppTypography.labelMedium.copyWith(color: hc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chat bubble for one [TutorMessage], including any embedded interactive
/// action (quiz options, practice / lesson buttons) and a read-aloud control.
class TutorMessageBubble extends StatelessWidget {
  final TutorMessage message;
  final TutorPersona persona;
  final bool isFilipino;
  final bool answered;

  /// Which extra channels this learner should get alongside the text. Defaults
  /// to text-only so every existing call site (and the overflow matrix) keeps
  /// its current shape.
  final TutorMediaPolicy media;

  final ValueChanged<String>? onQuizAnswer;

  /// Called with the picked [FlashcardCategory] enum name when the learner
  /// taps a favorite-topic chip.
  final ValueChanged<String>? onInterestPick;
  final VoidCallback? onActionTap;
  final VoidCallback? onSpeak;

  /// Play this word's Filipino Sign Language clip. Null hides the control —
  /// the caller supplies it only when the learner's [media] policy allows
  /// signs *and* the word has a clip, so it is never a dead end.
  final VoidCallback? onWatchSign;

  const TutorMessageBubble({
    super.key,
    required this.message,
    required this.persona,
    required this.isFilipino,
    this.answered = false,
    this.media = TutorMediaPolicy.none,
    this.onQuizAnswer,
    this.onInterestPick,
    this.onActionTap,
    this.onSpeak,
    this.onWatchSign,
  });

  @override
  Widget build(BuildContext context) {
    final isTutor = message.role == TutorMessageRole.tutor;
    final hc = HCColor.of(context);
    final avatarSize = context.scaledHeightCapped(32, max: 1.4);

    // Quizzes and re-teach cards name the flashcard they are about; that id is
    // the key to every extra channel (photo now, sign next).
    final mediaCardId = isTutor ? message.action?.wordId : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTutor) ...[
            TutorAvatar(persona: persona, size: avatarSize),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isTutor ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isTutor
                        ? hc.surface
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isTutor ? Radius.zero : const Radius.circular(16),
                      bottomRight:
                          isTutor ? const Radius.circular(16) : Radius.zero,
                    ),
                    border: Border.all(
                      color: isTutor
                          ? hc.border
                          : AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The card's picture, for learners who benefit from a
                      // concrete referent. Stacked above the text rather than
                      // beside it so a large font scale can never squeeze the
                      // question into a horizontal overflow. Falls back to the
                      // card's emoji when no photograph exists — which is the
                      // whole Actions category today, so the fallback is the
                      // common path, not an edge case.
                      if (media.photo && mediaCardId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ExcludeSemantics(
                            // The bubble text already names the word; a second
                            // announcement would just be noise for TalkBack.
                            child: FlashcardPictureById(
                              cardId: mediaCardId,
                              fallback: '📘',
                              extent: 64,
                              borderRadius: 14,
                            ),
                          ),
                        ),
                      Text(
                        message.content,
                        style: AppTypography.bodyMedium
                            .copyWith(color: hc.textPrimary),
                      ),
                      if (isTutor && (onSpeak != null || onWatchSign != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          // Wrap, not Row: at a large font scale two labelled
                          // controls no longer fit on one line inside the
                          // bubble, and they must move to a second line
                          // rather than overflow.
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (onSpeak != null)
                                _BubbleAction(
                                  icon: Icons.volume_up_rounded,
                                  label: isFilipino ? 'Pakinggan' : 'Listen',
                                  onTap: onSpeak!,
                                ),
                              // Only ever present when this learner's policy
                              // allows signs AND the word actually has a clip
                              // — the caller decides both, so a Deaf learner
                              // is never offered a sign that leads nowhere.
                              if (onWatchSign != null)
                                _BubbleAction(
                                  icon: Icons.sign_language_rounded,
                                  label: isFilipino
                                      ? 'Panoorin ang senyas'
                                      : 'Watch the sign',
                                  onTap: onWatchSign!,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Quiz options
                if (message.action?.type == TutorActionType.quickQuiz &&
                    message.action?.options != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Opacity(
                      opacity: answered ? 0.5 : 1,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.action!.options!.map((option) {
                          return Semantics(
                            button: true,
                            label: option,
                            child: InkWell(
                              onTap: answered
                                  ? null
                                  : () => onQuizAnswer?.call(option),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: AppTypography.labelMedium
                                      .copyWith(color: hc.textPrimary),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                // Favorite-topic picker chips
                if (message.action?.type == TutorActionType.pickInterests &&
                    message.action?.options != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Opacity(
                      opacity: answered ? 0.5 : 1,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final name in message.action!.options!)
                            for (final cat in FlashcardCategory.values)
                              if (cat.name == name)
                                _InterestChip(
                                  category: cat,
                                  isFilipino: isFilipino,
                                  onTap: answered
                                      ? null
                                      : () => onInterestPick?.call(name),
                                ),
                        ],
                      ),
                    ),
                  ),
                // Practice redirect button
                if (message.action?.type == TutorActionType.practiceRedirect)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: onActionTap,
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 18, color: AppColors.textOnPrimary),
                      label: Text(
                        isFilipino ? 'Mag-Practice' : 'Start Practice',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textOnPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                // Start-lesson button
                if (message.action?.type == TutorActionType.startLesson)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: onActionTap,
                      icon: const Icon(Icons.school_rounded,
                          size: 18, color: AppColors.textOnPrimary),
                      label: Text(
                        isFilipino ? 'Simulan ang Aralin' : 'Start Lesson',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textOnPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bannerAiTutorEnd,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isTutor) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

/// A small icon+label control under a tutor bubble ("Listen", "Watch the
/// sign"). Kept compact so several fit inside the bubble's width, and marked
/// as a button for screen readers.
class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BubbleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style:
                    AppTypography.labelSmall.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable favorite-topic chip (emoji + localized category label) shown by
/// the [TutorActionType.pickInterests] action.
class _InterestChip extends StatelessWidget {
  final FlashcardCategory category;
  final bool isFilipino;
  final VoidCallback? onTap;

  const _InterestChip({
    required this.category,
    required this.isFilipino,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final label = isFilipino ? category.labelFilipino : category.label;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style:
                    AppTypography.labelMedium.copyWith(color: hc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "tutor is typing" three-dot indicator with the animated avatar.
class TutorTypingIndicator extends StatelessWidget {
  final TutorPersona persona;
  const TutorTypingIndicator({super.key, required this.persona});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final avatarSize = context.scaledHeightCapped(32, max: 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          TutorAvatar(
              persona: persona,
              state: TutorAvatarState.thinking,
              size: avatarSize),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: hc.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .then()
        .fadeOut(duration: 400.ms);
  }
}
