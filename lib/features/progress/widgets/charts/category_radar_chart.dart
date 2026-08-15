import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/enums.dart';
import '../../../../l10n/app_localizations.dart';

/// Radar chart showing mastery percentages across all 12 categories.
class CategoryRadarChart extends StatelessWidget {
  final Map<String, double> categoryProgress;

  const CategoryRadarChart({super.key, required this.categoryProgress});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const categories = FlashcardCategory.values;
    final values = categories
        .map((c) => categoryProgress[c.label] ?? 0.0)
        .toList();

    final hc = HCColor.of(context);

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
            l10n.chartCategoryMasteryTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartCategoryMasterySubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(
                    dataEntries: values
                        .map((v) => RadarEntry(value: v * 100))
                        .toList(),
                    fillColor: AppColors.primary.withValues(alpha: 0.2),
                    borderColor: AppColors.primary,
                    borderWidth: 2.5,
                    entryRadius: 4,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: AppTypography.labelSmall.copyWith(
                  fontSize: 9,
                  color: hc.textSecondary,
                ),
                getTitle: (index, angle) => RadarChartTitle(
                  text: _shortLabel(l10n, categories[index]),
                ),
                tickCount: 4,
                ticksTextStyle: AppTypography.labelSmall.copyWith(
                  fontSize: 8,
                  color: hc.textSecondary.withValues(alpha: 0.5),
                ),
                tickBorderData: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.3),
                ),
                gridBorderData: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact axis label, localized.
  ///
  /// These are deliberately shorter than `cat.label` — a radar axis has no
  /// room for "Family & Greetings" — so they are their own strings rather
  /// than a truncation of the category name.
  String _shortLabel(AppLocalizations l10n, FlashcardCategory cat) {
    return switch (cat) {
      FlashcardCategory.animals => l10n.catShortAnimals,
      FlashcardCategory.colorsAndShapes => l10n.catShortColors,
      FlashcardCategory.numbers => l10n.catShortNumbers,
      FlashcardCategory.bodyParts => l10n.catShortBody,
      FlashcardCategory.foodAndDrinks => l10n.catShortFood,
      FlashcardCategory.familyAndGreetings => l10n.catShortFamily,
      FlashcardCategory.clothing => l10n.catShortClothing,
      FlashcardCategory.weather => l10n.catShortWeather,
      FlashcardCategory.classroom => l10n.catShortClassroom,
      FlashcardCategory.transportation => l10n.catShortTransport,
      FlashcardCategory.emotions => l10n.catShortEmotions,
      FlashcardCategory.daysAndTime => l10n.catShortDays,
      FlashcardCategory.actions => l10n.catShortActions,
    };
  }
}
