import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/source_scan.dart';

/// Two things that ran off a phone, kept from coming back.
///
/// Every dialog can scroll: 52 of 59 could not, and on a phone on its side at
/// the largest text size the Set PIN dialog ran 132 px past the screen, with
/// nothing to move it. Every dropdown wraps a long name inside its box:
/// a class name ran 372 px off a phone's Export Report screen.
///
/// A source scan: most of these open behind a press that no sweep makes.
final _dialog = RegExp(r'(?<![\w.])AlertDialog(\.adaptive)?\(');
final _dropdown = RegExp(r'(?<![\w.])DropdownButton(FormField)?<[^>]*>\(');

/// Settings' language menu: two short names, in a row's trailing slot, where
/// an expanded button has no width to fill.
const _dropdownsAtTheirOwnSize = {
  'lib/features/settings/screens/settings_screen.dart',
};

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.replaceAll('\\', '/').contains('/l10n/'));

  test('every AlertDialog scrolls', () {
    final found = <String>[];
    var seen = 0;
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final m in _dialog.allMatches(source)) {
        seen++;
        if (!namedArgs(source, m.end - 1).contains('scrollable')) {
          found.add('${file.path}:${lineOf(source, m.start)}');
        }
      }
    }
    expect(seen, greaterThan(50));
    expect(found, isEmpty, reason: 'give it scrollable: true');
  });

  test('every dropdown wraps inside its box', () {
    final found = <String>[];
    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      if (_dropdownsAtTheirOwnSize.contains(path)) continue;
      final source = file.readAsStringSync();
      for (final m in _dropdown.allMatches(source)) {
        if (!namedArgs(source, m.end - 1).contains('isExpanded')) {
          found.add('$path:${lineOf(source, m.start)}');
        }
      }
    }
    expect(found, isEmpty, reason: 'give it isExpanded: true');
  });
}
