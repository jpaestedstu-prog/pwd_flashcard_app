import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../data/remote/firestore_repository.dart';

/// One row in the exported CSV — a single learner's snapshot.
class CsvReportRow {
  final String profileId;
  final String profileName;
  final int wordsLearned;
  final int totalStars;
  final int streakDays;
  final DateTime? lastActivityDate;
  final int sessionsInRange;
  final int activeMinutesInRange;
  final int cardsReviewedInRange;

  const CsvReportRow({
    required this.profileId,
    required this.profileName,
    required this.wordsLearned,
    required this.totalStars,
    required this.streakDays,
    required this.lastActivityDate,
    required this.sessionsInRange,
    required this.activeMinutesInRange,
    required this.cardsReviewedInRange,
  });
}

/// Builds a downloadable CSV of student progress for a classroom.
///
/// All reads go through [FirestoreRepository] — no new collections or
/// schema. Designed for the free-tier (Spark) plan: a typical classroom
/// of 30 students produces ~60 reads per export, well under the daily
/// 50K cap.
class CsvReportService {
  CsvReportService._();

  /// Build the CSV rows for [classroomId] over the [last] window.
  ///
  /// [last] is matched against `session_logs.date`. Default = 30 days,
  /// which is the typical reporting cadence for IEP / classroom updates.
  static Future<List<CsvReportRow>> buildRows({
    required String classroomId,
    Duration last = const Duration(days: 30),
  }) async {
    const repo = FirestoreRepository();
    final students = await repo.getStudentsWithProgressByClassroom(classroomId);

    final cutoff = DateTime.now().subtract(last);
    final rows = <CsvReportRow>[];
    for (final entry in students) {
      final profile = entry.$1;
      final progress = entry.$2;
      final logs = await repo.getSessionLogs(profile.id);
      final inRange = logs.where((l) {
        final raw = l['date'];
        final ts = _parseTimestamp(raw);
        if (ts == null) return false;
        return ts.isAfter(cutoff);
      }).toList();
      final totalSeconds = inRange.fold<int>(
        0,
        (sum, l) => sum + ((l['durationSeconds'] as num?)?.toInt() ?? 0),
      );
      final totalCards = inRange.fold<int>(
        0,
        (sum, l) => sum + ((l['cardsReviewed'] as num?)?.toInt() ?? 0),
      );
      rows.add(CsvReportRow(
        profileId: profile.id,
        profileName: profile.name,
        wordsLearned: progress.wordsLearned,
        totalStars: progress.totalStars,
        streakDays: progress.streakDays,
        lastActivityDate: progress.lastActivityDate,
        sessionsInRange: inRange.length,
        activeMinutesInRange: (totalSeconds / 60).round(),
        cardsReviewedInRange: totalCards,
      ));
    }
    rows.sort((a, b) => a.profileName.compareTo(b.profileName));
    return rows;
  }

  /// Render [rows] into RFC-4180 CSV text with a header row.
  static String renderCsv(List<CsvReportRow> rows) {
    final buf = StringBuffer();
    buf.writeln([
      'Student Name',
      'Words Learned',
      'Total Stars',
      'Streak (days)',
      'Last Activity',
      'Sessions (in range)',
      'Active Minutes (in range)',
      'Cards Reviewed (in range)',
    ].map(_escape).join(','));
    for (final r in rows) {
      buf.writeln([
        r.profileName,
        r.wordsLearned.toString(),
        r.totalStars.toString(),
        r.streakDays.toString(),
        _formatDate(r.lastActivityDate),
        r.sessionsInRange.toString(),
        r.activeMinutesInRange.toString(),
        r.cardsReviewedInRange.toString(),
      ].map(_escape).join(','));
    }
    return buf.toString();
  }

  /// Build and write a CSV file to the app's temp directory. Returns the
  /// absolute path. The caller should hand the path to share_plus's
  /// `Share.shareXFiles([XFile(path)])` so the user can save / mail it.
  static Future<File> writeReportFile({
    required String classroomId,
    required String classroomLabel,
    Duration last = const Duration(days: 30),
  }) async {
    final rows = await buildRows(classroomId: classroomId, last: last);
    final csv = renderCsv(rows);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10); // YYYY-MM-DD
    final safeLabel = classroomLabel
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final filename = 'progress_${safeLabel}_$stamp.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    return file;
  }

  // ─── Helpers ─────────────────────────────────────────────

  /// CSV-escape a single field per RFC 4180: wrap in quotes if the value
  /// contains a comma / quote / newline; double any embedded quotes.
  static String _escape(String value) {
    final needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Session-log timestamps land in Firestore as either ISO strings (the
  /// older format) or Timestamps (newer). [getSessionLogs] forwards both
  /// shapes unchanged, so accept either here.
  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    // cloud_firestore Timestamp via dynamic dispatch — avoid a direct
    // import for testability.
    try {
      final dyn = raw as dynamic;
      final ts = dyn.toDate();
      if (ts is DateTime) return ts;
    } catch (_) {
      // Not a Timestamp; fall through.
    }
    return null;
  }
}

