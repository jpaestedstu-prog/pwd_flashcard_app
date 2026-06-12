import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/pronunciation_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/spelling_bee_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

/// Word Hunt focus mode: launching a game with `focusWordId` must play
/// exactly ONE round with that word and award exactly 1 star on a correct
/// answer; the flashcard viewer must show only that one card.

/// Captures what the game reports instead of touching Hive/Firestore.
class _StubProgressNotifier extends ProgressNotifier {
  GameType? gameType;
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
    this.gameType = gameType;
    this.score = score;
    this.total = total;
    stars = starsEarned;
  }

  @override
  List<Achievement> checkAchievements() => const [];
}

/// Guest profile: skips spaced repetition and remote sync inside the games.
class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => null;
}

/// `implements` (not extends) so the real `AudioPlayer()` field initializer
/// never runs — audioplayers needs platform channels.
class _SilentSoundService implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeTtsService extends TtsService {
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
  setUpAll(() async {
    Hive.init('./build/test_cache/word_hunt_focus');
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

  late _StubProgressNotifier progressStub;

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    // 10" tablet portrait so the whole gameplay layout (incl. the answer
    // grid) is on-screen and tappable.
    tester.view.physicalSize = const Size(800, 1280) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    progressStub = _StubProgressNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressProvider.overrideWith(() => progressStub),
          profileProvider.overrideWith(_StubProfileNotifier.new),
          soundServiceProvider.overrideWithValue(_SilentSoundService()),
          ttsServiceProvider.overrideWithValue(_FakeTtsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// Flush celebration/confetti one-shot timers, then unmount so repeating
  /// tickers dispose (same pattern as the screen matrix harness). The
  /// game-over celebration chains delays of several seconds, and
  /// `Future.delayed` timers cannot be cancelled by unmounting — they must
  /// fire (their callbacks no-op via `mounted` checks) before the test ends,
  /// so keep stepping after the unmount too.
  Future<void> settleAndUnmount(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets(
      'Spelling Bee focus mode plays one round and awards exactly 1 star',
      (tester) async {
    // a01 = Dog: three distinct letters, deterministic taps.
    await pumpScreen(
      tester,
      const SpellingBeeScreen(
        difficulty: GameDifficulty.easy,
        categories: [FlashcardCategory.animals],
        focusWordId: 'a01',
      ),
    );

    // Exactly one round.
    expect(find.textContaining('1/1'), findsOneWidget);

    // Spell D-O-G: each tap fills the next slot; the last one auto-checks.
    for (final letter in const ['D', 'O', 'G']) {
      await tester.tap(find.text(letter).first);
      await tester.pump();
    }

    // Correct → 1500 ms delay → game ends with the result dialog.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.byType(GameResultDialog), findsOneWidget);
    expect(progressStub.gameType, GameType.spellingBee);
    expect(progressStub.score, 1);
    expect(progressStub.total, 1);
    expect(progressStub.stars, 1, reason: 'focus mode awards exactly 1 star');

    await settleAndUnmount(tester);
  });

  testWidgets(
      'Pronunciation focus mode plays one round and awards exactly 1 star',
      (tester) async {
    await pumpScreen(
      tester,
      const PronunciationScreen(
        difficulty: GameDifficulty.easy,
        categories: [FlashcardCategory.animals],
        focusWordId: 'a01',
      ),
    );

    // Exactly one round.
    expect(find.textContaining('1/1'), findsOneWidget);

    // Round 0 prompts in English → choices show Filipino; Dog = Aso.
    await tester.tap(find.text('Aso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.byType(GameResultDialog), findsOneWidget);
    expect(progressStub.gameType, GameType.pronunciation);
    expect(progressStub.score, 1);
    expect(progressStub.total, 1);
    expect(progressStub.stars, 1, reason: 'focus mode awards exactly 1 star');

    await settleAndUnmount(tester);
  });

  testWidgets('Flashcard viewer focus mode shows only the one card',
      (tester) async {
    await pumpScreen(
      tester,
      const FlashcardViewerScreen(
        category: FlashcardCategory.classroom,
        focusWordId: 'cr13', // Table
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('1 / 1'), findsOneWidget);
    expect(find.text('Table'), findsWidgets);
    expect(find.text('Chair'), findsNothing);
    expect(find.text('Book'), findsNothing);

    await settleAndUnmount(tester);
  });
}
