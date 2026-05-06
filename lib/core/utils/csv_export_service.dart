import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../data/local/spaced_repetition_service.dart';
import '../../data/local/hive_service.dart';

/// Generates CSV data exports for teacher/parent use.
///
/// Produces a single CSV file with multiple sections:
/// 1. Summary metrics
/// 2. Category breakdown
/// 3. Game scores history
/// 4. Per-word accuracy (spaced repetition)
/// 5. Session logs
class CsvExportService {
  const CsvExportService._();

  /// Generate and share a CSV progress report.
  static Future<void> generateAndShare({
    required UserProfile profile,
    required LearningProgress progress,
    required List<Flashcard> allCards,
  }) async {
    final csv = _buildCsv(
      profile: profile,
      progress: progress,
      allCards: allCards,
    );

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toString().split(' ').first;
    final file = File(
        '${dir.path}/FlashLearn_Data_${profile.name}_$dateStr.csv');
    await file.writeAsString(csv);

    // Share
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FlashLearn PWD - Data Export for ${profile.name}',
    );
  }

  static String _buildCsv({
    required UserProfile profile,
    required LearningProgress progress,
    required List<Flashcard> allCards,
  }) {
    final buf = StringBuffer();
    final totalWords = allCards.length;
    final masteryPct = totalWords > 0
        ? (progress.wordsLearned / totalWords * 100).round()
        : 0;

    // ── Section 1: Summary ──
    buf.writeln('PROGRESS SUMMARY');
    buf.writeln('Metric,Value');
    buf.writeln('Student Name,${_esc(profile.name)}');
    buf.writeln('Role,${profile.role.label}');
    buf.writeln(
        'Report Date,${DateTime.now().toString().split(' ').first}');
    buf.writeln('Words Learned,${progress.wordsLearned}');
    buf.writeln('Total Words,$totalWords');
    buf.writeln('Mastery,$masteryPct%');
    buf.writeln('Total Stars,${progress.totalStars}');
    buf.writeln('Stars Spent,${progress.spentStars}');
    buf.writeln('Star Balance,${progress.starBalance}');
    buf.writeln('Streak Days,${progress.streakDays}');
    buf.writeln(
        'Last Activity,${progress.lastActivityDate.toString().split(' ').first}');

    // Spaced repetition summary
    final srSummary = SpacedRepetitionService.getSummary(profile.id);
    buf.writeln('Total Attempts,${srSummary.totalAttempted}');
    buf.writeln('Total Correct,${srSummary.totalCorrect}');
    buf.writeln('Words Struggling,${srSummary.wordsStruggling}');
    if (srSummary.totalAttempted > 0) {
      final acc =
          (srSummary.totalCorrect / srSummary.totalAttempted * 100).round();
      buf.writeln('Overall Accuracy,$acc%');
    }
    buf.writeln();

    // ── Section 2: Category Breakdown ──
    buf.writeln('CATEGORY BREAKDOWN');
    buf.writeln('Category,Progress');
    for (final cat in FlashcardCategory.values) {
      final pct =
          ((progress.categoryProgress[cat.label] ?? 0.0) * 100).round();
      buf.writeln('${_esc(cat.label)},$pct%');
    }
    buf.writeln();

    // ── Section 3: Game Scores ──
    buf.writeln('GAME SCORES');
    buf.writeln('Date,Game,Score,Total,Percentage,Stars,Duration (sec)');
    for (final score in progress.recentScores.reversed) {
      final pct =
          score.total > 0 ? (score.score / score.total * 100).round() : 0;
      buf.writeln(
        '${score.date.toString().split(' ').first},'
        '${_esc(score.gameType.label)},'
        '${score.score},'
        '${score.total},'
        '$pct%,'
        '${score.starsEarned},'
        '${score.durationSeconds ?? ""}',
      );
    }
    buf.writeln();

    // ── Section 4: Word Accuracy ──
    final accs = SpacedRepetitionService.getWordAccuracies(profile.id);
    buf.writeln('WORD ACCURACY');
    buf.writeln(
        'Word (English),Word (Filipino),Category,Accuracy,Correct,Total,Last Seen');
    for (final card in allCards) {
      final wa = accs[card.id];
      if (wa == null) continue; // skip words never attempted
      final accPct = (wa.accuracy * 100).round();
      buf.writeln(
        '${_esc(card.wordEnglish)},'
        '${_esc(card.wordFilipino)},'
        '${_esc(card.category.label)},'
        '$accPct%,'
        '${wa.correct},'
        '${wa.total},'
        '${wa.lastSeen.toString().split(' ').first}',
      );
    }
    buf.writeln();

    // ── Section 5: Session Logs ──
    final sessions = HiveService.getSessionLogs(profile.id);
    buf.writeln('SESSION LOGS');
    buf.writeln('Date,Duration (min),Games Played,Cards Reviewed');
    for (final s in sessions.reversed) {
      final date = s['date'] as String? ?? '';
      final datePart = date.contains(' ') ? date.split(' ').first : date;
      final durationMin = ((s['durationSeconds'] as int?) ?? 0) ~/ 60;
      buf.writeln(
        '$datePart,'
        '$durationMin,'
        '${s['gamesPlayed'] ?? 0},'
        '${s['cardsReviewed'] ?? 0}',
      );
    }

    return buf.toString();
  }

  /// Escape a CSV field — wrap in quotes if it contains commas or quotes.
  static String _esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
