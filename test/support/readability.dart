/// Guards against text that *fits its box* but is still unreadable.
///
/// The 24 overflow suites in this directory all answer one question: does the
/// content burst its container? That misses the opposite failure, which is what
/// large-text learners actually hit — the text fits perfectly and is ruined
/// anyway:
///
///   * **A word split across two lines.** Flutter breaks *inside* a word when
///     the word alone is wider than the line. The Games hub rendered
///     "Pronunciat / ion Practi…" at the Visual Impairment preset's 1.4x for as
///     long as that screen had existed, and no overflow test could see it,
///     because nothing overflowed.
///   * **An ellipsis that eats the meaning.** "Listen and pick the cor…" is
///     laid out correctly and tells the learner nothing.
///
/// Both are read from the *rendered* geometry rather than the source string, so
/// they catch the real break positions at a real width and text scale.
///
/// ### The test font is not the app's font
///
/// `flutter test` renders with a test font whose every glyph is a **full em
/// wide**. Real Nunito averages closer to 0.58 em, so a 167 px column holds
/// about 12 characters here and about 24 on the device. Taken literally that
/// makes every finding a false positive: text wraps in the test that has ample
/// room in the app.
///
/// So a split is only reported when the word would *also* fail at a realistic
/// glyph width. The rendered line break says a break happened; the width
/// estimate says whether it would happen to a learner. Both have to agree.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single readability problem found in the rendered tree.
class ReadabilityIssue {
  ReadabilityIssue(this.kind, this.text, this.detail);

  final String kind;
  final String text;
  final String detail;

  @override
  String toString() => '$kind — "$text"  ($detail)';
}

final RegExp _word = RegExp(r'[A-Za-z0-9À-ɏ]');

bool _isWordChar(String c) => c.isNotEmpty && _word.hasMatch(c);

/// The y-centre of each rendered line, derived from selection boxes.
///
/// `RenderParagraph` has no `computeLineMetrics` in this Flutter version, but
/// the selection boxes for the whole string are grouped by line, so distinct
/// `top` values are the lines.
List<({double top, double bottom, double left, double right})> _lines(
  RenderParagraph rp,
  int length,
) {
  final boxes = rp.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  final out = <({double top, double bottom, double left, double right})>[];
  for (final b in boxes) {
    final existing = out.indexWhere((l) => (l.top - b.top).abs() < 0.5);
    if (existing == -1) {
      out.add((top: b.top, bottom: b.bottom, left: b.left, right: b.right));
    } else {
      final l = out[existing];
      out[existing] = (
        top: l.top,
        bottom: l.bottom > b.bottom ? l.bottom : b.bottom,
        left: l.left < b.left ? l.left : b.left,
        right: l.right > b.right ? l.right : b.right,
      );
    }
  }
  out.sort((a, b) => a.top.compareTo(b.top));
  return out;
}

/// The widget ancestry that produced [rp], trimmed to the informative part.
///
/// A finding is only useful if you can find the widget. The creator chain names
/// the enclosing private classes (`_DropTargetRow`, `_StatChip`), which is
/// enough to grep straight to the file instead of hunting for the string.
String _creator(RenderParagraph rp) {
  final c = rp.debugCreator;
  if (c == null) return '';
  final chain = c
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split('←') // the "left arrow" separator in a creator chain
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  // Keep the first few, plus the first private (app-owned) class in the chain.
  final head = chain.take(3).toList();
  final owner = chain.firstWhere(
    (e) => e.startsWith('_') && !head.contains(e),
    orElse: () => '',
  );
  if (owner.isNotEmpty) head.add(owner);
  return head.join(' < ');
}

/// Every readability problem in the currently-pumped tree.
///
/// [minWordLength] ignores breaks inside very short tokens, which are nearly
/// always an emoji or icon-font glyph rather than a word a learner must read.
List<ReadabilityIssue> findReadabilityIssues(
  WidgetTester tester, {
  int minWordLength = 5,
  bool checkEllipsis = false,
}) {
  final issues = <ReadabilityIssue>[];
  final seen = <String>{};

  for (final rp in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (!rp.hasSize || rp.size.isEmpty) continue;
    final plain = rp.text.toPlainText(includeSemanticsLabels: false);
    if (plain.trim().length < 2) continue;

    final List<({double top, double bottom, double left, double right})> lines;
    try {
      lines = _lines(rp, plain.length);
    } catch (_) {
      continue; // Not laid out; nothing to judge.
    }
    if (lines.isEmpty) continue;

    // --- 1. a word broken across a line boundary -------------------------
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      final pos = rp.getPositionForOffset(
        Offset(line.left + 0.01, (line.top + line.bottom) / 2),
      );
      final at = pos.offset;
      if (at <= 0 || at >= plain.length) continue;
      if (!_isWordChar(plain[at - 1]) || !_isWordChar(plain[at])) continue;

      var s = at - 1;
      while (s > 0 && _isWordChar(plain[s - 1])) {
        s--;
      }
      var e = at;
      while (e < plain.length && _isWordChar(plain[e])) {
        e++;
      }
      final word = plain.substring(s, e);
      if (word.length < minWordLength) continue;

      // Would this word still not fit in the app's own font? The test font is
      // ~1 em per glyph against Nunito's ~0.58, so without this every wrapped
      // line reads as a defect.
      final fontSize = rp.textScaler.scale(rp.text.style?.fontSize ?? 14.0);
      final realistic = word.length * 0.58 * fontSize;
      // Compare against the width the paragraph was GIVEN, not the widest line
      // it produced. When a word breaks badly every rendered line is narrow, so
      // measuring the lines would compare the failure against itself and report
      // words that have ample room in the app's real font.
      final available = rp.constraints.maxWidth.isFinite
          ? rp.constraints.maxWidth
          : rp.size.width;
      if (realistic <= available) continue;
      final key = 'split|$word|${plain.hashCode}';
      if (!seen.add(key)) continue;
      final where = _creator(rp);
      issues.add(
        ReadabilityIssue(
          'word split across lines',
          plain.length > 60 ? '${plain.substring(0, 60)}…' : plain,
          '"$word" breaks as '
              '"${plain.substring(s, at)} / ${plain.substring(at, e)}"'
              '${where.isEmpty ? '' : '  in $where'}',
        ),
      );
    }

    // --- 2. an ellipsis that removed most of the sentence -----------------
    if (checkEllipsis &&
        rp.overflow == TextOverflow.ellipsis &&
        rp.maxLines != null &&
        lines.length >= rp.maxLines! &&
        plain.length > 24) {
      final last = lines.last;
      final endPos = rp.getPositionForOffset(
        Offset(last.right, (last.top + last.bottom) / 2),
      );
      final shown = endPos.offset;
      if (shown > 0 && shown < plain.length * 0.7) {
        final key = 'cut|${plain.hashCode}';
        if (seen.add(key)) {
          issues.add(
            ReadabilityIssue(
              'ellipsis hides most of the text',
              plain.length > 60 ? '${plain.substring(0, 60)}…' : plain,
              'about $shown of ${plain.length} characters visible',
            ),
          );
        }
      }
    }
  }
  return issues;
}

/// Fails listing every readability problem, or passes silently.
void expectReadable(
  WidgetTester tester, {
  String? at,
  int minWordLength = 5,
  bool checkEllipsis = false,
}) {
  final issues = findReadabilityIssues(
    tester,
    minWordLength: minWordLength,
    checkEllipsis: checkEllipsis,
  );
  if (issues.isEmpty) return;
  fail(
    'Unreadable text${at == null ? '' : ' at $at'}:\n'
    '${issues.map((i) => '  • $i').join('\n')}',
  );
}
