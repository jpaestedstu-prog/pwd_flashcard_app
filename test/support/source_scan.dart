/// Small readers of the app's Dart source, for the guard tests that scan it
/// (`excluded_taps_guard_test.dart`, `slider_names_guard_test.dart`).
library;

/// The 1-based line of [at] in [s].
int lineOf(String s, int at) => '\n'.allMatches(s.substring(0, at)).length + 1;

/// Index of the bracket closing the one at [open], skipping strings and
/// comments; null when unbalanced.
int? matchParen(String s, int open) {
  var depth = 0;
  for (var k = open; k < s.length; k++) {
    final skipped = _skip(s, k);
    if (skipped == null) return null;
    if (skipped != k) {
      k = skipped - 1;
      continue;
    }
    final c = s[k];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return k;
    }
  }
  return null;
}

/// The names of the named arguments of the call whose `(` is at [open] —
/// its own, not those of the calls nested in it.
Set<String> namedArgs(String s, int open) {
  final close = matchParen(s, open);
  if (close == null) return const {};
  final names = <String>{};
  var depth = 0;
  var argStart = true;
  for (var k = open + 1; k < close; k++) {
    final skipped = _skip(s, k);
    if (skipped == null) break;
    if (skipped != k) {
      // A string ends an argument's start; a comment before one does not.
      if (s[k] == "'" || s[k] == '"') argStart = false;
      k = skipped - 1;
      continue;
    }
    final c = s[k];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
      argStart = false;
      continue;
    }
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      continue;
    }
    if (depth != 0) continue;
    if (c == ',') {
      argStart = true;
      continue;
    }
    if (!argStart || c.trim().isEmpty) continue;
    final name = _namedArg.matchAsPrefix(s, k);
    if (name != null) names.add(name.group(1)!);
    argStart = false;
  }
  return names;
}

/// Index of the `(` of the nearest call to [callee] (`'DpadSliderScope'`)
/// whose arguments enclose [at], or null.
int? enclosingCall(String s, int at, String callee) {
  final pattern = RegExp('(?<![\\w.])${RegExp.escape(callee)}\\(');
  int? best;
  for (final m in pattern.allMatches(s.substring(0, at))) {
    final open = m.end - 1;
    final close = matchParen(s, open);
    if (close != null && close > at) best = open;
  }
  return best;
}

final _namedArg = RegExp(r'([A-Za-z_]\w*)\s*:(?!:)');

/// Index just past the string literal or comment that starts at [k], [k]
/// itself when none does, or null when it never ends.
int? _skip(String s, int k) {
  if (s.startsWith('//', k)) {
    final nl = s.indexOf('\n', k);
    return nl == -1 ? s.length : nl;
  }
  if (s.startsWith('/*', k)) {
    final close = s.indexOf('*/', k);
    return close == -1 ? null : close + 2;
  }
  final c = s[k];
  if (c != "'" && c != '"') return k;
  final raw = k > 0 && s[k - 1] == 'r';
  final triple = s.startsWith(c * 3, k);
  final end = triple ? c * 3 : c;
  for (var j = k + end.length; j < s.length; j++) {
    if (!raw && s[j] == r'\') {
      j++;
      continue;
    }
    if (s.startsWith(end, j)) return j + end.length;
  }
  return null;
}
