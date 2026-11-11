import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/navigation/text_focus_release.dart';

/// A text box lets go of the focus BEFORE a new screen's first frame.
///
/// In a browser the Name box of the profile form still held the focus as
/// "Let's Go!" opened the next screen. Flutter moves the focus by itself, but
/// only once the new screen is built, a frame late: in that frame the page
/// was told the box was focused, put its hidden field in focus, and removed it
/// a moment later with the old screen. NVDA read that field as "unknown". So
/// what is tested is the focus at the moment the new screen first builds.
void main() {
  late FocusNode field;
  late GlobalKey<NavigatorState> nav;

  Future<void> pumpForm(
    WidgetTester tester, {
    List<NavigatorObserver>? observers,
  }) async {
    field = FocusNode();
    addTearDown(field.dispose);
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: observers ?? [TextFocusReleaseObserver()],
      home: Scaffold(
        body: Column(children: [
          TextField(
            focusNode: field,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          ElevatedButton(onPressed: () {}, child: const Text("Let's Go!")),
        ]),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(field.hasFocus, isTrue);
    // A click on a button leaves the text box focused: buttons take no focus.
    await tester.tap(find.text("Let's Go!"));
    await tester.pump();
    expect(field.hasFocus, isTrue);
  }

  /// A page that notes whether the text box still held the focus as it built.
  Route<void> nextScreen(void Function(bool held) onFirstBuild) {
    var first = true;
    return MaterialPageRoute<void>(builder: (_) {
      if (first) {
        first = false;
        onFirstBuild(field.hasFocus);
      }
      return const Scaffold(body: Text('Next screen'));
    });
  }

  testWidgets('a new screen: the box has let go as it first builds',
      (tester) async {
    await pumpForm(tester);
    bool? held;
    nav.currentState!.push(nextScreen((h) => held = h));
    await tester.pump();
    expect(held, isFalse);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse,
        reason: 'no text input is left open behind the new screen');
  });

  testWidgets('a screen put in its place: the same', (tester) async {
    await pumpForm(tester);
    bool? held;
    nav.currentState!.pushReplacement(nextScreen((h) => held = h));
    await tester.pump();
    expect(held, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Next screen'), findsOneWidget);
  });

  testWidgets('without the observer the box still holds it (the bug)',
      (tester) async {
    await pumpForm(tester, observers: const []);
    bool? held;
    nav.currentState!.push(nextScreen((h) => held = h));
    await tester.pump();
    expect(held, isTrue,
        reason: 'if Flutter ever lets go by itself, the observer can go');
    await tester.pumpAndSettle();
  });

  testWidgets('a pop-up over the form leaves its focus alone, and the focus '
      'comes back to the box', (tester) async {
    await pumpForm(tester);
    bool? heldInPopup;
    showDialog<void>(
      context: nav.currentContext!,
      builder: (context) {
        heldInPopup ??= field.hasFocus;
        return AlertDialog(
          content: const Text('Pick a date'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    await tester.pumpAndSettle();
    expect(heldInPopup, isTrue, reason: 'a pop-up is not a new screen');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(field.hasFocus, isTrue);
  });

  testWidgets('a new screen\'s own text box keeps the focus it opens with',
      (tester) async {
    await pumpForm(tester);
    final other = FocusNode();
    addTearDown(other.dispose);
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: TextField(focusNode: other, autofocus: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(other.hasFocus, isTrue);
  });

  testWidgets('a focus that is not a text box is left alone', (tester) async {
    final button = FocusNode();
    addTearDown(button.dispose);
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [TextFocusReleaseObserver()],
      home: Scaffold(
        body: ElevatedButton(
          focusNode: button,
          onPressed: () {},
          child: const Text('Open'),
        ),
      ),
    ));
    button.requestFocus();
    await tester.pump();
    expect(button.hasFocus, isTrue);
    bool? held;
    var first = true;
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) {
      if (first) {
        first = false;
        held = button.hasFocus;
      }
      return const Scaffold(body: Text('Next'));
    }));
    await tester.pump();
    expect(held, isTrue, reason: 'the route remembers it for the way back');
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(button.hasFocus, isTrue);
  });
}
