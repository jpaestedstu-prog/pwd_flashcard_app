import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words never take a raw palette colour.
///
/// The palette is pastel on purpose, and pastel words are unreadable: green
/// "Shared" on the media tile, a red wrong answer on its pink tile, a gold
/// "late" — each about 2:1. The contrast sweep only measures what a screen
/// shows when a suite renders it, so text that changes colour after an
/// answer, when something is shared or when a step runs late slipped past it
/// (found on a tablet). Those words go through the theme instead —
/// `HCColor.successText` and friends, `HCColor.primary`, or
/// `readableOver(colour, ground)` for a tinted tile — and this keeps them
/// there. Icons the same way, at the 3:1 WCAG asks of a meaningful graphic
/// (`HCColor.graphic`): a yellow warning sign was 1.4:1 on white.

final _raw = RegExp(
  r'AppColors\.(success|warning|error|info|primary|secondary|accent)\b(?![.(\w])',
);

/// Words coloured straight from a score/status helper or a fixed hex: the
/// green "100%" and orange "Pending" of Assignment Tracking were 2-3:1.
final _rawWords = RegExp(r'^\s*(?:const\s+)?(?:_\w+\(|Color\(0x)');

/// The `color:` of a text style.
final _style = RegExp(
  r'(?:copyWith\(|TextStyle\()(?:[^()]|\([^()]*\))*?\bcolor:\s*',
  dotAll: true,
);

/// The `color:` of an icon — a tick or a warning sign carries meaning, and
/// WCAG asks 3:1 of it (`HCColor.graphic`).
final _icon = RegExp(
  r'\bIcon\((?:[^()]|\([^()]*\))*?\bcolor:\s*',
  dotAll: true,
);

/// A helper that makes a colour readable; a raw colour handed to one is fine.
final _helper = RegExp(r'\b(?:readable\w*|fillFor|bestOn|graphic)\(');

/// The expression starting at [from]: up to the first comma or closing
/// bracket outside any brackets of its own.
String _expression(String src, int from) {
  var depth = 0;
  for (var i = from; i < src.length; i++) {
    final c = src[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return src.substring(from, i);
      depth--;
    }
    if ((c == ',' || c == ';') && depth == 0) return src.substring(from, i);
  }
  return src.substring(from);
}

/// [expr] without the calls to the readable-colour helpers.
String _withoutHelpers(String expr) {
  var out = expr;
  for (var m = _helper.firstMatch(out); m != null; m = _helper.firstMatch(out)) {
    final args = _expression(out, m.end);
    final close = (m.end + args.length + 1).clamp(0, out.length);
    out = out.replaceRange(m.start, close, 'ok');
  }
  return out;
}

/// A variable that colours words, set to a raw palette colour.
final _wordVar = RegExp(
  r'\b(?:text|label|title|value|word|fg|foreground)\w*\s*=\s*(?:const\s+)?'
  r'AppColors\.(?:success|warning|error|info|primary|secondary|accent)\b(?![.(\w])',
  caseSensitive: false,
);

/// Files that paint another palette on purpose (a preview of a theme).
const _allowed = {
  'lib/core/theme/app_colors.dart',
  'lib/core/theme/app_theme.dart',
  'lib/core/theme/accessible_theme.dart',
  'lib/widgets/theme_preview_card.dart',
};

void main() {
  test('no text or icon is coloured with a raw palette colour', () {
    final found = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (_allowed.contains(path) || path.contains('/l10n/')) continue;
      final src = file.readAsStringSync();
      // A PDF prints on white paper, in its own colours.
      final pdf = src.contains('package:pdf/');
      String at(int offset) =>
          '$path:${'\n'.allMatches(src.substring(0, offset)).length + 1}';
      for (final m in [..._style.allMatches(src), ..._icon.allMatches(src)]) {
        final colour = _withoutHelpers(_expression(src, m.end));
        if (_raw.hasMatch(colour)) found.add(at(m.end));
        if (!pdf && identical(m.pattern, _style) &&
            _rawWords.hasMatch(colour)) {
          found.add(at(m.end));
        }
      }
      for (final m in _wordVar.allMatches(src)) {
        found.add(at(m.start));
      }
    }
    expect(
      found,
      isEmpty,
      reason:
          'Colour words with HCColor (successText, errorText, warningText, '
          'infoText, primary) or readableOver(colour, ground):\n'
          '${found.join('\n')}',
    );
  });
}
