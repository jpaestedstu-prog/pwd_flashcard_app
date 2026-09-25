import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/accessibility/learner_support.dart';
import '../../../core/utils/localized_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../routine/widgets/routine_media.dart';
import '../models/assessment_media.dart';
import '../models/learner_portfolio.dart';
import '../models/question_prompt.dart';
import 'assessment_media_cache.dart';
import 'assessment_service.dart';

/// A learner's portfolio as a PDF a parent can keep: the summary, every test
/// with its score, and the educator's feedback with its pictures.
///
/// Paper cannot play a video or a sound, so those are named ("Also attached:
/// FSL video, sound") with a line sending the reader to the app, rather
/// than left out without a word. Pictures are embedded when this device can
/// reach them; one it cannot is skipped, never a failed PDF.
class PortfolioPdf {
  const PortfolioPdf._();

  /// The widest a picture is drawn, in PDF points (A4 is 595 wide).
  static const double pictureWidth = 220;

  /// Replaces the picture loader in tests: bytes for a stored value, or null.
  static Future<Uint8List?> Function(String value)? debugLoadPicture;

  /// Replaces the font loader in tests, where the bundled fonts may be absent.
  static Future<pw.ThemeData?> Function()? debugTheme;

  static Future<Uint8List> build(
    LearnerPortfolio portfolio, {
    required String learnerName,
    required AppLocalizations l10n,
    DateTime? now,
  }) async {
    final made = now ?? DateTime.now();
    final theme = await (debugTheme ?? _loadTheme)();
    // Without the bundled font the PDF falls back to Helvetica, which has no
    // curly quotes or dashes — they would print as boxes. The bundled font
    // has those, but no emoji or arrows, which a note often carries.
    final text = theme == null ? _latin1Safe : _fontSafe;

    final pictures = <String, pw.ImageProvider>{};
    for (final entry in portfolio.entries) {
      for (final value in _pictureValues(entry)) {
        if (pictures.containsKey(value)) continue;
        final image = await _picture(value);
        if (image != null) pictures[value] = image;
      }
    }

    const ink = PdfColor.fromInt(0xFF212121);
    const muted = PdfColor.fromInt(0xFF5F6368);
    const brand = PdfColor.fromInt(0xFF4527A0);
    const soft = PdfColor.fromInt(0xFFEDE7F6);

    pw.Widget section(String title) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text(title),
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: brand,
        ),
      ),
    );

    pw.Widget stat(String value, String label) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: soft, width: 1.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              text(value),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: brand,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              text(label),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        ),
      ),
    );

    pw.Widget cell(String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text(value),
        style: pw.TextStyle(
          fontSize: 10,
          color: ink,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    final average = portfolio.averageScore;
    final results = portfolio.results;
    final feedbackEntries = [
      for (final e in portfolio.entries)
        if (!e.isResult) e,
    ];

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            text(l10n.wrFooter(context.pageNumber, context.pagesCount)),
            style: const pw.TextStyle(fontSize: 9, color: muted),
          ),
        ),
        build: (context) => [
          // ─── Header ─────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: brand,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  text(l10n.portfolioPdfTitle),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  text(l10n.portfolioPdfLearner(learnerName)),
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  text(
                    l10n.portfolioPdfMade(
                      LocalizedDate.monthDayYearLong(made, l10n),
                    ),
                  ),
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),

          // ─── Summary ────────────────────────────────
          section(l10n.portfolioPdfSummary),
          pw.Row(
            children: [
              stat('${portfolio.testsTaken}', l10n.portfolioTestsTaken),
              stat(
                average == null ? '-' : '${(average * 100).round()}%',
                l10n.portfolioAverage,
              ),
              stat('${portfolio.videoAnswers}', l10n.portfolioVideoAnswers),
              stat('${portfolio.feedbackCount}', l10n.portfolioFeedback),
            ],
          ),
          if (portfolio.gain != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              text(portfolio.gain!.summaryOf(l10n)),
              style: pw.TextStyle(
                fontSize: 11,
                color: ink,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],

          // ─── Tests ──────────────────────────────────
          if (results.isNotEmpty) ...[
            section(l10n.portfolioPdfTests),
            pw.Table(
              border: pw.TableBorder.all(color: soft),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(4),
                2: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: soft),
                  children: [
                    cell(l10n.portfolioPdfDate, bold: true),
                    cell(l10n.portfolioPdfTest, bold: true),
                    cell(l10n.portfolioPdfScore, bold: true),
                  ],
                ),
                for (final e in results)
                  pw.TableRow(
                    children: [
                      cell(LocalizedDate.monthDayYear(e.at, l10n)),
                      cell(_testLine(e, l10n)),
                      cell(_scoreLine(e, l10n)),
                    ],
                  ),
              ],
            ),
            // How each video answer was marked, under its test.
            for (final e in results)
              if (e.feedback != null && e.feedback!.reviews.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  text('${e.titleOf(l10n)} - ${l10n.portfolioVideoAnswers}'),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                for (final mark in e.feedback!.reviews.entries)
                  pw.Bullet(
                    text: text(
                      '${_questionText(e.result!.assessmentId, mark.key, l10n)}: '
                      '${mark.value ? l10n.assessReviewedCorrect : l10n.assessReviewedNotYet}',
                    ),
                    style: const pw.TextStyle(fontSize: 10, color: ink),
                  ),
              ],
          ],

          // ─── Feedback ───────────────────────────────
          if (feedbackEntries.isNotEmpty) ...[
            section(l10n.portfolioPdfFeedback),
            for (final e in feedbackEntries)
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: soft, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      text(l10n.assessFeedbackOn(e.titleOf(l10n))),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    pw.Text(
                      text(LocalizedDate.monthDayYear(e.at, l10n)),
                      style: const pw.TextStyle(fontSize: 9, color: muted),
                    ),
                    if (e.feedback!.note.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        text(e.feedback!.note.trim()),
                        style: const pw.TextStyle(fontSize: 11, color: ink),
                      ),
                    ],
                    ..._mediaBlock(e.feedback!.media, pictures, l10n, text),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// "Animals quiz · Supports: Extra time".
  static String _testLine(PortfolioEntry e, AppLocalizations l10n) {
    final supports = e.result!.accommodations;
    if (supports.isEmpty) return e.titleOf(l10n);
    return '${e.titleOf(l10n)}\n${l10n.portfolioSupports(supports.map((s) => s.labelOf(l10n)).join(', '))}';
  }

  /// "80%", "80% · 1 answer to review", or "Waiting for review".
  static String _scoreLine(PortfolioEntry e, AppLocalizations l10n) {
    final s = e.score!;
    final fraction = e.fraction;
    return [
      if (fraction != null) '${(fraction * 100).round()}%',
      if (s.pending > 0)
        fraction == null ? l10n.portfolioPdfWaiting : l10n.assessToReview(s.pending),
    ].join('\n');
  }

  static String _questionText(
    String assessmentId,
    String questionId,
    AppLocalizations l10n,
  ) {
    try {
      final assessment = AssessmentService.findAssessmentById(assessmentId);
      for (final q in assessment?.questions ?? const []) {
        if (q.id == questionId) {
          return QuestionPrompt.localize(q.questionText, l10n);
        }
      }
    } catch (_) {
      // The box may be closed (tests) — the generic label is still true.
    }
    return l10n.assessYourVideoAnswer;
  }

  /// The pictures of an entry's feedback: a photo, and a GIF's first frame.
  static Iterable<String> _pictureValues(PortfolioEntry e) {
    final media = e.isResult ? null : e.feedback?.media;
    if (media == null) return const [];
    return [
      for (final kind in const [AssessmentMediaKind.photo, AssessmentMediaKind.gif])
        if (media.has(kind)) media.urlFor(kind).trim(),
    ];
  }

  static List<pw.Widget> _mediaBlock(
    AssessmentMedia media,
    Map<String, pw.ImageProvider> pictures,
    AppLocalizations l10n,
    String Function(String) text,
  ) {
    final drawn = <AssessmentMediaKind>{};
    final images = <pw.Widget>[];
    for (final kind in const [AssessmentMediaKind.photo, AssessmentMediaKind.gif]) {
      final image = media.has(kind) ? pictures[media.urlFor(kind).trim()] : null;
      if (image == null) continue;
      drawn.add(kind);
      images.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8, right: 8),
          constraints: const pw.BoxConstraints(
            maxWidth: pictureWidth,
            maxHeight: 180,
          ),
          child: pw.Image(image),
        ),
      );
    }
    final rest = media.supplied.where((k) => !drawn.contains(k)).toList();
    return [
      if (images.isNotEmpty) pw.Wrap(children: images),
      // What the media shows or says, in the educator's words.
      if (media.trimmedDescription.isNotEmpty && media.hasAny) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          text(media.trimmedDescription),
          style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF212121)),
        ),
      ],
      if (rest.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          text(
            l10n.portfolioPdfInApp(rest.map((k) => k.labelOf(l10n)).join(', ')),
          ),
          // Not italic: the theme carries no italic face, and the fallback
          // (Helvetica) cannot print Filipino punctuation.
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColor.fromInt(0xFF5F6368),
          ),
        ),
      ],
    ];
  }

  static Future<pw.ImageProvider?> _picture(String value) async {
    try {
      final bytes = await (debugLoadPicture ?? _loadPicture)(value).timeout(
        AssessmentMediaCache.perItem,
      );
      if (bytes == null || bytes.isEmpty) return null;
      final image = pw.MemoryImage(bytes);
      // Decoding happens when the page is laid out; probe it now so a file
      // the PDF library cannot read is skipped instead of failing the save.
      await _probe(image);
      return image;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _probe(pw.MemoryImage image) async {
    final probe = pw.Document();
    probe.addPage(pw.Page(build: (_) => pw.Image(image)));
    await probe.save();
  }

  static Future<Uint8List?> _loadPicture(String value) async {
    if (isAssetMedia(value)) {
      final data = await rootBundle.load(value);
      return data.buffer.asUint8List();
    }
    final file = await AssessmentMediaCache.fileFor(value);
    return file?.readAsBytes();
  }

  static Future<pw.ThemeData?> _loadTheme() async {
    try {
      final regular = await rootBundle.load('google_fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('google_fonts/NotoSans-Bold.ttf');
      return pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (_) {
      return null;
    }
  }

  /// [s] without what the bundled Noto Sans cannot draw: an arrow becomes
  /// "->", and emoji (with the joiners and selectors that build them) and
  /// other pictographs are dropped. Letters, accents and punctuation stay.
  static String _fontSafe(String s) {
    final out = StringBuffer();
    for (final rune in s.runes) {
      if (rune == 0x2192) {
        out.write('->');
      } else if (rune == 0x2190) {
        out.write('<-');
      } else if (rune >= 0x1F000 ||
          (rune >= 0x2190 && rune <= 0x21FF) ||
          (rune >= 0x2300 && rune <= 0x23FF) ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          (rune >= 0x2B00 && rune <= 0x2BFF) ||
          (rune >= 0xFE00 && rune <= 0xFE0F) ||
          rune == 0x200D) {
        continue;
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// For tests: what [_fontSafe] makes of [s].
  static String fontSafeForTest(String s) => _fontSafe(s);

  /// [s] with the typography Helvetica lacks turned into plain letters, and
  /// anything else outside Latin-1 (an emoji in a note) dropped.
  static String _latin1Safe(String s) {
    const swaps = {
      '—': '-', '–': '-', '‘': "'", '’': "'",
      '“': '"', '”': '"', '…': '...', '→': '->',
      '·': '-', '•': '-',
    };
    final out = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final swap = swaps[ch];
      if (swap != null) {
        out.write(swap);
      } else if (rune <= 0xFF) {
        out.write(ch);
      }
    }
    return out.toString();
  }

  /// For tests: what [_latin1Safe] makes of [s].
  static String latin1SafeForTest(String s) => _latin1Safe(s);
}
