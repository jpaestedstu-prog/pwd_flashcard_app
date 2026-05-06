import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../models/showcase_models.dart';
import '../providers/showcase_provider.dart';

/// Screen that generates and previews a PDF portfolio summary for sharing
class ShowcaseShareScreen extends ConsumerWidget {
  const ShowcaseShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(showcaseProvider);
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final hc = HCColor.of(context);

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
          'Share Portfolio',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  const Text('📤', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Portfolio Summary PDF',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${portfolio.items.length} items • ${profile?.name ?? "Learner"}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share with your teacher or parent to show your progress!',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) => _generatePortfolioPdf(
                profileName: profile?.name ?? 'Learner',
                portfolio: portfolio,
                totalStars: progress.totalStars,
                wordsLearned: progress.wordsLearned,
                streakDays: progress.streakDays,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName:
                  '${profile?.name ?? "learner"}_portfolio.pdf',
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> _generatePortfolioPdf({
    required String profileName,
    required ShowcasePortfolio portfolio,
    required int totalStars,
    required int wordsLearned,
    required int streakDays,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final headerColor = PdfColor.fromHex('#7C4DFF');
    final accentColor = PdfColor.fromHex('#E040FB');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: headerColor,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$profileName\'s Learning Portfolio',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on ${_fmtDate(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'FlashLearn PWD',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),

          // ─── Stats Overview ──────────────────
          _sectionTitle('Overview', headerColor),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox('Total Stars', '$totalStars', accentColor),
              _statBox('Words Learned', '$wordsLearned', headerColor),
              _statBox('Day Streak', '$streakDays', PdfColor.fromHex('#FF5722')),
              _statBox('Portfolio Items', '${portfolio.items.length}', PdfColor.fromHex('#4CAF50')),
            ],
          ),
          pw.SizedBox(height: 20),

          // ─── Pinned Highlights ────────────────
          if (portfolio.items.any((i) => i.isPinned)) ...[
            _sectionTitle('Pinned Highlights', accentColor),
            pw.SizedBox(height: 10),
            ...portfolio.sortedItems
                .where((i) => i.isPinned)
                .map((item) => _itemRow(item)),
            pw.SizedBox(height: 20),
          ],

          // ─── All Portfolio Items ──────────────
          _sectionTitle('All Portfolio Items', headerColor),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerColor),
                children: [
                  _tableHeader('Type'),
                  _tableHeader('Title'),
                  _tableHeader('Description'),
                  _tableHeader('Date'),
                ],
              ),
              ...portfolio.sortedItems.map((item) => pw.TableRow(
                    children: [
                      _tableCell(item.type.label),
                      _tableCell(item.title),
                      _tableCell(item.description),
                      _tableCell(_fmtDate(item.earnedAt)),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 20),

          // ─── Summary by Type ──────────────────
          _sectionTitle('Summary by Type', headerColor),
          pw.SizedBox(height: 10),
          ...portfolio.typeCounts.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex(
                          _typeColorHex(e.key)),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('${e.key.label}: ${e.value}',
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _statBox(
      String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemRow(ShowcaseItem item) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '${item.type.label}: ',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(
                child: pw.Text(item.title,
                    style: const pw.TextStyle(fontSize: 11)),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(item.description,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        maxLines: 3,
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _typeColorHex(ShowcaseItemType type) => switch (type) {
    ShowcaseItemType.achievement => '#FFD700',
    ShowcaseItemType.highScore => '#FF9800',
    ShowcaseItemType.categoryMastery => '#4CAF50',
    ShowcaseItemType.learningPathComplete => '#7E57C2',
    ShowcaseItemType.streakMilestone => '#F44336',
    ShowcaseItemType.assessmentResult => '#00ACC1',
    ShowcaseItemType.customNote => '#78909C',
  };
}
