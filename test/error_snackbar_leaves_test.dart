import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';
import 'package:pwdpwdpwd/widgets/error_boundary.dart';

/// "Something went wrong" goes away by itself.
///
/// Since Flutter 3.44 a snack bar with an action stays on screen until the
/// action is tapped. The app's only such message, the generic error with its
/// OK, then stayed over a learner's page for good: on the emulator's test
/// Student it covered the Daily Challenge's answers through three screen
/// changes (9 Nov). It leaves after [errorSnackBarDuration] again, except for
/// someone using a screen reader or switch access, who needs to reach its OK.
void main() {
  Widget app({required bool accessibleNavigation}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(accessibleNavigation: accessibleNavigation),
      child: ErrorBoundary(child: child ?? const SizedBox.shrink()),
    ),
    home: const Scaffold(body: Center(child: Text('A learner page'))),
  );

  final message = find.textContaining('Something went wrong');

  Future<void> raise(WidgetTester tester) async {
    ErrorHandler.report(StateError('a test failure'), null, 'ErrorSnackBarTest');
    await tester.pump(); // the stream delivers it
    await tester.pump(const Duration(milliseconds: 750)); // in
    expect(message, findsOneWidget, reason: 'the message shows');
  }

  testWidgets('it leaves by itself after a few seconds', (tester) async {
    await tester.pumpWidget(app(accessibleNavigation: false));
    await raise(tester);

    await tester.pump(errorSnackBarDuration - const Duration(seconds: 1));
    expect(message, findsOneWidget, reason: 'still there to be read');

    await tester.pump(const Duration(seconds: 1)); // its time is up
    await tester.pump(const Duration(milliseconds: 750)); // out
    expect(
      message,
      findsNothing,
      reason: 'it stayed until OK was tapped (a snack bar with an action '
          'persists unless told not to)',
    );
  });

  testWidgets('with a screen reader it waits for OK', (tester) async {
    await tester.pumpWidget(app(accessibleNavigation: true));
    await raise(tester);

    await tester.pump(errorSnackBarDuration * 3);
    expect(message, findsOneWidget, reason: 'there until its OK is reached');

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(message, findsNothing);
  });
}
