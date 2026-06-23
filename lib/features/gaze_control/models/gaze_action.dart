import 'package:flutter/widgets.dart';

import 'gaze_models.dart';

/// One gaze-selectable action a screen exposes through `GazeScope`.
///
/// Each binds a [GazeZone] (look up / down / left / right) to a callback, plus
/// the label/icon/colour the overlay draws for it. [enabled] dims the target
/// and blocks selection (e.g. "Previous" on the first card), exactly like the
/// matching touch button.
class GazeAction {
  final GazeZone zone;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onSelect;
  final bool enabled;

  const GazeAction({
    required this.zone,
    required this.label,
    required this.icon,
    required this.color,
    required this.onSelect,
    this.enabled = true,
  });
}
