import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../data/models/enums.dart';

import '../../../providers/parent_provider.dart';

/// Generates a professional PDF weekly progress report for a child.
class ReportGenerator {
  ReportGenerator._();

  /// Load NotoSans fonts that support Unicode.
  ///
  /// Returns `null` when the font assets cannot be loaded (e.g. a stripped
  /// build or an OEM that fails the asset read) so that report generation
  /// still succeeds with the bundled Helvetica fallback rather than throwing
  /// and breaking the whole Preview / Share flow.
  static Future<pw.ThemeData?> _loadTheme() async {
    try {
      final regularData =
          await rootBundle.load('google_fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('google_fonts/NotoSans-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      return null;
    }
  }

  /// Generate a full weekly progress report PDF for one child.
  static Future<Uint8List> generateWeeklyReport(ChildSummary child) async {
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final headerColor = PdfColor.fromHex('#B39DDB');
    final accentColor = PdfColor.fromHex('#80CBC4');
    final warningColor = PdfColor.fromHex('#FFD54F');
    final successColor = PdfColor.fromHex('#81C784');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(child, weekStart, weekEnd, headerColor),
        footer: (context) => _buildFooter(context, now),
        build: (context) => [
          pw.SizedBox(height: 20),

          // ─── Overview Stats ─────────────────────
          _buildSectionTitle('Weekly Overview', headerColor),
          pw.SizedBox(height: 10),
          _buildStatsGrid(child, accentColor, warningColor, successColor),
          pw.SizedBox(height: 20),

          // ─── Study Time Breakdown ───────────────
          _buildSectionTitle('Daily Study Time', headerColor),
          pw.SizedBox(height: 10),
          _buildStudyTimeTable(child),
          pw.SizedBox(height: 20),

          // ─── Category Progress ──────────────────
          _buildSectionTitle('Category Mastery', headerColor),
          pw.SizedBox(height: 10),
          _buildCategoryTable(child),
          pw.SizedBox(height: 20),

          // ─── Recent Game Scores ─────────────────
          _buildSectionTitle('Recent Game Scores', headerColor),
          pw.SizedBox(height: 10),
          _buildGameScoresTable(child),
          pw.SizedBox(height: 20),

          // ─── Strengths & Areas to Improve ───────
          _buildSectionTitle('Insights & Recommendations', headerColor),
          pw.SizedBox(height: 10),
          _buildInsights(child, successColor, warningColor),
          pw.SizedBox(height: 20),

          // ─── Week over Week Trend ───────────────
          _buildSectionTitle('Week-over-Week Trend', headerColor),
          pw.SizedBox(height: 10),
          _buildWeekTrend(child, accentColor),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate a multi-child family summary PDF.
  static Future<Uint8List> generateFamilyReport(
      List<ChildSummary> children) async {
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    final now = DateTime.now();
    final headerColor = PdfColor.fromHex('#B39DDB');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: headerColor,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Family Progress Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on ${_formatDate(now)}',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => _buildFooter(context, now),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (int i = 0; i < children.length; i++) {
            final child = children[i];
            if (i > 0) widgets.add(pw.SizedBox(height: 30));
            widgets.addAll([
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F5F0FF'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: headerColor),
                ),
                child: pw.Text(
                  child.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              _buildCompactStats(child),
              pw.SizedBox(height: 10),
              _buildCategoryTable(child),
            ]);
          }
          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // ─── Header & Footer ─────────────────────────────────

  static pw.Widget _buildHeader(
    ChildSummary child,
    DateTime weekStart,
    DateTime weekEnd,
    PdfColor headerColor,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: headerColor,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Weekly Progress Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  child.name,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '${child.streakDays}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('day streak', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, DateTime now) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Generated by MagAral - Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  // ─── Stats Grid ──────────────────────────────────────

  static pw.Widget _buildStatsGrid(
    ChildSummary child,
    PdfColor accent,
    PdfColor warning,
    PdfColor success,
  ) {
    return pw.Row(
      children: [
        _statBox('${child.totalStars}', 'Total Stars', warning),
        pw.SizedBox(width: 8),
        _statBox('${child.wordsLearned}', 'Words Learned', accent),
        pw.SizedBox(width: 8),
        _statBox('${child.gamesPlayed}', 'Games Played', success),
        pw.SizedBox(width: 8),
        _statBox(
          '${child.studyMinutesThisWeek}m',
          'Study Time',
          PdfColor.fromHex('#64B5F6'),
        ),
      ],
    );
  }

  static pw.Widget _statBox(
    String value,
    String label,
    PdfColor color,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#FAFAFA'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 1.5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCompactStats(ChildSummary child) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('${child.totalStars} stars'),
        pw.Text('${child.wordsLearned} words'),
        pw.Text('${child.gamesPlayed} games'),
        pw.Text('${child.studyMinutesThisWeek}m this week'),
        pw.Text('${(child.averageAccuracy * 100).toStringAsFixed(0)}% accuracy'),
      ],
    );
  }

  // ─── Study Time Table ────────────────────────────────

  static pw.Widget _buildStudyTimeTable(ChildSummary child) {
    final days = child.dailyStudyMinutes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F0FF')),
          children: [
            _tableHeader('Date'),
            _tableHeader('Minutes'),
            _tableHeader('Visual'),
          ],
        ),
        ...days.map((entry) {
          final maxMinutes = days.map((e) => e.value).fold(1, (a, b) => a > b ? a : b);
          final barWidth = entry.value > 0 ? (entry.value / maxMinutes) * 150 : 0.0;
          return pw.TableRow(
            children: [
              _tableCell(_formatDateKey(entry.key)),
              _tableCell('${entry.value}'),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Container(
                  width: barWidth,
                  height: 12,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#80CBC4'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─── Category Progress ───────────────────────────────

  static pw.Widget _buildCategoryTable(ChildSummary child) {
    const categories = FlashcardCategory.values;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(),
        2: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F0FF')),
          children: [
            _tableHeader('Category'),
            _tableHeader('Progress'),
            _tableHeader('Mastery Bar'),
          ],
        ),
        ...categories.map((cat) {
          final progress = child.categoryProgress[cat.label] ?? 0.0;
          final percentage = (progress * 100).toStringAsFixed(0);
          final barWidth = progress * 150;
          final barColor = progress >= 0.8
              ? PdfColor.fromHex('#81C784')
              : progress >= 0.5
                  ? PdfColor.fromHex('#FFD54F')
                  : PdfColor.fromHex('#E57373');

          return pw.TableRow(
            children: [
              _tableCell(cat.label),
              _tableCell('$percentage%'),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Stack(
                  children: [
                    pw.Container(
                      width: 150,
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                    pw.Container(
                      width: barWidth,
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: barColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─── Game Scores Table ───────────────────────────────

  static pw.Widget _buildGameScoresTable(ChildSummary child) {
    final scores = child.recentScores.take(10).toList();
    if (scores.isEmpty) {
      return pw.Text(
        'No recent game scores this week.',
        style: const pw.TextStyle(color: PdfColors.grey500),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(),
        3: const pw.FlexColumnWidth(),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F0FF')),
          children: [
            _tableHeader('Game'),
            _tableHeader('Date'),
            _tableHeader('Score'),
            _tableHeader('Stars'),
            _tableHeader('Duration'),
          ],
        ),
        ...scores.map((s) {
          return pw.TableRow(
            children: [
              _tableCell(s.gameType.label),
              _tableCell(_formatDate(s.date)),
              _tableCell('${s.score}/${s.total}'),
              _tableCell('${s.starsEarned}/3'),
              _tableCell(s.durationSeconds != null
                  ? '${(s.durationSeconds! / 60).toStringAsFixed(1)}m'
                  : '-'),
            ],
          );
        }),
      ],
    );
  }

  // ─── Insights ────────────────────────────────────────

  static pw.Widget _buildInsights(
    ChildSummary child,
    PdfColor success,
    PdfColor warning,
  ) {
    final insights = <pw.Widget>[];

    // Strongest category
    if (child.strongestCategory != null) {
      insights.add(_insightRow(
        'Strongest area: ${child.strongestCategory}',
        'Keep up the excellent work in this category!',
        success,
      ));
    }

    // Weakest category
    if (child.weakestCategory != null) {
      insights.add(_insightRow(
        'Needs practice: ${child.weakestCategory}',
        'Focus on this category for improvement.',
        warning,
      ));
    }

    // Unexplored categories
    if (child.unexploredCategories.isNotEmpty) {
      insights.add(_insightRow(
        'Not yet explored: ${child.unexploredCategories.take(3).join(", ")}',
        'Try introducing these categories this week.',
        PdfColor.fromHex('#64B5F6'),
      ));
    }

    // Accuracy
    if (child.averageAccuracy >= 0.8) {
      insights.add(_insightRow(
        'Accuracy: ${(child.averageAccuracy * 100).toStringAsFixed(0)}%',
        'Outstanding accuracy! Consider increasing difficulty.',
        success,
      ));
    } else if (child.averageAccuracy < 0.5 && child.gamesPlayed > 0) {
      insights.add(_insightRow(
        'Accuracy: ${(child.averageAccuracy * 100).toStringAsFixed(0)}%',
        'Extra review sessions may help improve scores.',
        warning,
      ));
    }

    // Session frequency
    if (child.totalSessions < 3) {
      insights.add(_insightRow(
        'Low session count: ${child.totalSessions} sessions this month',
        'Try to have at least 3-4 learning sessions per week.',
        warning,
      ));
    }

    // Mastered categories count
    if (child.masteredCategories > 0) {
      insights.add(_insightRow(
        '${child.masteredCategories} categories mastered (>=80%)',
        'Great progress! ${12 - child.masteredCategories} more to go.',
        success,
      ));
    }

    if (insights.isEmpty) {
      insights.add(pw.Text('Start learning to see personalized insights!'));
    }

    return pw.Column(children: insights);
  }

  static pw.Widget _insightRow(
    String title,
    String subtitle,
    PdfColor sideColor,
  ) {
    // NOTE: the `pdf` package forbids combining a non-uniform border (e.g.
    // a left-only accent) with a borderRadius, and a stretch-aligned Row
    // explodes under MultiPage's unbounded height. A rounded card with a
    // uniform accent-coloured border keeps the design intent while being
    // safe to render on every page layout.
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: sideColor, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Week-over-Week Trend ────────────────────────────

  static pw.Widget _buildWeekTrend(ChildSummary child, PdfColor accent) {
    final change = child.weekOverWeekChange;
    final isUp = change >= 0;
    final arrow = isUp ? '+' : '-';
    final color = isUp ? PdfColor.fromHex('#81C784') : PdfColor.fromHex('#E57373');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: accent),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            '$arrow ${change.abs().toStringAsFixed(0)}%',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isUp
                      ? 'Study time increased compared to last week!'
                      : 'Study time decreased compared to last week.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'This week: ${child.studyMinutesThisWeek}min | Last week: ${child.studyMinutesLastWeek}min',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Title Helper ────────────────────────────

  static pw.Widget _buildSectionTitle(String text, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ─── Table Helpers ───────────────────────────────────

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // ─── Date Formatting ─────────────────────────────────

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatDateKey(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[date.weekday - 1]}, ${_formatDate(date)}';
    } catch (_) {
      return dateKey;
    }
  }
}
