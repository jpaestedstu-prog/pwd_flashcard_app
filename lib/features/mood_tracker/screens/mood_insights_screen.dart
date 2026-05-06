import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/mood_models.dart';

/// Mood-Activity Correlation Dashboard for thesis research.
///
/// Shows how mood relates to study time, games played,
/// and activity context — helping answer whether gamification
/// affects learner emotional experience.
class MoodInsightsScreen extends ConsumerWidget {
  const MoodInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodProvider);
    final notifier = ref.read(moodProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final colorScheme = Theme.of(context).colorScheme;

    final recent30 = notifier.recentEntries(30);

    // Build daily correlation data — mood + session logs by date
    final sessionLogs = profile != null
        ? HiveService.getSessionLogs(profile.id)
        : <Map<String, dynamic>>[];
    final correlation = _buildDailyCorrelation(recent30, sessionLogs);
    final activityBreakdown = _buildActivityBreakdown(recent30);
    final insights = _generateInsights(correlation, activityBreakdown, isFilipino);

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Mood Insights' : 'Mood Insights'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: moods.length < 3
            ? _buildEmptyState(isFilipino, colorScheme)
            : CustomScrollView(
                slivers: [
                  // ─── Key Insights ──────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
                      child: _InsightsBanner(
                        insights: insights,
                        isFilipino: isFilipino,
                        colorScheme: colorScheme,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                  ),

                  // ─── Mood vs Study Time ──────
                  if (correlation.length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                        child: _MoodStudyTimeChart(
                          data: correlation,
                          isFilipino: isFilipino,
                          colorScheme: colorScheme,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    ),

                  // ─── Mood vs Games Played ──────
                  if (correlation.where((d) => d.gamesPlayed > 0).length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                        child: _MoodGamesChart(
                          data: correlation,
                          isFilipino: isFilipino,
                          colorScheme: colorScheme,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    ),

                  // ─── Mood by Activity Context ──────
                  if (activityBreakdown.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                        child: _ActivityContextChart(
                          data: activityBreakdown,
                          isFilipino: isFilipino,
                          colorScheme: colorScheme,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    ),

                  // ─── Mood Distribution ──────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                      child: _MoodDistribution(
                        entries: recent30,
                        isFilipino: isFilipino,
                        colorScheme: colorScheme,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isFilipino, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            isFilipino
                ? 'Kailangan ng 3+ mood entries'
                : 'Need 3+ mood entries',
            style: AppTypography.titleMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFilipino
                ? 'Mag-check in ng mood para makita ang correlation insights!'
                : 'Check in your mood to see correlation insights!',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Data Builders ──────────────────────────────

  /// Groups mood entries and session logs by date to form daily data points.
  static List<_DailyCorrelation> _buildDailyCorrelation(
    List<MoodEntry> moods,
    List<Map<String, dynamic>> sessions,
  ) {
    // Build a map of date → session aggregate
    final sessionByDate = <String, _SessionAggregate>{};
    for (final s in sessions) {
      final dateStr = s['date'] as String? ?? '';
      final datePart =
          dateStr.contains(' ') ? dateStr.split(' ').first : dateStr.split('T').first;
      final agg = sessionByDate.putIfAbsent(
        datePart,
        () => _SessionAggregate(),
      );
      agg.durationMin += (((s['durationSeconds'] as int?) ?? 0) ~/ 60);
      agg.gamesPlayed += (s['gamesPlayed'] as int?) ?? 0;
      agg.cardsReviewed += (s['cardsReviewed'] as int?) ?? 0;
    }

    // Build a map of date → mood average
    final moodByDate = <String, List<MoodEntry>>{};
    for (final m in moods) {
      final key =
          '${m.timestamp.year}-${m.timestamp.month.toString().padLeft(2, '0')}-${m.timestamp.day.toString().padLeft(2, '0')}';
      moodByDate.putIfAbsent(key, () => []).add(m);
    }

    // Merge — only dates that have mood entries
    final result = <_DailyCorrelation>[];
    for (final entry in moodByDate.entries) {
      final date = entry.key;
      final moodEntries = entry.value;
      final avgMood = moodEntries.fold<double>(
              0, (sum, e) => sum + e.mood.numericValue) /
          moodEntries.length;
      final session = sessionByDate[date];

      result.add(_DailyCorrelation(
        date: date,
        avgMood: avgMood,
        studyMinutes: session?.durationMin ?? 0,
        gamesPlayed: session?.gamesPlayed ?? 0,
        cardsReviewed: session?.cardsReviewed ?? 0,
      ));
    }

    // Sort chronologically
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// Groups mood entries by their activityContext.
  static Map<String, _ActivityMood> _buildActivityBreakdown(
    List<MoodEntry> moods,
  ) {
    final map = <String, _ActivityMood>{};
    for (final m in moods) {
      final ctx = m.activityContext ?? 'general';
      final agg = map.putIfAbsent(ctx, () => _ActivityMood());
      agg.count++;
      agg.totalMood += m.mood.numericValue;
    }
    return map;
  }

  /// Generates human-readable insights from the correlation data.
  static List<String> _generateInsights(
    List<_DailyCorrelation> correlation,
    Map<String, _ActivityMood> activityBreakdown,
    bool isFilipino,
  ) {
    final insights = <String>[];

    if (correlation.length >= 2) {
      // Insight 1: Study day vs non-study day mood comparison
      final studyDays =
          correlation.where((d) => d.studyMinutes > 0).toList();
      final noStudyDays =
          correlation.where((d) => d.studyMinutes == 0).toList();
      if (studyDays.isNotEmpty && noStudyDays.isNotEmpty) {
        final avgStudy =
            studyDays.fold<double>(0, (s, d) => s + d.avgMood) /
                studyDays.length;
        final avgNoStudy =
            noStudyDays.fold<double>(0, (s, d) => s + d.avgMood) /
                noStudyDays.length;
        final diff = avgStudy - avgNoStudy;
        if (diff.abs() > 0.3) {
          insights.add(isFilipino
              ? 'Mood ay ${diff > 0 ? "mas mataas" : "mas mababa"} sa mga araw na may pag-aaral (${diff.abs().toStringAsFixed(1)} pts)'
              : 'Mood is ${diff > 0 ? "higher" : "lower"} on study days (${diff.abs().toStringAsFixed(1)} pts ${diff > 0 ? "better" : "worse"})');
        }
      }

      // Insight 2: Heavy vs light study
      if (studyDays.length >= 2) {
        final sorted = [...studyDays]
          ..sort((a, b) => a.studyMinutes.compareTo(b.studyMinutes));
        final half = sorted.length ~/ 2;
        final lightAvg =
            sorted.take(half).fold<double>(0, (s, d) => s + d.avgMood) /
                half;
        final heavyAvg =
            sorted.skip(half).fold<double>(0, (s, d) => s + d.avgMood) /
                (sorted.length - half);
        final diff2 = heavyAvg - lightAvg;
        if (diff2.abs() > 0.3) {
          insights.add(isFilipino
              ? 'Mas ${diff2 > 0 ? "masaya" : "pagod"} kapag mas maraming oras ng pag-aaral'
              : '${diff2 > 0 ? "Happier" : "Lower mood"} on longer study sessions');
        }
      }

      // Insight 3: Game days vs no-game days
      final gameDays =
          correlation.where((d) => d.gamesPlayed > 0).toList();
      final noGameDays =
          correlation.where((d) => d.gamesPlayed == 0).toList();
      if (gameDays.isNotEmpty && noGameDays.isNotEmpty) {
        final avgGame =
            gameDays.fold<double>(0, (s, d) => s + d.avgMood) /
                gameDays.length;
        final avgNoGame =
            noGameDays.fold<double>(0, (s, d) => s + d.avgMood) /
                noGameDays.length;
        final diff3 = avgGame - avgNoGame;
        if (diff3.abs() > 0.3) {
          insights.add(isFilipino
              ? 'Mood ay ${diff3 > 0 ? "mas masaya" : "mas mababa"} kapag may nilaro (${diff3.abs().toStringAsFixed(1)} pts)'
              : 'Mood is ${diff3 > 0 ? "better" : "lower"} on game days (${diff3.abs().toStringAsFixed(1)} pts)');
        }
      }
    }

    // Insight 4: Best activity context
    if (activityBreakdown.length >= 2) {
      final sorted = activityBreakdown.entries.toList()
        ..sort(
            (a, b) => b.value.average.compareTo(a.value.average));
      final best = sorted.first;
      final label = _contextLabel(best.key, isFilipino);
      insights.add(isFilipino
          ? 'Pinakamasayang mood: $label (avg ${best.value.average.toStringAsFixed(1)}/6)'
          : 'Happiest mood: $label (avg ${best.value.average.toStringAsFixed(1)}/6)');
    }

    if (insights.isEmpty) {
      insights.add(isFilipino
          ? 'Magdagdag pa ng mood entries para sa mas malalim na insights!'
          : 'Add more mood entries for deeper insights!');
    }

    return insights;
  }

  static String _contextLabel(String ctx, bool isFilipino) => switch (ctx) {
        'after_game' => isFilipino ? 'Pagkatapos mag-laro' : 'After games',
        'start_session' => isFilipino ? 'Simula ng session' : 'Session start',
        'end_session' => isFilipino ? 'Tapos ng session' : 'Session end',
        _ => isFilipino ? 'Pangkalahatan' : 'General',
      };
}

// ─── Data Classes ──────────────────────────────

class _SessionAggregate {
  int durationMin = 0;
  int gamesPlayed = 0;
  int cardsReviewed = 0;
}

class _DailyCorrelation {
  final String date;
  final double avgMood;
  final int studyMinutes;
  final int gamesPlayed;
  final int cardsReviewed;

  const _DailyCorrelation({
    required this.date,
    required this.avgMood,
    required this.studyMinutes,
    required this.gamesPlayed,
    required this.cardsReviewed,
  });
}

class _ActivityMood {
  int count = 0;
  int totalMood = 0;
  double get average => count > 0 ? totalMood / count : 0;
}

// ─── Widgets ──────────────────────────────

class _InsightsBanner extends StatelessWidget {
  final List<String> insights;
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _InsightsBanner({
    required this.insights,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded,
                  color: Colors.amber.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                isFilipino ? 'Mga Key Insight' : 'Key Insights',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: Colors.deepPurple.shade600,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        insight,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MoodStudyTimeChart extends StatelessWidget {
  final List<_DailyCorrelation> data;
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _MoodStudyTimeChart({
    required this.data,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Scatter plot: x = study minutes, y = mood
    final spots = data
        .map((d) => FlSpot(d.studyMinutes.toDouble(), d.avgMood))
        .toList();

    final maxX = data
        .fold<double>(30, (max, d) => d.studyMinutes > max ? d.studyMinutes.toDouble() : max);

    return _ChartCard(
      title: isFilipino ? 'Mood vs Oras ng Pag-aaral' : 'Mood vs Study Time',
      subtitle: isFilipino
          ? 'Bawat tuldok = isang araw'
          : 'Each dot = one day',
      child: SizedBox(
        height: 200,
        child: ScatterChart(
          ScatterChartData(
            minX: 0,
            maxX: maxX + 5,
            minY: 0.5,
            maxY: 6.5,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, _) {
                    final mood = MoodType.values
                        .where((m) => m.numericValue == value.toInt())
                        .firstOrNull;
                    if (mood == null) return const SizedBox();
                    return Text(mood.emoji, style: const TextStyle(fontSize: 14));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Text(
                  isFilipino ? 'Minuto' : 'Minutes',
                  style: AppTypography.labelSmall,
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, _) {
                    if (value == 0 || value % 15 != 0) {
                      return const SizedBox();
                    }
                    return Text('${value.toInt()}',
                        style: AppTypography.labelSmall);
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  ),
              rightTitles: const AxisTitles(
                  ),
            ),
            borderData: FlBorderData(show: false),
            scatterSpots: spots.map((s) {
              final moodIdx = s.y.round().clamp(1, 6);
              final mood = MoodType.values.firstWhere(
                (m) => m.numericValue == moodIdx,
                orElse: () => MoodType.neutral,
              );
              return ScatterSpot(s.x, s.y,
                  dotPainter: FlDotCirclePainter(
                    radius: 7,
                    color: mood.color.withValues(alpha: 0.8),
                    strokeWidth: 2,
                    strokeColor: mood.color,
                  ));
            }).toList(),
            scatterTouchData: ScatterTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}

class _MoodGamesChart extends StatelessWidget {
  final List<_DailyCorrelation> data;
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _MoodGamesChart({
    required this.data,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final spots = data
        .where((d) => d.gamesPlayed > 0)
        .map((d) => FlSpot(d.gamesPlayed.toDouble(), d.avgMood))
        .toList();

    final maxX = data.fold<double>(
        5, (max, d) => d.gamesPlayed > max ? d.gamesPlayed.toDouble() : max);

    return _ChartCard(
      title: isFilipino ? 'Mood vs Mga Laro' : 'Mood vs Games Played',
      subtitle: isFilipino
          ? 'Bawat tuldok = isang araw na may laro'
          : 'Each dot = a day with games',
      child: SizedBox(
        height: 200,
        child: ScatterChart(
          ScatterChartData(
            minX: 0,
            maxX: maxX + 1,
            minY: 0.5,
            maxY: 6.5,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, _) {
                    final mood = MoodType.values
                        .where((m) => m.numericValue == value.toInt())
                        .firstOrNull;
                    if (mood == null) return const SizedBox();
                    return Text(mood.emoji, style: const TextStyle(fontSize: 14));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Text(
                  isFilipino ? 'Mga Laro' : 'Games',
                  style: AppTypography.labelSmall,
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    if (value == 0 || value != value.roundToDouble()) {
                      return const SizedBox();
                    }
                    return Text('${value.toInt()}',
                        style: AppTypography.labelSmall);
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  ),
              rightTitles: const AxisTitles(
                  ),
            ),
            borderData: FlBorderData(show: false),
            scatterSpots: spots.map((s) {
              final moodIdx = s.y.round().clamp(1, 6);
              final mood = MoodType.values.firstWhere(
                (m) => m.numericValue == moodIdx,
                orElse: () => MoodType.neutral,
              );
              return ScatterSpot(s.x, s.y,
                  dotPainter: FlDotCirclePainter(
                    radius: 7,
                    color: mood.color.withValues(alpha: 0.8),
                    strokeWidth: 2,
                    strokeColor: mood.color,
                  ));
            }).toList(),
            scatterTouchData: ScatterTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}

class _ActivityContextChart extends StatelessWidget {
  final Map<String, _ActivityMood> data;
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _ActivityContextChart({
    required this.data,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.average.compareTo(a.value.average));

    final colors = [
      AppColors.primary,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ];

    return _ChartCard(
      title: isFilipino
          ? 'Mood ayon sa Aktibidad'
          : 'Mood by Activity Context',
      subtitle: isFilipino
          ? 'Average mood bawat uri ng aktibidad'
          : 'Average mood per activity type',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 6.5,
            minY: 0,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, _) {
                    final mood = MoodType.values
                        .where((m) => m.numericValue == value.toInt())
                        .firstOrNull;
                    if (mood == null) return const SizedBox();
                    return Text(mood.emoji, style: const TextStyle(fontSize: 14));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= sorted.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        MoodInsightsScreen._contextLabel(
                            sorted[idx].key, isFilipino),
                        style: AppTypography.labelSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  ),
              rightTitles: const AxisTitles(
                  ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final value = entry.value.value;
              return BarChartGroupData(
                x: idx,
                barRods: [
                  BarChartRodData(
                    toY: value.average,
                    color: colors[idx % colors.length],
                    width: 28,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIdx, rod, rodIdx) {
                  final entry = sorted[group.x.toInt()];
                  return BarTooltipItem(
                    '${entry.value.average.toStringAsFixed(1)}/6\n'
                    '(${entry.value.count} entries)',
                    AppTypography.labelSmall
                        .copyWith(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodDistribution extends StatelessWidget {
  final List<MoodEntry> entries;
  final bool isFilipino;
  final ColorScheme colorScheme;

  const _MoodDistribution({
    required this.entries,
    required this.isFilipino,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Count each mood type
    final counts = <MoodType, int>{};
    for (final e in entries) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
    }
    final total = entries.length;
    final sorted = MoodType.values
        .where((m) => (counts[m] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

    return _ChartCard(
      title: isFilipino
          ? 'Distribusyon ng Mood (30 Araw)'
          : 'Mood Distribution (30 Days)',
      subtitle: '$total ${isFilipino ? "entries" : "entries"}',
      child: Column(
        children: sorted.map((mood) {
          final count = counts[mood] ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 75,
                  child: Text(
                    isFilipino ? mood.labelFilipino : mood.label,
                    style: AppTypography.labelSmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 16,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest,
                      color: mood.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(pct * 100).round()}%',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hc = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.labelSmall.copyWith(
              color: hc.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
