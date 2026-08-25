import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Games flow is the one path every learner walks, so it has to speak both
/// app languages.
///
/// Two guards, both cheap and both the kind that rot silently otherwise:
/// every key the flow uses exists in *both* locales, and the Games-flow source
/// files have no user-facing English left hardcoded in them.

/// Source files that make up the shared Games chrome — the surfaces every game
/// passes through on the way in and out.
const _gamesFlowSources = <String>[
  'lib/features/games/screens/game_hub_screen.dart',
  'lib/features/games/screens/fsl_practice_hub_screen.dart',
  'lib/features/games/widgets/pause_overlay.dart',
  'lib/features/games/widgets/tap_quiz_game.dart',
  'lib/widgets/game_widgets.dart',
  'lib/widgets/game_review_sheet.dart',
  'lib/widgets/animated_score_reveal.dart',
  // The games themselves — prompts and screen-reader labels included.
  'lib/features/games/screens/word_match_screen.dart',
  'lib/features/games/screens/picture_word_screen.dart',
  'lib/features/games/screens/sentence_builder_screen.dart',
  'lib/features/games/screens/spelling_bee_screen.dart',
  'lib/features/games/screens/jigsaw_puzzle_screen.dart',
  'lib/features/games/screens/tracing_screen.dart',
  'lib/features/games/screens/yes_or_no_screen.dart',
  'lib/features/games/screens/odd_one_out_screen.dart',
  'lib/features/games/screens/first_letter_screen.dart',
  'lib/features/games/screens/drag_drop_screen.dart',
  'lib/features/games/screens/flashcard_quiz_screen.dart',
  'lib/features/games/screens/memory_match_screen.dart',
  'lib/features/games/screens/pronunciation_screen.dart',
  'lib/features/games/screens/fsl_sign_to_word_screen.dart',
  'lib/features/games/screens/fsl_word_to_sign_screen.dart',
];

/// Keys the Games flow introduced. Listed explicitly rather than scraped, so
/// deleting one from the ARB fails here instead of at runtime in Filipino.
const _gamesFlowKeys = <String>[
  'gameTipDifficulty', 'gameTipDaily', 'gameTipReview', 'gameTipStartEasy',
  'gameTipVariety', 'gameTipTimed',
  'playTogether', 'playTogetherSubtitle', 'playTogetherSemantics',
  'gamesPickedForYou', 'badgeNew', 'notPlayedYet', 'yourBestStars',
  'playGameSemantics',
  'chooseYourDifficulty', 'beatTheClock', 'beatTheClockSubtitle', 'lastPlayed',
  'chooseCategories', 'pickVocabulary', 'startWithAllCategories',
  'startWithOneCategory', 'startWithCategories', 'comingSoon',
  'gameReviewTitle', 'reviewCorrectCount', 'reviewWrongCount',
  'yourAnswerLabel',
  'paused', 'resumeGame', 'iNeedABreak', 'restartGame', 'restartGameTitle',
  'restartGameBody', 'quitToGames', 'pauseLabel',
  'reviewWords', 'starsEarnedChip', 'gameResultsSemantics',
  'resultAmazing', 'resultAmazingHint', 'resultGreat', 'resultGreatHint',
  'resultGood', 'resultGoodHint', 'resultKeepPracticing',
  'resultKeepPracticingHint',
  'fslPractice', 'fslPracticeHeading', 'fslPracticeIntro',
  'fslSignToWord', 'fslSignToWordSubtitle',
  'fslWordToSign', 'fslWordToSignSubtitle',
  'fslSignIt', 'fslSignItSubtitle', 'fslSignItSubtitleGaze',
  'fslVideosComingSoon',
  'resumeBadge', 'resumeTitle', 'resumeBody', 'resumeContinue',
  'resumeStartOver', 'resumeRoundProgress',
  'notEnoughWords', 'notEnoughWordsBody', 'backToGames',
  // Game and difficulty names + blurbs, now read from the ARB by
  // GameTypeX.labelOf / GameDifficultyX.labelOf.
  'wordMatch', 'spellingBee', 'memoryMatch', 'dragAndDrop', 'flashcardQuiz',
  'pronunciationPractice', 'sentenceBuilder', 'storyQuiz', 'tracing',
  'fslPractice', 'jigsawPuzzle', 'pictureWord', 'yesOrNo', 'oddOneOut',
  'firstLetter',
  'gameDescWordMatch', 'gameDescSpellingBee', 'gameDescMemoryMatch',
  'gameDescDragAndDrop', 'gameDescFlashcardQuiz', 'gameDescPronunciation',
  'gameDescSentenceBuilder', 'gameDescStoryQuiz', 'gameDescTracing',
  'gameDescFslPractice', 'gameDescJigsawPuzzle', 'gameDescPictureWord',
  'gameDescYesOrNo', 'gameDescOddOneOut', 'gameDescFirstLetter',
  'easy', 'medium', 'hard',
  'difficultyDescEasy', 'difficultyDescMedium', 'difficultyDescHard',
  // The "Auto" card's explanation, assembled in the widget from these.
  'suggestStarting', 'suggestScopeGame', 'suggestScopeRecent',
  'suggestScopeLifetime', 'suggestTierEasy', 'suggestTierMedium',
  'suggestTierHard',
  // In-round copy.
  'gameRoundHeader', 'findPictureFor', 'whichWordMatches',
  'whichDoesNotBelong', 'startsWithWhichLetter', 'isThisPrompt', 'hearIt',
  'heardTryAgain', 'cameraWordsFound', 'oddOneOutHint', 'allPiecesPlaced',
  'jigsawHowTo', 'movesUsed', 'knownCount', 'stillLearningCount',
  'fillInTheBlank', 'spellTheWord', 'traceWord', 'moves', 'matched',
  'amazing', 'keepGoing', 'percentMastered', 'listenAndPick', 'hintsLeft',
  // Screen-reader labels — what a Visual-Impairment learner actually hears.
  'answerChoiceSemantics', 'answerSemantics', 'correctAnswerSuffix',
  'wrongAnswerSuffix', 'questionEnglishFor', 'findPictureForSemantics',
  'pictureOfSemantics', 'whichWordMatchesSemantics', 'firstLetterQuestion',
  'yesNoQuestion', 'flashcardSemantics', 'flashcardProgressSemantics',
  'draggableWordSemantics', 'slotFilled', 'slotEmpty', 'letterAlreadyUsed',
  'letterTapToPlace', 'roundScoreSemantics', 'spelledSoFar', 'wordComplete',
  'oddOneOutQuestion', 'oddOneOutHintSpoken',
  'fslWatchAndChoose', 'fslWhatWordIsThisSign', 'fslWhichSignMeans',
  'videoChoice', 'iKnow', 'learning', 'dropTargetMatched',
  'dropTargetHolding', 'dropTargetEmptyHint',
  'memoryCardMatched', 'memoryCardShowing', 'memoryCardFaceDown',
  // Found by the device QA pass — single-word labels the earlier heuristic
  // skipped, plus the widgets that float over every game.
  'breakButton', 'iNeedABreakTooltip', 'replayVideo', 'showMe',
  'answerYes', 'answerNo', 'close', 'pauseLabel',
  'jigsawPuzzleProgress', 'jigsawCompleteFor', 'jigsawPieceSemantics',
  'jigsawPiecePlaced', 'memoryProgressSemantics',
  'playSoundEnglish', 'playSoundFilipino',
  'showMeTitle', 'gazePrev', 'gazeNext', 'gazeChoose', 'gazeFlip',
  'gazePlace', 'gazeUndo',
];

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> fil;

  setUpAll(() {
    en = _arb('lib/l10n/app_en.arb');
    fil = _arb('lib/l10n/app_fil.arb');
  });

  group('ARB parity', () {
    test('every Games-flow key exists in English', () {
      final missing = _gamesFlowKeys.where((k) => !en.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'missing from app_en.arb: $missing');
    });

    test('every Games-flow key exists in Filipino', () {
      final missing = _gamesFlowKeys.where((k) => !fil.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'missing from app_fil.arb: $missing');
    });

    test('no Games-flow string was left untranslated', () {
      // A Filipino value identical to the English one usually means the key
      // was copied across and never translated. Emoji-only and proper nouns
      // legitimately match, so they are exempted by name.
      // Proper nouns, brand-ish names and format strings that are legitimately
      // identical in both languages.
      const sameByDesign = {
        'fslPractice', 'beatTheClock', 'spellingBee', 'memoryMatch',
        'flashcardQuiz', 'sentenceBuilder', 'gameRoundHeader',
      };
      final untranslated = _gamesFlowKeys
          .where((k) => !sameByDesign.contains(k))
          .where((k) => en[k] == fil[k])
          .toList();
      expect(
        untranslated,
        isEmpty,
        reason: 'identical in both locales: $untranslated',
      );
    });

    test('both locales define exactly the same key set', () {
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final filKeys = fil.keys.where((k) => !k.startsWith('@')).toSet();
      expect(enKeys.difference(filKeys), isEmpty, reason: 'missing in fil');
      expect(filKeys.difference(enKeys), isEmpty, reason: 'extra in fil');
    });

    test('placeholders match between locales', () {
      final placeholderPattern = RegExp(r'\{(\w+)\}');
      for (final key in _gamesFlowKeys) {
        final enSlots = placeholderPattern
            .allMatches(en[key] as String)
            .map((m) => m.group(1))
            .toSet();
        final filSlots = placeholderPattern
            .allMatches(fil[key] as String)
            .map((m) => m.group(1))
            .toSet();
        expect(
          filSlots,
          enSlots,
          reason: '$key: Filipino placeholders differ from English',
        );
      }
    });
  });

  group('no hardcoded copy left in the Games flow', () {
    /// Strings that are not user-facing copy: asset/route paths, debug labels,
    /// enum-ish identifiers, and single symbols.
    ///
    /// The single-word case matters: an earlier version of this guard required
    /// a space, which let `tooltip: 'Close'` and `tooltip: 'Pause'` sit
    /// unlocalized in thirteen game screens until a device pass with the
    /// semantics tree caught them. Anything in a label-ish position is copy,
    /// however short.
    bool looksLikeCopy(String literal) {
      final t = literal.trim();
      if (t.length < 3) return false;
      if (t.startsWith('/') || t.contains('assets/')) return false;
      if (!RegExp(r'[a-z]').hasMatch(t)) return false;
      return RegExp(r'^[A-Z]').hasMatch(t);
    }

    /// Argument positions whose value is read aloud or displayed.
    const copySlots = [
      'tooltip:', 'label:', 'semanticLabel:', 'title:', 'subtitle:',
      'message:', 'hintText:', 'labelText:', 'child: Text(', 'Text(',
    ];

    for (final path in _gamesFlowSources) {
      test('$path has no user-facing English literal', () {
        final source = File(path).readAsStringSync();
        final offenders = <String>[];
        for (final line in const LineSplitter().convert(source)) {
          final code = line.trim();
          // Skip comments and the doc-comment prose that explains the code.
          if (code.startsWith('//') || code.startsWith('///')) continue;
          // Only inspect literals sitting in a slot that reaches the user;
          // this keeps map keys, route names and debug tags out of it.
          if (!copySlots.any(code.contains)) continue;
          for (final m in RegExp(r"'([^'\\\$]{3,})'").allMatches(code)) {
            final literal = m.group(1)!;
            if (looksLikeCopy(literal)) offenders.add('$literal  ← $code');
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'Hardcoded copy should move to the ARB files:\n'
              '${offenders.join('\n')}',
        );
      });
    }
  });
}
