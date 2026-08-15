import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/navigation/app_page_transitions.dart';
import 'package:pwdpwdpwd/navigation/nav_extensions.dart';

/// Regression guard for **system Back / back-swipe consistency**.
///
/// The reported bug: some features always returned to Home (or to a fixed hub)
/// instead of the screen the learner came from. The cause was `context.go()`,
/// which replaces the whole route stack, being used both to *enter* a feature
/// and to *leave* it — so the launching screen was gone by the time Back fired.
///
/// These tests pin the rule the app now follows:
///   * drill-downs are pushed, so Back retraces them;
///   * exits use [AppNavigation.popOrGo], so they land on the real caller and
///     only fall back to a hub when nothing is on the stack;
///   * bottom-nav tab roots are still switched with `go()` (they cannot be
///     pushed — see [kShellTabRoutes]).
void main() {
  final rootKey = GlobalKey<NavigatorState>();

  /// A miniature of the real router: a ShellRoute with tab roots, an activity
  /// route on the root navigator (like every game), a shell-navigator child
  /// (like /flashcards/create) and a top-level feature (like /recommendations).
  GoRouter buildRouter({String initial = '/home'}) => GoRouter(
        navigatorKey: rootKey,
        initialLocation: initial,
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: child,
              bottomNavigationBar: const SizedBox(height: 40),
            ),
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => AppPageTransitions.fade(
                  key: state.pageKey,
                  child: const Text('home'),
                ),
              ),
              GoRoute(
                path: '/games',
                pageBuilder: (context, state) => AppPageTransitions.fade(
                  key: state.pageKey,
                  child: const Text('games-hub'),
                ),
                routes: [
                  GoRoute(
                    path: 'word-match',
                    parentNavigatorKey: rootKey,
                    pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                      key: state.pageKey,
                      child: Builder(
                        builder: (c) => Center(
                          child: ElevatedButton(
                            // Mirrors every game's onExit / onQuit handler.
                            onPressed: () => c.popOrGo('/games'),
                            child: const Text('exit-game'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/flashcards',
                pageBuilder: (context, state) => AppPageTransitions.fade(
                  key: state.pageKey,
                  child: const Text('deck-list'),
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    pageBuilder: (context, state) =>
                        AppPageTransitions.slideUp(
                      key: state.pageKey,
                      child: const Text('create-card'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/recommendations',
            pageBuilder: (context, state) => AppPageTransitions.slideRight(
              key: state.pageKey,
              child: const Text('recommendations'),
            ),
          ),
        ],
      );

  /// Presses the platform Back button the same way Android does.
  Future<void> pressSystemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('system Back returns to the previous screen', () {
    testWidgets('game launched from the hub goes back to the hub', (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      router.go('/games');
      await t.pumpAndSettle();
      router.push('/games/word-match?difficulty=easy');
      await t.pumpAndSettle();
      expect(find.text('exit-game'), findsOneWidget);

      await pressSystemBack(t);
      expect(find.text('games-hub'), findsOneWidget);
    });

    testWidgets('game launched from a pushed page goes back to THAT page, '
        'not the games hub', (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      // Home -> Recommendations -> game (the lesson-step / recommendation flow)
      router.push('/recommendations');
      await t.pumpAndSettle();
      router.push('/games/word-match?difficulty=easy');
      await t.pumpAndSettle();

      await pressSystemBack(t);
      expect(find.text('recommendations'), findsOneWidget,
          reason: 'must return to the launcher, not the hub');

      await pressSystemBack(t);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('in-game Exit button lands on the launcher too', (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      router.push('/recommendations');
      await t.pumpAndSettle();
      router.push('/games/word-match');
      await t.pumpAndSettle();

      await t.tap(find.text('exit-game'));
      await t.pumpAndSettle();
      expect(find.text('recommendations'), findsOneWidget);
    });

    testWidgets('shell-navigator child pushed from its tab pops back', (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      router.go('/flashcards');
      await t.pumpAndSettle();
      router.push('/flashcards/create');
      await t.pumpAndSettle();
      expect(find.text('create-card'), findsOneWidget);

      await pressSystemBack(t);
      expect(find.text('deck-list'), findsOneWidget);
    });
  });

  group('popOrGo fallback', () {
    testWidgets('falls back to the hub when there is nothing to pop', (t) async {
      // Deep-link straight into the game (a notification / lock hand-off):
      // `go` builds the ancestor chain, so Back still reaches the hub.
      final router = buildRouter(initial: '/games/word-match');
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      await t.tap(find.text('exit-game'));
      await t.pumpAndSettle();
      expect(find.text('games-hub'), findsOneWidget);
    });
  });

  group('kShellTabRoutes', () {
    testWidgets('pushOrSwitchTab switches tabs instead of pushing them',
        (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      router.push('/recommendations');
      await t.pumpAndSettle();

      // The "Keep your streak" recommendation targets /home, a tab root.
      // Pushing it would duplicate the shell page key and assert.
      final ctx = t.element(find.text('recommendations'));
      ctx.pushOrSwitchTab('/home');
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('pushOrSwitchTab pushes a non-tab route', (t) async {
      final router = buildRouter();
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      router.push('/recommendations');
      await t.pumpAndSettle();

      final ctx = t.element(find.text('recommendations'));
      ctx.pushOrSwitchTab('/games/word-match?difficulty=hard');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      await pressSystemBack(t);
      expect(find.text('recommendations'), findsOneWidget);
    });

    test('tab roots are recognised with query strings and sub-paths', () {
      expect(kShellTabRoutes.contains(Uri.parse('/home').path), isTrue);
      expect(kShellTabRoutes.contains(Uri.parse('/home?x=1').path), isTrue);
      expect(
        kShellTabRoutes.contains(Uri.parse('/games/word-match').path),
        isFalse,
        reason: 'activity routes must still be pushed',
      );
    });
  });
}
