import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_step_timer.dart';

/// The shared step countdown — on the step screen and on the routine lock.
///
/// Pure widget, no providers: the host owns the finish cue, so this only has
/// to count honestly, say when it is done, and refuse to run in a preview.
Future<List<int>> _pump(
  WidgetTester tester, {
  int minutes = 1,
  bool asBar = false,
  bool enabled = true,
}) async {
  final finishes = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RoutineStepTimer(
            durationMinutes: minutes,
            asBar: asBar,
            filipino: false,
            enabled: enabled,
            onFinished: () => finishes.add(1),
          ),
        ),
      ),
    ),
  );
  return finishes;
}

void main() {
  testWidgets('starts full and counts down once started', (tester) async {
    await _pump(tester, minutes: 2);
    expect(find.text('02:00'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('01:57'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('pausing holds the time, reset puts it back', (tester) async {
    await _pump(tester, minutes: 2);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text('Pause'));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('01:55'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('reaching zero says so and fires the cue exactly once', (
    tester,
  ) async {
    final finishes = await _pump(tester);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Time is up — well done!'), findsOneWidget);
    expect(finishes, hasLength(1));
    // Stopped, so the button offers to go again rather than to pause.
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('a learner who does not read a clock gets a bar', (tester) async {
    await _pump(tester, minutes: 2, asBar: true);
    expect(find.text('02:00'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('an educator preview shows the timer but cannot run it', (
    tester,
  ) async {
    await _pump(tester, minutes: 2, enabled: false);
    await tester.tap(find.text('Start'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('02:00'), findsOneWidget);
  });
}
