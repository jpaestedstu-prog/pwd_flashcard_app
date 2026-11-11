import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/source_scan.dart';

/// Every slider names what it sets and says its value in words.
///
/// Flutter's `Slider` gives a screen reader its value bubble (`label:`) as
/// its name: Settings' Font Size slider was "100%", a routine step's length a
/// bare "15", and the controller settings' sliders repeated the row above
/// them. Swiped up or down, TalkBack reads the value the slider moves to from
/// its `semanticFormatterCallback` at once, before the screen rebuilds —
/// beside the old bubble ("65%, 60%"), or as a percentage of the track when
/// there is no formatter ("45%" for a voice speed). Found 29 Oct; the fix is
/// `DpadSliderScope(name: …)` around a slider with a formatter and no bubble,
/// the value shown in its row instead.
///
/// A source scan: most of these sliders sit on screens, or behind switches,
/// that no sweep renders.
void main() {
  test('every slider is named, says its value, and has no bubble', () {
    final found = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.contains('/l10n/')) continue;
      for (final problem in _sliderProblems(file.readAsStringSync())) {
        found.add('$path:$problem');
      }
    }
    expect(found, isEmpty,
        reason: 'wrap the slider in DpadSliderScope(name: …), give it a '
            'semanticFormatterCallback, and show its value in the row '
            'rather than in a bubble');
  });

  test('the scan sees an unnamed slider and a bubble', () {
    const bad = '''
      DpadSliderScope(child: Slider(
        value: v,
        label: '\$v min',
        onChanged: set,
      ))''';
    const fine = '''
      DpadSliderScope(
        name: t.timeLimit,
        child: Slider(
          value: v,
          semanticFormatterCallback: (v) => t.minutes(v.round()),
          onChanged: (v) => set(label: v),
        ),
      )''';
    const loose = '''
      Column(children: [
        Slider(value: v, semanticFormatterCallback: f, onChanged: set),
      ])''';
    expect(_sliderProblems(bad), hasLength(3),
        reason: 'a bubble, no formatter, and no name');
    expect(_sliderProblems(fine), isEmpty,
        reason: 'a label: inside the callback is not the slider\'s');
    expect(_sliderProblems(loose), hasLength(1));
  });
}

/// One entry per thing wrong with each `Slider(` in [source]: "line: why".
List<String> _sliderProblems(String source) {
  final out = <String>[];
  for (final m in RegExp(r'(?<![\w.])Slider\(').allMatches(source)) {
    final line = lineOf(source, m.start);
    final args = namedArgs(source, m.end - 1);
    if (args.contains('label')) {
      out.add('$line: a value bubble (label:), which becomes its name');
    }
    if (!args.contains('semanticFormatterCallback')) {
      out.add('$line: no semanticFormatterCallback, so its value is spoken '
          'as a percentage of the track');
    }
    final scope = enclosingCall(source, m.start, 'DpadSliderScope');
    if (scope == null || !namedArgs(source, scope).contains('name')) {
      out.add('$line: no DpadSliderScope(name: …), so nothing names it');
    }
  }
  return out;
}
