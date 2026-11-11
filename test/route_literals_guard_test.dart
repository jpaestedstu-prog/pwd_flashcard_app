import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every route the code asks for by name is one the router has.
///
/// A press of every button found Back on five assessment screens falling back
/// to `/assessment-hub`, and the hub is at `/assessment`: opened with nothing
/// behind it, Back led to the router's error page. A source scan, because most
/// of these buttons sit behind data no sweep has.
final _declared = RegExp(r"path:\s*'([^']+)'");

/// `context.go('/x')`, `context.push('/x/$id')`, `fallbackRoute: '/x'`,
/// `popOrGo('/x')`, `route: '/x'`.
final _asked = RegExp(
  r"""(?:\.go|\.push|\.pushReplacement|\.replace|popOrGo|fallbackRoute:|fallback:)\s*\(?\s*'(/[^']*)'""",
);

RegExp _pattern(String path) => RegExp(
      '^${path.replaceAllMapped(RegExp(r':\w+'), (_) => r'[^/]+')}\$',
    );

void main() {
  test('every route asked for is in the route table', () {
    final router = File('lib/navigation/app_router.dart').readAsStringSync();
    final paths = _declared.allMatches(router).map((m) => m.group(1)!).toList();
    final absolute = paths.where((p) => p.startsWith('/')).toList();
    final relative = paths.where((p) => !p.startsWith('/')).toList();
    final full = [
      ...absolute,
      for (final a in absolute)
        for (final r in relative) ...[
          '${a == '/' ? '' : a}/$r',
          // Nested a level further ('/games' > 'fsl-practice' > 'sign-it').
          for (final deeper in relative) '${a == '/' ? '' : a}/$r/$deeper',
        ],
    ];
    final patterns = [for (final p in full) _pattern(p)];

    final unknown = <String>[];
    var checked = 0;
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.contains('/l10n/')) continue;
      final source = file.readAsStringSync();
      for (final m in _asked.allMatches(source)) {
        final asked = m.group(1)!.split('?').first;
        checked++;
        // Built at run time: what is written must at least start a route.
        final dollar = asked.indexOf(r'$');
        final known = dollar >= 0
            ? full.any((p) => p.startsWith(asked.substring(0, dollar)))
            : patterns.any((p) => p.hasMatch(asked));
        if (!known) unknown.add('$path: ${m.group(1)}');
      }
    }
    expect(checked, greaterThan(100), reason: 'the scan must see the routes');
    expect(unknown, isEmpty);
  });
}
