import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/classroom/widgets/learner_accessibility_dialog.dart';

import 'support/screen_matrix.dart';

/// The dialog a Teacher or Parent sets one learner's accessibility needs in
/// (Manage Classes / Home Groups), at every device size and text scale.
/// "Multiple Disabilities" is the long one: it offers all four primary
/// groups and every extra, under a long learner name.
Widget _dialog(DisabilityType type) => Scaffold(
  body: LearnerAccessibilityDialog(
    learnerName: 'Maria Clara Dela Cruz',
    type: type,
    supports: LearnerSupportCatalog.defaultsFor(type),
  ),
);

void main() {
  for (final type in const [
    DisabilityType.multiple,
    DisabilityType.hearing,
    DisabilityType.none,
  ]) {
    testWidgets('${type.name}: the device matrix', (tester) async {
      await expectScreenNoOverflowAcrossDevices(tester, () => _dialog(type));
    });
  }

  testWidgets('multiple: the accessibility themes', (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => _dialog(DisabilityType.multiple),
    );
  });
}
