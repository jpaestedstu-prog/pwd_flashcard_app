import 'dart:typed_data';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/local/seed_data.dart';

/// Types of printable worksheets.
enum WorksheetType {
  wordTracing,
  pictureMatching,
  fillInTheBlank,
  wordSearch,
}

extension WorksheetTypeX on WorksheetType {
  String get label => switch (this) {
    WorksheetType.wordTracing => 'Word Tracing',
    WorksheetType.pictureMatching => 'Picture Matching',
    WorksheetType.fillInTheBlank => 'Fill in the Blank',
    WorksheetType.wordSearch => 'Word Search',
  };

  String get description => switch (this) {
    WorksheetType.wordTracing => 'Trace English and Filipino words with dotted letters',
    WorksheetType.pictureMatching => 'Draw lines to match words with their translations',
    WorksheetType.fillInTheBlank => 'Complete sentences with the correct vocabulary word',
    WorksheetType.wordSearch => 'Find hidden vocabulary words in a letter grid',
  };

  String get emoji => switch (this) {
    WorksheetType.wordTracing => '✏️',
    WorksheetType.pictureMatching => '🔗',
    WorksheetType.fillInTheBlank => '📝',
    WorksheetType.wordSearch => '🔍',
  };
}

/// Generates printable PDF worksheets for offline vocabulary practice.
class WorksheetService {
  WorksheetService._();

  static Future<Uint8List> generate({
    required WorksheetType type,
    required FlashcardCategory category,
    required GameDifficulty difficulty,
  }) async {
    final cards = SeedData.getByCategory(category);
    final numWords = switch (difficulty) {
      GameDifficulty.easy => 6,
      GameDifficulty.medium => 8,
      GameDifficulty.hard => 12,
    };
    final selected = (List.of(cards)..shuffle()).take(numWords).toList();

    return switch (type) {
      WorksheetType.wordTracing => _generateWordTracing(selected, category, difficulty),
      WorksheetType.pictureMatching => _generatePictureMatching(selected, category, difficulty),
      WorksheetType.fillInTheBlank => _generateFillInTheBlank(selected, category, difficulty),
      WorksheetType.wordSearch => _generateWordSearch(selected, category, difficulty),
    };
  }

  static Future<Uint8List> _generateWordTracing(
    List<Flashcard> cards,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) async {
    final pdf = pw.Document();
    final headerColor = PdfColor.fromHex('#B39DDB');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _buildHeader('Word Tracing', category, difficulty),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'Trace each word carefully. Practice writing both English and Filipino!',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          ...cards.expand((card) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('English: ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(card.wordEnglish,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: headerColor)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  // Tracing line
                  pw.Container(
                    height: 28,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                      ),
                    ),
                    child: pw.Text(
                      card.wordEnglish,
                      style: pw.TextStyle(
                        fontSize: 22,
                        color: PdfColor.fromHex('#DDDDDD'),
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Text('Filipino: ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(card.wordFilipino,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#80CBC4'))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    height: 28,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                      ),
                    ),
                    child: pw.Text(
                      card.wordFilipino,
                      style: pw.TextStyle(
                        fontSize: 22,
                        color: PdfColor.fromHex('#DDDDDD'),
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _generatePictureMatching(
    List<Flashcard> cards,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) async {
    final pdf = pw.Document();
    final shuffledFilipino = cards.map((c) => c.wordFilipino).toList()..shuffle();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _buildHeader('Picture/Word Matching', category, difficulty),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'Draw a line from each English word on the left to its Filipino translation on the right.',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left column: English words (numbered)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('English',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 12),
                    ...cards.asMap().entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 20),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          '${e.key + 1}. ${e.value.wordEnglish}',
                          style: const pw.TextStyle(fontSize: 13),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              // Right column: Filipino translations (shuffled, lettered)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Filipino',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 12),
                    ...shuffledFilipino.asMap().entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 20),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          '${String.fromCharCode(65 + e.key)}. ${e.value}',
                          style: const pw.TextStyle(fontSize: 13),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text('Answers: _______________________________________________',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _generateFillInTheBlank(
    List<Flashcard> cards,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) async {
    final pdf = pw.Document();
    final cardsWithSentences =
        cards.where((c) => c.exampleSentence != null).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _buildHeader('Fill in the Blank', category, difficulty),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'Fill in each blank with the correct word from the word bank below.',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          // Word bank
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F5F5F5'),
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Word Bank:',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: (List.of(cardsWithSentences)..shuffle())
                      .map((c) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(
                              border:
                                  pw.Border.all(color: PdfColors.grey500),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(c.wordEnglish,
                                style: const pw.TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          // Sentences
          ...cardsWithSentences.asMap().entries.map((e) {
            final card = e.value;
            final sentence = card.exampleSentence!.replaceAll(
              RegExp(card.wordEnglish, caseSensitive: false),
              '_________',
            );
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${e.key + 1}. $sentence',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '   Filipino: ${card.wordFilipino}',
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _generateWordSearch(
    List<Flashcard> cards,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) async {
    final pdf = pw.Document();
    final gridSize = switch (difficulty) {
      GameDifficulty.easy => 10,
      GameDifficulty.medium => 12,
      GameDifficulty.hard => 15,
    };
    final words = cards.map((c) => c.wordEnglish.toUpperCase()).toList();
    final grid = _generateWordSearchGrid(words, gridSize);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _buildHeader('Word Search', category, difficulty),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'Find and circle all the hidden words in the grid below!',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          // Word list
          pw.Wrap(
            spacing: 16,
            runSpacing: 8,
            children: cards
                .map((c) => pw.Text(
                      '${c.wordEnglish} (${c.wordFilipino})',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ))
                .toList(),
          ),
          pw.SizedBox(height: 20),
          // Grid
          pw.Center(
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: grid.map((row) {
                return pw.TableRow(
                  children: row.map((letter) {
                    return pw.Container(
                      width: 22,
                      height: 22,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        letter,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // ─── Shared PDF helpers ──────────────────────────

  static pw.Widget _buildHeader(
    String worksheetType,
    FlashcardCategory category,
    GameDifficulty difficulty,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FlashLearn PWD — $worksheetType',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Category: ${category.label}  •  Difficulty: ${difficulty.label}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Name: ____________________',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('Date: ____________________',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}  •  Generated by FlashLearn PWD',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  /// Generates a simple word search grid by placing words horizontally
  /// and vertically, then filling remaining cells with random letters.
  static List<List<String>> _generateWordSearchGrid(
      List<String> words, int size) {
    final random = Random();
    final grid = List.generate(
      size,
      (_) => List.generate(size, (_) => ''),
    );

    for (final word in words) {
      if (word.length > size) continue;
      var placed = false;
      for (var attempt = 0; attempt < 50 && !placed; attempt++) {
        final horizontal = random.nextBool();
        final r = random.nextInt(size);
        final c = random.nextInt(size);

        if (horizontal && c + word.length <= size) {
          var canPlace = true;
          for (var i = 0; i < word.length; i++) {
            final existing = grid[r][c + i];
            if (existing.isNotEmpty && existing != word[i]) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            for (var i = 0; i < word.length; i++) {
              grid[r][c + i] = word[i];
            }
            placed = true;
          }
        } else if (!horizontal && r + word.length <= size) {
          var canPlace = true;
          for (var i = 0; i < word.length; i++) {
            final existing = grid[r + i][c];
            if (existing.isNotEmpty && existing != word[i]) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            for (var i = 0; i < word.length; i++) {
              grid[r + i][c] = word[i];
            }
            placed = true;
          }
        }
      }
    }

    // Fill empty cells with random letters
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isEmpty) {
          grid[r][c] = String.fromCharCode(65 + random.nextInt(26));
        }
      }
    }

    return grid;
  }
}
