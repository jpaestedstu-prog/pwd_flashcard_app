import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/research_export_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../features/assessment/services/assessment_service.dart';
import '../../../widgets/app_back_button.dart';
import '../../../features/assessment/providers/assessment_provider.dart';
import '../../../providers/student_list_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../core/utils/accessible_sizing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Educator-only screen for exporting anonymized, cross-student research
/// data — designed specifically for thesis analysis and academic reporting.
///
/// The educator picks who is in the dataset. A shared tablet also holds
/// other classes' learners and practice profiles; the export used to take all
/// of them, indistinguishable once anonymised. Now the educator's own classes
/// and home groups are ticked for them and everyone else is listed unticked —
/// see [ResearchExportService.defaultParticipants].
class ResearchExportScreen extends ConsumerStatefulWidget {
  const ResearchExportScreen({super.key});

  @override
  ConsumerState<ResearchExportScreen> createState() =>
      _ResearchExportScreenState();
}

class _ResearchExportScreenState extends ConsumerState<ResearchExportScreen> {
  bool _isExporting = false;

  /// The educator's own choice, once they have touched a box. Until then the
  /// default is recomputed every build, so a roster that arrives from the
  /// cloud after the screen opens still gets ticked.
  Set<String>? _chosen;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    // Pull results sat on other devices *before* counting or exporting: the
    // pre-test and post-test of a learner on their own tablet only reach this
    // one through the educator sync, and an export taken without it would
    // quietly miss them.
    final educatorId = ref.watch(profileProvider)?.id ?? '';
    if (educatorId.isNotEmpty) {
      ref.watch(educatorAssessmentSyncProvider(educatorId));
    }
    final roster = ref.watch(educatorLearnerRosterProvider);
    // Students and home-group Children, local and remote — the same population
    // the export writes. See ResearchExportService.researchPopulation.
    final population = ResearchExportService.researchPopulation(
      HiveService.getAllProfilesWithProgress(),
      roster: roster,
    );
    final groupIds = <String>{};
    if (educatorId.isNotEmpty) {
      try {
        groupIds
          ..addAll(
            HiveService.getClassroomsByTeacher(educatorId).map((c) => c.id),
          )
          ..addAll(
            HiveService.getHomeGroupsByOwner(educatorId).map((g) => g.id),
          );
      } catch (_) {
        // Group boxes not open — the roster alone still decides.
      }
    }
    final defaults = ResearchExportService.defaultParticipants(
      population,
      rosterIds: {for (final (p, _) in roster) p.id},
      groupIds: groupIds,
    );
    final selected = _chosen ?? defaults;
    final mine = [
      for (final pair in population)
        if (defaults.contains(pair.$1.id)) pair,
    ];
    final others = [
      for (final pair in population)
        if (!defaults.contains(pair.$1.id)) pair,
    ];
    final learners = [
      for (final pair in population)
        if (selected.contains(pair.$1.id)) pair,
    ];
    final learnerCount = learners.length;

    // Compute quick stats for preview — over the learners being exported.
    int totalGames = 0;
    int totalSessions = 0;
    int assessmentCount = 0;
    int moodCount = 0;
    int gainCount = 0;

    for (final (profile, progress) in learners) {
      // Must match the CSV the export writes — `recentScores` is trimmed to 20.
      totalGames += progress.effectiveGamesPlayed;
      totalSessions += HiveService.getSessionLogs(profile.id).length;
      assessmentCount += AssessmentService.getResults(profile.id).length;
      moodCount += HiveService.getMoodEntries(profile.id).length;
      if (AssessmentService.getLearningGainReport(profile.id) != null) {
        gainCount++;
      }
    }

    void toggle(String id, bool on) => setState(() {
      final next = {...selected};
      on ? next.add(id) : next.remove(id);
      _chosen = next;
    });

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          t.rxTitle,
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
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.science_rounded,
                  color: HCColor.of(context).graphic(AppColors.info),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.rxHeader,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.rxIntro,
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

          // ─── Participants ──────────────────────
          Text(
            t.rxParticipants,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.rxParticipantsHint,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t.rxSelectedCount(learnerCount, population.length),
                style: AppTypography.labelMedium.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: population.isEmpty
                    ? null
                    : () => setState(
                        () => _chosen = {for (final (p, _) in population) p.id},
                      ),
                child: Text(t.rxTickAll),
              ),
              TextButton(
                onPressed: learnerCount == 0
                    ? null
                    : () => setState(() => _chosen = <String>{}),
                child: Text(t.rxUntickAll),
              ),
            ],
          ),
          if (mine.isNotEmpty) ...[
            _GroupHeading(text: t.rxYourGroups, hc: hc),
            for (final (profile, _) in mine)
              _ParticipantTile(
                profile: profile,
                selected: selected.contains(profile.id),
                onChanged: (on) => toggle(profile.id, on),
                hc: hc,
              ),
          ],
          if (others.isNotEmpty) ...[
            _GroupHeading(text: t.rxOtherLearners, hc: hc),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t.rxOtherLearnersHint,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
            for (final (profile, _) in others)
              _ParticipantTile(
                profile: profile,
                selected: selected.contains(profile.id),
                onChanged: (on) => toggle(profile.id, on),
                hc: hc,
              ),
          ],

          const SizedBox(height: 24),

          // ─── Data Summary ──────────────────────
          Text(
            t.rxDataAvailable,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _StatRow(
            icon: Icons.people_rounded,
            label: t.rxLearners,
            value: '$learnerCount',
            color: AppColors.primary,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.sports_esports_rounded,
            label: t.rxGameScores,
            value: '$totalGames',
            color: AppColors.secondary,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.timer_rounded,
            label: t.rxSessions,
            value: '$totalSessions',
            color: AppColors.warning,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.quiz_rounded,
            label: t.rxAssessmentResults,
            value: '$assessmentCount',
            color: AppColors.success,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.mood_rounded,
            label: t.rxMoodEntries,
            value: '$moodCount',
            color: Colors.pink,
            hc: hc,
          ),
          _StatRow(
            icon: Icons.trending_up_rounded,
            label: t.rxGainReports,
            value: '$gainCount',
            color: AppColors.info,
            hc: hc,
          ),

          const SizedBox(height: 24),

          // ─── Files Included ────────────────────
          Text(
            t.rxFilesIncluded,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          for (final (name, desc) in [
            ('students_overview.csv', t.rxFileStudentsOverview),
            ('learning_curves.csv', t.rxFileLearningCurves),
            ('session_patterns.csv', t.rxFileSessionPatterns),
            ('category_mastery.csv', t.rxFileCategoryMastery),
            ('word_accuracy.csv', t.rxFileWordAccuracy),
            ('assessment_results.csv', t.rxFileAssessmentResults),
            ('mood_data.csv', t.rxFileMoodData),
            ('adaptive_difficulty.csv', t.rxFileAdaptiveDifficulty),
            ('summary_stats.json', t.rxFileSummaryStats),
          ])
            _FileChip(name: name, desc: desc, hc: hc),

          const SizedBox(height: 32),

          // ─── Export Button ─────────────────────
          SizedBox(
            width: double.infinity,
            height: scaledControlHeight(context, 56),
            child: ElevatedButton.icon(
              onPressed: learnerCount == 0 || _isExporting
                  ? null
                  : () => _handleExport(selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: HCColor.of(context).primary,
                foregroundColor: HCColor.of(context).textOnPrimary,
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
                    ? t.rxGenerating
                    : t.rxExportButton(learnerCount),
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          if (learnerCount == 0) ...[
            const SizedBox(height: 12),
            Text(
              population.isEmpty ? t.rxNoLearners : t.rxNobodyTicked,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _handleExport(Set<String> selected) async {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    setState(() => _isExporting = true);
    try {
      await ResearchExportService.generateAndShare(
        roster: ref.read(educatorLearnerRosterProvider),
        onlyIds: selected,
      );
      if (mounted) {
        AppSnackBar.success(context, message: t.rxExported);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: t.rxExportFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ─── Helper Widgets ────────────────────────────────────────

class _GroupHeading extends StatelessWidget {
  final String text;
  final HCColor hc;
  const _GroupHeading({required this.text, required this.hc});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: AppTypography.labelLarge.copyWith(
        fontWeight: FontWeight.w700,
        color: hc.textPrimary,
      ),
    ),
  );
}

/// One learner, with the box that puts them in the dataset. The name shows
/// here only — the files carry the anonymous id.
class _ParticipantTile extends StatelessWidget {
  final UserProfile profile;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final HCColor hc;

  const _ParticipantTile({
    required this.profile,
    required this.selected,
    required this.onChanged,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? group;
    try {
      group = profile.classroomId != null
          ? HiveService.getCachedClassroom(profile.classroomId!)?.name
          : profile.homeGroupId != null
          ? HiveService.getCachedHomeGroup(profile.homeGroupId!)?.name
          : null;
    } catch (_) {
      group = null;
    }
    final details = [
      profile.role.labelOf(l10n),
      profile.disabilityType.labelOf(l10n),
      ?group,
    ].join(' · ');
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        profile.name,
        style: AppTypography.bodyMedium.copyWith(
          color: hc.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        details,
        style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
      ),
    );
  }
}

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
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
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

  const _FileChip({required this.name, required this.desc, required this.hc});

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
            Icon(Icons.description_outlined, size: 18, color: hc.textSecondary),
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
