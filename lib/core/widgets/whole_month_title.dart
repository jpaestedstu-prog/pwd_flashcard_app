import 'package:flutter/material.dart';

/// For `showDatePicker(builder:)`: keeps the month's name whole.
///
/// Flutter's date picker cuts its month title with "…" when the text is large:
/// "Nobyembre 2026" and "Setyembre 2026" lost their year on a phone at the
/// largest Font Size. The picker's own text is held a step below that size;
/// its numbers and buttons stay well readable, and nothing else changes.
Widget wholeMonthTitle(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: child ?? const SizedBox.shrink(),
    );

/// For `showTimePicker(builder:)`: the same step below the largest size. Typing
/// a time ("Lumipat sa text input mode") ran Flutter's own picker 19 px off the
/// bottom of a phone at the largest Font Size.
Widget wholeTimePicker(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: child ?? const SizedBox.shrink(),
    );
