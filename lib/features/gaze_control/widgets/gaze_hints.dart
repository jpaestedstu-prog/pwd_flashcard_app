import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../models/gaze_settings.dart';

/// The one-line instruction every gaze affordance shows — the shell's chip
/// over the tab bar, the traversal ring's chip over a dialog — worded from the
/// learner's own settings: which head moves steer, and what picks.
///
/// A hint that says "blink to open" to a learner whose blinks don't pick, or
/// "look at the screen" to a switch user whose camera is off, is worse than no
/// hint: it sends them looking for a gesture that will never answer.
abstract final class GazeHints {
  /// [rowsReachable]: up and down move between rows here (the hub grid, a
  /// dialog). False on the bare tab bar, where only left/right move.
  static String forSettings(
    BuildContext context,
    GazeSettings s, {
    required bool rowsReachable,
  }) {
    final t = _t(context);
    if (s.scanMode) return scan(t, s);
    final moves = !rowsReachable
        ? t.gzHintMoveTabs
        : (s.lookUpSelects ? t.gzHintMoveNoUp : t.gzHintMove);
    return '$moves · ${pick(t, s)}';
  }

  /// What picks, in head mode.
  static String pick(AppLocalizations t, GazeSettings s) {
    if (s.restSelects) return t.gzHintPickRest;
    if (s.blinkSelects && s.switchSelects) return t.gzHintPickEither;
    if (s.switchSelects) return t.gzHintPickSwitch;
    if (s.blinkSelects) return t.gzHintPickBlink;
    return t.gzHintPickLookUp;
  }

  /// What picks, while scanning.
  static String scan(AppLocalizations t, GazeSettings s) {
    if (s.blinkSelects && s.switchSelects) return t.gzHintScanEither;
    if (s.switchSelects) return t.gzHintScanSwitch;
    return t.gzFocusHintScan;
  }

  static AppLocalizations _t(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();
}
