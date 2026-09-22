import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/onboarding/widgets/learner_support_picker.dart';

import '../../support/device_matrix.dart';

/// The block that appears on a Student / Child profile at creation and in Edit
/// Profile: which sign system the learner uses, how they read the screen, how
/// they drive the app.
///
/// The one rule it has to enforce is that a primary mode can be *swapped* but
/// never *cleared* — a Deaf learner with no communication system recorded is
/// worse than one recorded wrongly, because nothing downstream can tell the
/// difference between "none" and "not asked".
void main() {
  Future<Set<LearnerSupportOption>> pumpPicker(
    WidgetTester tester,
    DisabilityType type, {
    Set<LearnerSupportOption>? initial,
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    var selected = initial ?? LearnerSupportCatalog.defaultsFor(type);

    tester.view.physicalSize = (device ?? const Size(1200, 1920)) * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LearnerSupportPicker(
                  disabilityType: type,
                  selected: selected,
                  onChanged: (next) => setState(() => selected = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return selected;
  }

  testWidgets('a Deaf learner is offered FSL, ASL and SEE', (tester) async {
    await pumpPicker(tester, DisabilityType.hearing);

    expect(find.text('Filipino Sign Language (FSL)'), findsOneWidget);
    expect(find.text('American Sign Language (ASL)'), findsOneWidget);
    expect(find.text('Signing Exact English (SEE)'), findsOneWidget);
    expect(find.text('Speech & Lip Reading'), findsOneWidget);
  });

  testWidgets('picking a different sign system swaps, not adds', (
    tester,
  ) async {
    await pumpPicker(tester, DisabilityType.hearing);

    await tester.tap(find.text('American Sign Language (ASL)'));
    await tester.pump();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });

  testWidgets('tapping the chosen mode again does not clear it', (
    tester,
  ) async {
    await pumpPicker(tester, DisabilityType.hearing);

    // A learner must always have one communication system recorded, so the
    // single-choice group ignores a tap on what is already selected.
    await tester.tap(find.text('Filipino Sign Language (FSL)'));
    await tester.pump();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });

  testWidgets('an extra can be added and removed freely', (tester) async {
    await pumpPicker(tester, DisabilityType.hearing);

    expect(find.byIcon(Icons.check_box_rounded), findsNothing);

    await tester.tap(find.text('Extra time on tests'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);

    await tester.tap(find.text('Extra time on tests'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box_rounded), findsNothing);
  });

  testWidgets('every category offers something to configure', (tester) async {
    for (final type in DisabilityType.values) {
      await pumpPicker(tester, type);
      expect(
        find.byType(LearnerSupportPicker),
        findsOneWidget,
        reason: '${type.name} should render a picker',
      );
      expect(
        LearnerSupportCatalog.groupsFor(type),
        isNotEmpty,
        reason: '${type.name} offers no supports at all',
      );
    }
  });

  testWidgets('Multiple Disabilities gets every primary group', (tester) async {
    await pumpPicker(tester, DisabilityType.multiple);

    // A learner who is both Deaf and has low vision needs a communication
    // system *and* a route to the screen; one category cannot carry both.
    expect(find.text('Communication & language'), findsOneWidget);
    expect(find.text('Reading the screen'), findsOneWidget);
    expect(find.text('Controlling the app'), findsOneWidget);
    expect(find.text('Learning support'), findsOneWidget);
  });

  // The tiles stack an emoji, a label and a two-line description beside a
  // trailing control — the shape that bursts on a narrow screen at a big font.
  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('the picker lays out at ${device.label}, ${scale}x text', (
        tester,
      ) async {
        for (final type in DisabilityType.values) {
          await pumpPicker(
            tester,
            type,
            device: device.size,
            dpr: device.devicePixelRatio,
            textScale: scale,
          );

          Object? firstError;
          for (
            Object? e = tester.takeException();
            e != null;
            e = tester.takeException()
          ) {
            firstError ??= e;
          }
          expect(
            firstError,
            isNull,
            reason: '${type.name} at ${device.label} ${scale}x: $firstError',
          );
        }
      });
    }
  }
}
