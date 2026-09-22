import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import 'localized_date.dart';
import '../../data/models/enums.dart';
import '../../data/models/achievements.dart';
import '../../data/local/hive_service.dart';
import '../../data/local/spaced_repetition_service.dart';
import '../../features/progress/models/category_mastery.dart';

/// Generates a shareable PDF progress report for teacher/parent use.
class ReportGenerator {
  const ReportGenerator._();

  /// The language of the report being built, set at the top of
  /// [generateAndShare]. The report follows the app's language; without an
  /// [AppLocalizations] it stays English.
  static AppLocalizations _l = AppLocalizationsEn();

  /// Load NotoSans fonts that support Unicode.
  static Future<pw.ThemeData> _loadTheme() async {
    final regularData = await rootBundle.load('google_fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('google_fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  /// Build and share/print the PDF report.
  static Future<void> generateAndShare({
    required UserProfile profile,
    required LearningProgress progress,
    required List<Flashcard> allCards,
    AppLocalizations? l10n,
  }) async {
    _l = l10n ?? AppLocalizationsEn();
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);

    final totalWords = allCards.length;
    final masteredWords = progress.wordsLearned;
    final masteryPct = totalWords > 0
        ? (masteredWords / totalWords * 100).round()
        : 0;
    final streak = progress.streakDays;
    final totalStars = progress.totalStars;

    // Achievements — the stored record union the live check, so the report a
    // parent or teacher receives counts the same badges the learner sees on
    // their Progress tab.
    final unlockedIds = Achievements.durableUnlockedIds(
      progress: progress,
      previouslyUnlockedIds: HiveService.getUnlockedAchievements(
        progress.profileId,
      ),
    );
    final totalAchievements = Achievements.all.length;
    final unlockedCount = unlockedIds.length;

    // Category data — share of each category's words actually learned.
    //
    // This used to report `categoryProgress`, a rolling accuracy average, under
    // a heading that reads as completion; a parent saw "Colors & Shapes 83%"
    // for a child who had met three of its thirteen words, and the "lowest
    // progress" recommendation below pointed at the wrong category as a result.
    final mastery = CategoryMastery.forProgress(progress, allCards);
    final categories = FlashcardCategory.values.map((cat) {
      final coverage = mastery[cat]?.coverage ?? 0.0;
      return (cat.labelOf(_l), (coverage * 100).round());
    }).toList();

    // Recent game scores
    final recentScores = progress.recentScores;

    // Weak words from spaced repetition
    final weakWords = SpacedRepetitionService.getWeakWords(
      profileId: profile.id,
      allCards: allCards,
    );
    final srSummary = SpacedRepetitionService.getSummary(profile.id);

    // Colors for PDF
    const primary = PdfColor.fromInt(0xFF6C63FF);
    const success = PdfColor.fromInt(0xFF4CAF50);
    const warning = PdfColor.fromInt(0xFFFF9800);
    const error = PdfColor.fromInt(0xFFF44336);
    const grey = PdfColor.fromInt(0xFF757575);
    const lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(profile, primary),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Title ──
          pw.SizedBox(height: 8),
          pw.Text(
            _l.prTitle,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _l.wrGeneratedOn(LocalizedDate.monthDayYear(DateTime.now(), _l)),
            style: const pw.TextStyle(fontSize: 10, color: grey),
          ),
          pw.Divider(color: primary, thickness: 1.5),
          pw.SizedBox(height: 16),

          // ── Key Metrics ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _metricBox(
                _l.prWordsLearned,
                '$masteredWords',
                subtitle: _l.prOfTotal(totalWords),
              ),
              _metricBox(_l.mastery, '$masteryPct%'),
              _metricBox(_l.stars, '$totalStars'),
              _metricBox(_l.streak, _l.prStreakDays(streak)),
              _metricBox(_l.badges, '$unlockedCount/$totalAchievements'),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Category Breakdown ──
          pw.Text(
            _l.prCategoryBreakdown,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 8),
          ...categories.map(
            (cat) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(
                      cat.$1,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Stack(
                      children: [
                        pw.Container(
                          height: 14,
                          decoration: pw.BoxDecoration(
                            color: lightGrey,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                        pw.Container(
                          height: 14,
                          width: (cat.$2 / 100) * 280,
                          decoration: pw.BoxDecoration(
                            color: cat.$2 >= 70
                                ? success
                                : cat.$2 >= 40
                                ? warning
                                : error,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '${cat.$2}%',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Spaced Repetition Insights ──
          pw.Text(
            _l.prLearningAnalysis,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _miniStat(_l.prTotalAttempts, '${srSummary.totalAttempted}'),
                _miniStat(_l.sumCorrect, '${srSummary.totalCorrect}'),
                _miniStat(_l.prStruggling, '${srSummary.wordsStruggling}'),
                _miniStat(
                  _l.prOverallAccuracy,
                  srSummary.totalAttempted > 0
                      ? '${(srSummary.totalCorrect / srSummary.totalAttempted * 100).round()}%'
                      : _l.prNotAvailable,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Weak words table
          if (weakWords.isNotEmpty) ...[
            pw.Text(
              _l.prNeedPractice,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              headers: [
                _l.prWordEn,
                _l.prWordFil,
                _l.wrCategory,
                _l.accuracy,
                _l.prAttempts,
              ],
              data: weakWords.take(10).map((item) {
                final card = item.$1;
                final wa = item.$2;
                return [
                  card.wordEnglish,
                  card.wordFilipino,
                  card.category.labelOf(_l),
                  '${(wa.accuracy * 100).round()}%',
                  '${wa.total}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Recent Activity ──
          if (recentScores.isNotEmpty) ...[
            pw.Text(
              _l.prRecentActivity,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              headers: [_l.wrGame, _l.wrScore, _l.prPercentage, _l.stars, _l.wrDate],
              data: recentScores.reversed.take(10).map((s) {
                final pct = s.total > 0 ? (s.score / s.total * 100).round() : 0;
                return [
                  s.gameType.labelOf(_l),
                  '${s.score}/${s.total}',
                  '$pct%',
                  '${s.starsEarned}/3',
                  s.date.toString().split(' ').first,
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Recommendations ──
          pw.Text(
            _l.recommendations,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 8),
          ..._buildRecommendations(categories, streak, weakWords.length),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name:
          'FlashLearn_Report_${profile.name}_${DateTime.now().toString().split(' ').first}',
    );
  }

  static pw.Widget _buildHeader(UserProfile profile, PdfColor primary) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 36,
              height: 36,
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'FL',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FlashLearn PWD',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.Text(
                  _l.prTagline,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF757575),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              profile.name,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              profile.role.labelOf(_l),
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF757575),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          _l.prFooter,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColor.fromInt(0xFF9E9E9E),
          ),
        ),
        pw.Text(
          _l.prPageOf(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColor.fromInt(0xFF9E9E9E),
          ),
        ),
      ],
    );
  }

  static pw.Widget _metricBox(String label, String value, {String? subtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F5F5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF6C63FF),
            ),
          ),
          if (subtitle != null)
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF9E9E9E),
              ),
            ),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColor.fromInt(0xFF757575),
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildRecommendations(
    List<(String, int)> categories,
    int streak,
    int weakCount,
  ) {
    final recs = <pw.Widget>[];

    // Sort weakest first
    final sorted = List.of(categories)..sort((a, b) => a.$2.compareTo(b.$2));

    if (sorted.isNotEmpty && sorted.first.$2 < 50) {
      recs.add(
        _recommendation(
          _l.prFocusOn(sorted.first.$1),
          _l.prFocusOnBody(sorted.first.$2),
        ),
      );
    }

    if (weakCount > 3) {
      recs.add(
        _recommendation(
          _l.prSmartReview,
          _l.prSmartReviewBody(weakCount),
        ),
      );
    }

    if (streak < 3) {
      recs.add(
        _recommendation(
          _l.prHabit,
          _l.prHabitBody(streak),
        ),
      );
    } else {
      recs.add(
        _recommendation(
          _l.prConsistency,
          _l.prConsistencyBody(streak),
        ),
      );
    }

    if (sorted.isNotEmpty && sorted.last.$2 >= 70) {
      recs.add(
        _recommendation(
          _l.prHarder,
          _l.prHarderBody(sorted.last.$1, sorted.last.$2),
        ),
      );
    }

    return recs;
  }

  static pw.Widget _recommendation(String title, String body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E0E0)),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(body, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
