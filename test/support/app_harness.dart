import 'package:flutter/material.dart';
import 'package:pwdpwdpwd/core/theme/form_factor.dart';

/// The `MaterialApp.builder` a layout test wants: the text scale the app would
/// apply, and the control sizes for the screen under test (`main.dart` does
/// the same). One place, so a test measures what a learner gets.
TransitionBuilder harnessBuilder({double textScale = 1.0}) {
  return (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: AdaptiveTheme(child: child ?? const SizedBox.shrink()),
  );
}
