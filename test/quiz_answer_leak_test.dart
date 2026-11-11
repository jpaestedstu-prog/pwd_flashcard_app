import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/flashcard_emojis.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/widgets/flashcard_image.dart';

/// A picture must not read out the word the learner is being asked for.
///
/// Every [FlashcardImage] face labels itself "English, Filipino" so a
/// screen-reader learner knows what they are looking at. Wherever the picture
/// *is the question*, that label was the answer. Word Match announced
/// "What is the English word for Motorsiklo? — Motorcycle, Motorsiklo — What is
/// this word?" before reading a single choice; a script that read only that
/// label scored 6/6 without seeing the screen.
///
/// Two layers here, because the widget fix alone would not stay fixed:
///  * the widget honours [FlashcardImage.revealsAnswer];
///  * the quiz prompts still pass it. That second one is a source guard —
///    the screens themselves need Hive and a provider scope to render, and a
///    silent regression there is precisely what this file exists to catch.
void main() {
  final card = SeedData.allFlashcards
      .firstWhere((c) => c.wordEnglish == 'Dog');

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('FlashcardImage.revealsAnswer', () {
    testWidgets('teaching pictures still name the word', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(FlashcardImage(card: card, size: 48)));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(card.wordEnglish)), findsWidgets,
          reason: 'the viewer and Smart Review rely on this label');
      expect(find.bySemanticsLabel(RegExp(card.wordFilipino)), findsWidgets);
      handle.dispose();
    });

    testWidgets('quiz pictures say "Picture clue" and nothing more',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(FlashcardImage(card: card, size: 48, revealsAnswer: false)),
      );
      await tester.pump();

      // Exactly the clue: the emoji used to merge into the same node, and a
      // screen reader names an emoji — "Picture clue, dog" for the word Dog.
      expect(find.bySemanticsLabel(FlashcardImage.answerSafeLabel),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(card.wordEnglish)), findsNothing,
          reason: 'the English word is the answer in Word Match');
      expect(find.bySemanticsLabel(RegExp(card.wordFilipino)), findsNothing,
          reason: 'the Filipino word is the answer in the Daily Challenge');
      expect(find.bySemanticsLabel(RegExp(FlashcardEmojis.forId(card.id))), findsNothing,
          reason: 'a screen reader says an emoji by name');
      handle.dispose();
    });

    testWidgets('FlashcardPicture forwards the flag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(FlashcardPicture(card: card, extent: 40, revealsAnswer: false)),
      );
      await tester.pump();

      // Exactly the clue: the emoji used to merge into the same node, and a
      // screen reader names an emoji — "Picture clue, dog" for the word Dog.
      expect(find.bySemanticsLabel(FlashcardImage.answerSafeLabel),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(card.wordEnglish)), findsNothing);
      expect(find.bySemanticsLabel(RegExp(FlashcardEmojis.forId(card.id))), findsNothing);
      handle.dispose();
    });
  });

  group('quiz prompts opt out of the naming label', () {
    // Where the picture *is* the question. Each entry is the screen and the
    // constructor argument that identifies its prompt picture, so a moved or
    // renamed prompt fails loudly rather than silently reverting.
    const prompts = <String, String>{
      'lib/features/games/screens/word_match_screen.dart':
          'card: round.correctCard,',
      'lib/features/games/screens/picture_word_screen.dart':
          'card: round.correctCard,',
      'lib/features/games/screens/yes_or_no_screen.dart': 'card: round.card,',
      'lib/features/games/screens/spelling_bee_screen.dart': 'card: card,',
      'lib/features/games/screens/sentence_builder_screen.dart': 'card: card,',
      'lib/features/games/screens/drag_drop_screen.dart': 'card: target.card,',
      'lib/features/home/screens/home_screen.dart': 'card: _card,',
      'lib/features/daily_challenge/screens/daily_challenge_screen.dart':
          'card: _word,',
    };

    for (final entry in prompts.entries) {
      test('${entry.key.split('/').last} keeps its prompt answer-safe', () {
        final source = File(entry.key).readAsStringSync();
        final at = source.indexOf(entry.value);
        expect(at, greaterThan(-1),
            reason: 'prompt picture "${entry.value}" is gone from '
                '${entry.key} — if it moved, update this guard');

        final window = _enclosingCall(source, at);
        expect(window, contains('revealsAnswer: false'),
            reason: '${entry.key} would announce the answer to a screen '
                'reader before the learner has answered');
      });
    }
  });

  test('a picture question never names its word', () {
    // Picture Word's picture-to-word rounds asked "Which word matches this
    // picture? Hair" — and "Hair" was the right answer among the buttons.
    final source = File('lib/features/games/screens/picture_word_screen.dart')
        .readAsStringSync();
    final at = source.indexOf('prompt: Semantics(');
    expect(at, isNot(-1), reason: 'the picture prompt moved');
    final call = _enclosingCall(source, at + 'prompt: Semantics('.length);
    expect(call, isNot(contains('correctCard.word')),
        reason: 'the prompt would say the answer');
    expect(call, contains('excludeSemantics: true'),
        reason: 'the picture inside would be read out under the question');
  });
}

/// The full text of the constructor call containing [at].
///
/// Scans back to the `(` that opens the call, then forward to its match, so
/// the assertion covers the whole argument list however long the comments
/// inside it grow. A fixed-size window silently stopped short of the flag.
String _enclosingCall(String source, int at) {
  var open = at;
  var depth = 0;
  while (open > 0) {
    open--;
    final c = source[open];
    if (c == ')') depth++;
    if (c == '(') {
      if (depth == 0) break;
      depth--;
    }
  }
  var close = open;
  depth = 0;
  while (close < source.length - 1) {
    close++;
    final c = source[close];
    if (c == '(') depth++;
    if (c == ')') {
      if (depth == 0) break;
      depth--;
    }
  }
  return source.substring(open, close + 1);
}
