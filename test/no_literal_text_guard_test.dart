import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words on a screen come from the translations, or are one side of a choice
/// between the two languages. On 4 Nov a scan like this found the Break screen's
/// title, "Last saved", "Retry now" and more, in English on Filipino screens:
/// some only ever show with data from the cloud, where no sweep of the screens
/// could see them.
void main() {
  // `Text('Words…')`, and the same in the other places that reach a person.
  final literal = RegExp(
    r"""(?<![\w.])(?:const\s+)?(?:Text\(\s*|tooltip:\s*|semanticsLabel:\s*|hintText:\s*|labelText:\s*|helperText:\s*)(?:r?)(['"])((?:(?!\1)[^\n])*)\1""",
  );
  final letters = RegExp(r'[A-Za-z]{3,}');
  // Either language is decided near by.
  final choosing = RegExp(
    r"isFilipino|filipino|Filipino|isFil\b|\bfil\b|'fil'|localeName|\bl \?|l10n\?\.|\?\? *$|_t\(context\)\s*\?\?",
  );
  // The same in both languages: the app's and other names, and what a box looks
  // like when it is empty.
  const sameInBoth = <String>{
    'FlashLearn PWD',
    'FlashLearn',
    'FSL',
    'TV',
    'AI Tutor',
    'ABC123',
    'XXXX-XXXX-XX',
    'Home',
    'Select',
    // The minutes, the recording light, a web address's beginning.
    'min',
    'REC',
    'https://…',
  };
  // Not a person's reading: the printed sheets carry their own strings.
  bool skipFile(String path) =>
      path.contains('/l10n/') ||
      path.contains('/debug/') ||
      path.endsWith('.g.dart') ||
      path.contains('/data/local/seed') ||
      path.contains('tv_cast_page');

  test('no screen shows words that skip the translations', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (skipFile(path)) continue;
      final lines = f.readAsLinesSync();
      final source = lines.join('\n');
      for (final m in literal.allMatches(source)) {
        final text = m.group(2)!;
        // What it interpolates is the reader's already.
        // A quote inside an interpolation ended the match early: nothing to
        // read in it.
        if (text.split(r'${').length - 1 > text.split('}').length - 1) continue;
        final words = text.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
        if (!letters.hasMatch(words)) continue;
        if (sameInBoth.contains(words.trim())) continue;
        final line = '\n'.allMatches(source.substring(0, m.start)).length;
        // A comment showing an example.
        if (lines[line].trimLeft().startsWith('//')) continue;
        final from = line - 6 < 0 ? 0 : line - 6;
        final to = line + 7 > lines.length ? lines.length : line + 7;
        if (choosing.hasMatch(lines.sublist(from, to).join('\n'))) continue;
        found.add('$path:${line + 1} $text');
      }
    }
    expect(found, isEmpty);
  });
}
