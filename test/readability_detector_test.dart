import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/readability.dart';

/// Proves the readability detector itself works.
///
/// A guard that silently never fires is worse than no guard, because it reads
/// as a passing check. These cases pin both directions: the detector must fire
/// on text a learner genuinely cannot read, and stay quiet on text that merely
/// wraps or ellipses a little.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double width = 90}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('fires when a word is split across lines', (tester) async {
    // "Pronunciation" cannot fit 90 logical px at this size, so Flutter breaks
    // inside it — the exact Games-hub failure, reproduced.
    await pump(
      tester,
      const Text(
        'Pronunciation Practice',
        style: TextStyle(fontSize: 22),
        maxLines: 2,
      ),
    );

    final issues = findReadabilityIssues(tester);
    expect(issues, isNotEmpty, reason: 'a split word must be reported');
    expect(issues.first.kind, 'word split across lines');
    expect(issues.first.detail, contains('Pronunciation'));
  });

  testWidgets('stays quiet when the same phrase has room', (tester) async {
    await pump(
      tester,
      const Text(
        'Pronunciation Practice',
        style: TextStyle(fontSize: 22),
        maxLines: 2,
      ),
      width: 400,
    );

    expect(findReadabilityIssues(tester), isEmpty);
  });

  // Opt-in, and deliberately so. The test font is a full em per glyph against
  // Nunito's ~0.58, which halves every line's capacity, so left on by default
  // this check fires on any two-line clamp that is perfectly readable in the
  // app. The split check survives that skew because it cross-checks the word
  // against a realistic width; this one has no equivalent escape.
  testWidgets('fires when an ellipsis eats most of the sentence', (
    tester,
  ) async {
    await pump(
      tester,
      const Text(
        'Listen carefully and then pick the correct word from the choices',
        style: TextStyle(fontSize: 20),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      width: 110,
    );

    final issues = findReadabilityIssues(tester, checkEllipsis: true);
    expect(
      issues.any((i) => i.kind == 'ellipsis hides most of the text'),
      isTrue,
      reason: 'a sentence cut to a fragment must be reported',
    );
  });

  testWidgets('stays quiet on a short label that wraps between words', (
    tester,
  ) async {
    await pump(
      tester,
      const Text('Word Match', style: TextStyle(fontSize: 20), maxLines: 2),
    );

    expect(findReadabilityIssues(tester), isEmpty);
  });
}
