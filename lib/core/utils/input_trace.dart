import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../accessibility/focused_label.dart';

/// Traces input, focus and speech to the device log, for checking on a
/// tablet what a learner who cannot see the screen would have heard.
///
/// Off in every published build. A trace build is a release build made with
/// `--dart-define=FLASHLEARN_TRACE_INPUT=true`: a debug build is slow enough
/// to hide the timing a learner meets (a press lost on the first launch after
/// installing only showed at release speed). Debug builds trace the
/// controller as they always did. Read with `adb logcat -s flutter`.
abstract final class InputTrace {
  static const bool _requested = bool.fromEnvironment('FLASHLEARN_TRACE_INPUT');

  /// Whether lines are written at all.
  static bool get on => _requested || kDebugMode;

  static void log(String line) {
    if (on) debugPrint(line);
  }

  /// In a trace build, also logs every focus change by the focused control's
  /// spoken name — where each press of a D-pad, a key or a switch landed.
  static void installFocusLog() {
    if (!_requested) return;
    FocusNode? last;
    FocusManager.instance.addListener(() {
      final node = FocusManager.instance.primaryFocus;
      if (identical(node, last)) return;
      last = node;
      final label = FocusedLabel.of(node?.context);
      debugPrint('InputTrace focus: ${label ?? node?.toStringShort() ?? '-'}');
    });
  }
}
