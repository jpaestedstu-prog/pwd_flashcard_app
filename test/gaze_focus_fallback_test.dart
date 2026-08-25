import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';

/// Regression cover for `GazeFocusDriver.move`'s reading-order fallback.
///
/// Directional traversal is the right first answer for a D-pad — "the control
/// below this one" is what a learner means. But it is *geometric*, and it will
/// not cross a scroll boundary into a pinned footer. On the game category
/// picker that left a hands-free learner stuck: they reached the last category
/// and simply stopped, because the "Start" button underneath was unreachable.
///
/// So when geometry finds nothing, `move` falls back to reading order
/// (`nextFocus` / `previousFocus`), which has no such blind spot.
void main() {
  /// Two nodes side by side. Nothing is above or below either one, so
  /// `focusInDirection(down)` must fail — which is exactly the situation the
  /// fallback exists for. Reading order still runs left → right.
  Widget row(FocusNode a, FocusNode b) => MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          Focus(focusNode: a, child: const SizedBox(width: 50, height: 50)),
          Focus(focusNode: b, child: const SizedBox(width: 50, height: 50)),
        ],
      ),
    ),
  );

  testWidgets('geometry first: down reaches the control below', (tester) async {
    final a = FocusNode(debugLabel: 'a');
    final b = FocusNode(debugLabel: 'b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: a, child: const SizedBox(width: 50, height: 50)),
              Focus(focusNode: b, child: const SizedBox(width: 50, height: 50)),
            ],
          ),
        ),
      ),
    );
    a.requestFocus();
    await tester.pump();

    expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
    await tester.pump();
    expect(b.hasPrimaryFocus, isTrue);
  });

  testWidgets('falls back to reading order when nothing is below', (
    tester,
  ) async {
    // Without the fallback this returns false and focus never leaves `a` — the
    // dead end that stranded learners on the category picker.
    final a = FocusNode(debugLabel: 'a');
    final b = FocusNode(debugLabel: 'b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(row(a, b));
    a.requestFocus();
    await tester.pump();

    expect(
      GazeFocusDriver.move(TraversalDirection.down),
      isTrue,
      reason: 'geometry fails here, so reading order must carry it',
    );
    await tester.pump();
    expect(b.hasPrimaryFocus, isTrue);
  });

  testWidgets('backwards directions fall back to the previous control', (
    tester,
  ) async {
    final a = FocusNode(debugLabel: 'a');
    final b = FocusNode(debugLabel: 'b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(row(a, b));
    b.requestFocus();
    await tester.pump();

    // Up is a *backward* direction, so the fallback must step backwards — going
    // forwards would move the learner further from where they came.
    expect(GazeFocusDriver.move(TraversalDirection.up), isTrue);
    await tester.pump();
    expect(a.hasPrimaryFocus, isTrue);
  });

  testWidgets('reaches a footer button across a scroll boundary', (
    tester,
  ) async {
    // The end state the fix has to guarantee, in the layout the bug appeared
    // in: a scrollable list of options with a pinned action button underneath,
    // like the game category picker. (Geometry alone can satisfy this in a
    // synthetic tree — the two Row cases above are what pin the fallback
    // itself.)
    final last = FocusNode(debugLabel: 'last-option');
    final start = FocusNode(debugLabel: 'start');
    addTearDown(last.dispose);
    addTearDown(start.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < 12; i++)
                      const SizedBox(height: 80, child: Text('option')),
                    Focus(
                      focusNode: last,
                      child: const SizedBox(height: 80, width: 200),
                    ),
                  ],
                ),
              ),
              Focus(
                focusNode: start,
                child: const SizedBox(height: 60, width: 200),
              ),
            ],
          ),
        ),
      ),
    );
    last.requestFocus();
    await tester.pumpAndSettle();

    expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
    await tester.pumpAndSettle();
    expect(
      start.hasPrimaryFocus,
      isTrue,
      reason:
          'the pinned footer must be reachable, or the screen is a dead end',
    );
  });
}
