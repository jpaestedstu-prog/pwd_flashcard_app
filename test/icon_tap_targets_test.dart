import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An icon under a bare tap handler is a control only a sighted pointer user
/// can operate: it has no label for a screen reader, takes no focus (so a
/// switch, gaze or keyboard never reaches it) and is usually far under the
/// 48 dp target. Four had crept in (a note's delete, the Daily Challenge's two
/// speakers, the seasonal banner's close) and were found on the Honor on
/// 13 October 2026. Use an IconButton with a tooltip.
void main() {
  test('no icon is a bare tap target', () {
    final bare = RegExp(
      r'GestureDetector\(\s*onTap:[^\n]*\n(?:[^\n]*\n){0,2}?\s*child: (?:const )?Icon\(',
    );
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            bare.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
