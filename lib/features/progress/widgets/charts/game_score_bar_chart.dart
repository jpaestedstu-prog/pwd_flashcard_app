import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Grouped bar chart showing average score percentage per game type.
class GameScoreBarChart extends StatelessWidget {
  final List<GameScore> scores;

  const GameScoreBarChart({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Group scores by game type and compute average percentage
    final Map<GameType, List<double>> grouped = {};
    for (final s in scores) {
      if (s.total > 0) {
        grouped.putIfAbsent(s.gameType, () => []).add(s.score / s.total * 100);
      }
    }

    // Sort by enum index so bars appear in consistent order
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    final hc = HCColor.of(context);

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.softShadow,
        ),
        child: Center(
          child: Text(
            l10n.chartNoGameScores,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
        ),
      );
    }

    final barColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chartGamePerformanceTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartGamePerformanceSubtitle,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final gameType = entries[groupIndex].key;
                      return BarTooltipItem(
                        '${gameType.labelOf(l10n)}\n${rod.toY.round()}%',
                        AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
                        if (i < 0 || i >= entries.length) {
                          return const SizedBox();
                        }
                        final gameType = entries[i].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _shortLabel(l10n, gameType),
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 8,
                              color: hc.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: hc.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: entries.asMap().entries.map((e) {
                  final i = e.key;
                  final avg =
                      e.value.value.reduce((a, b) => a + b) /
                      e.value.value.length;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: avg,
                        color: barColors[i % barColors.length],
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact axis label for each game type, localized.
  String _shortLabel(AppLocalizations l10n, GameType type) {
    switch (type) {
      case GameType.wordMatch:
        return l10n.gameShortMatch;
      case GameType.spellingBee:
        return l10n.gameShortSpell;
      case GameType.flashcardQuiz:
        return l10n.gameShortQuiz;
      case GameType.memoryMatch:
        return l10n.gameShortMemory;
      case GameType.dragAndDrop:
        return l10n.gameShortDrag;
      case GameType.pronunciation:
        return l10n.gameShortPronun;
      case GameType.sentenceBuilder:
        return l10n.gameShortSentence;
      case GameType.storyQuiz:
        return l10n.gameShortStory;
      case GameType.tracing:
        return l10n.gameShortTrace;
      case GameType.fslPractice:
        return l10n.gameShortFsl;
      case GameType.jigsawPuzzle:
        return l10n.gameShortJigsaw;
      case GameType.pictureWord:
        return l10n.gameShortPicWord;
      case GameType.yesOrNo:
        return l10n.gameShortYesNo;
      case GameType.oddOneOut:
        return l10n.gameShortOdd;
      case GameType.firstLetter:
        return l10n.gameShortLetter;
    }
  }
}
