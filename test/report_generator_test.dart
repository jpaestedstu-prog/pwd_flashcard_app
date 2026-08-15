import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/reports/services/report_generator.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// The Preview / Share PDF feature is only as reliable as the bytes it
/// produces. These tests exercise [ReportGenerator] end-to-end (including the
/// font-fallback path that keeps generation alive when the bundled font
/// assets can't be read on a given device) and assert that a structurally
/// valid PDF comes back for both the rich-data and empty-data cases.
void main() {
  // ReportGenerator reads font assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  ChildSummary buildChild({
    String name = 'Juan dela Cruz',
    List<GameScore> scores = const [],
    Map<String, double> categoryProgress = const {},
    Map<String, double> categoryCoverage = const {},
    Map<String, int> dailyStudyMinutes = const {},
    int wordHuntFinds = 0,
    int signsWatched = 0,
    int wordHuntStreak = 0,
  }) {
    return ChildSummary(
      profileId: 'p1',
      name: name,
      avatarEmoji: '🦊',
      avatarIndex: 0,
      disabilityType: DisabilityType.hearing,
      wordsLearned: 42,
      totalStars: 120,
      streakDays: 5,
      gamesPlayed: scores.length,
      averageAccuracy: 0.82,
      studyMinutesThisWeek: 90,
      studyMinutesLastWeek: 60,
      totalSessions: 8,
      dailyStudyMinutes: dailyStudyMinutes,
      categoryProgress: categoryProgress,
      categoryCoverage: categoryCoverage,
      wordHuntFinds: wordHuntFinds,
      signsWatched: signsWatched,
      wordHuntStreak: wordHuntStreak,
      recentScores: scores,
      lastActivityDate: DateTime.now(),
    );
  }

  void expectValidPdf(Uint8List bytes) {
    expect(bytes.length, greaterThan(100));
    // Every PDF starts with the "%PDF" magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  }

  test('generates a valid PDF with rich data', () async {
    final child = buildChild(
      scores: [
        GameScore(
          gameType: GameType.wordMatch,
          score: 8,
          total: 10,
          starsEarned: 3,
          date: DateTime.now(),
          durationSeconds: 120,
        ),
      ],
      categoryProgress: {
        FlashcardCategory.values.first.label: 0.9,
        FlashcardCategory.values.last.label: 0.3,
      },
      dailyStudyMinutes: {
        '2026-05-30': 20,
        '2026-05-31': 35,
      },
    );

    final bytes = await ReportGenerator.generateWeeklyReport(child);
    expectValidPdf(bytes);
  });

  test('generates a valid PDF with empty/edge-case data', () async {
    // No scores, no category progress, no study minutes, and a name with
    // punctuation/diacritics that must not break generation or the filename.
    final child = buildChild(name: 'Ñoña (Ward 3) #2');
    final bytes = await ReportGenerator.generateWeeklyReport(child);
    expectValidPdf(bytes);
  });

  test('generates a valid family report for multiple children', () async {
    final bytes = await ReportGenerator.generateFamilyReport([
      buildChild(name: 'Ana'),
      buildChild(name: 'Ben'),
    ]);
    expectValidPdf(bytes);
  });
}
