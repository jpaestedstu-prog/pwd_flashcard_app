import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/seeded_random.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/break_time/break_time.dart';
import 'package:pwdpwdpwd/features/games/screens/drag_drop_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/first_letter_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/flashcard_quiz_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/jigsaw_puzzle_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/odd_one_out_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/picture_word_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/pronunciation_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/sentence_builder_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/spelling_bee_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/tracing_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/word_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/yes_or_no_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// The floating Break pill (bottom-left in every game) must never cover a
/// game's own controls. On a phone it reaches about 120 dp in from the left
/// and 60 dp up: it covered the Flashcard Quiz's "Still Learning" button,
/// Tracing's "Clear", the first Jigsaw piece and the bottom-left answer card
/// of First Letter, Yes or No and Odd One Out, so a tap there opened a break
/// instead. Overflow checks cannot see this (two widgets overlapping is not
/// an error), so every tap target's rectangle is compared with the pill's.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/game_break_clearance');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  const hard = GameDifficulty.hard;
  final games = <String, Widget Function()>{
    'DragDrop': () => const DragDropScreen(difficulty: hard),
    'FirstLetter': () => const FirstLetterScreen(difficulty: hard),
    'FlashcardQuiz': () => const FlashcardQuizScreen(difficulty: hard),
    'JigsawPuzzle': () => const JigsawPuzzleScreen(difficulty: hard),
    'MemoryMatch': () => const MemoryMatchScreen(difficulty: hard),
    'OddOneOut': () => const OddOneOutScreen(difficulty: hard),
    'PictureWord': () => const PictureWordScreen(difficulty: hard),
    'Pronunciation': () => const PronunciationScreen(difficulty: hard),
    'SentenceBuilder': () => const SentenceBuilderScreen(difficulty: hard),
    'SpellingBee': () => const SpellingBeeScreen(difficulty: hard),
    'Tracing': () => const TracingScreen(difficulty: hard),
    'WordMatch': () => const WordMatchScreen(difficulty: hard),
    'YesOrNo': () => const YesOrNoScreen(difficulty: hard),
  };

  // Phones upright and sideways, and a tablet.
  const sizes = <String, Size>{
    '360x640': Size(360, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
    '800x360': Size(800, 360),
    '686x1097': Size(686, 1097),
  };

  var combination = 0;
  for (final game in games.entries) {
    for (final size in sizes.entries) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        // The games deal a random card; a seed per combination makes every
        // run identical while still covering many different cards (the same
        // scheme as the overflow matrix, see seeded_random.dart).
        final seed = ++combination;
        testWidgets('${game.key}: nothing under the Break pill, '
            '${size.key} ${scale}x', (tester) async {
          debugContentRandomSeed = seed;
          addTearDown(() => debugContentRandomSeed = null);
          final covered =
              await _coveredByPill(tester, game.value, size.value, scale);
          expect(covered, isEmpty,
              reason: 'under the Break pill: ${covered.join('; ')}');
        });
      }
    }
  }
}

Future<List<String>> _coveredByPill(
  WidgetTester tester,
  Widget Function() build,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            // A phone's status bar and gesture bar.
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
        home: build(),
      ),
    ),
  );
  // Past the entrance animations, which slide controls in.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  // The pill is in its lane under the game (GameBreakBar), or in the app bar
  // on a short screen (GameBreakAction): exactly one of them shows it.
  final host = find.byWidgetPredicate(
    (w) => w is GameBreakBar || w is GameBreakAction,
  );
  final pillFinder = find.descendant(of: host, matching: find.byType(InkWell));
  final errorsFirst = <String>[];
  if (pillFinder.evaluate().length != 1) {
    errorsFirst.add('expected one Break pill, found '
        '${pillFinder.evaluate().length}');
  }
  if (pillFinder.evaluate().isEmpty) return errorsFirst;
  final pill = tester.getRect(pillFinder.first);
  final insidePill = find
      .descendant(of: host, matching: find.byWidgetPredicate((_) => true))
      .evaluate()
      .map((e) => e.widget)
      .toSet();

  bool tappable(Widget w) => switch (w) {
        GestureDetector(:final onTap) => onTap != null,
        InkWell(:final onTap) => onTap != null,
        ButtonStyleButton(:final onPressed) => onPressed != null,
        IconButton(:final onPressed) => onPressed != null,
        _ => false,
      };

  // A layout that overflowed paints past its box, under the bar: that is the
  // way something can still end up beneath it.
  final errors = <String>[];
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    errors.add('layout error: $e');
  }

  final covered = <String>[...errorsFirst, ...errors];
  for (final element in find.byWidgetPredicate(tappable).evaluate()) {
    final widget = element.widget;
    if (insidePill.contains(widget)) continue;
    // Inside a list, a control below the visible part is reached by
    // scrolling, and the list ends above the bar.
    if (Scrollable.maybeOf(element) != null) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty || !rect.overlaps(pill)) continue;
    // A control that also spans the whole screen (a swipe or tap-anywhere
    // layer) is not covered in any way that matters.
    if (rect.width >= size.width * 0.9 && rect.height >= size.height * 0.5) {
      continue;
    }
    final texts = find
        .descendant(of: find.byWidget(widget), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(2)
        .join('/');
    covered.add('${widget.runtimeType} "$texts" $rect');
  }
  return covered;
}
