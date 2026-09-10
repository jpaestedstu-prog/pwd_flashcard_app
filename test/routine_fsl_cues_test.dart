import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_sign_launcher.dart';

/// Guards the Routine feature's FSL content against the failure that matters
/// most to a Deaf learner: a Signs button that does not work.
///
/// The catalog's cues are hand-written English words. Two things can silently
/// break them — a word that matches no seed flashcard, and a word that matches
/// a card with no clip registered in the manifest. Neither is visible to the
/// analyser, and both would ship as a button that opens the "not available"
/// sheet on the one surface a Deaf learner depends on.
///
/// This reads the real manifest from disk rather than going through
/// `FslAssetsService` (which needs an asset bundle and a plugin), so it runs
/// as a plain `test()` with no Flutter binding.
void main() {
  late Set<String> manifestKeys;

  setUpAll(() {
    final file = File('assets/data/fsl_video_manifest.json');
    expect(file.existsSync(), isTrue,
        reason: 'the FSL manifest must be present for this guard to mean '
            'anything');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = json['entries'] as List;
    manifestKeys = {
      for (final e in entries)
        '${(e as Map)['category']}__'
            '${(e['word_english'] as String).toLowerCase()}',
    };
  });

  test('every routine sign cue resolves to a seed flashcard', () {
    final unresolved = <String>[];
    for (final info in RoutineCatalog.all) {
      for (final cue in info.signCues) {
        if (RoutineSignLauncher.cardFor(cue) == null) {
          unresolved.add('${info.activity.name} → "${cue.word}"');
        }
      }
    }
    expect(unresolved, isEmpty,
        reason: 'these cues match no flashcard, so they would show a Deaf '
            'learner nothing: $unresolved');
  });

  test('every routine sign cue has a clip registered in the manifest', () {
    final missing = <String>[];
    for (final info in RoutineCatalog.all) {
      for (final cue in info.signCues) {
        final card = RoutineSignLauncher.cardFor(cue);
        if (card == null) continue;
        final key =
            '${card.category.label}__${card.wordEnglish.toLowerCase()}';
        if (!manifestKeys.contains(key)) {
          missing.add('${info.activity.name} → "${cue.word}" ($key)');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'these cues resolve to a card with no FSL video, so the Signs '
            'button would dead-end: $missing');
  });

  test('a categorised cue picks the card in that category', () {
    // "Walk" is a Transportation seed card; there is also an Actions verb in
    // the seed set. Without the category the lookup takes whichever comes
    // first, and the learner gets the wrong sign.
    final exercise = RoutineCatalog.infoFor(RoutineActivity.exercise);
    final walkCue = exercise.signCues.firstWhere((c) => c.word == 'Walk');
    final card = RoutineSignLauncher.cardFor(walkCue);
    expect(card, isNotNull);
    expect(card!.category, walkCue.category);
  });

  test('an educator-typed override is matched case-insensitively and in '
      'Filipino too', () {
    const base = RoutineStep(id: 's', activity: RoutineActivity.custom);
    for (final typed in ['water', 'WATER', 'Water', 'Tubig']) {
      final cues = RoutineCatalog.signCuesFor(base.copyWith(signWord: typed));
      final card = RoutineSignLauncher.cardFor(cues.single);
      expect(card, isNotNull, reason: 'typed "$typed" resolved to nothing');
      expect(card!.wordEnglish, 'Water', reason: 'typed "$typed"');
    }
  });

  test('a nonsense override resolves to nothing rather than a random card',
      () {
    const base = RoutineStep(id: 's', activity: RoutineActivity.custom);
    final cues =
        RoutineCatalog.signCuesFor(base.copyWith(signWord: 'qqzzxx'));
    expect(RoutineSignLauncher.cardFor(cues.single), isNull);
  });

  test('a custom step with no override offers no signs at all', () {
    const base = RoutineStep(id: 's', activity: RoutineActivity.custom);
    expect(RoutineCatalog.signCuesFor(base), isEmpty);
    expect(RoutineSignLauncher.cueSummary(base), '');
  });

  test('cueSummary names the signs a learner is about to see', () {
    const brushing =
        RoutineStep(id: 's', activity: RoutineActivity.brushingTeeth);
    expect(RoutineSignLauncher.cueSummary(brushing), 'Teeth · Water');
  });

  test('the seed set really does contain every cue word', () {
    // A second, blunter check: catches a cue whose word was renamed in the
    // seed data, which the resolver's Filipino fallback could otherwise mask.
    final english = {
      for (final c in SeedData.allFlashcards) c.wordEnglish.toLowerCase(),
    };
    for (final info in RoutineCatalog.all) {
      for (final cue in info.signCues) {
        expect(english, contains(cue.word.toLowerCase()),
            reason: '${info.activity.name} cue "${cue.word}"');
      }
    }
  });
}
