import 'package:flutter/material.dart';

import '../../../core/services/knowledge_tracing_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/seed_data.dart';
import '../models/teacher_analytics_models.dart';

/// Predictive early-warning card driven by the Elo knowledge-tracing model.
///
/// Complements the raw-accuracy "needing help" alert: that one fires after
/// accuracy has already collapsed below 50%, while this card flags students
/// whose recent per-word success is *declining* or whose predicted mastery
/// is drifting low — practiced-but-getting-worse, which raw averages hide.
/// Renders nothing when no student needs attention.
class KnowledgeEarlyWarningCard extends StatelessWidget {
  final List<StudentAnalytics> students;
  final bool isFilipino;

  const KnowledgeEarlyWarningCard({
    super.key,
    required this.students,
    required this.isFilipino,
  });

  static final Map<String, String> _wordById = {
    for (final card in SeedData.allFlashcards) card.id: card.wordEnglish,
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final flagged = <(StudentAnalytics, EloSummary)>[];
    for (final student in students) {
      final summary = KnowledgeTracingService.summary(student.profileId);
      if (summary.needsAttention) flagged.add((student, summary));
    }
    if (flagged.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppColors.warning, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFilipino
                      ? 'Maagang Babala (hinulaang mastery)'
                      : 'Early Warning (predicted mastery)',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (student, summary) in flagged) ...[
            Text(
              _lineFor(student, summary),
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            isFilipino
                ? 'Batay sa pagbaba ng tamang sagot sa bawat salita, bago pa '
                    'bumagsak ang kabuuang accuracy.'
                : 'Based on per-word success trends — flags trouble before '
                    'overall accuracy drops.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.warning.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _lineFor(StudentAnalytics student, EloSummary summary) {
    final parts = <String>[];
    if (summary.decliningWordIds.isNotEmpty) {
      final names = summary.decliningWordIds
          .map((id) => _wordById[id] ?? id)
          .take(3)
          .join(', ');
      final more = summary.decliningWordIds.length > 3
          ? ' +${summary.decliningWordIds.length - 3}'
          : '';
      parts.add(
        isFilipino ? 'bumababa: $names$more' : 'declining: $names$more',
      );
    }
    final masteryPct = (summary.predictedMastery * 100).round();
    parts.add(
      isFilipino
          ? 'hinulaang mastery $masteryPct%'
          : 'predicted mastery $masteryPct%',
    );
    return '• ${student.name} — ${parts.join(' · ')}';
  }
}
