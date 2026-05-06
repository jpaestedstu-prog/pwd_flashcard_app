import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../core/utils/score_utils.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../assessment/models/assessment_models.dart';
import '../../assessment/providers/assessment_provider.dart';
import '../../assessment/services/assessment_service.dart';
import '../widgets/learning_gain_widgets.dart';

/// Dashboard visualizing pre-test vs post-test learning gains
class LearningGainScreen extends ConsumerWidget {
  const LearningGainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hc = HCColor.of(context);

    if (profile == null) {
      return Scaffold(
        body: RichEmptyState(
          emoji: '👤',
          title: 'No Profile Selected',
          description: 'Select a profile to view learning gain data.',
          actionLabel: 'Go Back',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () => context.pop(),
        ),
      );
    }

    final profileId = profile.id;
    final assessmentNotifier = ref.watch(assessmentResultsProvider.notifier);
    final report = assessmentNotifier.learningGainReport;
    final hasPreTest = assessmentNotifier.hasPreTest;
    final hasPostTest = assessmentNotifier.hasPostTest;

    // Score trends
    final preTrend = AssessmentService.getScoreTrend(
        profileId, AssessmentType.preTest);
    final postTrend = AssessmentService.getScoreTrend(
        profileId, AssessmentType.postTest);

    // Average scores by type
    final avgScores = AssessmentService.getAverageScores(profileId);

    // All results for per-category mastery table
    final allResults = AssessmentService.getResults(profileId);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Learning Gains',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/assessment'),
            icon: const Icon(Icons.assignment_rounded, size: 18),
            label: const Text('Take Test'),
          ),
        ],
      ),
      body: !hasPreTest
          ? _NoDataState(
              hasPreTest: false,
              hasPostTest: false,
              onTakeTest: () => context.push('/assessment'),
              hc: hc,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ─── Learning Gain Summary ──────────
                if (report != null) ...[
                  LearningGainSummaryCard(report: report),
                  const SizedBox(height: 20),
                ] else if (hasPreTest && !hasPostTest) ...[
                  _PostTestPrompt(
                    onTakePostTest: () => context.push('/assessment'),
                    hc: hc,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),
                ],

                // ─── Average Scores by Type ─────────
                if (avgScores.isNotEmpty) ...[
                  _AverageScoresCard(avgScores: avgScores, hc: hc)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),
                ],

                // ─── Category Gain Breakdown ────────
                if (report != null) ...[
                  LearningGainBarChart(report: report)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),

                  CategoryGainList(report: report)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),
                ],

                // ─── Score Trend Chart ──────────────
                if (preTrend.isNotEmpty || postTrend.isNotEmpty) ...[
                  AssessmentTrendChart(
                    preTrend: preTrend,
                    postTrend: postTrend,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),
                ],

                // ─── Assessment History ─────────────
                if (allResults.isNotEmpty) ...[
                  _AssessmentHistoryCard(results: allResults, hc: hc)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 500.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 20),
                ],

                // ─── Recommendations ────────────────
                if (report != null)
                  _RecommendationsCard(report: report, hc: hc)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 600.ms)
                      .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// ─── No Data State ──────────────────────────────────────

class _NoDataState extends StatelessWidget {
  final bool hasPreTest;
  final bool hasPostTest;
  final VoidCallback onTakeTest;
  final dynamic hc;

  const _NoDataState({
    required this.hasPreTest,
    required this.hasPostTest,
    required this.onTakeTest,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return RichEmptyState(
      emoji: '📊',
      title: 'No Learning Data Yet',
      description:
          'Take a Pre-Test first to establish your baseline, '
          'then take a Post-Test after learning to see your improvement!',
      actionLabel: 'Take Pre-Test',
      actionIcon: Icons.assignment_rounded,
      onAction: onTakeTest,
      accentColor: AppColors.info,
    );
  }
}

// ─── Post-Test Prompt ───────────────────────────────────

class _PostTestPrompt extends StatelessWidget {
  final VoidCallback onTakePostTest;
  final dynamic hc;

  const _PostTestPrompt({
    required this.onTakePostTest,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Ready for your Post-Test?',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve completed your Pre-Test! Take the Post-Test to see how much you\'ve learned.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTakePostTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Take Post-Test'),
          ),
        ],
      ),
    );
  }
}

// ─── Average Scores Card ────────────────────────────────

class _AverageScoresCard extends StatelessWidget {
  final Map<AssessmentType, double> avgScores;
  final dynamic hc;

  const _AverageScoresCard({required this.avgScores, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 22, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                'Average Scores',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: avgScores.entries.map((e) {
              final pct = (e.value * 100).round();
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _typeColor(e.key).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _typeColor(e.key).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        e.key.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$pct%',
                        style: AppTypography.titleMedium.copyWith(
                          color: _typeColor(e.key),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.key.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _typeColor(AssessmentType type) => switch (type) {
    AssessmentType.preTest => AppColors.info,
    AssessmentType.postTest => AppColors.success,
    AssessmentType.categoryMastery => AppColors.warning,
    AssessmentType.custom => AppColors.primary,
  };
}

// ─── Assessment History Card ────────────────────────────

class _AssessmentHistoryCard extends StatelessWidget {
  final List<AssessmentResult> results;
  final dynamic hc;

  const _AssessmentHistoryCard({required this.results, required this.hc});

  @override
  Widget build(BuildContext context) {
    final sorted = List<AssessmentResult>.from(results)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final recent = sorted.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 22, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                'Recent Assessments',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${results.length} total',
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recent.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final pct = (r.percentage * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(r.type.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.type.label,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _fmtDate(r.completedAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _scoreColor(pct).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pct% (${r.score}/${r.totalQuestions})',
                      style: AppTypography.labelSmall.copyWith(
                        color: _scoreColor(pct),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(r.gradeEmoji, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (60 * i).ms)
                .slideX(begin: 0.05, end: 0);
          }),
        ],
      ),
    );
  }

  Color _scoreColor(int pct) => scoreColorFromPercent(pct);

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─── Recommendations Card ───────────────────────────────

class _RecommendationsCard extends StatelessWidget {
  final LearningGainReport report;
  final dynamic hc;

  const _RecommendationsCard({required this.report, required this.hc});

  @override
  Widget build(BuildContext context) {
    final gains = report.categoryGains;
    final weakest = gains.entries.toList()
      ..sort((a, b) => a.value.post.compareTo(b.value.post));
    final strongest = gains.entries.toList()
      ..sort((a, b) => b.value.post.compareTo(a.value.post));

    final recommendations = <_Recommendation>[];

    // Identify areas needing improvement
    if (weakest.isNotEmpty && weakest.first.value.post < 0.6) {
      recommendations.add(_Recommendation(
        icon: Icons.school_rounded,
        title: 'Focus on ${weakest.first.key}',
        description:
            'Your weakest category at ${(weakest.first.value.post * 100).round()}%. Try reviewing flashcards and playing games in this category.',
        color: AppColors.warning,
      ));
    }

    if (!report.hasImproved) {
      recommendations.add(const _Recommendation(
        icon: Icons.replay_rounded,
        title: 'Practice More',
        description:
            'Try reviewing flashcards and playing games before retaking the post-test.',
        color: AppColors.info,
      ));
    }

    if (report.postTestPercentage >= 0.9) {
      recommendations.add(const _Recommendation(
        icon: Icons.emoji_events_rounded,
        title: 'Excellent Performance!',
        description:
            'You\'re doing amazing! Try harder difficulty levels to keep challenging yourself.',
        color: AppColors.success,
      ));
    }

    if (strongest.isNotEmpty && strongest.first.value.post >= 0.8) {
      recommendations.add(_Recommendation(
        icon: Icons.star_rounded,
        title: 'Best at ${strongest.first.key}',
        description:
            'Your strongest category at ${(strongest.first.value.post * 100).round()}%! Great job!',
        color: AppColors.success,
      ));
    }

    // Categories with most improvement
    final mostImproved = gains.entries.toList()
      ..sort((a, b) => b.value.gain.compareTo(a.value.gain));
    if (mostImproved.isNotEmpty && mostImproved.first.value.gain > 0) {
      recommendations.add(_Recommendation(
        icon: Icons.trending_up_rounded,
        title: 'Most Improved: ${mostImproved.first.key}',
        description:
            'Improved by ${(mostImproved.first.value.gain * 100).round()}% — keep it up!',
        color: AppColors.accent,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, size: 22, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(r.icon, size: 18, color: r.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (100 + i * 80).ms)
                .slideX(begin: 0.1, end: 0);
          }),
        ],
      ),
    );
  }
}

class _Recommendation {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Recommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
