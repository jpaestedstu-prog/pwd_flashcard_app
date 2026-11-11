import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/games/screens/drag_drop_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Drag & Drop without dragging.
///
/// Every word could only be dragged, so arrow keys, a remote, a switch box, a
/// game controller, Gaze Control and a screen reader could not play the game
/// at all — none of them can drag. Pressing a word now picks it up, and
/// pressing a Filipino row puts it there, through the same matching a drop
/// runs. A finger can still drag.

/// Captures what the game reports instead of touching Hive/Firestore.
class _StubProgressNotifier extends ProgressNotifier {
  int? score;

  @override
  LearningProgress build() {
    profileId = '';
    return LearningProgress(profileId: '', lastActivityDate: DateTime(2026));
  }

  @override
  void recordGameResult({
    required GameType gameType,
    required int score,
    required int total,
    required int starsEarned,
    List<FlashcardCategory> categoriesPlayed = const [],
    int? durationSeconds,
    Set<String> correctWordIds = const {},
    GameDifficulty? playedDifficulty,
  }) {
    this.score = score;
  }

  @override
  List<Achievement> checkAchievements() => const [];
}

/// Guest: no spaced repetition, resume point or sync inside the game.
class _Guest extends ProfileNotifier {
  @override
  UserProfile? build() => null;
}

/// `implements` so the real `AudioPlayer()` never starts.
class _SilentSoundService implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentTts extends TtsService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakEnglish(String text) async {}
  @override
  Future<void> speakFilipino(String text) async {}
  @override
  Future<void> stop() async {}
}

const _pickHint = '. Press to pick it up, or drag it to its Filipino match';

void main() {
  setUpAll(() async {
    // Wiped before use, never deleted after: a fire-and-forget Hive write in
    // the fake-async zone would stall a teardown delete for minutes.
    final dir = Directory('./build/test_cache/drag_drop_pick_place');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Hive.init(dir.path);
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

  late _StubProgressNotifier progress;

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    progress = _StubProgressNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressProvider.overrideWith(() => progress),
          profileProvider.overrideWith(_Guest.new),
          soundServiceProvider.overrideWithValue(_SilentSoundService()),
          ttsServiceProvider.overrideWithValue(_SilentTts()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DragDropScreen(difficulty: GameDifficulty.easy),
        ),
      ),
    );
    // The rows fade in, one after another — and a row still at opacity 0
    // is out of the semantics tree. Frames, not one long jump: a jump starts
    // the delayed fades and paints their first frame only.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets the celebration's one-shot timers run out, then unmounts so the
  /// endless animations dispose. In frames: the result arrives 600 ms after
  /// the last word, and its own entrance then waits up to 2 s more.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  /// The words still in the bank, as a screen reader names them.
  List<String> bankWords(WidgetTester tester) => [
    for (final w in tester.widgetList<Semantics>(find.byType(Semantics)))
      if (w.properties.label case final l? when l.endsWith(_pickHint))
        l.substring(0, l.length - _pickHint.length),
  ];

  Finder chip(String word) => find.bySemanticsLabel(
    RegExp('^${RegExp.escape(word)}(${RegExp.escape(_pickHint)}'
        '|, picked up\\. Now press its Filipino match)\$'),
  );

  /// A row [word] belongs on: its Filipino word is one of [word]'s.
  String rowFor(WidgetTester tester, String word) {
    final filipino = {
      for (final c in SeedData.allFlashcards)
        if (c.wordEnglish == word) c.wordFilipino,
    };
    return filipino.firstWhere(
      (f) => tester.any(find.bySemanticsLabel(RegExp('^${RegExp.escape(f)}\\b|'
          ': ${RegExp.escape(f)},'))),
    );
  }

  /// A row [word] does not belong on.
  String wrongRowFor(WidgetTester tester, String word) {
    final right = {
      for (final c in SeedData.allFlashcards)
        if (c.wordEnglish == word) c.wordFilipino,
    };
    final rows = [
      for (final w in tester.widgetList<Semantics>(find.byType(Semantics)))
        if (w.properties.label case final l?
            when l.startsWith('Drop target: '))
          l.substring('Drop target: '.length, l.indexOf(','))
        else if (w.properties.label case final l?
            when l.contains('. Press to put '))
          l.substring(0, l.indexOf('. Press to put ')),
    ];
    return rows.firstWhere((f) => !right.contains(f));
  }

  Finder row(String filipino) => find.bySemanticsLabel(
    RegExp('^(Drop target: ${RegExp.escape(filipino)},'
        '|${RegExp.escape(filipino)}\\. Press to put '
        '|Matched: ${RegExp.escape(filipino)} is )'),
  );

  /// The D-pad focus of the control [semantics] labels.
  FocusNode focusOf(WidgetTester tester, Finder semantics) => Focus.of(
    tester.element(
      find
          .descendant(of: semantics, matching: find.byType(GestureDetector))
          .first,
    ),
  );

  /// What Enter, Space, a controller's A, a switch or a blink send.
  Future<void> press(WidgetTester tester, Finder semantics) async {
    focusOf(tester, semantics).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  /// What a screen reader's double-tap sends.
  void srTap(WidgetTester tester, Finder semantics) {
    final node = tester.getSemantics(semantics);
    node.owner!.performAction(node.id, SemanticsAction.tap);
  }

  testWidgets('keys alone play a word: press it, then press its row', (
    tester,
  ) async {
    await pumpGame(tester);
    final word = bankWords(tester).first;
    final filipino = rowFor(tester, word);

    // Before anything is picked up a row is not a control: nothing to put.
    expect(focusOf(tester, row(filipino)).canRequestFocus, isFalse);

    await press(tester, chip(word));
    expect(
      find.bySemanticsLabel('$word, picked up. Now press its Filipino match'),
      findsOneWidget,
    );
    expect(tester.getSemantics(chip(word)).flagsCollection.isSelected,
        Tristate.isTrue);
    expect(find.bySemanticsLabel('$filipino. Press to put $word here'),
        findsOneWidget);

    await press(tester, row(filipino));
    await tester.pump();

    expect(find.bySemanticsLabel('Matched: $filipino is $word'),
        findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    // Focus moves on to a word still to place, so the next press picks it.
    final focused = FocusManager.instance.primaryFocus!;
    final next = bankWords(tester);
    expect(next, isNot(contains(word)));
    expect(
      next.any((w) => identical(focusOf(tester, chip(w)), focused)),
      isTrue,
      reason: 'focus should rest on the next word to place',
    );
    await finish(tester);
  });

  testWidgets('a miss leaves the word to try again, with focus on it', (
    tester,
  ) async {
    await pumpGame(tester);
    final word = bankWords(tester).first;
    final wrong = wrongRowFor(tester, word);

    await press(tester, chip(word));
    await press(tester, row(wrong));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Drop target: $wrong, currently has $word (wrong)'),
      findsOneWidget,
    );
    expect(find.text('0 / 3'), findsOneWidget);
    expect(bankWords(tester), contains(word));
    expect(
      identical(
        FocusManager.instance.primaryFocus,
        focusOf(tester, chip(word)),
      ),
      isTrue,
    );
    await finish(tester);
  });

  testWidgets('pressing a picked-up word puts it back down', (tester) async {
    await pumpGame(tester);
    final word = bankWords(tester).first;

    await press(tester, chip(word));
    expect(tester.getSemantics(chip(word)).flagsCollection.isSelected,
        Tristate.isTrue);
    await press(tester, chip(word));

    expect(tester.getSemantics(chip(word)).flagsCollection.isSelected,
        Tristate.isFalse);
    expect(find.bySemanticsLabel(RegExp(r'\. Press to put ')), findsNothing);
    await finish(tester);
  });

  testWidgets('a screen reader plays the whole round by double-tapping', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpGame(tester);

    for (var i = 0; i < 3; i++) {
      final word = bankWords(tester).first;
      final filipino = rowFor(tester, word);
      srTap(tester, chip(word));
      await tester.pump();
      srTap(tester, row(filipino));
      await tester.pump();
      await tester.pump();
    }

    expect(find.text('3 / 3'), findsOneWidget);
    expect(progress.score, 3);
    handle.dispose();
    await finish(tester);
  });

  group('a round never deals two cards with the same word', () {
    test('across the whole seed set: no twin survives', () {
      final dealt = distinctDragDropCards(SeedData.allFlashcards);
      final english = dealt.map((c) => c.wordEnglish.toLowerCase());
      final filipino = dealt.map((c) => c.wordFilipino.toLowerCase());
      expect(english.toSet(), hasLength(dealt.length));
      expect(filipino.toSet(), hasLength(dealt.length));
      // Chicken (Manok) ×2, Walk ×2 and Gabi ×2 lose one each; no other
      // card is dropped.
      expect(dealt, hasLength(SeedData.allFlashcards.length - 3));
    });

    test('whichever twin comes first is the one kept', () {
      final walks = [
        for (final c in SeedData.allFlashcards)
          if (c.wordEnglish == 'Walk') c,
      ];
      expect(walks, hasLength(2));
      expect(distinctDragDropCards(walks), [walks.first]);
      expect(distinctDragDropCards(walks.reversed), [walks.last]);
    });
  });

  testWidgets('a finger can still drag a word onto its row', (tester) async {
    await pumpGame(tester);
    final word = bankWords(tester).first;
    final filipino = rowFor(tester, word);

    final from = tester.getCenter(chip(word));
    final to = tester.getCenter(row(filipino));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Matched: $filipino is $word'),
        findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await finish(tester);
  });
}
