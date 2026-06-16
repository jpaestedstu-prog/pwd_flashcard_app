import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/core/theme/app_typography.dart';
import 'package:pwdpwdpwd/core/utils/responsive_utils.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/stories/widgets/story_fsl_button.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the **quiz answer-option** layout after the
/// per-choice controls were added: two language "listen" pills (English +
/// Tagalog) and a compact "watch in FSL" button.
///
/// Those helpers live in a [Wrap] beneath the choice text (mirroring
/// `StoryQuizScreen`), so they should flow onto a new line rather than overflow.
/// This test renders every option of "A Day at the Farm" — the story that
/// actually ships FSL clips — in the answered state, across the full device ×
/// text-scale matrix, to prove that holds on the smallest phones at the largest
/// accessibility font scale.
Widget _listenPill(BuildContext context, String label, Color color) {
  return Semantics(
    button: true,
    label: 'Listen to this choice in $label',
    child: ExcludeSemantics(
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.volume_up_rounded, size: context.scaleIcon(18)),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );
}

Widget _optionRow(
  BuildContext context, {
  required Story story,
  required StoryQuestion question,
  required int idx,
}) {
  final text = question.optionsEn[idx];
  // Answered + correct → the correctness icon and every helper are present at
  // once, the widest the layout ever gets.
  const textColor = AppColors.success;
  const borderColor = AppColors.success;

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: context.scaleIcon(36),
                height: context.scaleIcon(36),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + idx),
                    style: AppTypography.titleSmall.copyWith(color: textColor),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: AppTypography.bodyLarge.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      question.optionsFil[idx],
                      style: AppTypography.bodyMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: context.scaleIcon(24)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 50),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _listenPill(context, 'English', AppColors.info),
                _listenPill(context, 'Tagalog', AppColors.secondary),
                if (question.fslForOption(idx) != null)
                  StoryFslButton(
                    pageUrl: question.fslForOption(idx)!,
                    cacheKey: 'story_${story.id}_q0_o$idx',
                    label: question.optionsEn[idx],
                    secondaryLabel: question.optionsFil[idx],
                    color: story.category.color,
                    compact: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _optionList(BuildContext context) {
  final story = SeedStories.all.firstWhere((s) => s.id == 's_a01');
  final question = story.questions.first;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Also exercise the full-width "Watch in FSL" chip used for the prompt.
        if (question.fslVideoUrl != null)
          StoryFslButton(
            pageUrl: question.fslVideoUrl!,
            cacheKey: 'story_${story.id}_q0',
            label: question.questionEn,
            secondaryLabel: question.questionFil,
            color: story.category.color,
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < question.optionsEn.length; i++)
          _optionRow(context, story: story, question: question, idx: i),
      ],
    ),
  );
}

void main() {
  testWidgets('Quiz option row with FSL + dual-language audio survives the '
      'device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      _optionList,
      // Options are page content that scrolls vertically; we only care that the
      // controls never overflow a row horizontally.
      host: LayoutHost.scrollable,
    );
  });
}
