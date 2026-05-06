import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/research_export_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/hive_service.dart';
import '../../../features/assessment/services/assessment_service.dart';

/// Educator-only screen for exporting anonymized, cross-student research
/// data — designed specifically for thesis analysis and academic reporting.
class ResearchExportScreen extends ConsumerStatefulWidget {
  const ResearchExportScreen({super.key});

  @override
  ConsumerState<ResearchExportScreen> createState() =>
      _ResearchExportScreenState();
}

class _ResearchExportScreenState extends ConsumerState<ResearchExportScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final allProfiles = HiveService.getAllProfilesWithProgress();
    final students = allProfiles
        .where((p) => p.$1.role == UserRole.student)
        .toList();
    final studentCount = students.length;

    // Compute quick stats for preview
    int totalGames = 0;
    int totalSessions = 0;
    int assessmentCount = 0;
    int moodCount = 0;
    int gainCount = 0;

    for (final (profile, progress) in students) {
      totalGames += progress.recentScores.length;
      totalSessions += HiveService.getSessionLogs(profile.id).length;
      assessmentCount += AssessmentService.getResults(profile.id).length;
      moodCount += HiveService.getMoodEntries(profile.id).length;
      if (AssessmentService.getLearningGainReport(profile.id) != null) {
        gainCount++;
      }
    }

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
          'Research Data Export',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Description Card ──────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded,
                    color: AppColors.info, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thesis Research Export',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Export anonymized, cross-student data for '
                        'academic analysis. Student names are replaced '
                        'with IDs (S001, S002, …).',
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),

          const SizedBox(height: 24),

          // ─── Data Summary ──────────────────────
          Text(
            'Data Available',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _StatRow(
            icon: Icons.people_rounded,
            label: 'Students',
            value: '$studentCount',
            color: AppColors.primary,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.sports_esports_rounded,
            label: 'Game scores',
            value: '$totalGames',
            color: AppColors.secondary,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.timer_rounded,
            label: 'Sessions logged',
            value: '$totalSessions',
            color: AppColors.warning,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.quiz_rounded,
            label: 'Assessment results',
            value: '$assessmentCount',
            color: AppColors.success,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.mood_rounded,
            label: 'Mood entries',
            value: '$moodCount',
            color: Colors.pink,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.trending_up_rounded,
            label: 'Learning gain reports',
            value: '$gainCount',
            color: AppColors.info,
            hc: hc,
          ),

          const SizedBox(height: 24),

          // ─── Files Included ────────────────────
          Text(
            'Files Included',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _FileChip(
              name: 'students_overview.csv',
              desc: 'Demographics & aggregate stats per student',
              hc: hc),
          _FileChip(
              name: 'learning_curves.csv',
              desc: 'Game scores over time (for trend analysis)',
              hc: hc),
          _FileChip(
              name: 'session_patterns.csv',
              desc: 'Session logs with day-of-week patterns',
              hc: hc),
          _FileChip(
              name: 'category_mastery.csv',
              desc: 'Per-category mastery % for each student',
              hc: hc),
          _FileChip(
              name: 'word_accuracy.csv',
              desc: 'Spaced-repetition per-word accuracy data',
              hc: hc),
          _FileChip(
              name: 'assessment_results.csv',
              desc: 'Pre/post test scores & learning gains',
              hc: hc),
          _FileChip(
              name: 'mood_data.csv',
              desc: 'Mood check-ins correlated with activities',
              hc: hc),
          _FileChip(
              name: 'adaptive_difficulty.csv',
              desc: 'Difficulty adjustments & accuracy over time',
              hc: hc),
          _FileChip(
              name: 'summary_stats.json',
              desc: 'High-level aggregates for quick reference',
              hc: hc),

          const SizedBox(height: 32),

          // ─── Export Button ─────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: studentCount == 0 || _isExporting
                  ? null
                  : _handleExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_rounded),
              label: Text(
                _isExporting
                    ? 'Generating…'
                    : 'Export Research Data ($studentCount students)',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          if (studentCount == 0) ...[
            const SizedBox(height: 12),
            Text(
              'No student profiles found. Create student profiles to '
              'export research data.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: hc.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      await ResearchExportService.generateAndShare();
      if (mounted) {
        AppSnackBar.success(context, message: 'Research data exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ─── Helper Widgets ────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final HCColor hc;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  final String desc;
  final HCColor hc;

  const _FileChip({
    required this.name,
    required this.desc,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hc.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hc.border),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: 18, color: hc.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hc.textPrimary,
                    ),
                  ),
                  Text(
                    desc,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
