import 'package:flutter/widgets.dart';

/// Control heights that grow with the learner's text size.
///
/// A button written as `SizedBox(height: 56, child: FilledButton(...))` keeps
/// that 56 logical pixels however large the text inside it becomes. The app
/// multiplies the learner's Font Size setting by the OS scale and clamps the
/// product at 1.5 (`main.dart`), and the **Visual Impairment preset alone sets
/// 1.4** — so exactly the learners who need the biggest text got labels with
/// their lower halves sliced off ("Show Answer" on Smart Review, "Magpatuloy"
/// in the accessibility wizard, "Add New Profile" on the switcher).
///
/// Scaling the box by the same scaler the text uses keeps the label whole. The
/// button grows taller on a large-text profile, which is the correct trade: a
/// tall button is usable, a clipped one is not.
double scaledControlHeight(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);
