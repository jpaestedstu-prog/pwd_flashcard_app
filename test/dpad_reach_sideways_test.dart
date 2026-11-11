import 'package:flutter/widgets.dart' show Size;

import 'support/dpad_reach_matrix.dart';

/// The same on the Honor held sideways, where a tall card's middle lies past the
/// tab bar's: ▼ used to leave the column for a tab or the guest's Home button.
void main() => dpadReachMatrix(const Size(1097, 608), tag: ' (tablet sideways)');
