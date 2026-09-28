import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/fsl_video_sheet.dart';
import 'package:video_player/video_player.dart';

/// Two dead ends found driving the 1.2.0 release on an emulator.
///
/// 1. A Guest Player has no tab bar, and its home opens Games and Cards with
///    `go()` — tab roots, which cannot be pushed — so nothing sat behind them:
///    no on-screen way home, and system Back closed the app.
/// 2. The FSL sheet waited forever on a clip the device could not decode (the
///    player retries the codec and never errors), shimmering instead of
///    saying the video could not load.

class _StubProfile extends ProfileNotifier {
  _StubProfile({required this.guest});
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
        id: 'guest-test',
        name: 'Guest',
        role: UserRole.player,
        isGuestPlayer: guest,
        createdAt: DateTime(2026),
      );
}

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              BottomNavShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const Text('home-screen'),
            ),
            GoRoute(
              path: '/flashcards',
              builder: (context, state) => const Text('decks-screen'),
            ),
            GoRoute(
              path: '/games',
              builder: (context, state) => const Text('games-screen'),
            ),
          ],
        ),
      ],
    );

/// A player that never finishes opening — what the emulator's decoder did.
class _HangingController extends VideoPlayerController {
  _HangingController() : super.networkUrl(Uri.parse('https://example.com/x.mp4'));

  @override
  Future<void> initialize() => Completer<void>().future;
}

class _HangingSource implements VideoSource {
  @override
  VideoPlayerController createController() => _HangingController();
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/guest_back_and_fsl_timeout');
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
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('Guest Player hubs lead back home', () {
    late GoRouter router;
    late bool appClosed;
    // What the framework last told the engine about Back. On Android's
    // predictive back the engine only delivers Back to Flutter while this is
    // true; handlePopRoute() below skips that gate, so it is asserted apart.
    bool? frameworkHandlesBack;

    Future<void> pumpShell(WidgetTester tester, {required bool guest}) async {
      appClosed = false;
      frameworkHandlesBack = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') appClosed = true;
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            frameworkHandlesBack = call.arguments as bool;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      router = _router();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _StubProfile(guest: guest)),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no Home button on the guest home itself', (tester) async {
      await pumpShell(tester, guest: true);
      expect(find.text('home-screen'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Cards shows a Home button that returns to the guest home',
        (tester) async {
      await pumpShell(tester, guest: true);
      router.go('/flashcards');
      await tester.pumpAndSettle();
      expect(find.text('decks-screen'), findsOneWidget);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Home'));
      await tester.pumpAndSettle();
      expect(find.text('home-screen'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('system Back from Games returns home instead of closing',
        (tester) async {
      await pumpShell(tester, guest: true);
      router.go('/games');
      await tester.pumpAndSettle();
      expect(find.text('games-screen'), findsOneWidget);
      expect(frameworkHandlesBack, isTrue,
          reason: 'else the device never hands Back to the app on a hub');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appClosed, isFalse);
      expect(find.text('home-screen'), findsOneWidget);
      expect(frameworkHandlesBack, isFalse,
          reason: 'on the guest home, Back belongs to the system again');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('system Back on the guest home still leaves the app',
        (tester) async {
      await pumpShell(tester, guest: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appClosed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a Player with Progress keeps its tab bar and no Home button',
        (tester) async {
      await pumpShell(tester, guest: false);
      router.go('/flashcards');
      await tester.pumpAndSettle();
      expect(find.text('decks-screen'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('FSL sheet', () {
    testWidgets('a clip that never opens ends in "Unable to load video"',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FslVideoSheet(
                  videoSource: _HangingSource(),
                  wordEnglish: 'Cat',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Unable to load video'), findsNothing,
          reason: 'still within the time a slow clip is allowed');

      await tester.pump(FslVideoSheet.initTimeout);
      await tester.pump();
      expect(find.text('Unable to load video'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
