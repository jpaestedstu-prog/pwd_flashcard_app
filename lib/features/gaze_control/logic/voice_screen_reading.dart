import 'package:flutter/widgets.dart';

import '../../../core/accessibility/focused_label.dart';
import '../../gamepad/providers/gamepad_screen.dart';
import '../../gamepad/providers/gamepad_sections.dart';
import '../providers/gaze_home_grid.dart';
import 'gaze_focus_driver.dart';

/// What a voice user hears after "read the screen".
///
/// The same three sources the game controller's X button reads, in the same
/// order: a screen that describes itself (a quiz's question and its answers),
/// else a hub's tiles, else every control in reading order. Gathered here
/// rather than shared with the controller host because the host decides
/// between them with its own cursor state; voice has none.
String readScreenForVoice({required bool filipino}) {
  if (gamepadScreen.hasContent) {
    return voiceScreenSummary(
      title: gamepadScreen.title ?? gamepadSections.currentLabel ?? '',
      prose: gamepadScreen.narration,
      choices: [
        for (final item in gamepadScreen.items)
          if (item.enabled) item.label,
      ],
      filipino: filipino,
    );
  }
  if (gazeHomeGrid.hasGrid) {
    return voiceScreenSummary(
      title: gamepadSections.currentLabel ?? '',
      prose: const [],
      choices: [
        for (final row in gazeHomeGrid.rows)
          for (final cell in row) cell.label,
        for (final item in gamepadScreen.floating) item.label,
      ],
      filipino: filipino,
    );
  }
  final node = GazeFocusDriver.focused ?? FocusManager.instance.primaryFocus;
  final names = <String>[
    if (node != null && node.context != null)
      for (final control in GazeFocusDriver.readingOrderOf(node))
        if (FocusedLabel.of(control.context) case final label?
            when label.trim().isNotEmpty)
          label.split('\n').first.trim(),
  ];
  return voiceScreenSummary(
    title: gamepadSections.currentLabel ?? '',
    prose: const [],
    choices: names,
    filipino: filipino,
  );
}

/// Most names read in one go; past that, "and N more" (a long monologue
/// that cannot be interrupted is worse than a short list).
const int maxVoiceChoices = 12;

/// The sentence itself: heading, the screen's own words, then what can be
/// said. Pure, so the wording is unit-tested.
String voiceScreenSummary({
  required String title,
  required List<String> prose,
  required List<String> choices,
  required bool filipino,
}) {
  final parts = <String>[];
  final heading = title.trim();
  if (heading.isNotEmpty) parts.add(_sentence(heading));
  for (final line in prose) {
    final text = line.trim();
    if (text.isEmpty || text == heading) continue;
    parts.add(_sentence(text));
  }
  final seen = <String>{};
  final unique = [
    for (final c in choices)
      if (c.trim().isNotEmpty && seen.add(c.trim().toLowerCase())) c.trim(),
  ];
  if (unique.isNotEmpty) {
    final named = unique.take(maxVoiceChoices).join(', ');
    final more = unique.length - maxVoiceChoices;
    final tail = more > 0
        ? (filipino ? ', at $more pa.' : ', and $more more.')
        : '.';
    parts.add(
      filipino ? 'Masasabi mo: $named$tail' : 'You can say: $named$tail',
    );
  }
  if (parts.isEmpty) {
    return filipino
        ? 'Walang mababasa dito.'
        : 'There is nothing to read here.';
  }
  return parts.join(' ');
}

String _sentence(String text) =>
    RegExp(r'[.!?…]$').hasMatch(text) ? text : '$text.';
