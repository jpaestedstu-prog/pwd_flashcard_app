import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/services/certificate_service.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../models/category_mastery.dart';
import '../../../widgets/app_back_button.dart';

class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final hc = HCColor.of(context);
    final studentName = profile?.name ?? 'Learner';

    // Build available certificates
    final certificates = <_CertificateItem>[];

    // Category mastery certificates.
    //
    // Gated on how much of the category the learner actually covered, and the
    // printed word count is that same real figure. Both used to come from
    // `categoryProgress`, which is a rolling *accuracy* average rather than a
    // completion ratio — `accuracy * cardCount` put a number on a physical
    // award that the learner had never reached (five perfect three-question
    // games read as "17/20 words learned"). See [CategoryMastery].
    final mastery = ref.watch(categoryMasteryProvider);
    for (final cat in FlashcardCategory.values) {
      final catMastery = mastery[cat];
      if (catMastery != null && catMastery.isMastered) {
        certificates.add(_CertificateItem(
          title: '${cat.label} Mastery',
          subtitle:
              '${catMastery.wordsLearned}/${catMastery.totalWords} words learned',
          emoji: '🏆',
          color: cat.color,
          onGenerate: () => CertificateService.categoryMastery(
            studentName: studentName,
            category: cat,
            wordsLearned: catMastery.wordsLearned,
            totalWords: catMastery.totalWords,
          ),
        ));
      }
    }

    // Streak milestone certificates.
    //
    // Awarded against the all-time best streak, not the current run. Keying
    // these off `streakDays` meant a learner who reached 30 days and then
    // missed one had their certificate taken off the shelf — a printed award
    // for something that demonstrably happened. Being ill costs the flame on
    // the Progress tab, never the award.
    final bestStreak = progress.effectiveBestStreak;
    final milestones = [7, 14, 30, 60, 100];
    for (final days in milestones) {
      if (bestStreak >= days) {
        certificates.add(_CertificateItem(
          title: '$days-Day Streak',
          subtitle: 'Consistent study dedication',
          emoji: '🔥',
          color: const Color(0xFFFF5722),
          onGenerate: () => CertificateService.streakMilestone(
            studentName: studentName,
            streakDays: days,
          ),
        ));
      }
    }

    // Overall progress certificate (if learned 50+ words)
    if (progress.wordsLearned >= 50) {
      certificates.add(_CertificateItem(
        title: 'Learning Excellence',
        subtitle: '${progress.wordsLearned} words, ${progress.totalStars} stars',
        emoji: '⭐',
        color: AppColors.warning,
        onGenerate: () => CertificateService.overallProgress(
          studentName: studentName,
          totalWords: progress.wordsLearned,
          totalStars: progress.totalStars,
          // The best streak reached, for the same reason as the milestone
          // certificates above — a printed award should not shrink.
          streakDays: bestStreak,
        ),
      ));
    }

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(fallbackRoute: '/progress'),
        title: Text(
          'My Certificates',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: certificates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 64, color: hc.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'No certificates yet',
                    style: AppTypography.titleSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep learning to earn certificates!\n'
                    'Master a category (80%+), build a 7-day streak,\n'
                    'or learn 50+ words.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: certificates.length,
              itemBuilder: (context, index) {
                final cert = certificates[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CertificateCard(
                    item: cert,
                    studentName: studentName,
                  ),
                ).animate().fadeIn(
                      duration: 350.ms,
                      delay: Duration(milliseconds: 80 * index),
                    ).slideY(begin: 0.05, end: 0);
              },
            ),
    );
  }
}

class _CertificateItem {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final Future<List<int>> Function() onGenerate;

  const _CertificateItem({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onGenerate,
  });
}

class _CertificateCard extends StatefulWidget {
  final _CertificateItem item;
  final String studentName;

  const _CertificateCard({
    required this.item,
    required this.studentName,
  });

  @override
  State<_CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<_CertificateCard> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Semantics(
      button: true,
      label: 'Certificate: ${widget.item.title}. ${widget.item.subtitle}. '
          'Tap to preview and share.',
      child: GestureDetector(
        onTap: _isGenerating ? null : _generateAndShare,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: widget.item.color, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.item.color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(widget.item.emoji,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      widget.item.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isGenerating)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.item.color,
                  ),
                )
              else
                Icon(
                  Icons.download_rounded,
                  color: widget.item.color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await widget.item.onGenerate();
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes as dynamic,
        name: 'Certificate - ${widget.item.title}',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: 'Failed to generate certificate: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
