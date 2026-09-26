import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/learner_support.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/localized_date.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../reports/screens/weekly_report_screen.dart' show ReportPreviewScreen;
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';
import '../models/learner_portfolio.dart';
import '../models/question_prompt.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';
import '../services/portfolio_pdf.dart';
import '../widgets/assessment_media_panel.dart';
import '../widgets/assessment_media_sheets.dart';

/// Everything one learner has done and been told in the assessment module:
/// every test with its score (a person's marks on video answers counted in),
/// their video answers to watch again, and the feedback with its pictures,
/// video and signs — newest first.
///
/// Two readers. The learner sees their own, with media shown the way their
/// accessibility profile meets it. A teacher or parent sees a learner's,
/// with everything shown, and can hand the family a PDF of it.
class LearnerPortfolioScreen extends ConsumerWidget {
  /// Whose portfolio. Null — or a learner's own id — is the viewer's own.
  final String? learnerId;

  /// The learner's name from the link, for when the roster has not loaded.
  final String? learnerName;

  const LearnerPortfolioScreen({super.key, this.learnerId, this.learnerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final padding = context.pagePadding;
    final viewer = ref.watch(profileProvider);
    final isEducator = viewer?.role.isEducator ?? false;
    // Only an educator reads someone else's; the router already turns a
    // learner's hand-typed link back to their own, and this agrees.
    final id = isEducator ? (learnerId ?? '') : (viewer?.id ?? '');

    // Repaint when a pull lands: results and feedback made on other tablets.
    if (viewer != null && viewer.id.isNotEmpty) {
      ref.watch(
        isEducator
            ? educatorAssessmentSyncProvider(viewer.id)
            : learnerAssignmentSyncProvider(viewer.id),
      );
    }
    ref.watch(assignmentsProvider);
    if (!isEducator) ref.watch(assessmentResultsProvider);

    final roster = isEducator
        ? ref.watch(educatorLearnerRosterProvider)
        : const <Never>[];
    String name = isEducator ? (learnerName ?? '') : (viewer?.name ?? '');
    for (final d in roster) {
      if (d.$1.id == id) name = d.$1.name;
    }

    final presentation = isEducator
        ? AssessmentMediaPresentation.educatorPreview
        : ref.watch(assessmentMediaPresentationProvider);
    final portfolio = id.isEmpty
        ? LearnerPortfolio.from(
            learnerId: id,
            results: const [],
            feedback: const [],
            titleOf: (_) => null,
          )
        : LearnerPortfolio.load(id);

    return Scaffold(
      backgroundColor: hc.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    AppBackButton(
                      fallbackRoute: '/assessment-hub',
                      color: hc.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: FitText(
                              isEducator ? t.portfolioTitle : t.portfolioMine,
                              style: AppTypography.headlineLarge.copyWith(
                                color: hc.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            isEducator && name.isNotEmpty
                                ? t.portfolioOfSub(curlyQuotes(name))
                                : t.portfolioMineSub,
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── PDF for the family (educators) ────────
            if (isEducator && !portfolio.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _PdfButton(portfolio: portfolio, learnerName: name),
                  ),
                ),
              ),

            if (portfolio.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ExcludeSemantics(
                        child: Text('🗂️', style: TextStyle(fontSize: 64)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.portfolioEmpty,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // ─── Summary ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                  child: _Summary(portfolio: portfolio),
                ),
              ),
              if (portfolio.gain != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                    child: _GainLine(report: portfolio.gain!),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      t.portfolioSoFar,
                      style: AppTypography.titleLarge.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              // No entrance stagger: a lazy list rebuilds cards on scroll-back
              // and a replayed fade makes them blink.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = portfolio.entries[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: entry.isResult
                            ? _ResultCard(entry: entry)
                            : _FeedbackCard(
                                entry: entry,
                                presentation: presentation,
                              ),
                      );
                    },
                    childCount: portfolio.entries.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Summary ─────────────────────────────────────────

class _Summary extends StatelessWidget {
  final LearnerPortfolio portfolio;

  const _Summary({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final average = portfolio.averageScore;
    final tiles = [
      (
        icon: Icons.assignment_turned_in_rounded,
        color: AppColors.primary,
        value: '${portfolio.testsTaken}',
        label: t.portfolioTestsTaken,
      ),
      (
        icon: Icons.insights_rounded,
        color: average == null ? AppColors.info : scoreColor(average),
        value: average == null ? '—' : '${(average * 100).round()}%',
        label: t.portfolioAverage,
      ),
      (
        icon: Icons.videocam_rounded,
        color: AppColors.info,
        value: '${portfolio.videoAnswers}',
        label: t.portfolioVideoAnswers,
      ),
      (
        icon: Icons.rate_review_rounded,
        color: AppColors.success,
        value: '${portfolio.feedbackCount}',
        label: t.portfolioFeedback,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Columns drop as the font grows, so a label never wraps letter by
        // letter in a sliver of a tile — 4, 2 or 1, never 3, which left the
        // fourth tile alone on a row of its own.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final fit = (constraints.maxWidth / (150 * scale)).floor();
        final columns = fit >= 4 ? 4 : (fit >= 2 ? 2 : 1);
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: _StatTile(
                  icon: tile.icon,
                  color: tile.color,
                  value: tile.value,
                  label: tile.label,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      container: true,
      // A dash has nothing to say aloud: just the label until there is one.
      label: value == '—' ? label : '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTypography.headlineSmall.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GainLine extends StatelessWidget {
  final LearningGainReport report;

  const _GainLine({required this.report});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final color = report.hasImproved ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            report.hasImproved
                ? Icons.trending_up_rounded
                : Icons.trending_flat_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              report.summaryOf(AppLocalizations.of(context)),
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entries ─────────────────────────────────────────

/// A test the learner sat: its name, day, score and supports, and their
/// video answers to watch again.
class _ResultCard extends StatelessWidget {
  final PortfolioEntry entry;

  const _ResultCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);
    final t = l10n ?? AppLocalizationsEn();
    final result = entry.result!;
    final score = entry.score!;
    final fraction = entry.fraction;
    final title = curlyQuotes(entry.titleOf(l10n));
    final date = LocalizedDate.monthDayYear(entry.at, l10n);
    final supports = result.accommodations.map((s) => s.labelOf(l10n)).join(
      ', ',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.textSecondary.withValues(alpha: 0.15)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      result.type.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        date,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      if (supports.isNotEmpty)
                        Text(
                          t.portfolioSupports(supports),
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      if (fraction == null)
                        Text(
                          t.assessSentForReview,
                          style: AppTypography.bodySmall.copyWith(
                            color: HCColor.of(context).infoText,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (score.pending > 0)
                        Text(
                          t.assessToReview(score.pending),
                          style: AppTypography.bodySmall.copyWith(
                            color: HCColor.of(context).infoText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // A percentage or a camera, sized to itself: it used to be
                // Flexible beside the Expanded title, took half the row and
                // parked the score mid-card. The words for a waiting test
                // are under the date instead.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (fraction == null
                                ? AppColors.info
                                : scoreColor(fraction))
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: fraction == null
                      ? Icon(
                          Icons.videocam_rounded,
                          size: 20,
                          color: HCColor.of(context).graphic(AppColors.info),
                        )
                      // Dark words on the tint: the pastel score colour on
                      // its own tint was too faint to read.
                      : Text(
                          '${(fraction * 100).round()}%',
                          style: AppTypography.labelLarge.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (result.reviewAnswers.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showVideoAnswers(context, entry),
              icon: const Icon(Icons.play_circle_rounded),
              label: Text(t.portfolioWatchAnswers),
            ),
          ],
        ],
      ),
    );
  }
}

/// The learner's video answers on one test, each with its question and, once
/// a person has marked it, the mark.
Future<void> _showVideoAnswers(BuildContext context, PortfolioEntry entry) {
  FocusManager.instance.primaryFocus?.unfocus();
  final result = entry.result!;
  Map<String, AssessmentQuestion> questions = const {};
  try {
    questions = {
      for (final q
          in AssessmentService.findAssessmentById(
                result.assessmentId,
              )?.questions ??
              const <AssessmentQuestion>[])
        q.id: q,
    };
  } catch (_) {
    // No box (a test harness): the answers still play, under a generic label.
  }
  final marks = entry.feedback?.reviews ?? const <String, bool>{};
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final hc = HCColor.of(sheet);
      final l10n = AppLocalizations.of(sheet);
      final t = l10n ?? AppLocalizationsEn();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                curlyQuotes(entry.titleOf(l10n)),
                style: AppTypography.titleLarge.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.portfolioVideoAnswers,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final answer in result.reviewAnswers) ...[
              Text(
                curlyQuotes(
                  QuestionPrompt.localize(
                    questions[answer.questionId]?.questionText ??
                        t.assessYourVideoAnswer,
                    l10n,
                  ),
                ),
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                ),
              ),
              if (marks.containsKey(answer.questionId))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        marks[answer.questionId]!
                            ? Icons.check_circle_rounded
                            : Icons.replay_rounded,
                        size: 20,
                        color: marks[answer.questionId]!
                            ? HCColor.of(context).graphic(AppColors.success)
                            : HCColor.of(context).graphic(AppColors.warning),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          marks[answer.questionId]!
                              ? t.assessReviewedCorrect
                              : t.assessReviewedNotYet,
                          style: AppTypography.labelLarge.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    t.assessSentForReview,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              AssessmentMediaPanel(
                media: AssessmentMedia(video: answer.givenAnswer),
                presentation: AssessmentMediaPresentation.educatorPreview,
                fallbackLabel: t.assessYourVideoAnswer,
              ),
              const SizedBox(height: 8),
            ],
            TextButton.icon(
              onPressed: () => Navigator.of(sheet).maybePop(),
              icon: const Icon(Icons.close_rounded),
              label: Text(t.assessMediaClose),
            ),
          ],
        ),
      );
    },
  );
}

/// Feedback a teacher or parent wrote, opening to the whole of it.
class _FeedbackCard extends StatelessWidget {
  final PortfolioEntry entry;
  final AssessmentMediaPresentation presentation;

  const _FeedbackCard({required this.entry, required this.presentation});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);
    final t = l10n ?? AppLocalizationsEn();
    final feedback = entry.feedback!;
    final title = curlyQuotes(entry.titleOf(l10n));
    final note = curlyQuotes(feedback.note.trim());
    final kinds = presentation.kindsFor(feedback.media);
    final date = LocalizedDate.monthDayYear(entry.at, l10n);
    void open() => showFeedbackForLearner(
      context,
      assignmentTitle: entry.title ?? title,
      feedback: feedback,
      presentation: presentation,
    );

    return Semantics(
      button: true,
      onTap: open,
      label: [
        t.assessFeedbackOn(title),
        date,
        if (note.isNotEmpty) note,
        if (kinds.isNotEmpty) kinds.map((k) => k.labelOf(t)).join(', '),
        t.assessFeedbackTapToOpen,
      ].join('. '),
      child: ExcludeSemantics(
        child: Material(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              open();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.assessFeedbackOn(title),
                          style: AppTypography.titleSmall.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          date,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                        if (kinds.isNotEmpty) ...[
                          const SizedBox(height: 8),
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

// ─── PDF ─────────────────────────────────────────────

/// Makes the family's PDF and opens it in the preview, where it is shared.
class _PdfButton extends StatefulWidget {
  final LearnerPortfolio portfolio;
  final String learnerName;

  const _PdfButton({required this.portfolio, required this.learnerName});

  @override
  State<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<_PdfButton> {
  bool _busy = false;

  Future<void> _make() async {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    setState(() => _busy = true);
    try {
      final bytes = await PortfolioPdf.build(
        widget.portfolio,
        learnerName: widget.learnerName,
        l10n: t,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewScreen(
            pdfBytes: bytes,
            title: t.portfolioPdfSubject(widget.learnerName),
            filename: 'portfolio_${_fileStem(widget.learnerName)}.pdf',
            shareSubject: t.portfolioPdfSubject(widget.learnerName),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Portfolio PDF failed: $e');
      if (mounted) AppSnackBar.error(context, message: t.portfolioPdfFailed);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return FilledButton.icon(
      onPressed: _busy ? null : _make,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_rounded),
      label: Text(t.portfolioSharePdf),
    );
  }
}

/// A file name every Android share target accepts.
String _fileStem(String name) {
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'learner' : cleaned;
}
