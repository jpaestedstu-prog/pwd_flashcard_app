import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../data/models/enums.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/utils/localized_date.dart';
import '../models/question_prompt.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../../../widgets/shared_widgets.dart';
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';
import '../models/post_test_readiness.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_media_panel.dart';
import '../widgets/assessment_media_sheets.dart';
import '../../../widgets/app_back_button.dart';
import '../../../core/widgets/fit_text.dart';

class AssessmentHubScreen extends ConsumerWidget {
  const AssessmentHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final results = ref.watch(assessmentResultsProvider);
    final customAssessments = ref.watch(customAssessmentsProvider);
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final profileId = profile?.id ?? '';

    // The educator sections belong to the *role*, not just the classroom
    // teacher: a Parent runs the same assessment surface over their home
    // group. Gating on `== UserRole.teacher` left a Parent who opened this
    // screen with nothing but a learner hub inviting them to sit their own
    // pre-test — no builder, no assessments, no way back to their children.
    final isEducator = profile?.role.isEducator ?? false;
    // Who *sits* the pre-test / post-test pair: the enrolled learners, and
    // only them. A Teacher runs a class and a Parent runs a home group — they
    // are measured by what their learners gain, not by taking the instrument
    // themselves, and this page used to hand them their own copy of it. A
    // Player has no educator to read a learning gain and is never part of the
    // study, so the pair is not theirs either; they keep the mastery tests.
    final sitsPrePost = profile?.role.isEnrollableLearner ?? false;
    final hasPreTest =
        sitsPrePost && AssessmentService.hasCompletedPreTest(profileId);
    final hasPostTest =
        sitsPrePost && AssessmentService.hasCompletedPostTest(profileId);
    final gainReport = isEducator
        ? null
        : AssessmentService.getLearningGainReport(profileId);
    // An educator running the pair as a measure rather than as practice can
    // close it once it is done — see `Classroom.allowAssessmentRetakes`.
    final retakesAllowed = AssessmentService.retakesAllowed(profile);
    // Warmed here, read in `_startAssessment`: for a learner who signs, part
    // of the instrument is sign items, and the manifest has to be loaded
    // before they tap rather than after.
    if (sitsPrePost && ref.watch(accessibilityContentPolicyProvider).showFsl) {
      ref.watch(fslAvailabilityProvider);
    }
    final retakeLocked =
        l10n?.assessRetakeLocked ??
        'Already done — ask your teacher to reopen it';
    // One round trip per profile per session, pulling whatever this device
    // does not yet know: for an educator their own templates/assignments plus
    // their assignees' results, for a learner the work set for them elsewhere.
    // Watched, not awaited — the hub renders local data immediately and
    // repaints if the pull adds anything.
    if (profileId.isNotEmpty) {
      ref.watch(
        isEducator
            ? educatorAssessmentSyncProvider(profileId)
            : learnerAssignmentSyncProvider(profileId),
      );
    }
    // Work an educator has assigned to this learner. Templates live under the
    // *educator's* key, so these are resolved here and handed to the test
    // screen directly rather than looked up again by id.
    final assignedWork = isEducator || profileId.isEmpty
        ? const <({AssessmentAssignment assignment, Assessment assessment})>[]
        : AssessmentService.getOpenableAssignments(profileId);
    // The two halves of the study instrument are the educator's to hand out.
    // A learner's cards open only what was assigned: they used to generate a
    // test of their own — a different sample of words from the class's — and
    // the post-test card unlocked by itself after a week, before the teacher
    // had decided the study period was over.
    final assignedPre = _assignedOf(assignedWork, AssessmentType.preTest);
    final assignedPost = _assignedOf(assignedWork, AssessmentType.postTest);
    // How this learner meets pictures, video and sign language an educator
    // attached — the badges on their work and the sheets below follow it.
    final mediaPresentation = ref.watch(assessmentMediaPresentationProvider);
    // What their teacher or parent wrote back, newest first.
    final feedbackForYou = isEducator || profileId.isEmpty
        ? const <({AssessmentAssignment assignment, AssessmentFeedback feedback})>[]
        : AssessmentService.getFeedbackForStudent(profileId);

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
                    AppBackButton(color: hc.textPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FitText(
                            l10n?.assessCenterTitle ?? 'Assessment Center',
                            style: AppTypography.headlineLarge.copyWith(
                              color: hc.textPrimary,
                            ),
                          ),
                          Text(
                            isEducator
                                ? (l10n?.assessCenterEducatorSub ??
                                      "Build, assign and track your learners' tests")
                                : (l10n?.assessCenterLearnerSub ??
                                      'Measure your learning progress'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEducator && results.isNotEmpty)
                      IconButton(
                          tooltip: _tr(context).hubResultsTooltip,
                          onPressed: () => context.push('/assessment/results'),
                          icon: Icon(
                            Icons.analytics_rounded,
                            color: hc.primary,
                            size: 28,
                          ),
                        ),
                    // Everything they have done and been told, in one place.
                    if (!isEducator &&
                        (results.isNotEmpty || feedbackForYou.isNotEmpty))
                      IconButton(
                        tooltip: _tr(context).portfolioMine,
                        onPressed: () => context.push('/assessment/portfolio'),
                        icon: Icon(
                          Icons.folder_special_rounded,
                          color: hc.primary,
                          size: 28,
                        ),
                      ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            // ─── Educator Toolbar ──────────────────────────
            // An educator arriving from the "Assessments" tile used to land on
            // a page that only offered to test *them*; their three actual jobs
            // now sit at the top of it.
            if (isEducator)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                  child:
                      Row(
                        children: [
                          Expanded(
                            child: _EducatorAction(
                              icon: Icons.add_circle_rounded,
                              label: _tr(context).hubCreate,
                              color: AppColors.sectionAssessment,
                              onTap: () => context.push('/assessment/builder'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EducatorAction(
                              icon: Icons.assignment_turned_in_rounded,
                              label: _tr(context).hubAssign,
                              color: AppColors.success,
                              onTap: () => context.push('/assessment/assign'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EducatorAction(
                              icon: Icons.track_changes_rounded,
                              label: _tr(context).hubTrack,
                              color: AppColors.info,
                              onTap: () => context.push('/assessment/tracking'),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
                ),
              ),

            // ─── Assigned To You ───────────────────────────
            // The learner's home already banners "you have N assessments to
            // complete" and deep-links here. Until this section existed that
            // was a promise the hub could not keep — nothing on it named an
            // assignment, and the templates live under the educator's key so
            // there was no way to reach one at all.
            if (assignedWork.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: SectionHeader(
                    title: '📌 ${l10n?.assessAssignedToYou ?? 'Assigned to You'}',
                    color: hc.textPrimary,
                  ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final work = assignedWork[index];
                    return _AssignedWorkTile(
                          assignment: work.assignment,
                          assessment: work.assessment,
                          presentation: mediaPresentation,
                          onTap: () => _openAssigned(context, ref, work),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (120 + index * 60).ms)
                        .slideY(begin: 0.08, end: 0);
                  }, childCount: assignedWork.length),
                ),
              ),
            ],

            // ─── Feedback For You ──────────────────────────
            // The educator's note on a piece of work, with whatever they
            // showed or signed. Learners only — an educator writes these from
            // Assignment Tracking.
            if (feedbackForYou.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: SectionHeader(
                    title: '💬 ${_tr(context).assessFeedbackForYou}',
                    color: hc.textPrimary,
                  ).animate().fadeIn(duration: 400.ms, delay: 90.ms),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = feedbackForYou[index];
                    return _FeedbackTile(
                      assignment: item.assignment,
                      feedback: item.feedback,
                      presentation: mediaPresentation,
                    );
                  }, childCount: feedbackForYou.length),
                ),
              ),
            ],

            // ─── Learning Gain Banner ──────────────────────
            // Null for an educator — see `gainReport` above.
            if (gainReport != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: 16,
                  ),
                  child: _LearningGainBanner(report: gainReport)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
              ),

            // ─── Pre/Post Test Section (learners only) ─────
            if (sitsPrePost) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                child: SectionHeader(
                  title: '📊 ${l10n?.assessPrePostSection ?? 'Pre-Test & Post-Test'}',
                  color: hc.textPrimary,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Text(
                  l10n?.assessPrePostLearnerBlurb ??
                      'Take a pre-test before studying, then a post-test after — see your growth!',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
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
                  // The cell has to get taller as the type does. Its two lines
                  // are already capped at one line each, so the only way the
                  // card can fit larger text is more height — under the
                  // dyslexia theme (1.6 line height) at 2.0x a fixed ratio
                  // left it 16px short. Dividing by the scale gives the text
                  // room instead of taking size away from it; the grid
                  // scrolls, so the extra height costs nothing else.
                  childAspectRatio: (context.isTablet ? 2.5 : 3.2) /
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                ),
                delegate: SliverChildListDelegate([
                  _AssessmentTypeCard(
                        type: AssessmentType.preTest,
                        isCompleted: hasPreTest,
                        latestScore: hasPreTest
                            ? AssessmentService.getLatestPreTest(
                                profileId,
                              )?.percentage
                            : null,
                        isLocked: assignedPre == null &&
                            (!hasPreTest || !retakesAllowed),
                        lockMessage: hasPreTest
                            ? retakeLocked
                            : (l10n?.assessPreFromEducator ??
                                  'Your teacher or parent will give you '
                                      'this test'),
                        onTap: assignedPre != null
                            ? () => _openAssigned(context, ref, assignedPre)
                            : hasPreTest && retakesAllowed
                            ? () => _startAssessment(
                                context,
                                ref,
                                AssessmentType.preTest,
                              )
                            : null,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 250.ms)
                      .slideY(begin: 0.1, end: 0),
                  _AssessmentTypeCard(
                        type: AssessmentType.postTest,
                        isCompleted: hasPostTest,
                        latestScore: hasPostTest
                            ? AssessmentService.getLatestPostTest(
                                profileId,
                              )?.percentage
                            : null,
                        isLocked: assignedPost == null &&
                            (!hasPostTest || !retakesAllowed),
                        lockMessage: hasPostTest
                            ? retakeLocked
                            : !hasPreTest
                            ? const PostTestReadiness(
                                gate: PostTestGate.noPreTest,
                              ).lockMessageOf(l10n)
                            : (l10n?.assessPostFromEducator ??
                                  'Your teacher or parent will open this '
                                      'after your lessons'),
                        onTap: assignedPost != null
                            ? () => _openAssigned(context, ref, assignedPost)
                            : hasPostTest && retakesAllowed
                            ? () => _startAssessment(
                                context,
                                ref,
                                AssessmentType.postTest,
                              )
                            : null,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                ]),
              ),
            ),
            ],

            // ─── Educator: whose pre/post is still outstanding ───
            // The section an educator gets where their own pre-test used to
            // be. Same instrument, opposite side of it: who has sat which
            // half, and what the gain came to.
            if (isEducator) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                  child: SectionHeader(
                    title:
                        '📊 ${l10n?.assessPrePostSection ?? 'Pre-Test & Post-Test'}',
                    color: hc.textPrimary,
                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Text(
                    l10n?.assessPrePostEducatorBlurb ??
                        'Your learners sit these. Assign the pre-test first, '
                            'then the post-test after the lessons — the gain '
                            'appears here.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          context.push('/assessment/class-report'),
                      icon: const Icon(Icons.insights_rounded, size: 18),
                      label: Text(l10n?.assessClassReport ?? 'Class report'),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
                sliver: _LearnerGainCoverage(hc: hc),
              ),
            ],

            // ─── Category Mastery Section (learners only) ──
            if (!isEducator) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                child: SectionHeader(
                  title:
                      '🏆 ${l10n?.assessMasterySection ?? 'Category Mastery Tests'}',
                  color: hc.textPrimary,
                ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Text(
                  l10n?.assessMasteryBlurb ??
                      'Test your knowledge in specific vocabulary categories',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
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
                  // Same reasoning as the type grid above: a fixed 40px icon
                  // plus a label that grows with the font needs a taller cell
                  // as the type grows, or the column runs off the bottom —
                  // 36px under the dyslexia theme at 2.0x.
                  childAspectRatio: 1.4 /
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = FlashcardCategory.values[index];
                  final categoryResults = results
                      .where(
                        (r) =>
                            r.type == AssessmentType.categoryMastery &&
                            r.categories.contains(category),
                      )
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
                        onTap: () =>
                            _startCategoryMastery(context, ref, category),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (400 + index * 60).ms)
                      .slideY(begin: 0.1, end: 0);
                }, childCount: FlashcardCategory.values.length),
              ),
            ),
            ],

            // ─── Teacher Section: Quiz Builder ────────────
            if (isEducator) ...[
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
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade600,
                          ],
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
                                Text(
                                  _tr(context).hubQuizBuilder,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _tr(context).hubQuizBuilderDesc,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 580.ms),
                ),
              ),
            ],

            // ─── Teacher Section: Custom Assessments ───────
            if (isEducator) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '✏️ ${_tr(context).hubCustomAssessments}',
                          style: AppTypography.titleLarge.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                          tooltip: _tr(context).hubCreateCustomTooltip,
                          onPressed: () => context.push('/assessment/builder'),
                          icon: Icon(
                            Icons.add_circle_rounded,
                            color: hc.primary,
                            size: 32,
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
                      horizontal: padding,
                      vertical: 16,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: hc.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: hc.border),
                      ),
                      child: Column(
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            _tr(context).hubNoCustom,
                            style: AppTypography.titleSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tr(context).hubNoCustomHint,
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textHint,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 650.ms),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: 8,
                  ),
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
                                '/assessment/take/${assessment.id}',
                                extra: assessment,
                              ),
                              onEdit: () => context.push(
                                '/assessment/builder?edit='
                                '${Uri.encodeQueryComponent(assessment.id)}',
                              ),
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

            // ─── Recent Results Quick View (learners only) ─
            if (!isEducator && results.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '📈 ${l10n?.assessRecentResults ?? 'Recent Results'}',
                          style: AppTypography.titleLarge.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: _tr(context).hubViewAllResults,
                        child: TextButton(
                          onPressed: () => context.push('/assessment/results'),
                          child: Text(l10n?.assessSeeAll ?? 'See All'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final sorted = List.of(results)
                      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
                    final result = sorted[index];
                    return _RecentResultTile(result: result)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (750 + index * 60).ms)
                        .slideX(begin: 0.05, end: 0);
                  }, childCount: results.length.clamp(0, 5)),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /// Build this category's mastery test and hand it to the test screen.
  ///
  /// The test is generated here rather than inside the route so that a rebuild
  /// of the router cannot reshuffle a quiz the learner is halfway through.
  void _startCategoryMastery(
    BuildContext context,
    WidgetRef ref,
    FlashcardCategory category,
  ) {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final assessment = AssessmentService.generateCategoryMastery(
      profileId: profile.id,
      category: category,
    );
    context.push(
      '/assessment/category/${category.index}',
      extra: assessment,
    );
  }

  static ({AssessmentAssignment assignment, Assessment assessment})?
  _assignedOf(
    List<({AssessmentAssignment assignment, Assessment assessment})> work,
    AssessmentType type,
  ) {
    for (final w in work) {
      if (w.assessment.type == type) return w;
    }
    return null;
  }

  /// Opens assigned work — through its instructions first, when the educator
  /// wrote or attached any, so a learner watches the signed instructions
  /// before the clock starts rather than during it.
  Future<void> _openAssigned(
    BuildContext context,
    WidgetRef ref,
    ({AssessmentAssignment assignment, Assessment assessment}) work,
  ) async {
    final presentation = ref.read(assessmentMediaPresentationProvider);
    if (assignmentHasBriefing(work.assignment, presentation)) {
      final start = await showAssignmentBriefing(
        context,
        assignment: work.assignment,
        assessment: work.assessment,
        presentation: presentation,
      );
      if (!start || !context.mounted) return;
    }
    context.push('/assessment/take/${work.assessment.id}', extra: work.assessment);
  }

  /// A self-started sitting — only ever a *retake*, and only where the class or
  /// home group allows retakes. First sittings come from an assignment.
  void _startAssessment(
    BuildContext context,
    WidgetRef ref,
    AssessmentType type,
  ) {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    // Belt and braces: the cards are not built for anyone else, but a
    // generated pre-test saved under an educator's id would pollute the very
    // learning-gain figures they are meant to be reading.
    if (!profile.role.isEnrollableLearner) return;
    // A learner who signs sits part of the instrument in their own language.
    // A learner who reads or lip-reads gets none — the content policy has
    // already answered that question, and it is the same answer that decides
    // whether they see sign surfaces anywhere else.
    final signCards =
        ref.read(accessibilityContentPolicyProvider).showFsl
        ? (ref.read(fslAvailabilityProvider).valueOrNull?.cardsWithVideo ??
              const <Flashcard>[])
        : const <Flashcard>[];
    final assessment = AssessmentService.generateStandardAssessment(
      profileId: profile.id,
      type: type,
      signCards: signCards,
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
      label: _tr(
        context,
      ).hubGainSemantics(report.summaryOf(AppLocalizations.of(context))),
      child: AppCard(
        gradient: gradient,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  improved ? '🚀' : '📊',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tr(context).hubGainTitle,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Flexible pills: "Panimulang Pagsusulit" is three times the
            // width of "Pre-Test", and at a large font the fixed row ran
            // off the card in Filipino.
            Row(
              children: [
                Flexible(
                  child: _ScorePill(
                    label: AssessmentType.preTest.labelOf(
                      AppLocalizations.of(context),
                    ),
                    score: report.preTestPercentage,
                  ),
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
                Flexible(
                  child: _ScorePill(
                    label: AssessmentType.postTest.labelOf(
                      AppLocalizations.of(context),
                    ),
                    score: report.postTestPercentage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.summaryOf(AppLocalizations.of(context)),
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
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
          ? _tr(context).hubCardLockedSemantics(
              type.labelOf(AppLocalizations.of(context)),
              lockMessage ?? '',
            )
          : isCompleted
          ? _tr(context).hubCardDoneSemantics(
              type.labelOf(AppLocalizations.of(context)),
              ((latestScore ?? 0) * 100).round(),
            )
          : _tr(context).hubCardNewSemantics(
              type.labelOf(AppLocalizations.of(context)),
            ),
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
                        type.labelOf(AppLocalizations.of(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Bounded to one line (full text is in the Semantics label
                      // above) so the card can't overflow its fixed-ratio grid
                      // cell at large accessibility font scales.
                      Text(
                        isLocked
                            ? lockMessage ?? ''
                            : isCompleted
                            ? _tr(
                                context,
                              ).hubBest(((latestScore ?? 0) * 100).round())
                            : _tr(context).hubTapToStart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textOnPrimary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(
                    Icons.lock_rounded,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                  )
                else if (isCompleted)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                  ),
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
          bestScore != null
          ? _tr(context).hubMasteryTriedSemantics(
              category.labelOf(_tr(context)),
              (bestScore! * 100).round(),
              attemptCount,
            )
          : _tr(
              context,
            ).hubMasteryNewSemantics(category.labelOf(_tr(context))),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: hc.isDark ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: catColor.withValues(alpha: hc.isDark ? 0.8 : 0.4),
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
                category.labelOf(_tr(context)),
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
                  _tr(context).hubBest((bestScore! * 100).round()),
                  style: AppTypography.labelSmall.copyWith(
                    color: HCColor.of(context).readableOver(catColor, catColor.withValues(alpha: 0.3)),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  _tr(context).hubNotTested,
                  style: AppTypography.labelSmall.copyWith(color: hc.textHint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Educator Action ───────────────────────────────────

/// One button in the educator toolbar at the top of the hub.
class _EducatorAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EducatorAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hc.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Assigned Work Tile ────────────────────────────────

/// One assessment an educator has assigned to this learner and that they have
/// not finished yet. Tapping opens the educator's own template — not a freshly
/// generated look-alike — so the result the educator sees back in Assignment
/// Tracking matches the assignment they made.
class _AssignedWorkTile extends StatelessWidget {
  final AssessmentAssignment assignment;
  final Assessment assessment;
  final AssessmentMediaPresentation presentation;
  final VoidCallback onTap;

  const _AssignedWorkTile({
    required this.assignment,
    required this.assessment,
    required this.presentation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final overdue = assignment.isOverdue;
    final accent = overdue ? hc.error : AppColors.sectionAssessment;
    final due = assignment.deadline;
    // What this learner will meet — their own slots, so a learner who does
    // not sign is not promised a sign video.
    final mediaKinds = {
      ...presentation.kindsFor(assignment.media),
      for (final q in assessment.questions) ...presentation.kindsFor(q.media),
    }.toList()
      ..sort((a, b) => presentation.order.indexOf(a) - presentation.order.indexOf(b));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: [
          QuestionPrompt.title(
            assignment.assessmentTitle.isEmpty
                ? assessment.title
                : assignment.assessmentTitle,
            AppLocalizations.of(context),
          ),
          _tr(context).hubQuestionCount(assessment.questions.length),
          if (due != null)
            overdue
                ? _tr(context).hubOverdue
                : _tr(context).hubDue(_friendlyDate(context, due)),
          if (mediaKinds.isNotEmpty)
            mediaKinds.map((k) => k.labelOf(_tr(context))).join(', '),
          _tr(context).hubTapToStart,
        ].join('. '),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    overdue
                        ? Icons.warning_amber_rounded
                        : Icons.assignment_turned_in_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        QuestionPrompt.title(
                          assignment.assessmentTitle.isEmpty
                              ? assessment.title
                              : assignment.assessmentTitle,
                          AppLocalizations.of(context),
                        ),
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        due == null
                            ? _tr(
                                context,
                              ).hubQuestionCount(assessment.questions.length)
                            : '${_tr(context).hubQuestionCount(assessment.questions.length)} • '
                                  '${overdue ? _tr(context).hubOverdue : _tr(context).hubDue(_friendlyDate(context, due))}',
                        style: AppTypography.bodySmall.copyWith(
                          color: overdue ? hc.error : hc.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (assignment.instructions != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          assignment.instructions!,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textHint,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (mediaKinds.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ExcludeSemantics(
                          child: AssessmentMediaBadges(kinds: mediaKinds),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: hc.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _friendlyDate(BuildContext context, DateTime dt) =>
      LocalizedDate.monthDayYear(dt, AppLocalizations.of(context));
}

// ─── Feedback Tile ─────────────────────────────────────

/// One piece of feedback from a learner's teacher or parent. Opens the note
/// with its pictures, video or signed version, shown the way this learner
/// needs them.
class _FeedbackTile extends StatelessWidget {
  final AssessmentAssignment assignment;
  final AssessmentFeedback feedback;
  final AssessmentMediaPresentation presentation;

  const _FeedbackTile({
    required this.assignment,
    required this.feedback,
    required this.presentation,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final title = QuestionPrompt.title(
      assignment.assessmentTitle,
      AppLocalizations.of(context),
    );
    final kinds = presentation.kindsFor(feedback.media);
    final note = curlyQuotes(feedback.note.trim());
    void open() => showFeedbackForLearner(
      context,
      assignmentTitle: assignment.assessmentTitle,
      feedback: feedback,
      presentation: presentation,
      assessmentId: assignment.assessmentId,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        onTap: open,
        label: [
          t.assessFeedbackOn(title),
          if (note.isNotEmpty) note,
          if (kinds.isNotEmpty) kinds.map((k) => k.labelOf(t)).join(', '),
          t.assessFeedbackTapToOpen,
        ].join('. '),
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: open,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.45)),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.rate_review_rounded,
                      color: HCColor.of(context).graphic(AppColors.info),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.assessFeedbackOn(title),
                          style: AppTypography.titleSmall.copyWith(
                            color: hc.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.isNotEmpty)
                          Text(
                            note,
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (kinds.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AssessmentMediaBadges(kinds: kinds),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: hc.textHint),
                ],
              ),
            ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomAssessmentTile({
    required this.assessment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label:
            _tr(context).hubCustomTileSemantics(
              assessment.title,
              _tr(context).hubQuestionCount(assessment.questions.length),
            ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hc.border),
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
                  child: Icon(Icons.assignment_rounded, color: hc.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment.title,
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_tr(context).hubQuestionCount(assessment.questions.length)} • '
                        '${assessment.difficulty.labelOf(_tr(context))}',
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      if (assessment.updatedAt != null)
                        Text(
                          _tr(context).assessEditedOn(
                            LocalizedDate.monthDayYear(
                              assessment.updatedAt!,
                              AppLocalizations.of(context),
                            ),
                          ),
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _tr(context).assessEditTooltip(assessment.title),
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: hc.primary,
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: _tr(context).assessDeleteTooltip(assessment.title),
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: hc.error,
                    size: 22,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: hc.textHint),
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
        title: Text(_tr(context).hubDeleteTitle),
        content: Text(_tr(context).hubDeleteBody(assessment.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr(context).hubCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: HCColor.of(context).errorText),
            child: Text(_tr(context).hubDelete),
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
        label:
            _tr(context).hubResultSemantics(
              result.type.labelOf(AppLocalizations.of(context)),
              pct,
              result.gradeOf(AppLocalizations.of(context)),
              LocalizedDate.monthDayYear(
                result.completedAt,
                AppLocalizations.of(context),
              ),
            ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hc.border),
          ),
          child: Row(
            children: [
              Text(result.gradeEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.type.labelOf(AppLocalizations.of(context)),
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      LocalizedDate.monthDayYear(
                        result.completedAt,
                        AppLocalizations.of(context),
                      ),
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _scoreColor(result.percentage).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: result.hasAutoScore
                    ? Text(
                        '$pct%',
                        style: AppTypography.labelLarge.copyWith(
                          color: HCColor.of(context).readableOver(_scoreColor(result.percentage), _scoreColor(result.percentage).withValues(alpha: 0.15)),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    // Answered only on video: waiting for a person, not 0%.
                    : Semantics(
                        label: _tr(context).assessSentForReview,
                        child: Icon(
                          Icons.videocam_rounded,
                          color: HCColor.of(context).graphic(AppColors.info),
                          size: 20,
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

}

// ─── Educator: pre / post coverage across the roster ───

/// A sliver listing every learner this educator enrols, with which half of
/// the instrument each has sat and what the gain came to.
///
/// This is the educator's half of the pre-test / post-test feature. They do
/// not take it — they need to know who still owes them one, which is a roster
/// question, not a personal one.
class _LearnerGainCoverage extends ConsumerWidget {
  final HCColor hc;
  const _LearnerGainCoverage({required this.hc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(educatorLearnerRosterProvider);

    if (roster.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: hc.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hc.border),
          ),
          child: Column(
            children: [
              const Text('🧑‍🏫', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                _tr(context).hubNoLearners,
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tr(context).hubNoLearnersHint,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: hc.textHint),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
      );
    }

    final sorted = [...roster]..sort(
      (a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()),
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final learner = sorted[index].$1;
        return _LearnerGainTile(
              profile: learner,
              hc: hc,
              onTap: () =>
                  context.push('/student-profile-detail', extra: learner),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: (250 + index * 50).ms)
            .slideY(begin: 0.06, end: 0);
      }, childCount: sorted.length),
    );
  }
}

class _LearnerGainTile extends StatelessWidget {
  final UserProfile profile;
  final HCColor hc;
  final VoidCallback onTap;

  const _LearnerGainTile({
    required this.profile,
    required this.hc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPre = AssessmentService.hasCompletedPreTest(profile.id);
    final hasPost = AssessmentService.hasCompletedPostTest(profile.id);
    final report = AssessmentService.getLearningGainReport(profile.id);
    final gain = report == null ? null : (report.improvement * 100).round();
    final gainLabel = gain == null
        ? null
        : '${gain >= 0 ? '+' : ''}$gain%';
    // Same rule the learner's own card obeys, phrased for the person who can
    // do something about it: "waiting" is not the same problem as "has not
    // started", and only one of them is the educator's to solve.
    final readiness = AssessmentService.getPostTestReadiness(profile.id);

    final status = gainLabel != null
        ? _tr(context).hubGain(gainLabel)
        : readiness.educatorSummaryOf(AppLocalizations.of(context));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: _tr(context).hubLearnerRowSemantics(profile.name, status),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hc.border),
              boxShadow: AppColors.softShadow,
            ),
            // Wraps rather than overflows: the name plus two state pills and a
            // gain chip is more than a phone has room for at a large font.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatePill(label: _tr(context).hubPre, done: hasPre, hc: hc),
                _StatePill(
                  label: _tr(context).hubPost,
                  done: hasPost,
                  hc: hc,
                ),
                if (!hasPost && hasPre)
                  _ReadinessPill(readiness: readiness, hc: hc),
                if (gain != null && gainLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (gain >= 0 ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      gainLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: gain >= 0
                            ? HCColor.of(context).successText
                            : HCColor.of(context).warningText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a learner is in the wait between the two halves.
///
/// Only shown once the pre-test is in and the post-test is not: before that
/// the row already says "pre-test outstanding", and afterwards the gain says
/// everything this would.
class _ReadinessPill extends StatelessWidget {
  final PostTestReadiness readiness;
  final HCColor hc;
  const _ReadinessPill({required this.readiness, required this.hc});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (readiness.gate) {
      PostTestGate.ready => (AppColors.success, Icons.play_circle_rounded),
      PostTestGate.assigned => (AppColors.info, Icons.assignment_rounded),
      _ => (AppColors.warning, Icons.hourglass_bottom_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              readiness.educatorSummaryOf(AppLocalizations.of(context)),
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).readableOver(color, color.withValues(alpha: 0.4)),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final String label;
  final bool done;
  final HCColor hc;
  const _StatePill({
    required this.label,
    required this.done,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : hc.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).readableOver(color, color.withValues(alpha: 0.4)),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// This file's strings: English when no delegate is present, which is how
/// widget tests build these screens.
AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
