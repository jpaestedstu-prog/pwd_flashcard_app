import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/core/services/xp_level_service.dart';
import 'package:pwdpwdpwd/features/games/widgets/pause_overlay.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_modal_region.dart';
import 'package:pwdpwdpwd/features/stickers/models/sticker_models.dart';
import 'package:pwdpwdpwd/features/stickers/widgets/sticker_unlocked_overlay.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/achievement_overlay.dart';
import 'package:pwdpwdpwd/widgets/fsl_loading_overlay.dart';
import 'package:pwdpwdpwd/widgets/tutorial_overlay.dart';
import 'package:pwdpwdpwd/widgets/level_up_celebration_screen.dart';

import 'support/all_screens.dart';

/// Pop-ups drawn in a screen's own Stack have no route, so nothing but
/// [GazeModalRegion] makes them modal. On the tablet (4 Nov) TalkBack could
/// still reach "Back", the tabs and the stickers under a new sticker's card,
/// where a finger could not.
void main() {
  setUpAll(() => openMemoryBoxes('pop_up_hides_page'));

  Future<void> pump(WidgetTester tester, Widget? popUp) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: [
              Scaffold(
                appBar: AppBar(title: const Text('Page title')),
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Behind'),
                  ),
                ),
              ),
              ?popUp,
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
  }

  final popUps = <String, Widget Function()>{
    'a new sticker': () => StickerUnlockedOverlay(
          stickers: StickerData.allStickers.take(3).toList(),
          isFilipino: false,
          reducedMotion: true,
          onDismiss: () {},
        ),
    'a new achievement': () => AchievementUnlockedOverlay(
          achievements: [Achievements.all.first],
          onDismiss: () {},
        ),
    'a paused game': () => PauseOverlay(
          onResume: () {},
          onRestart: () {},
          onQuit: () async {},
        ),
    // The FSL Dictionary's stars stayed in reach under it (the crawl, 8 Nov).
    'a sign video loading': () => const FslLoadingOverlay(),
  };

  testWidgets('with nothing over it, the page is there for a screen reader',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, null);
    expect(find.semantics.byLabel('Behind'), findsOneWidget);
    expect(find.semantics.byLabel('Page title'), findsOneWidget);
    semantics.dispose();
  });

  for (final MapEntry(key: name, value: build) in popUps.entries) {
    testWidgets('$name hides the page from a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, build());
      expect(find.semantics.byLabel('Behind'), findsNothing);
      expect(find.semantics.byLabel('Page title'), findsNothing);
      semantics.dispose();
    });

    testWidgets('Tab stays inside $name', (tester) async {
      await pump(tester, build());
      expect(find.byType(GazeModalRegion), findsOneWidget);
      final behind = find.ancestor(
        of: find.text('Behind'),
        matching: find.byType(ElevatedButton),
      );
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        expect(
          context != null &&
              find
                  .descendant(of: behind, matching: find.byWidget(context.widget))
                  .evaluate()
                  .isNotEmpty,
          isFalse,
          reason: 'press $i',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  // A hub on the router, as in the app: Back on it leaves the app. With one of
  // these open, it closes the pop-up instead, and then Back is the app's again.
  final closable = <String, Widget Function(VoidCallback)>{
    'a new sticker': (close) => StickerUnlockedOverlay(
          stickers: StickerData.allStickers.take(3).toList(),
          isFilipino: false,
          reducedMotion: true,
          onDismiss: close,
        ),
    'a new achievement': (close) => AchievementUnlockedOverlay(
          achievements: [Achievements.all.first],
          onDismiss: close,
        ),
    'a new level': (close) => LevelUpCelebrationScreen(
          newLevel: const PlayerLevel(
            level: 3,
            title: 'Learner',
            emoji: '🌟',
            xpRequired: 300,
          ),
          reducedMotion: true,
          onDismiss: close,
        ),
    'the first-visit tour': (close) => TutorialOverlay(
          steps: tutorialStepsForRole(UserRole.student),
          onComplete: close,
        ),
  };

  for (final MapEntry(key: name, value: build) in closable.entries) {
    testWidgets('Back closes $name, and goes no further', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var leftTheApp = false;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') leftTheApp = true;
        return null;
      });
      addTearDown(() =>
          messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      var open = true;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => StatefulBuilder(
              builder: (context, setState) => Stack(
                children: [
                  const Scaffold(body: Text('The hub')),
                  if (open) build(() => setState(() => open = false)),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(open, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(open, isFalse);
      expect(leftTheApp, isFalse);
      expect(find.text('The hub'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(leftTheApp, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });
  }

  group('a new sticker', () {
    testWidgets('says what was won once', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, popUps['a new sticker']!());
      final name = StickerData.allStickers.first.nameOf(isFilipino: false);
      expect(find.semantics.byLabel(RegExp('New sticker!')), findsOneWidget);
      expect(find.semantics.byLabel('New Sticker!'), findsNothing);
      expect(find.semantics.byLabel(name), findsNothing);
      expect(find.semantics.byLabel('Next'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Back closes the card and stays on the page', (tester) async {
      var closed = 0;
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('First')),
          routes: {
            '/album': (_) => StatefulBuilder(
                  builder: (context, setState) => Stack(
                    children: [
                      const Scaffold(body: Text('Album')),
                      if (closed == 0)
                        StickerUnlockedOverlay(
                          stickers: StickerData.allStickers.take(3).toList(),
                          isFilipino: false,
                          reducedMotion: true,
                          onDismiss: () => setState(() => closed++),
                        ),
                    ],
                  ),
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/album');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Next'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(closed, 1);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Album'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('First'), findsOneWidget);
    });

    testWidgets('one press goes straight to the album, however many are new',
        (tester) async {
      var closed = 0;
      await pump(
        tester,
        StickerUnlockedOverlay(
          stickers: StickerData.allStickers.take(9).toList(),
          isFilipino: false,
          reducedMotion: true,
          onDismiss: () => closed++,
        ),
      );
      await tester.tap(find.text('Go to the album'));
      await tester.pump();
      expect(closed, 1);
    });
  });

  // The overlay takes the focus while a clip loads, so a controller cannot
  // press the dimmed words. When it goes, the learner's place must come back.
  testWidgets('when a sign video has loaded, the focus is back on the word',
      (tester) async {
    final loading = ValueNotifier<bool>(false);
    addTearDown(loading.dispose);
    final word = FocusNode(debugLabel: 'word');
    addTearDown(word.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (_, on, _) => Stack(
            children: [
              Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(onPressed: () {}, child: const Text('First')),
                    ElevatedButton(
                      focusNode: word,
                      onPressed: () {},
                      child: const Text('Apple'),
                    ),
                  ],
                ),
              ),
              if (on) const FslLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
    word.requestFocus();
    await tester.pump();
    expect(word.hasPrimaryFocus, isTrue);

    loading.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(word.hasFocus, isFalse, reason: 'the overlay holds it while loading');

    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(word.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
