import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/game_catalog.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// Which games offer "Continue where you left off", and which deliberately
/// do not.
///
/// Source-level rather than behavioural: standing up eleven real game screens
/// needs the flashcard-image, TTS and video stacks, none of which have
/// platform channels under `flutter test`. What this file guards is the wiring
/// contract — every resumable game mixes in `GameResumeMixin`, declares the
/// `resume` flag, and is handed it by the router — plus the *reason* each
/// excluded game is excluded, so a future change has to argue with a test
/// rather than silently drop one.

/// Games that hold a sequential deck and can therefore be resumed.
const _resumable = <GameType>{
  GameType.wordMatch,
  GameType.spellingBee,
  GameType.sentenceBuilder,
  GameType.flashcardQuiz,
  GameType.pronunciation,
  GameType.jigsawPuzzle,
  GameType.tracing,
  GameType.pictureWord,
  GameType.yesOrNo,
  GameType.oddOneOut,
  GameType.firstLetter,
};

/// Games that cannot resume, and why. Memory Match and Drag & Drop are single
/// boards rather than a sequence of rounds — there is no "round 3 of 10" to
/// return to. FSL Practice resolves its deck from video availability
/// asynchronously, so the deck is not knowable when the snapshot is read.
const _notResumable = <GameType, String>{
  GameType.memoryMatch: 'single board, no round index',
  GameType.dragAndDrop: 'single board, no round index',
  GameType.fslPractice: 'deck resolved asynchronously from video availability',
  GameType.storyQuiz: 'launched from the Stories tab, not the hub',
};

/// Source file backing each resumable game. The TapQuiz trio share a base.
const _sourceOf = <GameType, String>{
  GameType.wordMatch: 'lib/features/games/screens/word_match_screen.dart',
  GameType.spellingBee: 'lib/features/games/screens/spelling_bee_screen.dart',
  GameType.sentenceBuilder:
      'lib/features/games/screens/sentence_builder_screen.dart',
  GameType.flashcardQuiz:
      'lib/features/games/screens/flashcard_quiz_screen.dart',
  GameType.pronunciation:
      'lib/features/games/screens/pronunciation_screen.dart',
  GameType.jigsawPuzzle: 'lib/features/games/screens/jigsaw_puzzle_screen.dart',
  GameType.tracing: 'lib/features/games/screens/tracing_screen.dart',
  GameType.pictureWord: 'lib/features/games/screens/picture_word_screen.dart',
  GameType.yesOrNo: 'lib/features/games/widgets/tap_quiz_game.dart',
  GameType.oddOneOut: 'lib/features/games/widgets/tap_quiz_game.dart',
  GameType.firstLetter: 'lib/features/games/widgets/tap_quiz_game.dart',
};

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('every game is either resumable or explicitly excluded', () {
    final accounted = {..._resumable, ..._notResumable.keys};
    expect(
      GameType.values.toSet().difference(accounted),
      isEmpty,
      reason: 'a new game must declare whether it can resume',
    );
    expect(
      _resumable.intersection(_notResumable.keys.toSet()),
      isEmpty,
      reason: 'a game cannot be both',
    );
  });

  group('resumable games are wired for it', () {
    for (final game in _resumable) {
      test('${game.name} mixes in GameResumeMixin', () {
        final src = _read(_sourceOf[game]!);
        expect(src, contains('GameResumeMixin'));
        expect(
          src,
          contains('void _restoreSaved('),
          reason: 'restoring is per game — the mixin deliberately omits it',
        );
        expect(src, contains('saveResumePoint()'));
        expect(src, contains('clearResumePoint()'));
      });
    }
  });

  group('non-resumable games stay out of it', () {
    const sources = {
      GameType.memoryMatch: 'lib/features/games/screens/memory_match_screen.dart',
      GameType.dragAndDrop: 'lib/features/games/screens/drag_drop_screen.dart',
    };
    sources.forEach((game, path) {
      test('${game.name} does not write a snapshot (${_notResumable[game]})', () {
        final src = _read(path);
        expect(src, isNot(contains('GameResumeMixin')));
        expect(src, isNot(contains('saveResumePoint')));
      });
    });
  });

  group('the router hands the flag through', () {
    late String router;
    setUpAll(() => router = _read('lib/navigation/app_router.dart'));

    test('parses the resume query parameter', () {
      expect(router, contains('bool _parseResume(GoRouterState state)'));
      expect(router, contains("queryParameters['resume'] == 'true'"));
    });

    test('every resumable route passes it', () {
      // The TapQuiz trio have their own routes even though they share a base.
      const screens = [
        'WordMatchScreen',
        'SpellingBeeScreen',
        'SentenceBuilderScreen',
        'FlashcardQuizScreen',
        'PronunciationScreen',
        'JigsawPuzzleScreen',
        'TracingScreen',
        'PictureWordScreen',
        'YesOrNoScreen',
        'OddOneOutScreen',
        'FirstLetterScreen',
      ];
      for (final screen in screens) {
        final start = router.indexOf('$screen(');
        expect(start, greaterThan(-1), reason: '$screen has no route');
        // The constructor call ends at the first `),` that closes it; a
        // generous window is enough to see the argument list.
        final window = router.substring(start, start + 400);
        expect(
          window,
          contains('resume: _parseResume(state)'),
          reason: '$screen route drops the resume flag',
        );
      }
    });
  });

  test('the hub offers resume for a broad share of each roster', () {
    // Not a hard floor per category, but a learner should not find that the
    // feature is effectively absent from their curated ten.
    for (final type in DisabilityType.values) {
      final roster = GameCatalog.forCategory(type);
      final resumable = roster.where(_resumable.contains).length;
      expect(
        resumable,
        greaterThanOrEqualTo(6),
        reason: '${type.name} roster only has $resumable resumable games',
      );
    }
  });
}
