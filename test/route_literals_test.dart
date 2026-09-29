import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every hard-coded route the app navigates to must be one the router knows.
///
/// A typo in a route string compiles, passes every widget test that does not
/// drive that exact path, and fails only on a device: on 2026-09-29 the My Day
/// lock hand-off in main.dart read `go('/routine-locxk')` and the full suite
/// was green. This reads the sources, so it catches the next one wherever it
/// lands.
///
/// It checks the first path segment of each literal (`/routine-lock` of
/// `/routine-lock?x=1`, `/flashcards` of `/flashcards/viewer/$id`) against
/// the top-level `path:` entries in app_router.dart. Literals whose first
/// segment is interpolated are skipped.
void main() {
  test('every go/push route literal names a route the router defines', () {
    final router = File('lib/navigation/app_router.dart').readAsStringSync();
    final defined = RegExp(r"path:\s*'/([a-z0-9-]*)")
        .allMatches(router)
        .map((m) => m.group(1)!)
        .toSet();
    expect(defined, contains('routine-lock'), reason: 'router parse sanity');

    final call = RegExp(
      r"\.(?:go|push|pushReplacement|popOrGo|pushOrSwitchTab|replace)"
      r"(?:<[^>]*>)?\(\s*'/([a-z0-9-]*)",
    );
    final unknown = <String>[];
    var checked = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final m in call.allMatches(source)) {
        final first = m.group(1)!;
        final next = source.length > m.end ? source[m.end] : '';
        if (next == r'$') continue; // interpolated first segment
        checked++;
        if (first.isEmpty) continue; // go('/') — the root
        if (!defined.contains(first)) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          unknown.add('${entity.path}:$line  /$first');
        }
      }
    }
    expect(checked, greaterThan(200), reason: 'scanner found the call sites');
    expect(unknown, isEmpty, reason: 'routes the router does not define');
  });
}
