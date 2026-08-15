import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/games/screens/drag_drop_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/first_letter_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/odd_one_out_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/yes_or_no_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/flashcard_quiz_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/jigsaw_puzzle_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/picture_word_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/pronunciation_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/sentence_builder_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/spelling_bee_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/tracing_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/word_match_screen.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The full tablet matrix minus the 360 px-tall phone-landscape viewport.
/// Used for the portrait swipe-card game (FlashcardQuiz): a portrait card with
/// large, accessible swipe buttons is designed for tablet/portrait vertical
/// room — landscape on a short phone is "not applicable" for it. Every tablet
/// size + orientation, plus phone portrait, at up to 2.0× font, is still
/// covered.
final List<DeviceSize> _tabletAndPortrait =
    kTabletMatrix.where((d) => d.label != 'phone landscape').toList();

/// Overflow matrix for the in-game **play** screens. Each is rendered at its
/// first gameplay frame (round 0) across every tablet size × orientation ×
/// accessibility font scale and asserted to lay out without an overflow.
///
/// The hardest difficulty is used everywhere because it produces the densest
/// layouts — the most answer choices, the longest sentences, the biggest
/// memory board — which is where a fixed-grid cell or status row bursts.
///
/// `timedMode: false` keeps `initState` free of the countdown `Timer.periodic`
/// (see `TimedGameMixin`), so the only async is one-shot entrance animations,
/// which the harness flushes on teardown.

const _hard = GameDifficulty.hard;

void main() {
  // The play screens read Hive-backed providers only in tap/save callbacks, but
  // open the standard app boxes up front so any lazily-created provider during
  // the first build has a backing store and never throws.
  setUpAll(() async {
    Hive.init('./build/test_cache/games_screens');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('WordMatchScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const WordMatchScreen(difficulty: _hard),
    );
  });

  testWidgets('SpellingBeeScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const SpellingBeeScreen(difficulty: _hard),
    );
  });

  testWidgets('DragDropScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const DragDropScreen(difficulty: _hard),
    );
  });

  testWidgets('SentenceBuilderScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const SentenceBuilderScreen(difficulty: _hard),
    );
  });

  testWidgets('PictureWordScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const PictureWordScreen(difficulty: _hard),
    );
  });

  testWidgets('MemoryMatchScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const MemoryMatchScreen(difficulty: _hard),
    );
  });

  testWidgets('FlashcardQuizScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const FlashcardQuizScreen(difficulty: _hard),
      devices: _tabletAndPortrait,
    );
  });

  testWidgets('JigsawPuzzleScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const JigsawPuzzleScreen(difficulty: _hard),
    );
  });

  testWidgets('TracingScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const TracingScreen(difficulty: _hard),
    );
  });

  testWidgets('PronunciationScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const PronunciationScreen(difficulty: _hard),
    );
  });

  testWidgets('YesOrNoScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const YesOrNoScreen(difficulty: _hard),
    );
  });

  testWidgets('OddOneOutScreen first frame survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const OddOneOutScreen(difficulty: _hard),
    );
  });

  testWidgets('FirstLetterScreen first frame survives the device matrix',
      (tester) async {
    // Hard offers six letter tiles — the densest answer grid of the three.
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const FirstLetterScreen(difficulty: _hard),
    );
  });
}
