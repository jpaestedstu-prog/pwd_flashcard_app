import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A control hidden from the screen reader with the drawing around it can no
/// longer be pressed by it.
///
/// `ExcludeSemantics` (or `excludeSemantics: true`) is how the app stops a
/// label being read twice — but whatever is under it is gone for TalkBack,
/// its press too. Found while making every screen read once (29 Oct): the
/// classroom lock warning could be heard and never dismissed, and the sign
/// clip's Replay button could not be reached. Either the press must sit
/// above the exclusion, or the enclosing `Semantics` must carry its own
/// `onTap`.
///
/// A source scan rather than a screen sweep: the two above were on screens
/// no sweep renders.
void main() {
  test('no press is hidden from the screen reader', () {
    final found = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.contains('/l10n/')) continue;
      final source = file.readAsStringSync();
      for (final line in _hiddenPresses(source)) {
        final where = '$path:$line';
        if (!_allowed.contains(where.split(':').first)) found.add(where);
      }
    }
    expect(found, isEmpty,
        reason: 'a screen reader could not press these; put the press above '
            'the exclusion or give the Semantics around it an onTap');
  });

  test('the scan sees a hidden press', () {
    // The scan itself, on the shape of the lock-warning bug.
    const bad = '''
      Semantics(
        label: 'Warning',
        child: ExcludeSemantics(
          child: InkWell(onTap: dismiss, child: Text('x')),
        ),
      )''';
    const fine = '''
      Semantics(
        label: 'Warning',
        onTap: dismiss,
        child: ExcludeSemantics(
          child: InkWell(onTap: dismiss, child: Text('x')),
        ),
      )''';
    // The FSL dictionary tile: its own press above the exclusion (fine),
    // but a favourite toggle inside it (hidden).
    const nested = '''
      Semantics(
        button: true,
        label: 'Dog',
        child: InkResponse(
          onTap: open,
          child: ExcludeSemantics(
            child: Row(children: [
              Text('Dog'),
              IconButton(onPressed: favourite, icon: star),
            ]),
          ),
        ),
      )''';
    expect(_hiddenPresses(bad), isNotEmpty);
    expect(_hiddenPresses(fine), isEmpty);
    expect(_hiddenPresses(nested), isNotEmpty);
  });
}

/// Hidden on purpose: the AI Buddy's scrim (a tap outside the panel closes
/// it; the panel has its own Close button for a screen reader).
const _allowed = {'lib/features/companion/widgets/companion_overlay.dart'};

final _press = RegExp(
  r'\b(InkWell|GestureDetector|DpadGestureDetector|DpadFocusable|InkResponse|'
  r'ElevatedButton|TextButton|OutlinedButton|FilledButton|IconButton|'
  r'FloatingActionButton|Switch|Checkbox|Radio|Slider|TextField|TextFormField|'
  r'ListTile|SwitchListTile|CheckboxListTile|RadioListTile|PopupMenuButton|'
  r'DropdownButton|ChoiceChip|FilterChip|ActionChip|InputChip|Dismissible|'
  r'AppButton|SquareActionButton|DpadInfoStop)\s*(<[^>]*>)?\(',
);
final _onPress = RegExp(r'\bon(Tap|Pressed|Changed|Selected|LongPress)\s*:');
final _outerTap = RegExp(r'\bonTap:\s*(?!null\b)');

/// Lines of [source] where an exclusion covers a press that no enclosing
/// Semantics carries.
List<int> _hiddenPresses(String source) {
  final out = <int>[];
  int lineOf(int at) => '\n'.allMatches(source.substring(0, at)).length + 1;

  for (final m in RegExp(r'\bExcludeSemantics\(').allMatches(source)) {
    final end = _matchParen(source, m.end - 1);
    if (end == null) continue;
    final body = source.substring(m.end, end);
    if (RegExp(r'excluding:\s*(?!true)').hasMatch(
      body.substring(0, body.length < 200 ? body.length : 200),
    )) {
      continue; // decided at run time
    }
    if (!_press.hasMatch(body) && !_onPress.hasMatch(body)) continue;
    final head = _enclosingSemanticsHead(source, m.start);
    if (head != null && _outerTap.hasMatch(head)) continue;
    out.add(lineOf(m.start));
  }
  for (final m in RegExp(r'(?<![\w.])Semantics\(').allMatches(source)) {
    final end = _matchParen(source, m.end - 1);
    if (end == null) continue;
    final body = source.substring(m.end, end);
    if (!RegExp(r'\bexcludeSemantics:\s*true').hasMatch(body)) continue;
    final child = body.indexOf('child:');
    if (child == -1) continue;
    final rest = body.substring(child);
    if (!_press.hasMatch(rest) && !_onPress.hasMatch(rest)) continue;
    if (_outerTap.hasMatch(body.substring(0, child))) continue;
    out.add(lineOf(m.start));
  }
  return out;
}

/// The argument text, up to [at], of the nearest `Semantics(` call that
/// encloses [at].
String? _enclosingSemanticsHead(String s, int at) {
  var k = at;
  while (true) {
    k = s.lastIndexOf('Semantics(', k - 1);
    if (k <= 0) return null;
    final before = s[k - 1];
    if (RegExp(r'[\w]').hasMatch(before)) continue; // ExcludeSemantics(, …
    final end = _matchParen(s, k + 'Semantics'.length);
    if (end == null) return null;
    if (end > at) {
      // Its own arguments only, up to its `child:` — an onTap further down
      // belongs to some widget below it, not to this Semantics.
      final args = s.substring(k, at);
      final child = _topLevelChild(args, 'Semantics('.length);
      return child == -1 ? args : args.substring(0, child);
    }
  }
}

/// Index in [args] of the first `child:` at the call's own depth.
int _topLevelChild(String args, int from) {
  var depth = 0;
  for (var k = from; k < args.length; k++) {
    final c = args[k];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 && args.startsWith('child:', k)) return k;
  }
  return -1;
}

/// Index of the bracket closing the one at [open], skipping strings and
/// comments; null when unbalanced.
int? _matchParen(String s, int open) {
  var depth = 0;
  String? quote;
  var triple = false;
  for (var k = open; k < s.length; k++) {
    final c = s[k];
    if (quote != null) {
      if (c == r'\') {
        k++;
        continue;
      }
      if (triple) {
        if (s.startsWith(quote * 3, k)) {
          quote = null;
          k += 2;
        }
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (s.startsWith('//', k)) {
      final nl = s.indexOf('\n', k);
      if (nl == -1) return null;
      k = nl;
      continue;
    }
    if (s.startsWith('/*', k)) {
      final close = s.indexOf('*/', k);
      if (close == -1) return null;
      k = close + 1;
      continue;
    }
    if (c == "'" || c == '"') {
      triple = s.startsWith(c * 3, k);
      quote = c;
      if (triple) k += 2;
      continue;
    }
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return k;
    }
  }
  return null;
}
