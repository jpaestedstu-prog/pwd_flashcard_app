import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';

/// The `:silent` suffix is a **claim**, not a mechanism.
///
/// `ErrorHandler.report(e, s, 'Thing:silent')` reads like it suppresses the
/// global "Something went wrong" snackbar, but suppression comes from
/// membership in `_silentSources` alone. A source that names itself `:silent`
/// and is not in that set is the worst of both worlds: the author believed the
/// error was handled quietly, and the learner gets the generic banner anyway.
///
/// That is exactly how all twelve routine paths shipped — a learner ticking a
/// step off "My Day" on a device whose cloud write was refused got
/// "Something went wrong. The app will continue working." on top of the
/// specific, correct explanation `reportRoutineSync` had already given them.
///
/// So the convention is enforced: if a call site says `:silent`, the set has
/// to agree. Deliberately raising a source is still fine — just don't call it
/// `:silent`.
void main() {
  test('every source tagged :silent is actually registered as silent', () {
    final pattern = RegExp(r"'([^']*:silent)'");
    final offenders = <String, Set<String>>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The registry itself quotes every entry; it is the answer, not a caller.
      if (entity.path.replaceAll(r'\', '/').endsWith(
        'core/utils/error_handler.dart',
      )) {
        continue;
      }
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        final source = match.group(1)!;
        if (ErrorHandler.isSilentSource(source)) continue;
        offenders.putIfAbsent(entity.path, () => <String>{}).add(source);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These sources name themselves ":silent" but are missing from '
          'ErrorHandler._silentSources, so they still raise the global error '
          'snackbar. Add them to the set, or drop the ":silent" suffix if the '
          'error really should be shown.',
    );
  });
}
