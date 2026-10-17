import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/navigation/nav_extensions.dart';

/// A screen's own Close, Done or Save goes back — or, with nothing below it,
/// to its hub. Smart Review opened from its reminder (`go('/smart-review')`)
/// and any screen after a browser reload had nothing below, and a plain
/// `context.pop()` threw "There is nothing to pop": it could not be closed.
void main() {
  Widget app(GoRouter router) => MaterialApp.router(routerConfig: router);

  GoRouter router(String initial, List<Object?> results) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  const Text('HOME'),
                  TextButton(
                    onPressed: () async =>
                        results.add(await context.push<Object?>('/review')),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/review',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.popOrGo('/home', 'done'),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      );

  testWidgets('with nothing below, Done lands on the hub instead of throwing',
      (tester) async {
    final r = router('/review', []);
    await tester.pumpWidget(app(r));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('opened from a screen, Done goes back to it with the result',
      (tester) async {
    final results = <Object?>[];
    final r = router('/home', results);
    await tester.pumpWidget(app(r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(results, ['done']);
  });

  test('no screen goes back with a plain context.pop()', () {
    // A dialog's or sheet's own context (ctx, dialogContext…) is fine: it
    // always has its route below. A screen's is not.
    final offenders = <String>[];
    final pop = RegExp(r'\bcontext\.pop\(');
    for (final file in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pop.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'use context.popOrGo(hub, [result]) instead');
  });
}
