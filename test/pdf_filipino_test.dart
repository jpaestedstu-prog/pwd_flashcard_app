import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pwdpwdpwd/core/services/certificate_service.dart';
import 'package:pwdpwdpwd/core/services/worksheet_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/reports/services/report_generator.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// The PDFs a parent or teacher prints follow the app's language. These build
/// each one in Filipino — the path the study's tablets take — and check a real
/// PDF comes back (a missing key or an unloaded date format would throw).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fil = AppLocalizationsFil();

  setUpAll(() async {
    // The app's localization delegates load this; a unit test has to.
    await initializeDateFormatting('fil');
  });

  void expectValidPdf(Uint8List bytes) {
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  }

  final child = ChildSummary(
    profileId: 'p1',
    name: 'Ana',
    avatarEmoji: '🦊',
    avatarIndex: 0,
    disabilityType: DisabilityType.hearing,
    wordsLearned: 42,
    totalStars: 120,
    streakDays: 5,
    gamesPlayed: 1,
    averageAccuracy: 0.85,
    studyMinutesThisWeek: 90,
    studyMinutesLastWeek: 60,
    totalSessions: 2,
    dailyStudyMinutes: const {'2026-09-21': 20, '2026-09-22': 35},
    categoryProgress: {
      FlashcardCategory.animals.label: 0.9,
      FlashcardCategory.numbers.label: 0.3,
    },
    categoryCoverage: const {},
    wordHuntFinds: 0,
    signsWatched: 0,
    wordHuntStreak: 0,
    recentScores: [
      GameScore(
        gameType: GameType.wordMatch,
        score: 8,
        total: 10,
        starsEarned: 3,
        date: DateTime(2026, 9, 22),
        durationSeconds: 120,
      ),
    ],
    lastActivityDate: DateTime(2026, 9, 22),
  );

  test('weekly and family reports build in Filipino', () async {
    expectValidPdf(await ReportGenerator.generateWeeklyReport(child, l10n: fil));
    expectValidPdf(
      await ReportGenerator.generateFamilyReport([child, child], l10n: fil),
    );
  });

  test('certificates build in Filipino', () async {
    expectValidPdf(
      await CertificateService.categoryMastery(
        studentName: 'Ana',
        category: FlashcardCategory.animals,
        wordsLearned: 12,
        totalWords: 13,
        l10n: fil,
      ),
    );
    expectValidPdf(
      await CertificateService.streakMilestone(
        studentName: 'Ana',
        streakDays: 7,
        l10n: fil,
      ),
    );
    expectValidPdf(
      await CertificateService.overallProgress(
        studentName: 'Ana',
        totalWords: 50,
        totalStars: 100,
        streakDays: 7,
        l10n: fil,
      ),
    );
  });

  test('every worksheet type builds in Filipino', () async {
    for (final type in WorksheetType.values) {
      expectValidPdf(
        await WorksheetService.generate(
          type: type,
          category: FlashcardCategory.animals,
          difficulty: GameDifficulty.easy,
          l10n: fil,
        ),
      );
    }
  });

  test('the Filipino strings the PDFs use are really Filipino', () {
    expect(fil.wrWeeklyTitle, isNot('Weekly Progress Report'));
    expect(fil.cePdfTitle, isNot('CERTIFICATE OF ACHIEVEMENT'));
    expect(fil.wsName, startsWith('Pangalan'));
    expect(fil.wrFooter(1, 2), contains('FlashLearn PWD'));
    expect(fil.wrFooter(1, 2), isNot(contains('MagAral')));
  });
}
