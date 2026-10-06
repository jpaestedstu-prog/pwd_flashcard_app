import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pwdpwdpwd/core/services/certificate_service.dart';
import 'package:pwdpwdpwd/core/services/worksheet_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/showcase/models/showcase_models.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_share_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';

/// Every PDF a parent or teacher prints must be able to draw the punctuation
/// the app's own strings use. Without a theme the pdf package uses its
/// built-in Helvetica, which covers Latin-1 only, so the portfolio title's
/// curly apostrophe, the worksheet footer's bullet and the title's dash each
/// came out as an empty box ("Ana□s Learning Portfolio"). The package reports
/// every such character through print(); these tests listen for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('fil');
  });

  /// The characters the pdf package could not draw while [build] ran — and
  /// any text style (italic, say) that fell back to a built-in font at all,
  /// which is where such a character would land next.
  Future<List<String>> missingGlyphs(Future<Object?> Function() build) async {
    final missing = <String>[];
    await runZoned(
      build,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.contains('Unable to find a font') ||
              line.contains('has no Unicode support')) {
            missing.add(line);
          } else {
            parent.print(zone, line);
          }
        },
      ),
    );
    return missing;
  }

  test('every worksheet draws its dash and bullets, in both languages', () async {
    for (final l10n in [AppLocalizationsEn(), AppLocalizationsFil()]) {
      for (final type in WorksheetType.values) {
        final missing = await missingGlyphs(() => WorksheetService.generate(
              type: type,
              category: FlashcardCategory.animals,
              difficulty: GameDifficulty.medium,
              l10n: l10n,
            ));
        expect(missing, isEmpty, reason: '${type.name} (${l10n.localeName})');
      }
    }
  });

  test('a certificate draws curly quotes and dashes in names and titles', () async {
    final missing = await missingGlyphs(() => CertificateService.generate(
          type: CertificateType.categoryMastery,
          studentName: 'Ana D’Souza',
          achievementTitle: 'Animals — Mga Hayop',
          achievementDetail: '“Great job!” • 12 of 12 words',
          date: DateTime(2026, 10, 6),
        ));
    expect(missing, isEmpty);
  });

  test('the showcase portfolio title draws its apostrophe', () async {
    final missing = await missingGlyphs(() => ShowcaseShareScreen.generatePortfolioPdf(
          profileName: 'Ana',
          portfolio: ShowcasePortfolio(
            profileId: 'p1',
            profileName: 'Ana',
            lastUpdated: DateTime(2026, 10, 6),
          ),
          totalStars: 12,
          wordsLearned: 30,
          streakDays: 4,
          l10n: AppLocalizationsEn(),
        ));
    expect(missing, isEmpty);
  });
}
