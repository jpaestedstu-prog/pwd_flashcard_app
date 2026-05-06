import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../models/survey_models.dart';
import '../services/survey_service.dart';

/// Displays past SUS survey results and scores.
class SurveyResultsScreen extends ConsumerWidget {
  const SurveyResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final colorScheme = Theme.of(context).colorScheme;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Survey Results')),
        body: const Center(child: Text('No profile selected')),
      );
    }

    final results = SurveyService.getSurveyResults(profile.id);
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Mga Resulta ng Sarbey' : 'Survey Results'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (results.isEmpty)
            TextButton.icon(
              onPressed: () => context.push('/sus-survey'),
              icon: const Icon(Icons.add_rounded),
              label: Text(isFilipino ? 'Kumuha ng Sarbey' : 'Take Survey'),
            ),
        ],
      ),
      body: results.isEmpty
          ? _buildEmpty(context, isFilipino, padding)
          : ListView.builder(
              padding: EdgeInsets.all(padding),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return _buildResultCard(
                  context,
                  result,
                  isFilipino,
                  colorScheme,
                  isLatest: index == 0,
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: 50 * index),
                    );
              },
            ),
      floatingActionButton: results.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/sus-survey'),
              icon: const Icon(Icons.rate_review_rounded),
              label: Text(isFilipino ? 'Bagong Sarbey' : 'New Survey'),
            )
          : null,
    );
  }

  Widget _buildEmpty(BuildContext context, bool isFilipino, double padding) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFilipino
                  ? 'Wala pang sarbey na natapos'
                  : 'No surveys completed yet',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFilipino
                  ? 'Magsimula ng sarbey para maibigay ang iyong feedback!'
                  : 'Start a survey to provide your feedback!',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/sus-survey'),
              icon: const Icon(Icons.rate_review_rounded),
              label: Text(isFilipino ? 'Kumuha ng Sarbey' : 'Take Survey'),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    SusSurveyResult result,
    bool isFilipino,
    ColorScheme colorScheme, {
    bool isLatest = false,
  }) {
    final score = result.susScore;
    final scoreColor = _scoreColor(score);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isLatest
            ? BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (isLatest) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFilipino ? 'Pinakabago' : 'Latest',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatDate(result.completedAt, isFilipino),
                  style: AppTypography.bodySmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  result.gradeEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Score display
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: AppTypography.displaySmall.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ 100',
                    style: AppTypography.titleMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.gradeLabel,
                    style: AppTypography.labelLarge.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Score bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: scoreColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              score >= 68
                  ? (isFilipino
                      ? 'Mataas sa average na kakayahang-gamit'
                      : 'Above-average usability')
                  : (isFilipino
                      ? 'Mas mababa sa average na kakayahang-gamit'
                      : 'Below-average usability'),
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Feedback
            if (result.feedback != null && result.feedback!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                isFilipino ? 'Komento:' : 'Feedback:',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.feedback!,
                style: AppTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 85) return Colors.green.shade600;
    if (score >= 72) return Colors.lightGreen.shade600;
    if (score >= 52) return Colors.amber.shade700;
    if (score >= 38) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  String _formatDate(DateTime date, bool isFilipino) {
    final months = isFilipino
        ? [
            'Ene', 'Peb', 'Mar', 'Abr', 'May', 'Hun',
            'Hul', 'Ago', 'Set', 'Okt', 'Nob', 'Dis',
          ]
        : [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
