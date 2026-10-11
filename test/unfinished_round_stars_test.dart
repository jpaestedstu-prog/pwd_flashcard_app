import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/games/game_pause_mixin.dart';
import 'package:pwdpwdpwd/features/games/screens/drag_drop_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/flashcard_quiz_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/jigsaw_puzzle_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';
import 'package:pwdpwdpwd/features/games/timed_game_mixin.dart';
import 'package:pwdpwdpwd/features/games/unfinished_round_stars.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// A round that ends before it is done earns stars only for what was done.
///
/// Found on the tablet: Memory Match, one flip, "Quit to Games" paid 3 stars
/// (and the 6 XP they carry), because its stars count moves and one move is
/// very few. Jigsaw (efficiency against the optimum for *every* puzzle),
/// Drag & Drop (3 for completing) and the Flashcard Quiz (a star for
/// finishing) paid the same way on a quit or when Beat the Clock ran out.

/// Captures what the game reports instead of touching Hive/Firestore.
class _StubProgressNotifier extends ProgressNotifier {
  int? score;
  int? total;
  int? stars;

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
    this.total = total;
    stars = starsEarned;
  }

  @override
  List<Achievement> checkAchievements() => const [];
}

/// Guest: no spaced repetition, resume point or sync inside the games.
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

void main() {
  group('unfinishedRoundStars', () {
    test('scores against the whole round', () {
      expect(unfinishedRoundStars(0, 8), 0);
      expect(unfinishedRoundStars(1, 8), 0);
      expect(unfinishedRoundStars(4, 8), 1);
      expect(unfinishedRoundStars(6, 8), 2);
      expect(unfinishedRoundStars(7, 8), 2);
      expect(unfinishedRoundStars(9, 10), 3);
    });

    test('an empty round earns nothing', () {
      expect(unfinishedRoundStars(0, 0), 0);
      expect(unfinishedRoundStars(3, 0), 0);
    });
  });

  setUpAll(() async {
    // Wiped before use, never deleted after: a fire-and-forget Hive write in
    // the fake-async zone would stall a teardown delete for minutes.
    final dir = Directory('./build/test_cache/unfinished_round_stars');
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

  final games = <String, Widget Function()>{
    'Memory Match':
        () => const MemoryMatchScreen(difficulty: GameDifficulty.hard),
    'Jigsaw': () => const JigsawPuzzleScreen(difficulty: GameDifficulty.easy),
    'Drag & Drop': () => const DragDropScreen(difficulty: GameDifficulty.easy),
    'Flashcard Quiz':
        () => const FlashcardQuizScreen(difficulty: GameDifficulty.easy),
  };

  late _StubProgressNotifier progress;

  Future<State> pumpGame(WidgetTester tester, Widget screen) async {
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
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump();
    return tester.state(find.byType(screen.runtimeType));
  }

  /// Lets the celebration's one-shot timers run out, then unmounts so the
  /// endless animations dispose.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final game in games.entries) {
    testWidgets('${game.key}: quitting before a move earns no stars',
        (tester) async {
      final state = await pumpGame(tester, game.value());

      // What the pause menu's "Quit to Games" runs.
      // ignore: invalid_use_of_protected_member
      await (state as GamePauseMixin).savePartialProgress();

      expect(progress.stars, 0);
      expect(progress.score, 0);
      await finish(tester);
    });

    testWidgets('${game.key}: the clock running out earns no stars either',
        (tester) async {
      final state = await pumpGame(tester, game.value());

      (state as TimedGameMixin).onTimeUp();
      await tester.pump();

      expect(progress.stars, 0);
      expect(progress.score, 0);
      await finish(tester);
    });
  }
}
