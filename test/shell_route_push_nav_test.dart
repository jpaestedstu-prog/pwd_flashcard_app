import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/navigation/app_page_transitions.dart';

/// Regression guard for the Navigator `'!keyReservation.contains(key)'`
/// assertion (duplicate page key).
///
/// With go_router 14, `context.push()` of a route nested inside a ShellRoute
/// while the shell is already on the stack rebuilds the shell page with the
/// same key and crashes. The app hit this when the Word Hunt sheet (over the
/// pushed /object-scan page) and learning-path lesson steps pushed
/// /games/* routes. The fix: game activity routes carry
/// `parentNavigatorKey: rootNavigatorKey` so their pages build on the root
/// navigator — mirrored here by `parentNavigatorKey: rootKey`. If someone
/// removes that from app_router.dart, this test's shape documents why it
/// must come back.
void main() {
  final rootKey = GlobalKey<NavigatorState>();

  GoRouter buildRouter() => GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/home',
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
                  child: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => context.push('/object-scan'),
                        child: const Text('open-scan'),
                      ),
                    ),
                  ),
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
                    path: 'spelling-bee',
                    // The load-bearing line — same as app_router.dart.
                    parentNavigatorKey: rootKey,
                    pageBuilder: (context, state) =>
                        AppPageTransitions.scaleUp(
                      key: state.pageKey,
                      child: const Text('spelling-screen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/object-scan',
            pageBuilder: (context, state) => AppPageTransitions.slideUp(
              key: state.pageKey,
              child: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => Builder(
                        builder: (sheetContext) => ElevatedButton(
                          onPressed: () =>
                              sheetContext.push('/games/spelling-bee?x=1'),
                          child: const Text('to-spelling'),
                        ),
                      ),
                    ),
                    child: const Text('open-sheet'),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  testWidgets(
      'pushing a shell-nested game route from a modal sheet over a pushed '
      'page does not duplicate page keys (Word Hunt flow)', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-scan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'push /object-scan');

    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'open modal sheet');

    await tester.tap(find.text('to-spelling'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'push /games/spelling-bee from sheet');
    expect(find.text('spelling-screen'), findsOneWidget);
  });

  testWidgets(
      'plain push of a shell-nested game route from a pushed page does not '
      'duplicate page keys (lesson step flow)', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-scan'));
    await tester.pumpAndSettle();

    router.push('/games/spelling-bee?x=1');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'plain push, no sheet');
    expect(find.text('spelling-screen'), findsOneWidget);

    // Back pops the game off the root navigator, returning to the
    // pushed page — the behavior Word Hunt and lesson steps rely on.
    router.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'pop back from game');
    expect(find.text('open-sheet'), findsOneWidget);
  });
}
