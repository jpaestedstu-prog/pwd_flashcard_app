import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/enums.dart';

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

  /// Generate a certificate PDF.
  static Future<Uint8List> generate({
    required CertificateType type,
    required String studentName,
    required String achievementTitle,
    required String achievementDetail,
    DateTime? date,
  }) async {
    final pdf = pw.Document();
    final certDate = date ?? DateTime.now();
    final dateStr =
        '${certDate.month}/${certDate.day}/${certDate.year}';

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
                    'CERTIFICATE OF ACHIEVEMENT',
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
                    'This certificate is proudly presented to',
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
                    'For ${type.label}',
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
                            'Date: $dateStr',
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
  }) {
    return generate(
      type: CertificateType.categoryMastery,
      studentName: studentName,
      achievementTitle: '${category.label} Category Mastery',
      achievementDetail:
          'Successfully learned $wordsLearned out of $totalWords words '
          'in the ${category.label} vocabulary category.',
    );
  }

  /// Generate a streak-milestone certificate.
  static Future<Uint8List> streakMilestone({
    required String studentName,
    required int streakDays,
  }) {
    return generate(
      type: CertificateType.streakMilestone,
      studentName: studentName,
      achievementTitle: '$streakDays-Day Learning Streak',
      achievementDetail:
          'Demonstrated outstanding dedication by maintaining '
          'a $streakDays-day consecutive study streak.',
    );
  }

  /// Generate an overall progress certificate.
  static Future<Uint8List> overallProgress({
    required String studentName,
    required int totalWords,
    required int totalStars,
    required int streakDays,
  }) {
    return generate(
      type: CertificateType.overallProgress,
      studentName: studentName,
      achievementTitle: 'Learning Excellence',
      achievementDetail:
          'Learned $totalWords words, earned $totalStars stars, '
          'and maintained a $streakDays-day streak.',
    );
  }
}
