import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/rich_empty_states.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';
import '../services/class_analysis.dart';
import '../models/question_prompt.dart';

/// The educator's read of the whole class rather than one learner at a time.
///
/// Three questions that the per-learner screens could not answer:
///
///  * **Which categories are gaining?** The study compares accessibility
///    categories and nothing showed that comparison.
///  * **Which items is the class failing?** Every answer and response time has
///    been recorded since assessments existed and nothing read it back, so an
///    educator knew *who* struggled but never *which words*.
///  * **Who retook what?** The learning gain is measured from the newest
///    sitting of each half, which is invisible when only one score is shown.
class ClassReportScreen extends ConsumerWidget {
  const ClassReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final l10n = AppLocalizations.of(context);

    if (profile == null || !profile.role.isEducator) {
      return Scaffold(
        backgroundColor: hc.background,
        body: RichEmptyState(
          emoji: '🧑‍🏫',
          title: l10n?.reportForEducatorsTitle ?? 'For teachers and parents',
          description:
              l10n?.reportForEducatorsDesc ??
              'This report reads a whole class at once. Your own results live '
                  'in the Assessment Center.',
          actionLabel: l10n?.goBack ?? 'Go back',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () => context.pop(),
        ),
      );
    }

    // Results that landed on another device only reach this one through the
    // educator pull. Watched, not awaited — local data renders immediately.
    ref.watch(educatorAssessmentSyncProvider(profile.id));

    final roster = ref.watch(educatorLearnerRosterProvider);
    final learners = [...roster.map((r) => r.$1)]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    final gains = ClassAnalysis.gainsByAccessibility([
      for (final learner in learners)
        (
          type: learner.disabilityType,
          report: AssessmentService.getLearningGainReport(learner.id),
        ),
    ]);

    // Item analysis spans the whole roster: one learner's answers say nothing
    // about whether an item is hard.
    final allResults = <AssessmentResult>[
      for (final learner in learners) ...AssessmentService.getResults(learner.id),
    ];
    final items = ClassAnalysis.itemStats(
      allResults,
      prompts: AssessmentService.questionPrompts(),
    );

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(fallbackRoute: '/assessment'),
        title: Text(
          l10n?.eduClassReport ?? 'Class Report',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
            tooltip: l10n?.reportCheckNewResults ?? 'Check for new results',
            onPressed: () =>
                ref.invalidate(educatorAssessmentSyncProvider(profile.id)),
          ),
        ],
      ),
      body: learners.isEmpty
          ? RichEmptyState(
              emoji: '🧑‍🏫',
              title: l10n?.assessNoLearnersYet ?? 'No learners yet',
              description:
                  l10n?.reportNoLearnersDesc ??
                  'Share a class or home-group code, then assign the '
                      'pre-test. The report fills in as results come back.',
              actionLabel: l10n?.reportAssignWork ?? 'Assign work',
              actionIcon: Icons.assignment_turned_in_rounded,
              onAction: () => context.push('/assessment/assign'),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 40),
              children: [
                // ─── Gain by accessibility category ─────
                _SectionTitle(
                  title:
                      '📊 ${l10n?.reportGainSection ?? 'Learning gain by accessibility'}',
                  subtitle:
                      l10n?.reportGainSectionDesc ??
                      'Averages over the learners who have finished both '
                          'halves. Anyone still missing one is counted '
                          'separately.',
                  hc: hc,
                ),
                const SizedBox(height: 12),
                if (gains.every((g) => g.learners == 0))
                  _Hint(
                    text:
                        l10n?.reportGainNone ??
                        'No learner has finished both halves yet, so there is '
                            'nothing to average. Assign the pre-test first.',
                    hc: hc,
                  )
                else
                  for (var i = 0; i < gains.length; i++)
                    _GroupGainCard(gain: gains[i], hc: hc)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (60 * i).ms)
                        .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 28),

                // ─── Item analysis ──────────────────────
                _SectionTitle(
                  title: '🔍 ${l10n?.reportItemsSection ?? 'Hardest items'}',
                  subtitle:
                      l10n?.reportItemsSectionDesc ??
                      'Every question the class has answered, hardest first. '
                          '“Split the class” with a low separation usually '
                          'means the wording, not the word.',
                  hc: hc,
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  _Hint(
                    text:
                        l10n?.reportItemsNone ??
                        'No answers recorded yet. This fills in as your '
                            'learners finish assessments.',
                    hc: hc,
                  )
                else
                  for (var i = 0; i < items.length && i < 25; i++)
                    _ItemCard(stat: items[i], hc: hc)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (40 * i).ms),

                const SizedBox(height: 28),

                // ─── Attempts per learner ───────────────
                _SectionTitle(
                  title: '🔁 ${l10n?.reportAttemptsSection ?? 'Attempts'}',
                  subtitle:
                      l10n?.reportAttemptsSectionDesc ??
                      'The most recent sitting of each half is the one a '
                          'learning gain is measured from.',
                  hc: hc,
                ),
                const SizedBox(height: 12),
                for (final learner in learners)
                  _LearnerAttemptsRow(profile: learner, hc: hc),
              ],
            ),
    );
  }
}

// ─── Section chrome ────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final HCColor hc;
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  final HCColor hc;
  const _Hint({required this.text, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hc.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
      ),
    );
  }
}

// ─── Gain by category ──────────────────────────────────

class _GroupGainCard extends StatelessWidget {
  final GroupGain gain;
  final HCColor hc;
  const _GroupGainCard({required this.gain, required this.hc});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = gain.type.labelOf(l10n);
    final measured = gain.learners > 0;
    final pct = (gain.meanGain * 100).round();
    final accent = !measured
        ? hc.textHint
        : gain.hasImproved
        ? AppColors.success
        : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: measured
            ? (l10n?.reportGainSemantics(
                    label,
                    gain.learners,
                    (gain.meanPre * 100).round(),
                    (gain.meanPost * 100).round(),
                    pct,
                  ) ??
                  '$label. ${gain.learners} '
                      '${gain.learners == 1 ? 'learner' : 'learners'} '
                      'measured. Mean pre-test '
                      '${(gain.meanPre * 100).round()} percent, post-test '
                      '${(gain.meanPost * 100).round()} percent, gain $pct '
                      'percent.')
            : (l10n?.reportGainNoneSemantics(label, gain.pending) ??
                  '$label. No learner has finished both halves yet. '
                      '${gain.pending} waiting.'),
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hc.border),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(gain.type.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (measured) ...[
                      _Metric(
                        label: l10n?.reportMetricPre ?? 'Pre',
                        value: '${(gain.meanPre * 100).round()}%',
                        color: hc.textSecondary,
                      ),
                      _Metric(
                        label: l10n?.reportMetricPost ?? 'Post',
                        value: '${(gain.meanPost * 100).round()}%',
                        color: hc.textSecondary,
                      ),
                      _Metric(
                        label: l10n?.reportMetricGain ?? 'Gain',
                        value: '${pct >= 0 ? '+' : ''}$pct%',
                        color: accent,
                      ),
                      if (gain.meanNormalizedGain != null)
                        _Metric(
                          label: l10n?.reportMetricNormalized ?? 'Normalized',
                          value: gain.meanNormalizedGain!.toStringAsFixed(2),
                          color: hc.textSecondary,
                        ),
                      _Metric(
                        label: l10n?.reportMetricMeasured ?? 'Measured',
                        value: '${gain.learners}',
                        color: hc.textSecondary,
                      ),
                    ] else
                      _Metric(
                        label: l10n?.reportMetricMeasured ?? 'Measured',
                        value: '0',
                        color: hc.textHint,
                      ),
                    if (gain.pending > 0)
                      _Metric(
                        label: l10n?.reportMetricWaiting ?? 'Still waiting',
                        value: '${gain.pending}',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: AppTypography.labelSmall.copyWith(
          color: HCColor.of(context).readableOver(color, color.withValues(alpha: 0.12)),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── One item ──────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final ItemStat stat;
  final HCColor hc;
  const _ItemCard({required this.stat, required this.hc});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pct = (stat.difficulty * 100).round();
    final accent = scoreColor(stat.difficulty);
    final seconds = (stat.medianResponseMs / 1000).toStringAsFixed(1);
    final band = stat.difficultyLabelOf(l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: [
          QuestionPrompt.localize(stat.prompt, l10n),
          l10n?.reportItemCorrectSemantics(stat.correct, stat.attempts, pct) ??
              '${stat.correct} of ${stat.attempts} correct, $pct percent',
          band,
          if (stat.commonWrongAnswer != null)
            l10n?.reportItemWrongSemantics(
                  QuestionPrompt.answer(stat.commonWrongAnswer!, l10n),
                ) ??
                'Most common wrong answer, ${stat.commonWrongAnswer}',
          if (stat.needsReview)
            l10n?.reportItemReviewSemantics ?? 'This item may need rewording',
        ].join('. '),
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: stat.needsReview
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : hc.border,
              ),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QuestionPrompt.localize(stat.prompt, l10n),
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Metric(
                      label: '',
                      value: '${stat.correct}/${stat.attempts} · $pct%',
                      color: accent,
                    ),
                    _Metric(
                      label: '',
                      value: band,
                      color: hc.textSecondary,
                    ),
                    _Metric(
                      label: l10n?.reportMetricMedian ?? 'Median',
                      value: '${seconds}s',
                      color: hc.textSecondary,
                    ),
                    if (stat.discrimination != null)
                      _Metric(
                        label: l10n?.reportMetricSeparation ?? 'Separation',
                        value: stat.discrimination!.toStringAsFixed(2),
                        color: stat.needsReview
                            ? AppColors.warning
                            : hc.textSecondary,
                      ),
                    if (stat.commonWrongAnswer != null)
                      _Metric(
                        label:
                            l10n?.reportMetricOftenAnswered ?? 'Often answered',
                        value:
                            '${QuestionPrompt.answer(stat.commonWrongAnswer!, l10n)} '
                            '(×${stat.commonWrongCount})',
                        color: AppColors.error,
                      ),
                  ],
                ),
                if (stat.needsReview) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n?.reportNeedsReview ??
                        'Your strongest learners did no better on this one — '
                            'worth rereading the wording.',
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).warningText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Attempts per learner ──────────────────────────────

class _LearnerAttemptsRow extends StatelessWidget {
  final UserProfile profile;
  final HCColor hc;
  const _LearnerAttemptsRow({required this.profile, required this.hc});

  @override
  Widget build(BuildContext context) {
    final pre = AssessmentService.getAttempts(
      profile.id,
      AssessmentType.preTest,
    );
    final post = AssessmentService.getAttempts(
      profile.id,
      AssessmentType.postTest,
    );
    if (pre.isEmpty && post.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLarge.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AttemptChip(
                  label: AppLocalizations.of(context)?.reportMetricPre ?? 'Pre',
                  attempts: pre,
                  hc: hc,
                ),
                _AttemptChip(
                  label:
                      AppLocalizations.of(context)?.reportMetricPost ?? 'Post',
                  attempts: post,
                  hc: hc,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttemptChip extends StatelessWidget {
  final String label;
  final List<AssessmentResult> attempts;
  final HCColor hc;
  const _AttemptChip({
    required this.label,
    required this.attempts,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (attempts.isEmpty) {
      return _Metric(
        label: label,
        value: l10n?.reportAttemptNone ?? 'none',
        color: hc.textHint,
      );
    }
    // Newest first, so the first entry is the one the gain uses.
    final counted = (attempts.first.percentage * 100).round();
    final extra = attempts.length - 1;
    return _Metric(
      label: label,
      value: extra == 0
          ? '$counted%'
          : '$counted% ${l10n?.reportAttemptEarlier(extra) ?? '(+$extra earlier)'}',
      color: scoreColor(attempts.first.percentage),
    );
  }
}
