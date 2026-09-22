import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../utils/localized_date.dart';

/// Types of certificates that can be generated.
enum CertificateType {
  categoryMastery,
  assessmentCompletion,
  streakMilestone,
  overallProgress,
}

extension CertificateTypeX on CertificateType {
  String get label => switch (this) {
    CertificateType.categoryMastery => 'Category Mastery',
    CertificateType.assessmentCompletion => 'Assessment Completion',
    CertificateType.streakMilestone => 'Streak Milestone',
    CertificateType.overallProgress => 'Overall Progress',
  };

  /// [label] in the certificate's language.
  String labelOf(AppLocalizations l10n) => switch (this) {
    CertificateType.categoryMastery => l10n.wrCategoryMastery,
    CertificateType.assessmentCompletion => l10n.ceTypeAssessment,
    CertificateType.streakMilestone => l10n.ceTypeStreak,
    CertificateType.overallProgress => l10n.ceTypeOverall,
  };

  String get emoji => switch (this) {
    CertificateType.categoryMastery => '🏆',
    CertificateType.assessmentCompletion => '📋',
    CertificateType.streakMilestone => '🔥',
    CertificateType.overallProgress => '⭐',
  };
}

/// Generates decorated PDF certificates for student achievements.
class CertificateService {
  CertificateService._();

  /// Generate a certificate PDF, worded in [l10n]'s language (English when
  /// none is given).
  static Future<Uint8List> generate({
    required CertificateType type,
    required String studentName,
    required String achievementTitle,
    required String achievementDetail,
    DateTime? date,
    AppLocalizations? l10n,
  }) async {
    final l = l10n ?? AppLocalizationsEn();
    final pdf = pw.Document();
    final certDate = date ?? DateTime.now();
    final dateStr = LocalizedDate.monthDayYear(certDate, l);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: _accentColor(type),
                width: 4,
              ),
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: _accentColor(type),
                ),
              ),
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // ─── Header ──────────────────────
                  pw.Text(
                    l.cePdfTitle,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: _accentColor(type),
                      letterSpacing: 3,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 120,
                    height: 2,
                    color: _accentColor(type),
                  ),
                  pw.SizedBox(height: 30),

                  // ─── Presented To ────────────────
                  pw.Text(
                    l.cePdfPresented,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    studentName,
                    style: pw.TextStyle(
                      fontSize: 36,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 250,
                    height: 1,
                    color: PdfColors.grey400,
                  ),
                  pw.SizedBox(height: 30),

                  // ─── Achievement ─────────────────
                  pw.Text(
                    l.cePdfFor(type.labelOf(l)),
                    style: const pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    achievementTitle,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _accentColor(type),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    achievementDetail,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 40),

                  // ─── Footer ──────────────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 150,
                            height: 1,
                            color: PdfColors.grey400,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            l.cePdfDate(dateStr),
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            width: 150,
                            height: 1,
                            color: PdfColors.grey400,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'FlashLearn PWD',
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static PdfColor _accentColor(CertificateType type) => switch (type) {
    CertificateType.categoryMastery => PdfColor.fromHex('#B39DDB'),
    CertificateType.assessmentCompletion => PdfColor.fromHex('#4FC3F7'),
    CertificateType.streakMilestone => PdfColor.fromHex('#FF7043'),
    CertificateType.overallProgress => PdfColor.fromHex('#FFD54F'),
  };

  /// Generate a category-mastery certificate.
  static Future<Uint8List> categoryMastery({
    required String studentName,
    required FlashcardCategory category,
    required int wordsLearned,
    required int totalWords,
    AppLocalizations? l10n,
  }) {
    final l = l10n ?? AppLocalizationsEn();
    final name = category.labelOf(l);
    return generate(
      type: CertificateType.categoryMastery,
      studentName: studentName,
      achievementTitle: l.ceCatTitle(name),
      achievementDetail: l.ceCatDetail(wordsLearned, totalWords, name),
      l10n: l,
    );
  }

  /// Generate a streak-milestone certificate.
  static Future<Uint8List> streakMilestone({
    required String studentName,
    required int streakDays,
    AppLocalizations? l10n,
  }) {
    final l = l10n ?? AppLocalizationsEn();
    return generate(
      type: CertificateType.streakMilestone,
      studentName: studentName,
      achievementTitle: l.ceStreakTitle(streakDays),
      achievementDetail: l.ceStreakDetail(streakDays),
      l10n: l,
    );
  }

  /// Generate an overall progress certificate.
  static Future<Uint8List> overallProgress({
    required String studentName,
    required int totalWords,
    required int totalStars,
    required int streakDays,
    AppLocalizations? l10n,
  }) {
    final l = l10n ?? AppLocalizationsEn();
    return generate(
      type: CertificateType.overallProgress,
      studentName: studentName,
      achievementTitle: l.certExcellence,
      achievementDetail: l.ceOverallDetail(totalWords, totalStars, streakDays),
      l10n: l,
    );
  }
}
