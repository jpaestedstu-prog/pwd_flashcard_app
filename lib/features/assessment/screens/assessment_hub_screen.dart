import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/shared_widgets.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';

class AssessmentHubScreen extends ConsumerWidget {
  const AssessmentHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final results = ref.watch(assessmentResultsProvider);
    final customAssessments = ref.watch(customAssessmentsProvider);
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final profileId = profile?.id ?? '';

    final hasPreTest = AssessmentService.hasCompletedPreTest(profileId);
    final hasPostTest = AssessmentService.hasCompletedPostTest(profileId);
    final gainReport = AssessmentService.getLearningGainReport(profileId);
    final isTeacher = profile?.role == UserRole.teacher;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Go back',
                      child: IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        icon: Icon(Icons.arrow_back_rounded,
                            color: hc.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assessment Center',
                            style: AppTypography.headlineLarge
                                .copyWith(color: hc.textPrimary),
                          ),
                          Text(
                            'Measure your learning progress',
                            style: AppTypography.bodyMedium
                                .copyWith(color: hc.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (results.isNotEmpty)
                      Semantics(
                        button: true,
                        label: 'View assessment results and analytics',
                        child: IconButton(
                          onPressed: () => context.push('/assessment/results'),
                          icon: Icon(Icons.analytics_rounded,
                              color: hc.primary, size: 28),
                        ),
                      ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            // ─── Learning Gain Banner ──────────────────────
            if (gainReport != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: padding, vertical: 16),
                  child: _LearningGainBanner(report: gainReport)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
              ),

            // ─── Pre/Post Test Section ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                child: SectionHeader(
                  title: '📊 Pre-Test & Post-Test',
                  color: hc.textPrimary,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Text(
                  'Take a pre-test before studying, then a post-test after — see your growth!',
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.isTablet ? 2 : 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: context.isTablet ? 2.5 : 3.2,
                ),
                delegate: SliverChildListDelegate([
                  _AssessmentTypeCard(
                    type: AssessmentType.preTest,
                    isCompleted: hasPreTest,
                    latestScore: hasPreTest
                        ? AssessmentService.getLatestPreTest(profileId)
                            ?.percentage
                        : null,
                    onTap: () {
                      _startAssessment(context, ref, AssessmentType.preTest);
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.1, end: 0),
                  _AssessmentTypeCard(
                    type: AssessmentType.postTest,
                    isCompleted: hasPostTest,
                    latestScore: hasPostTest
                        ? AssessmentService.getLatestPostTest(profileId)
                            ?.percentage
                        : null,
                    isLocked: !hasPreTest,
                    lockMessage: 'Complete a Pre-Test first',
                    onTap: hasPreTest
                        ? () {
                            _startAssessment(
                                context, ref, AssessmentType.postTest);
                          }
                        : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0),
                ]),
              ),
            ),

            // ─── Category Mastery Section ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                child: SectionHeader(
                  title: '🏆 Category Mastery Tests',
                  color: hc.textPrimary,
                ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Text(
                  'Test your knowledge in specific vocabulary categories',
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
                ).animate().fadeIn(duration: 400.ms, delay: 380.ms),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.isTablet ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = FlashcardCategory.values[index];
                    final categoryResults = results
                        .where((r) =>
                            r.type == AssessmentType.categoryMastery &&
                            r.categories.contains(category))
                        .toList();
                    final bestScore = categoryResults.isEmpty
                        ? null
                        : categoryResults
                            .map((r) => r.percentage)
                            .reduce((a, b) => a > b ? a : b);

                    return _CategoryMasteryCard(
                      category: category,
                      bestScore: bestScore,
                      attemptCount: categoryResults.length,
                      onTap: () {
                        context.push('/assessment/category/${category.index}');
                      },
                    )
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: (400 + index * 60).ms,
                        )
                        .slideY(begin: 0.1, end: 0);
                  },
                  childCount: FlashcardCategory.values.length,
                ),
              ),
            ),

            // ─── Teacher Section: Quiz Builder ────────────
            if (isTeacher) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/quiz-builder'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('🧩', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quiz Builder',
                                    style: AppTypography.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  'Create custom quizzes from any flashcards',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white70, size: 20),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 580.ms),
                ),
              ),
            ],

            // ─── Teacher Section: Custom Assessments ───────
            if (isTeacher) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '✏️ Custom Assessments',
                          style: AppTypography.titleLarge
                              .copyWith(color: hc.textPrimary),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Create a new custom assessment',
                        child: IconButton(
                          onPressed: () =>
                              context.push('/assessment/builder'),
                          icon: Icon(Icons.add_circle_rounded,
                              color: hc.primary, size: 32),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                ),
              ),
              if (customAssessments
                  .where((a) => a.type == AssessmentType.custom)
                  .isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: padding, vertical: 16),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: hc.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: hc.border),
                      ),
                      child: Column(
                        children: [
                          const Text('📝',
                              style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No custom assessments yet',
                            style: AppTypography.titleSmall
                                .copyWith(color: hc.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to create one for your students',
                            style: AppTypography.bodySmall
                                .copyWith(color: hc.textHint),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 650.ms),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                      horizontal: padding, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final customs = customAssessments
                            .where((a) => a.type == AssessmentType.custom)
                            .toList();
                        final assessment = customs[index];
                        return _CustomAssessmentTile(
                          assessment: assessment,
                          onTap: () => context.push(
                              '/assessment/take/${assessment.id}'),
                          onDelete: () {
                            ref
                                .read(customAssessmentsProvider.notifier)
                                .deleteAssessment(assessment.id);
                          },
                        )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: (650 + index * 60).ms,
                            )
                            .slideX(begin: 0.05, end: 0);
                      },
                      childCount: customAssessments
                          .where((a) => a.type == AssessmentType.custom)
                          .length,
                    ),
                  ),
                ),
            ],

            // ─── Recent Results Quick View ─────────────────
            if (results.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '📈 Recent Results',
                          style: AppTypography.titleLarge
                              .copyWith(color: hc.textPrimary),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'View all results',
                        child: TextButton(
                          onPressed: () =>
                              context.push('/assessment/results'),
                          child: const Text('See All'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sorted = List.of(results)
                        ..sort((a, b) =>
                            b.completedAt.compareTo(a.completedAt));
                      final result = sorted[index];
                      return _RecentResultTile(result: result)
                          .animate()
                          .fadeIn(
                            duration: 400.ms,
                            delay: (750 + index * 60).ms,
                          )
                          .slideX(begin: 0.05, end: 0);
                    },
                    childCount: results.length.clamp(0, 5),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  void _startAssessment(
      BuildContext context, WidgetRef ref, AssessmentType type) {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final assessment = AssessmentService.generateStandardAssessment(
      profileId: profile.id,
      type: type,
    );
    context.push('/assessment/take/${assessment.id}', extra: assessment);
  }
}

// ─── Learning Gain Banner ──────────────────────────────

class _LearningGainBanner extends StatelessWidget {
  final LearningGainReport report;
  const _LearningGainBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final improved = report.hasImproved;
    final gradient = improved
        ? const LinearGradient(
            colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFF8F00), Color(0xFFFFCA28)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Semantics(
      label:
          'Learning gain report. ${report.summary}',
      child: AppCard(
        gradient: gradient,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(improved ? '🚀' : '📊',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Learning Gain Report',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ScorePill(
                  label: 'Pre-Test',
                  score: report.preTestPercentage,
                ),
                const SizedBox(width: 12),
                Icon(
                  improved
                      ? Icons.trending_up_rounded
                      : Icons.trending_flat_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                _ScorePill(
                  label: 'Post-Test',
                  score: report.postTestPercentage,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.summary,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final double score;
  const _ScorePill({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            '${(score * 100).round()}%',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assessment Type Card ──────────────────────────────

class _AssessmentTypeCard extends StatelessWidget {
  final AssessmentType type;
  final bool isCompleted;
  final double? latestScore;
  final bool isLocked;
  final String? lockMessage;
  final VoidCallback? onTap;

  const _AssessmentTypeCard({
    required this.type,
    this.isCompleted = false,
    this.latestScore,
    this.isLocked = false,
    this.lockMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final gradient = switch (type) {
      AssessmentType.preTest => const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      AssessmentType.postTest => const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      _ => LinearGradient(
          colors: [hc.primary, hc.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
    };

    return Semantics(
      button: !isLocked,
      label: isLocked
          ? '${type.label}. Locked. $lockMessage'
          : '${type.label}. ${isCompleted ? "Completed. Latest score ${((latestScore ?? 0) * 100).round()} percent. Tap to retake." : "Not yet taken. Tap to start."}',
      child: GestureDetector(
        onTap: isLocked ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isLocked ? 0.5 : 1.0,
          child: AppCard(
            gradient: gradient,
            borderRadius: 18,
            child: Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLocked
                            ? lockMessage ?? ''
                            : isCompleted
                                ? 'Best: ${((latestScore ?? 0) * 100).round()}%'
                                : 'Tap to start',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(Icons.lock_rounded,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.6))
                else if (isCompleted)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.9))
                else
                  Icon(Icons.arrow_forward_rounded,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category Mastery Card ─────────────────────────────

class _CategoryMasteryCard extends StatelessWidget {
  final FlashcardCategory category;
  final double? bestScore;
  final int attemptCount;
  final VoidCallback onTap;

  const _CategoryMasteryCard({
    required this.category,
    this.bestScore,
    this.attemptCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final catColor = hc.categoryColor(category);

    return Semantics(
      button: true,
      label:
          '${category.label} mastery test. ${bestScore != null ? "Best score: ${(bestScore! * 100).round()} percent, $attemptCount attempts" : "Not attempted yet"}. Tap to start.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: hc.hc ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: catColor.withValues(alpha: hc.hc ? 0.8 : 0.4),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, size: 22, color: catColor),
              ),
              const SizedBox(height: 6),
              Text(
                category.label,
                style: AppTypography.labelMedium.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (bestScore != null)
                Text(
                  'Best: ${(bestScore! * 100).round()}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: catColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  'Not tested',
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Assessment Tile ────────────────────────────

class _CustomAssessmentTile extends StatelessWidget {
  final Assessment assessment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomAssessmentTile({
    required this.assessment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: '${assessment.title}. ${assessment.questions.length} questions. Tap to take.',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: hc.border),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hc.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment_rounded,
                      color: hc.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment.title,
                        style: AppTypography.titleSmall
                            .copyWith(color: hc.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${assessment.questions.length} questions • ${assessment.difficulty.label}',
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(Icons.delete_outline_rounded,
                      color: hc.error, size: 22),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: hc.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assessment?'),
        content: Text(
            'Are you sure you want to delete "${assessment.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Result Tile ────────────────────────────────

class _RecentResultTile extends StatelessWidget {
  final AssessmentResult result;
  const _RecentResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = (result.percentage * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '${result.type.label}. Score: $pct percent. ${result.grade}. Completed ${_formatDate(result.completedAt)}.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hc.border),
          ),
          child: Row(
            children: [
              Text(result.gradeEmoji,
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.type.label,
                      style: AppTypography.labelMedium
                          .copyWith(color: hc.textPrimary),
                    ),
                    Text(
                      _formatDate(result.completedAt),
                      style: AppTypography.labelSmall
                          .copyWith(color: hc.textHint),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor(result.percentage)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct%',
                  style: AppTypography.labelLarge.copyWith(
                    color: _scoreColor(result.percentage),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double pct) => scoreColor(pct);

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
