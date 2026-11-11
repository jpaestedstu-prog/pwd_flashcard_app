import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A learner, parent or teacher reads plain words when something fails, never
/// the program's own error ("Hindi na-export: MissingPluginException(No
/// implementation found for method getTemporaryDirectory…"), which a press in
/// the Filipino crawl put on screen on 4 Nov. The detail goes to the log.
///
/// A source check, so it also covers the failures a test cannot cause.
void main() {
  final raw = <RegExp>[
    // A translated message handed the error's text: t.certFailed('$e').
    RegExp(r"""\.\w+\(\s*'\$\{?(e|err|error|exception)\}?'\s*\)"""),
    // Or the text of a future or stream's error.
    RegExp(r"""'\$\{\s*(snap|snapshot|async|asyncValue)\.error\s*\}'"""),
    // A snack bar, or an error card, made of it.
    RegExp(r"""message:\s*(e|err|error)\.toString\(\)"""),
    RegExp(r"""Text\(\s*(e|err|error)\.toString\(\)"""),
    RegExp(r"""Text\(\s*'[^'\n]*\$(\{(e|err|error)\}|(e|err|error)\b(?!\.))"""),
  ];

  /// Words about the failure that never reach a screen.
  const notOnScreen = <String>{
    // What the screen maps to words by the failure's kind (join_class_screen,
    // join_home_group_screen, post_join_setup_screen, backup_restore_screen).
    'lib/providers/join_code_provider.dart',
    'lib/providers/home_group_join_provider.dart',
    'lib/core/services/backup_service.dart',
  };

  test('no screen shows a program error', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/') || path.contains('/debug/')) continue;
      if (notOnScreen.contains(path)) continue;
      final source = f.readAsStringSync();
      for (final pattern in raw) {
        for (final m in pattern.allMatches(source)) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          found.add('$path:$line ${m.group(0)}');
        }
      }
    }
    expect(found, isEmpty);
  });

  test('and those three services really do have their words mapped', () {
    for (final screen in const [
      'lib/features/classroom/screens/join_class_screen.dart',
      'lib/features/home_group/screens/join_home_group_screen.dart',
      'lib/features/onboarding/screens/post_join_setup_screen.dart',
    ]) {
      final source = File(screen).readAsStringSync();
      expect(source, contains('JoinCodeError.unknown'), reason: screen);
      expect(source, isNot(contains('failure.message')), reason: screen);
      expect(source, isNot(contains('Failure.message')), reason: screen);
    }
    final restore =
        File('lib/features/settings/screens/backup_restore_screen.dart')
            .readAsStringSync();
    expect(restore, contains('r.message'));
    // The one reading of the service's English sentence: it picks the words.
    expect(RegExp(r'Text\(\s*r\.message').hasMatch(restore), isFalse);
  });
}
