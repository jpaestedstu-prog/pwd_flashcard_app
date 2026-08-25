import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/mood_context.dart';
import '../models/mood_models.dart';

class MoodHistoryScreen extends ConsumerWidget {
  const MoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodProvider);
    final notifier = ref.read(moodProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    final recent7 = notifier.recentEntries(7);
    final recent30 = notifier.recentEntries(30);
    final avgMood7 = notifier.averageMood(7);
    final avgMood30 = notifier.averageMood(30);

    // Sorted once here, not inside the item builder — building item N used to
    // copy and re-sort the whole history, so a learner with a long record
    // paid O(n log n) per visible tile.
    final newestFirst = List.of(moods)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Kasaysayan ng Mood' : 'Mood History'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (moods.length >= 3)
            IconButton(
              onPressed: () => GoRouter.of(context).push('/mood-insights'),
              icon: const Icon(Icons.insights_rounded),
              tooltip: isFilipino ? 'Mood Insights' : 'Mood Insights',
            ),
        ],
      ),
      body: SafeArea(
        child: moods.isEmpty
            // Centre the empty state, but let it scroll instead of overflowing
            // a short viewport at a large font scale.
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      isFilipino
                          ? 'Walang naka-record na mood'
                          : 'No mood entries yet',
                      style: AppTypography.titleMedium
                          .copyWith(color: hc.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFilipino
                          ? 'Mag-check in ng mood para makita ang iyong history dito!'
                          : 'Check in your mood to see your history here!',
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
                    ),
                  ),
                )
            : CustomScrollView(
                slivers: [
                  // ─── Summary Cards ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(padding, 8, padding, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: isFilipino ? '7 Araw' : '7 Days',
                              entries: recent7.length,
                              avgMood: avgMood7,
                              color: AppColors.primary,
                              isFilipino: isFilipino,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: isFilipino ? '30 Araw' : '30 Days',
                              entries: recent30.length,
                              avgMood: avgMood30,
                              color: AppColors.secondary,
                              isFilipino: isFilipino,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                  // ─── Mood Trend Chart ──────────
                  if (recent7.length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            padding, 20, padding, 0),
                        child: Container(
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
                                isFilipino
                                    ? 'Mood Trend (7 Araw)'
                                    : 'Mood Trend (7 Days)',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: hc.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 180,
                                child: LineChart(
                                  LineChartData(
                                    minY: 0.5,
                                    maxY: 6.5,
                                    gridData: const FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, _) {
                                            final mood = MoodType.values
                                                .where((m) =>
                                                    m.numericValue ==
                                                    value.toInt())
                                                .firstOrNull;
                                            if (mood == null) {
                                              return const SizedBox();
                                            }
                                            return Text(
                                              mood.emoji,
                                              style: const TextStyle(
                                                  fontSize: 14),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: const AxisTitles(
                                        
                                      ),
                                      topTitles: const AxisTitles(
                                        
                                      ),
                                      rightTitles: const AxisTitles(
                                        
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: recent7
                                            .asMap()
                                            .entries
                                            .map((e) => FlSpot(
                                                  e.key.toDouble(),
                                                  e.value.mood.numericValue
                                                      .toDouble(),
                                                ))
                                            .toList(),
                                        isCurved: true,
                                        color: AppColors.primary,
                                        barWidth: 3,
                                        dotData: FlDotData(
                                          getDotPainter: (spot, _, _, _) {
                                            final moodIdx =
                                                spot.y.toInt().clamp(1, 6);
                                            final mood = MoodType.values
                                                .firstWhere(
                                              (m) =>
                                                  m.numericValue == moodIdx,
                                              orElse: () => MoodType.neutral,
                                            );
                                            return FlDotCirclePainter(
                                              radius: 5,
                                              color: mood.color,
                                              strokeWidth: 2,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 150.ms),
                      ),
                    ),

                  // ─── Recent Entries ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(padding, 24, padding, 8),
                      child: Text(
                        isFilipino
                            ? 'Mga Kamakailang Entry'
                            : 'Recent Entries',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: padding),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = newestFirst[index];
                          // No per-index stagger: this list is lazy, so a
                          // tile built after a scroll would start its delay
                          // from the moment it scrolled in and sit invisible.
                          return _MoodEntryTile(
                            entry: entry,
                            isFilipino: isFilipino,
                            onDelete: () =>
                                _confirmDelete(context, ref, entry, isFilipino),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: 0.03, end: 0);
                        },
                        childCount: newestFirst.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
      ),
    );
  }

  /// Remove a single reading.
  ///
  /// `MoodNotifier.removeMood` has existed since the feature shipped but had
  /// no caller — a learner who tapped the wrong face was stuck with it in
  /// their history and in the research export forever.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MoodEntry entry,
    bool isFilipino,
  ) async {
    final label = entry.mood.labelOf(isFilipino: isFilipino);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFilipino ? 'Burahin ang entry?' : 'Delete this entry?'),
        content: Text(
          isFilipino
              ? 'Tatanggalin ang "$label" sa iyong mood history.'
              : 'This removes "$label" from your mood history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isFilipino ? 'Burahin' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(moodProvider.notifier).removeMood(entry.id);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int entries;
  final double? avgMood;
  final Color color;
  final bool isFilipino;

  const _SummaryCard({
    required this.title,
    required this.entries,
    this.avgMood,
    required this.color,
    required this.isFilipino,
  });

  /// The nearest mood to an average value, named in the learner's language.
  static String _averageLabel(double avg, bool isFilipino) =>
      _nearestMood(avg).labelOf(isFilipino: isFilipino);

  static MoodType _nearestMood(double avg) => MoodType.values.firstWhere(
        (m) => m.numericValue == avg.round().clamp(1, 6),
        orElse: () => MoodType.neutral,
      );

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final moodLabel = avgMood != null ? _nearestMood(avgMood!).emoji : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.labelMedium
                  .copyWith(color: hc.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(moodLabel, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // The old ternary was inverted: English always read
                    // "entries", so a single reading showed "1 entries".
                    isFilipino
                        ? '$entries ${entries == 1 ? 'entry' : 'na entry'}'
                        : '$entries ${entries == 1 ? 'entry' : 'entries'}',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  if (avgMood != null)
                    Text(
                      // Named, not scored. "Avg: 2.0/6" is not an answer a
                      // learner can use, and it is the only summary a
                      // cognitive / multiple profile would have been given.
                      isFilipino
                          ? 'Kadalasan: ${_averageLabel(avgMood!, true)}'
                          : 'Mostly: ${_averageLabel(avgMood!, false)}',
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodEntryTile extends StatelessWidget {
  final MoodEntry entry;
  final bool isFilipino;
  final VoidCallback onDelete;

  const _MoodEntryTile({
    required this.entry,
    required this.isFilipino,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final date = entry.timestamp;
    final dateStr =
        '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final moodLabel = entry.mood.labelOf(isFilipino: isFilipino);
    final moodContext = MoodContextX.fromKey(entry.activityContext);

    return Semantics(
      label: isFilipino
          ? 'Pakiramdam na $moodLabel noong $dateStr'
              '${entry.note != null ? ', tala: ${entry.note}' : ''}'
          : '$moodLabel mood on $dateStr'
              '${entry.note != null ? ', note: ${entry.note}' : ''}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: entry.mood.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: entry.mood.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.mood.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(entry.mood.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moodLabel,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: entry.mood.darkColor,
                    ),
                  ),
                  // What the learner was doing. Only worth a line when it is
                  // something more specific than "anytime".
                  if (moodContext != MoodContext.general)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(moodContext.icon,
                            size: 12, color: hc.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            moodContext.labelOf(isFilipino: isFilipino),
                            style: AppTypography.labelSmall
                                .copyWith(color: hc.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Text(
                      entry.note!,
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                    fontSize: 11,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: isFilipino ? 'Burahin ang entry' : 'Delete entry',
                  icon: Icon(Icons.delete_outline_rounded, color: hc.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
