import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Peer Collab's copy lives in the ARB files, and this keeps it there.
///
/// The same guard the Games flow has, scoped to this feature: every key it uses
/// exists in *both* locales with the same placeholders, and no user-facing
/// English literal is left in the source. Peer Collab shipped with its whole
/// vocabulary written as `isFilipino ? 'x' : 'y'` inline, which is why the
/// scan half matters as much as the parity half.
const _collabKeys = <String>[
  'collabLearnTogether',
  'collabTeamTagline',
  'collabPlayer2NameLabel',
  'collabPlayer2NameSemantics',
  'collabPlayer2NameHint',
  'collabChooseActivity',
  'collabEnterPlayer2Name',
  'collabNoWords',
  'collabHearAgain',
  'collabWordRelay',
  'collabPictureGuess',
  'collabSignChallenge',
  'collabStoryBuilder',
  'collabWordRelayDesc',
  'collabPictureGuessDesc',
  'collabSignChallengeDesc',
  'collabStoryBuilderDesc',
  'collabTeam',
  'collabPromptDescribe',
  'collabPromptNextLetter',
  'collabPromptAddSentence',
  'collabPromptGuess',
  'collabAnswerWas',
  'collabHintClue',
  'collabHintLetter',
  'collabHintSentence',
  'collabHintGuess',
  'collabWordToSpell',
  'collabWordToDescribe',
  'collabSignToShow',
  'collabWhatIsTheWord',
  'collabClueLabel',
  'collabClueCategory',
  'collabClueFirstLetter',
  'collabClueLength',
  'collabPassSpoken',
  'collabBuildStoryTogether',
  'collabStartTheStory',
  'collabWatchTheSign',
  'collabPhraseBig',
  'collabPhraseISee',
  'collabPhraseHappy',
  'collabPhraseWeLike',
  'collabGreatTeamwork',
  'collabPointsTogether',
  'collabSubmitAnswer',
  'collabSetUpForYou',
  'collabAdaptTapToAnswer',
  'collabAdaptReadAloud',
  'collabAdaptBiggerButtons',
  'collabAdaptShorter',
  'collabLeaveTitle',
  'collabLeaveBody',
  'collabLeaveConfirm',
  'collabKeepPlaying',
  // Reused rather than duplicated, so resuming reads the same here as it does
  // in the Games hub.
  'resumeBadge',
  'resumeTitle',
  'resumeContinue',
  'resumeStartOver',
  'resumeRoundProgress',
  'playAgain',
  'gazePrev',
  'gazeNext',
  'gazeChoose',
];

const _collabSources = <String>[
  'lib/features/peer_collaboration/models/collab_models.dart',
  'lib/features/peer_collaboration/models/collab_presentation.dart',
  'lib/features/peer_collaboration/services/collab_session_store.dart',
  'lib/features/peer_collaboration/screens/peer_collaboration_screen.dart',
];

Map<String, dynamic> _arb(String locale) => json.decode(
      File('lib/l10n/app_$locale.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  final en = _arb('en');
  final fil = _arb('fil');

  group('ARB parity', () {
    test('every key exists in English', () {
      expect(_collabKeys.where((k) => !en.containsKey(k)), isEmpty);
    });

    test('every key exists in Filipino', () {
      expect(_collabKeys.where((k) => !fil.containsKey(k)), isEmpty);
    });

    test('placeholders match between locales', () {
      final pattern = RegExp(r'\{(\w+)\}');
      for (final key in _collabKeys) {
        Set<String?> slots(Map<String, dynamic> arb) =>
            pattern.allMatches(arb[key] as String).map((m) => m.group(1)).toSet();
        expect(slots(fil), slots(en),
            reason: '$key: Filipino placeholders differ from English');
      }
    });

    test('every collab key is actually used', () {
      // Dead ARB entries are quiet debt: they still have to be translated, and
      // they make the guard's key list lie about what the feature says.
      final source = _collabSources
          .map((path) => File(path).readAsStringSync())
          .join();
      final unused = _collabKeys
          .where((k) => k.startsWith('collab'))
          .where((k) => !source.contains(k))
          .toList();
      expect(unused, isEmpty, reason: 'declared but never read: $unused');
    });

    test('the copy is actually translated', () {
      // Borrowed activity names that read the same in both languages. Everything
      // else being identical means it was never translated.
      const sameByDesign = {
        'collabWordRelay',
        'collabSignChallenge',
        'collabStoryBuilder',
        'collabTeamTagline',
      };
      final untranslated = _collabKeys
          .where((k) => k.startsWith('collab'))
          .where((k) => !sameByDesign.contains(k))
          .where((k) => en[k] == fil[k])
          .toList();
      expect(untranslated, isEmpty,
          reason: 'identical in both locales: $untranslated');
    });
  });

  group('no hardcoded copy left in Peer Collab', () {
    /// Strings that are not user-facing copy: paths, enum-ish identifiers, and
    /// single symbols. Single words count — `tooltip: 'Close'` is copy.
    bool looksLikeCopy(String literal) {
      final t = literal.trim();
      if (t.length < 3) return false;
      if (t.startsWith('/') || t.contains('assets/')) return false;
      if (!RegExp(r'[a-z]').hasMatch(t)) return false;
      return RegExp(r'^[A-Z]').hasMatch(t);
    }

    const copySlots = [
      'tooltip:',
      'label:',
      'semanticLabel:',
      'title:',
      'subtitle:',
      'message:',
      'hintText:',
      'labelText:',
      'confirmLabel:',
      'cancelLabel:',
      'content:',
      'child: Text(',
      'Text(',
    ];

    /// The English `label` / `description` getters are the documented source for
    /// logs and exports — one dataset must read the same whatever language the
    /// tablet is set to — so their switch bodies are not offenders.
    const exemptFiles = {
      'lib/features/peer_collaboration/models/collab_models.dart',
    };

    for (final path in _collabSources) {
      test('$path has no user-facing English literal', () {
        if (exemptFiles.contains(path)) return;
        final offenders = <String>[];
        for (final line
            in const LineSplitter().convert(File(path).readAsStringSync())) {
          final code = line.trim();
          if (code.startsWith('//') || code.startsWith('///')) continue;
          if (!copySlots.any(code.contains)) continue;
          for (final m in RegExp(r"'([^'\\\$]{3,})'").allMatches(code)) {
            final literal = m.group(1)!;
            if (looksLikeCopy(literal)) offenders.add('$literal  ← $code');
          }
        }
        expect(offenders, isEmpty,
            reason: 'Hardcoded copy should move to the ARB files:\n'
                '${offenders.join('\n')}');
      });
    }

    test('the screen no longer branches on the locale for its copy', () {
      final source = File(_collabSources.last).readAsStringSync();
      final branches = const LineSplitter()
          .convert(source)
          .map((l) => l.trim())
          .where((l) => !l.startsWith('//'))
          .where((l) => l.contains('isFilipino ?'))
          // Choosing which half of a bilingual **flashcard** to show is data
          // selection, not copy: the card really does carry two words, and
          // neither of them lives in an ARB file. Every other locale branch in
          // this screen was copy, and every one of those is gone.
          .where((l) => !l.contains('wordFilipino'))
          .toList();
      expect(branches, isEmpty,
          reason: 'copy comes from AppLocalizations now:\n$branches');
    });
  });
}
