import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/localized_date.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../models/showcase_models.dart';
import '../providers/showcase_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/utils/pdf_theme.dart';

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
        leading: const AppBackButton(fallbackRoute: '/progress'),
        title: Text(
          _t(context).scSharePortfolio,
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
                    _t(context).scPdfTitle,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(context).scItemsFor(
                      portfolio.items.length,
                      profile?.name ?? _t(context).playerFallbackName,
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(context).scShareHint,
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
              build: (_) => generatePortfolioPdf(
                profileName:
                    profile?.name ?? _t(context).playerFallbackName,
                l10n: _t(context),
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

  /// The language of the portfolio PDF being built, set at the top of
  /// [generatePortfolioPdf] from the app's language.
  static AppLocalizations _l = AppLocalizationsEn();

  @visibleForTesting
  static Future<Uint8List> generatePortfolioPdf({
    required String profileName,
    required ShowcasePortfolio portfolio,
    required int totalStars,
    required int wordsLearned,
    required int streakDays,
    required AppLocalizations l10n,
  }) async {
    _l = l10n;
    final pdf = pw.Document(theme: await PdfTheme.unicode());
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
                    _l.pfTitle(profileName),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _l.wrGeneratedOn(_fmtDate(now)),
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
            _l.prPageOf(context.pageNumber, context.pagesCount),
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),

          // ─── Stats Overview ──────────────────
          _sectionTitle(_l.pfOverview, headerColor),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox(_l.wrTotalStars, '$totalStars', accentColor),
              _statBox(_l.wrWordsLearned, '$wordsLearned', headerColor),
              _statBox(_l.pfDayStreak, '$streakDays', PdfColor.fromHex('#FF5722')),
              _statBox(_l.pfItems, '${portfolio.items.length}', PdfColor.fromHex('#4CAF50')),
            ],
          ),
          pw.SizedBox(height: 20),

          // ─── Pinned Highlights ────────────────
          if (portfolio.items.any((i) => i.isPinned)) ...[
            _sectionTitle(_l.pfPinned, accentColor),
            pw.SizedBox(height: 10),
            ...portfolio.sortedItems
                .where((i) => i.isPinned)
                .map((item) => _itemRow(item)),
            pw.SizedBox(height: 20),
          ],

          // ─── All Portfolio Items ──────────────
          _sectionTitle(_l.pfAllItems, headerColor),
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
                  _tableHeader(_l.pfType),
                  _tableHeader(_l.pfItemTitle),
                  _tableHeader(_l.pfDescription),
                  _tableHeader(_l.wrDate),
                ],
              ),
              ...portfolio.sortedItems.map((item) => pw.TableRow(
                    children: [
                      _tableCell(item.type.labelOf(_l)),
                      _tableCell(item.title),
                      _tableCell(item.description),
                      _tableCell(_fmtDate(item.earnedAt)),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 20),

          // ─── Summary by Type ──────────────────
          _sectionTitle(_l.pfSummaryByType, headerColor),
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
                  pw.Text('${e.key.labelOf(_l)}: ${e.value}',
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
                '${item.type.labelOf(_l)}: ',
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

  static String _fmtDate(DateTime d) => LocalizedDate.monthDayYear(d, _l);

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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
