import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../models/teacher_analytics_models.dart';
import '../../../widgets/app_back_button.dart';

/// Screen for teachers to compare 2–3 students side by side across
/// key metrics: words learned, accuracy, streak, stars, categories.
class StudentComparisonScreen extends ConsumerStatefulWidget {
  const StudentComparisonScreen({super.key});

  @override
  ConsumerState<StudentComparisonScreen> createState() =>
      _StudentComparisonScreenState();
}

class _StudentComparisonScreenState
    extends ConsumerState<StudentComparisonScreen> {
  final Set<String> _selectedIds = {};

  List<StudentAnalytics> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    final allData = HiveService.getAllProfilesWithProgress();
    _allStudents = allData
        .where((d) => d.$1.role == UserRole.student)
        .map((d) => StudentAnalytics.from(d.$1, d.$2))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<StudentAnalytics> get _selectedStudents =>
      _allStudents.where((s) => _selectedIds.contains(s.profileId)).toList();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    ref.watch(progressProvider); // rebuild on data change

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'Compare Students',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _allStudents.isEmpty
          ? Center(
              child: Text(
                'No students available',
                style: AppTypography.bodyMedium
                    .copyWith(color: hc.textSecondary),
              ),
            )
          : CustomScrollView(
              slivers: [
                // ─── Student Selector ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _StudentSelector(
                      allStudents: _allStudents,
                      selectedIds: _selectedIds,
                      onToggle: _toggleStudent,
                      hc: hc,
                    ).animate().fadeIn(duration: 300.ms),
                  ),
                ),

                // ─── Comparison Content ────────────────
                if (_selectedStudents.length >= 2) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _MetricsComparisonCard(
                        students: _selectedStudents,
                        hc: hc,
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _CategoryComparisonChart(
                        students: _selectedStudents,
                        hc: hc,
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: _StrengthsWeaknessTable(
                        students: _selectedStudents,
                        hc: hc,
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    ),
                  ),
                ] else if (_selectedIds.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Select at least 2 students to compare',
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.compare_arrows_rounded,
                              size: 56, color: hc.textHint),
                          const SizedBox(height: 12),
                          Text(
                            'Select 2–3 students above to compare',
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _toggleStudent(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
      }
    });
  }
}

// ─── Student Selector Chips ──────────────────────────

class _StudentSelector extends StatelessWidget {
  final List<StudentAnalytics> allStudents;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final HCColor hc;

  const _StudentSelector({
    required this.allStudents,
    required this.selectedIds,
    required this.onToggle,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedIds.length >= 2
              ? AppColors.primary.withValues(alpha: 0.3)
              : hc.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people_rounded, color: hc.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Select Students',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selectedIds.length >= 2
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedIds.length >= 2
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${selectedIds.length}/3',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selectedIds.length >= 2
                        ? AppColors.success
                        : AppColors.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allStudents.asMap().entries.map((entry) {
              final idx = entry.key;
              final student = entry.value;
              final selected = selectedIds.contains(student.profileId);
              final avatar = AvatarData.getAvatar(student.avatarIndex);
              final chipColor = _colorForIndex(idx);
              return GestureDetector(
                onTap: () => onToggle(student.profileId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              chipColor.withValues(alpha: 0.18),
                              chipColor.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                    color: selected ? null : hc.border.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? chipColor.withValues(alpha: 0.4)
                          : hc.border.withValues(alpha: 0.5),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: chipColor.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(avatar.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        student.name,
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              selected ? chipColor : hc.textPrimary,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: chipColor),
                      ],
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 250.ms, delay: (60 + idx * 40).ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    delay: (60 + idx * 40).ms,
                    duration: 250.ms,
                  );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Metrics Comparison Card ─────────────────────────

class _MetricsComparisonCard extends StatelessWidget {
  final List<StudentAnalytics> students;
  final HCColor hc;

  const _MetricsComparisonCard({
    required this.students,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap the comparison bars in the professional panel chrome for
    // consistency with the other educator surfaces. The per-student bars are a
    // genuine comparison visual, so they stay as-is (the single-value pro tiles
    // don't apply here).
    return ProPanel(
      title: 'Key Metrics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricRow(
            metric: 'Words Learned',
            icon: Icons.school_rounded,
            values: students.map((s) => s.wordsLearned.toDouble()).toList(),
            names: students.map((s) => s.name).toList(),
            maxVal: 144,
            format: (v) => v.toInt().toString(),
            hc: hc,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            metric: 'Accuracy',
            icon: Icons.percent_rounded,
            values: students
                .map((s) => s.averageAccuracy * 100)
                .toList(),
            names: students.map((s) => s.name).toList(),
            maxVal: 100,
            format: (v) => '${v.round()}%',
            hc: hc,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            metric: 'Streak (days)',
            icon: Icons.local_fire_department_rounded,
            values:
                students.map((s) => s.streakDays.toDouble()).toList(),
            names: students.map((s) => s.name).toList(),
            maxVal: null,
            format: (v) => v.toInt().toString(),
            hc: hc,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            metric: 'Stars Earned',
            icon: Icons.star_rounded,
            values:
                students.map((s) => s.totalStars.toDouble()).toList(),
            names: students.map((s) => s.name).toList(),
            maxVal: null,
            format: (v) => v.toInt().toString(),
            hc: hc,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            metric: 'Games Played',
            icon: Icons.sports_esports_rounded,
            values:
                students.map((s) => s.gamesPlayed.toDouble()).toList(),
            names: students.map((s) => s.name).toList(),
            maxVal: null,
            format: (v) => v.toInt().toString(),
            hc: hc,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String metric;
  final IconData icon;
  final List<double> values;
  final List<String> names;
  final double? maxVal;
  final String Function(double) format;
  final HCColor hc;

  const _MetricRow({
    required this.metric,
    required this.icon,
    required this.values,
    required this.names,
    required this.maxVal,
    required this.format,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMax =
        maxVal ?? values.fold<double>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: hc.textSecondary),
            const SizedBox(width: 6),
            Text(
              metric,
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: hc.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...values.asMap().entries.map((entry) {
          final i = entry.key;
          final val = entry.value;
          final color = _colorForIndex(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    names[i],
                    style: AppTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: effectiveMax > 0
                          ? (val / effectiveMax).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: color.withValues(alpha: 0.1),
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    format(val),
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Category Comparison Chart ───────────────────────

class _CategoryComparisonChart extends StatelessWidget {
  final List<StudentAnalytics> students;
  final HCColor hc;

  const _CategoryComparisonChart({
    required this.students,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all categories
    final allCats = <String>{};
    for (final s in students) {
      allCats.addAll(s.categoryProgress.keys);
    }
    final sortedCats = allCats.toList()..sort();

    if (sortedCats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Comparison',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final cat = sortedCats[group.x];
                      final studentName = students[rodIndex].name;
                      return BarTooltipItem(
                        '$studentName\n$cat: ${rod.toY.round()}%',
                        AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= sortedCats.length) {
                          return const SizedBox();
                        }
                        final name = sortedCats[i];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: Text(
                              name.length > 10
                                  ? '${name.substring(0, 9)}…'
                                  : name,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 7,
                                color: hc.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 8,
                          color: hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      ),
                  rightTitles: const AxisTitles(
                      ),
                ),
                gridData: FlGridData(
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: hc.border.withValues(alpha: 0.4),
                    strokeWidth: 0.5,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedCats.asMap().entries.map((entry) {
                  final catName = entry.value;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: students.asMap().entries.map((sEntry) {
                      final val = sEntry.value.categoryProgress[catName] ?? 0;
                      return BarChartRodData(
                        toY: (val * 100).clamp(0, 100),
                        color: _colorForIndex(sEntry.key),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: students.asMap().entries.map((entry) {
              final i = entry.key;
              final name = entry.value.name;
              return _LegendDot(color: _colorForIndex(i), label: name);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Strengths & Weaknesses Table ────────────────────

class _StrengthsWeaknessTable extends StatelessWidget {
  final List<StudentAnalytics> students;
  final HCColor hc;

  const _StrengthsWeaknessTable({
    required this.students,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strengths & Weaknesses',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...students.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final color = _colorForIndex(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (s.strongestCategory != null) ...[
                              const Icon(Icons.arrow_upward_rounded,
                                  size: 12,
                                  color: AppColors.success),
                              Text(
                                ' ${s.strongestCategory}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.success,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (s.strongestCategory != null &&
                                s.weakestCategory != null)
                              const SizedBox(width: 10),
                            if (s.weakestCategory != null) ...[
                              const Icon(Icons.arrow_downward_rounded,
                                  size: 12,
                                  color: AppColors.error),
                              Text(
                                ' ${s.weakestCategory}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: HCColor.of(context).textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─── Color Palette for Students ───────────────────────

Color _colorForIndex(int index) {
  const colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
  ];
  return colors[index % colors.length];
}
