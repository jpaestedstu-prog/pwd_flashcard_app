import 'package:flutter/widgets.dart' show Size;

import 'support/dpad_reach_matrix.dart';

/// The same on a phone held sideways, where a window is at its shortest.
void main() => dpadReachMatrix(const Size(640, 360), tag: ' (phone sideways)');
