import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// The app's words with no sign video are placeholders on purpose: the project
/// owner keeps them as "Coming soon" until they say otherwise (12 October
/// 2026), and `docs/fsl_recording_checklist.csv` lists them for whoever
/// records them later (`docs/fsl_recording_guide.md`). This keeps the two in
/// step: a sign appearing, or one going missing, shows up here and in the
/// checklist together, never silently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the words with no sign are exactly the recording checklist', () async {
    FslAssetsService.reset();
    addTearDown(FslAssetsService.reset);
    final availability = await FslAssetsService.load();

    final unsigned = {
      for (final card in SeedData.allFlashcards)
        if (!availability.hasVideo(card))
          '${card.category.label} | ${card.wordEnglish}',
    };

    final field = RegExp(r'"([^"]*)"');
    final checklist = {
      for (final line in File('docs/fsl_recording_checklist.csv')
          .readAsLinesSync()
          .skip(1)
          .where((l) => l.trim().isNotEmpty))
        () {
          final cells = field.allMatches(line).map((m) => m.group(1)!).toList();
          return '${cells[0]} | ${cells[1]}';
        }(),
    };

    expect(unsigned, checklist);
    expect(unsigned, hasLength(33));
  });
}
