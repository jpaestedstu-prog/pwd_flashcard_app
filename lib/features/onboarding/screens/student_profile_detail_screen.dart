import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../features/progress/theme/progress_theme_provider.dart';
import '../../../features/progress/theme/progress_layout_provider.dart';
import '../../../features/progress/theme/progress_theme_picker.dart';
import '../../../features/progress/widgets/shared/progress_section_header.dart';
import '../../../features/progress/widgets/shared/progress_stat_grid.dart';

/// Shows full profile information and learning progress for a student.
///
/// Theme-aware like the other Progress surfaces: it reads this profile's
/// selectable skin + layout template (and yields to accessibility modes), so
/// a learner sees the same look here as on the main Progress dashboard.
class StudentProfileDetailScreen extends ConsumerWidget {
  final UserProfile profile;

  const StudentProfileDetailScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = AvatarData.getAvatar(profile.avatarIndex);
    final progress = HiveService.getProgress(profile.id);
    final achievements = HiveService.getUnlockedAchievements(profile.id);

    // ─── This profile's skin + layout (yield to accessibility modes) ───
    final theme = ref.watch(progressThemeForProvider(profile.id));
    final layout = ref.watch(progressLayoutForProvider(profile.id));
    final settings = ref.watch(settingsProvider);
    final useTheme =
        !(settings.highContrastMode || settings.dyslexiaMode);
    final accent = useTheme ? theme.accent : AppColors.primary;
    final cardSurface = useTheme
        ? theme.cardSurface(HCColor.of(context).surface)
        : HCColor.of(context).surface;

    // Width-cap content on wide tablets (centered) + tier-aware page padding.
    final maxW = context.maxContentWidth;
    final sideInset = maxW.isFinite
        ? ((context.screenWidth - maxW) / 2).clamp(0.0, double.infinity)
        : 0.0;
    final contentHPad = context.pagePadding + sideInset;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: 'Customize progress',
            onPressed: () => showProgressCustomizeSheet(
              context,
              selectedThemeId: theme.id,
              selectedLayoutId: layout.id,
              onThemeSelected: (id) =>
                  selectProgressThemeFor(ref, profile.id, id),
              onLayoutSelected: (id) =>
                  selectProgressLayoutFor(ref, profile.id, id),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/edit-profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: contentHPad, vertical: 16),
        child: Column(
          children: [
            // ── Profile Header ──
            _ProfileHeader(
              profile: profile,
              avatar: avatar,
              isDark: isDark,
              accent: accent,
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0),
            SizedBox(height: layout.sectionGap),

            // ── Quick Stats (responsive, overflow-safe grid) ──
            ProgressStatGrid(
              layout: layout,
              stats: [
                ProgressStat(
                  icon: Icons.menu_book_rounded,
                  value: '${progress.wordsLearned}',
                  label: 'Words',
                  color: AppColors.primary,
                ),
                ProgressStat(
                  icon: Icons.local_fire_department_rounded,
                  value: '${progress.streakDays}',
                  label: 'Streak',
                  color: AppColors.warning,
                ),
                ProgressStat(
                  icon: Icons.star_rounded,
                  value: '${progress.starBalance}',
                  label: 'Stars',
                  color: AppColors.accent,
                ),
                ProgressStat(
                  icon: Icons.emoji_events_rounded,
                  value: '${achievements.length}',
                  label: 'Badges',
                  color: const Color(0xFF7E57C2),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.05, end: 0),
            SizedBox(height: layout.sectionGap),

            // ── Category Progress ──
            if (progress.categoryProgress.isNotEmpty) ...[
              const _SectionTitle(title: 'Category Progress'),
              const SizedBox(height: 8),
              _CategoryProgressSection(
                categoryProgress: progress.categoryProgress,
                isDark: isDark,
                accent: accent,
                surface: cardSurface,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.05, end: 0),
              SizedBox(height: layout.sectionGap),
            ],

            // ── Recent Scores ──
            if (progress.recentScores.isNotEmpty) ...[
              const _SectionTitle(title: 'Recent Game Scores'),
              const SizedBox(height: 8),
              _RecentScoresSection(
                scores: progress.recentScores,
                isDark: isDark,
                accent: accent,
                surface: cardSurface,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.05, end: 0),
            ],

            // ── Profile Details ──
            SizedBox(height: layout.sectionGap),
            const _SectionTitle(title: 'Profile Details'),
            const SizedBox(height: 8),
            _ProfileDetailsSection(
              profile: profile,
              isDark: isDark,
              accent: accent,
              surface: cardSurface,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 400.ms)
                .slideY(begin: 0.05, end: 0),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Header ──────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final AvatarOption avatar;
  final bool isDark;
  final Color accent;

  const _ProfileHeader({
    required this.profile,
    required this.avatar,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            avatar.color.withValues(alpha: 0.3),
            accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: avatar.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(avatar.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (profile.age != null)
                _HeaderChip(
                  icon: Icons.cake_rounded,
                  label: '${profile.age} yrs old',
                  color: AppColors.accent,
                ),
              if (profile.gradeLevel != null)
                _HeaderChip(
                  icon: Icons.school_rounded,
                  label: profile.gradeLevel!.label,
                  color: accent,
                ),
            ],
          ),
          if (profile.hasPinProtection) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'PIN Protected',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

// ─── Section Title ───────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    // Delegates to the shared header so the student detail screen matches the
    // Progress screen's section styling.
    return ProgressSectionHeader(title: title);
  }
}

// ─── Category Progress ───────────────────────────────────

class _CategoryProgressSection extends StatelessWidget {
  final Map<String, double> categoryProgress;
  final bool isDark;
  final Color accent;
  final Color surface;

  const _CategoryProgressSection({
    required this.categoryProgress,
    required this.isDark,
    required this.accent,
    required this.surface,
  });

  /// Resolve a progress key to a FlashcardCategory by matching .name or .label.
  static FlashcardCategory? _resolveCategory(String key) {
    for (final cat in FlashcardCategory.values) {
      if (cat.name == key || cat.label == key) return cat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = categoryProgress.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Overall mastery summary
    final totalProgress = sorted.isEmpty
        ? 0.0
        : sorted.fold(0.0, (sum, e) => sum + e.value) / sorted.length;

    return Column(
      children: [
        // Overall mastery card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                accent.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // Circular overall progress
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: totalProgress.clamp(0.0, 1.0),
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                    Text(
                      '${(totalProgress * 100).round()}%',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Mastery',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sorted.where((e) => e.value >= 0.9).length} of ${sorted.length} categories mastered',
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Individual categories
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.1),
            ),
            boxShadow: isDark ? null : AppColors.softShadow,
          ),
          child: Column(
            children: [
              for (int i = 0; i < sorted.length; i++) ...[
                _CategoryRow(
                  name: sorted[i].key,
                  progress: sorted[i].value,
                  category: _resolveCategory(sorted[i].key),
                  index: i,
                ),
                if (i < sorted.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final double progress;
  final FlashcardCategory? category;
  final int index;

  const _CategoryRow({
    required this.name,
    required this.progress,
    this.category,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final catColor = category?.color ?? AppColors.primary;
    final catDarkColor = category?.darkColor ?? AppColors.primaryDark;
    final catIcon = category?.icon ?? Icons.category_rounded;
    final displayName = category?.label ?? name;
    final isMastered = progress >= 0.9;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor.withValues(alpha: 0.08),
            catColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: catColor.withValues(alpha: isMastered ? 0.3 : 0.1),
          width: isMastered ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Category icon container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catDarkColor, catColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(catIcon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          // Name and progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: catDarkColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pct%',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: catDarkColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [catDarkColor, catColor],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mastery badge
          if (isMastered) ...[
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 14, color: AppColors.successDark),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Recent Scores ───────────────────────────────────────

class _RecentScoresSection extends StatelessWidget {
  final List<GameScore> scores;
  final bool isDark;
  final Color accent;
  final Color surface;

  const _RecentScoresSection({
    required this.scores,
    required this.isDark,
    required this.accent,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    // Show most recent 5
    final recent = scores.length > 5 ? scores.sublist(scores.length - 5) : scores;
    final display = recent.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < display.length; i++) ...[
            _ScoreRow(score: display[i], accent: accent),
            if (i < display.length - 1)
              Divider(
                height: 20,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final GameScore score;
  final Color accent;

  const _ScoreRow({required this.score, required this.accent});

  @override
  Widget build(BuildContext context) {
    final pct = score.total > 0 ? (score.score / score.total * 100).round() : 0;
    return Row(
      children: [
        // Game type icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.videogame_asset_rounded, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score.gameType.label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatDate(score.date),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${score.score}/${score.total}',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 2),
                Text(
                  '${score.starsEarned}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pct > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$pct%',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── Profile Details ─────────────────────────────────────

class _ProfileDetailsSection extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;
  final Color accent;
  final Color surface;

  const _ProfileDetailsSection({
    required this.profile,
    required this.isDark,
    required this.accent,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Role',
            value: profile.role.label,
            accent: accent,
          ),
          if (profile.birthDate != null) ...[
            const _DetailDivider(),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Birth Date',
              value: _formatDate(profile.birthDate!),
              accent: accent,
            ),
          ],
          if (profile.section != null && profile.section!.isNotEmpty) ...[
            const _DetailDivider(),
            _DetailRow(
              icon: Icons.group_rounded,
              label: 'Section',
              value: profile.section!,
              accent: accent,
            ),
          ],
          if (profile.disabilityType != DisabilityType.none) ...[
            const _DetailDivider(),
            _DetailRow(
              icon: profile.disabilityType.icon,
              label: 'Accessibility',
              value: profile.disabilityType.label,
              accent: accent,
            ),
          ],
          if (profile.tags.isNotEmpty) ...[
            const _DetailDivider(),
            _TagsRow(tags: profile.tags, accent: accent),
          ],
          const _DetailDivider(),
          _DetailRow(
            icon: Icons.event_rounded,
            label: 'Created',
            value: _formatDate(profile.createdAt),
            accent: accent,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // Expanded + end-aligned so a long value ellipsizes instead of
          // overflowing the row at large font scales (e.g. long section names).
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppColors.border.withValues(alpha: 0.3),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final List<String> tags;
  final Color accent;

  const _TagsRow({required this.tags, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.label_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Text(
            'Tags',
            style: AppTypography.bodyMedium.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: AppTypography.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
