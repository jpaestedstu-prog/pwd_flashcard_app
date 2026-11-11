import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every bottom sheet names the area behind it.
///
/// Without a `barrierLabel`, TalkBack reads the dimmed area around a sheet
/// as "Scrim", Material's own word, in English and in Filipino alike. 43 of
/// the app's 45 sheets named it; the routine alert and mood sheets did not
/// (found 3 Nov). This keeps the next sheet from forgetting.
void main() {
  test('every showModalBottomSheet passes a barrierLabel', () {
    final missing = <String>[];
    var sheets = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final calls = RegExp(r'\bshowModalBottomSheet\s*(<[^>]*>)?\s*\(');
      for (final call in calls.allMatches(source)) {
        // The call's own arguments, up to its closing parenthesis.
        var depth = 1;
        var end = call.end;
        while (depth > 0 && end < source.length) {
          final c = source[end];
          if (c == '(') depth++;
          if (c == ')') depth--;
          end++;
        }
        sheets++;
        if (!source.substring(call.end, end).contains('barrierLabel')) {
          final line = '\n'.allMatches(source.substring(0, call.start)).length;
          missing.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(sheets, greaterThan(40), reason: 'the scan found the sheets');
    expect(missing, isEmpty, reason: 'sheets read as "Scrim"');
  });
}
