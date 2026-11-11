import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/widgets/square_action_button.dart';

/// What a screen reader hears from the square Back / Next / FSL buttons.
///
/// The label used to end in "button" as well as carrying the role: TalkBack
/// said "Back button, button", and in Filipino "Bumalik button, button"
/// (on the tablet, 29 Oct).
void main() {
  Future<void> pump(WidgetTester tester, Widget button) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: button))),
      );

  testWidgets('says its caption once, as a button', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      SquareActionButton(
        icon: Icons.arrow_back_rounded,
        label: 'Back',
        onTap: () => taps++,
      ),
    );
    expect(
      tester.getSemantics(find.byType(SquareActionButton)),
      isSemantics(
        label: 'Back',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    await tester.tap(find.byType(SquareActionButton));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('a description of its own replaces the caption',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      SquareActionButton(
        icon: Icons.sign_language_rounded,
        label: 'FSL',
        semanticLabel: 'Show the sign in Filipino Sign Language',
        onTap: () {},
      ),
    );
    expect(
      find.bySemanticsLabel('Show the sign in Filipino Sign Language'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('button', caseSensitive: false)),
        findsNothing);
    semantics.dispose();
  });
}
