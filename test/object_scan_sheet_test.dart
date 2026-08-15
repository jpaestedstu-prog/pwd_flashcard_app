import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/discovered_word_sheet.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Stubs keep the sheet test free of Hive writes inside testWidgets (the
/// FakeAsync write-queue deadlock) and of TTS platform channels.
class _StubProgressNotifier extends ProgressNotifier {
  int stars = 0;
  int activities = 0;

  @override
  LearningProgress build() {
    profileId = 'test-profile';
    return LearningProgress(
      profileId: 'test-profile',
      lastActivityDate: DateTime(2026),
    );
  }

  @override
  void addStars(int s) => stars += s;

  @override
  void recordDailyActivity() => activities++;
}

class _FakeTtsService extends TtsService {
  final spoken = <String>[];

  @override
  Future<void> speakEnglish(String text) async => spoken.add('en:$text');

  @override
  Future<void> speakFilipino(String text) async => spoken.add('fil:$text');
}

/// Settings stub so the sheet can read `ttsEnabled` (for auto-speak) without
/// opening the Hive settings box inside testWidgets.
class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._ttsEnabled);
  final bool _ttsEnabled;

  @override
  AppSettings build() => AppSettings(ttsEnabled: _ttsEnabled);
}

Flashcard _card(String id) =>
    SeedData.allFlashcards.firstWhere((c) => c.id == id);

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/object_scan_sheet');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  late _StubProgressNotifier progressStub;
  late _FakeTtsService tts;

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Flashcard card,
    bool isNewDiscovery = false,
    bool starAwarded = false,
    // Auto-speak is off by default so the existing button/navigation
    // assertions see only the speech they trigger.
    bool ttsEnabled = false,
    List<Achievement> unlockedAchievements = const [],
  }) async {
    progressStub = _StubProgressNotifier();
    tts = _FakeTtsService();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: DiscoveredWordSheet(
                card: card,
                isNewDiscovery: isNewDiscovery,
                starAwarded: starAwarded,
                unlockedAchievements: unlockedAchievements,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/games/spelling-bee',
          builder: (_, state) => Text(
              'route:spelling:${state.uri.queryParameters['word'] ?? 'none'}'),
        ),
        GoRoute(
          path: '/games/pronunciation',
          builder: (_, state) => Text(
              'route:pronunciation:${state.uri.queryParameters['word'] ?? 'none'}'),
        ),
        GoRoute(
          path: '/learning-path-viewer/:category',
          builder: (_, state) => Text(
              'route:flashcards:${state.pathParameters['category']}'
              ':${state.uri.queryParameters['word'] ?? 'none'}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressProvider.overrideWith(() => progressStub),
          ttsServiceProvider.overrideWithValue(tts),
          settingsProvider.overrideWith(() => _StubSettingsNotifier(ttsEnabled)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the word in English and Filipino with its example',
      (tester) async {
    await pumpSheet(tester, card: _card('cr13'));
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Mesa'), findsOneWidget);
    expect(find.textContaining('The book is on the table.'), findsOneWidget);
  });

  testWidgets('shows the word definition (meaning)', (tester) async {
    await pumpSheet(tester, card: _card('cr13'));
    expect(
      find.textContaining('A table is a piece of furniture'),
      findsOneWidget,
    );
  });

  testWidgets('auto-speaks the English word on open when TTS is enabled',
      (tester) async {
    await pumpSheet(tester, card: _card('cr13'), ttsEnabled: true);
    // Post-frame callback fires the auto-speak after layout.
    await tester.pump();
    expect(tts.spoken, ['en:Table']);
  });

  testWidgets('does not auto-speak when TTS is disabled', (tester) async {
    await pumpSheet(tester, card: _card('cr13'));
    await tester.pump();
    expect(tts.spoken, isEmpty);
  });

  testWidgets('new discovery with a star shows the +1 banner', (tester) async {
    await pumpSheet(
      tester,
      card: _card('f13'),
      isNewDiscovery: true,
      starAwarded: true,
    );
    expect(find.textContaining('New word found! +1'), findsOneWidget);
  });

  testWidgets('new discovery past the star cap shows praise without a star',
      (tester) async {
    await pumpSheet(tester, card: _card('f13'), isNewDiscovery: true);
    expect(find.text('New word found! Great job!'), findsOneWidget);
    expect(find.textContaining('+1'), findsNothing);
  });

  testWidgets('TTS buttons speak the right language and record activity',
      (tester) async {
    await pumpSheet(tester, card: _card('cr13'));

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(tts.spoken.single, startsWith('en:Table'));

    await tester.tap(find.text('Filipino'));
    await tester.pump();
    expect(tts.spoken.last, 'fil:Mesa');
    expect(progressStub.activities, 2);
  });

  testWidgets('spelling button opens a single-word spelling round',
      (tester) async {
    await pumpSheet(tester, card: _card('cr13'));
    await tester.tap(find.text('Spelling Bee'));
    await tester.pumpAndSettle();
    expect(find.text('route:spelling:cr13'), findsOneWidget);
    expect(progressStub.activities, 1);
  });

  testWidgets(
      'hyphenated words fall back to a category spelling round '
      '(letters cannot be scrambled)', (tester) async {
    final tshirt = SeedData.allFlashcards
        .firstWhere((c) => c.wordEnglish == 'T-shirt');
    await pumpSheet(tester, card: tshirt);
    await tester.tap(find.text('Spelling Bee'));
    await tester.pumpAndSettle();
    expect(find.text('route:spelling:none'), findsOneWidget);
  });

  testWidgets('flashcards button opens the viewer focused on the one card',
      (tester) async {
    final card = _card('f14'); // Cup → foodAndDrinks
    await pumpSheet(tester, card: card);
    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    expect(
      find.text('route:flashcards:${card.category.index}:f14'),
      findsOneWidget,
    );
  });

  testWidgets('pronunciation button opens a single-word round',
      (tester) async {
    await pumpSheet(tester, card: _card('cr13'));
    await tester.tap(find.text('Pronunciation Practice'));
    await tester.pumpAndSettle();
    expect(find.text('route:pronunciation:cr13'), findsOneWidget);
  });

  testWidgets('FSL button is hidden for a word without a sign video',
      (tester) async {
    // cr13 (Table) is a new Word Hunt word — no FSL manifest entry exists.
    await pumpSheet(tester, card: _card('cr13'));
    await tester.pump();
    expect(find.text('FSL'), findsNothing);
  });

  testWidgets('celebrates a badge the find just unlocked', (tester) async {
    // Word Hunt has no game-over dialog, so the sheet is where a newly earned
    // badge has to land — otherwise the unlock happens invisibly.
    await pumpSheet(
      tester,
      card: _card('cr13'),
      isNewDiscovery: true,
      starAwarded: true,
      unlockedAchievements: [Achievements.huntFirstFind],
    );
    expect(
      find.text('${Achievements.huntFirstFind.title} unlocked!'),
      findsOneWidget,
    );
  });

  testWidgets('no badge chip when the find unlocked nothing', (tester) async {
    await pumpSheet(tester, card: _card('cr13'), isNewDiscovery: true);
    expect(find.textContaining('unlocked!'), findsNothing);
  });
}
