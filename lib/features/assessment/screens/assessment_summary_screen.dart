import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../models/assessment_models.dart';
import '../models/question_prompt.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../core/widgets/reflow_row.dart';

/// Shown immediately after completing an assessment — celebration + summary.
class AssessmentSummaryScreen extends ConsumerWidget {
  final AssessmentResult result;

  const AssessmentSummaryScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final pct = result.percentage;
    final pctDisplay = (pct * 100).round();
    // A test answered only on video has no score until a person marks it;
    // "0% — Keep Practicing" would tell a child they got it all wrong.
    final scored = result.hasAutoScore;
    final toReview = result.reviewAnswers.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ─── Grade emoji + title ───────────────────
              Text(
                scored ? result.gradeEmoji : '🎥',
                style: const TextStyle(fontSize: 64),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  scored
                      ? result.gradeOf(AppLocalizations.of(context))
                      : _t(context).assessSentForReview,
                  textAlign: TextAlign.center,
                  style: AppTypography.displaySmall.copyWith(
                    color: hc.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 4),
              Text(
                (AppLocalizations.of(context) ?? AppLocalizationsEn())
                    .sumComplete(
                      result.type.labelOf(AppLocalizations.of(context)),
                    ),
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 32),

              if (!scored)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _t(context).assessAllForReview,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),

              // ─── Score Circle ──────────────────────────
              if (scored) ...[
              CircularPercentIndicator(
                    radius: 80,
                    lineWidth: 12,
                    percent: pct.clamp(0, 1),
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pctDisplay%',
                          style: AppTypography.displayMedium.copyWith(
                            color: _scoreColor(pct),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${result.score}/${result.totalQuestions}',
                          style: AppTypography.labelMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    progressColor: _scoreColor(pct),
                    backgroundColor: hc.border,
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 1200,
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                  ),

              const SizedBox(height: 28),

              // ─── Stats Row ─────────────────────────────
              // Three result cards across, stacking when the labels no longer
              // fit a third of the row.
              ReflowRow(
                    labels: [
                      _t(context).sumTime,
                      _t(context).sumCorrect,
                      _t(context).sumWrong,
                    ],
                    children: [
                      _StatCard(
                        icon: Icons.timer_rounded,
                        value: _formatDuration(result.durationSeconds),
                        label: _t(context).sumTime,
                        color: hc.info,
                      ),
                      _StatCard(
                        icon: Icons.check_circle_rounded,
                        value: '${result.score}',
                        label: _t(context).sumCorrect,
                        color: AppColors.success,
                      ),
                      _StatCard(
                        icon: Icons.cancel_rounded,
                        value: '${result.totalQuestions - result.score}',
                        label: _t(context).sumWrong,
                        color: AppColors.error,
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 600.ms)
                  .slideY(begin: 0.1, end: 0),
              ],
              if (scored && toReview > 0) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_rounded, color: AppColors.info),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _t(context).assessToReview(toReview),
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // ─── Category Breakdown ────────────────────
              if (result.categoryScores.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _t(context).sumCategoryBreakdown,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...result.categoryScores.entries.map((entry) {
                  final catPct = (entry.value * 100).round();
                  return _CategoryScoreBar(
                    category: entry.key,
                    score: entry.value,
                    displayPercent: catPct,
                  );
                }),
                const SizedBox(height: 16),
              ],

              // ─── Question Review ───────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _t(context).sumQuestionReview,
                  style: AppTypography.titleMedium.copyWith(
                    color: hc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(result.answers.length, (i) {
                final answer = result.answers[i];
                return _QuestionReviewTile(
                  index: i + 1,
                  answer: answer,
                ).animate().fadeIn(duration: 300.ms, delay: (800 + i * 50).ms);
              }),

              const SizedBox(height: 32),

              // ─── Actions ───────────────────────────────
              // Two icon buttons side by side do not fit half a phone row at
              // a large text scale, however small the label gets. Stack them
              // instead: taller, but both fully readable and fully tappable.
              ReflowRow(
                    labels: [
                      _t(context).sumBackToHub,
                      _t(context).sumViewAnalytics,
                    ],
                    children: [
                      OutlinedButton.icon(
                          onPressed: () => context.popOrGo('/assessment'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          // A button's child Row measures intrinsics, so
                          // the style step rather than FitText.
                          label: Text(
                            _t(context).sumBackToHub,
                            style: fittedStyle(
                              context,
                              _t(context).sumBackToHub,
                              Theme.of(context).textTheme.labelLarge,
                              longWord: 4,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ElevatedButton.icon(
                          onPressed: () => context.push('/assessment/results'),
                          icon: const Icon(Icons.analytics_rounded),
                          label: Text(
                            _t(context).sumViewAnalytics,
                            style: fittedStyle(
                              context,
                              _t(context).sumViewAnalytics,
                              Theme.of(context).textTheme.labelLarge,
                              longWord: 4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hc.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 1000.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double pct) => scoreColor(pct);

  static AppLocalizations _t(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    if (min == 0) return '${sec}s';
    return '${min}m ${sec}s';
  }
}

// ─── Stat Card ─────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          FitText(
            value,
            maxLines: 1,
            style: AppTypography.titleLarge.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          FitText(
            label,
            maxLines: 1,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Category Score Bar ────────────────────────────────

class _CategoryScoreBar extends StatelessWidget {
  final String category;
  final double score;
  final int displayPercent;

  const _CategoryScoreBar({
    required this.category,
    required this.score,
    required this.displayPercent,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    Color barColor;
    if (score >= 0.75) {
      barColor = AppColors.success;
    } else if (score >= 0.5) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: (AppLocalizations.of(context) ?? AppLocalizationsEn())
            .sumCategorySemantics(
              QuestionPrompt.categoryName(
                category,
                AppLocalizations.of(context),
              ),
              displayPercent,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    QuestionPrompt.categoryName(
                      category,
                      AppLocalizations.of(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$displayPercent%',
                  style: AppTypography.labelMedium.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score.clamp(0, 1),
                minHeight: 8,
                backgroundColor: hc.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Question Review Tile ──────────────────────────────

class _QuestionReviewTile extends StatelessWidget {
  final int index;
  final QuestionAnswer answer;

  const _QuestionReviewTile({required this.index, required this.answer});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (answer.needsReview) return _sentForReview(context, hc);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: answer.isCorrect
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (answer.isCorrect ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: AppTypography.labelSmall.copyWith(
                    color: answer.isCorrect
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                QuestionPrompt.answer(
                  answer.givenAnswer,
                  AppLocalizations.of(context),
                ),
                style: AppTypography.bodySmall.copyWith(color: hc.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              answer.isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: answer.isCorrect ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// A video answer: not right or wrong yet, and never shown as a raw
  /// `shared://` value.
  Widget _sentForReview(BuildContext context, HCColor hc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: AppTypography.labelSmall.copyWith(
                    color: HCColor.of(context).infoText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (AppLocalizations.of(context) ?? AppLocalizationsEn())
                    .assessSentForReview,
                style: AppTypography.bodySmall.copyWith(color: hc.textPrimary),
              ),
            ),
            const Icon(Icons.videocam_rounded, color: AppColors.info, size: 20),
          ],
        ),
      ),
    );
  }
}
