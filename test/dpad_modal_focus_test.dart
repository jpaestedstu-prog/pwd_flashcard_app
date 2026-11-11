import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_modal_region.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/navigation/dpad_modal_focus.dart';

/// A pop-up opens with its first control focused.
///
/// Flutter focuses a new dialog's scope but nothing inside it, so a D-pad's
/// first press — a remote's OK, a switch, Enter — fell on the empty scope and
/// did nothing. The Daily Reward dialog that greets a learner every morning
/// took two presses to collect.

final _navigator = GlobalKey<NavigatorState>();

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigator,
      shortcuts: dpadShortcuts,
      actions: dpadActions,
      home: const Scaffold(body: Center(child: Text('Home'))),
    ),
  );
}

BuildContext get _context => _navigator.currentContext!;

/// The label of the control that holds focus, read off its text; null while
/// a scope holds it (nothing inside focused).
String? _focusedText(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus;
  if (node is FocusScopeNode) return null;
  final context = node?.context;
  if (context == null) return null;
  String? text;
  void visit(Element e) {
    if (text != null) return;
    final w = e.widget;
    if (w is Text) {
      text = w.data;
      return;
    }
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return text;
}

void main() {
  // Per test: each test has a focus manager of its own.
  setUp(DpadModalFocus.install);

  testWidgets('the Daily Reward dialog collects on the first press', (
    tester,
  ) async {
    // Its shape: one control, the reward itself.
    await _pumpApp(tester);
    var collected = 0;
    showDialog<void>(
      context: _context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Reward!'),
        content: const Text('Day 1'),
        actions: [
          FilledButton(
            onPressed: () {
              collected++;
              Navigator.pop(ctx);
            },
            child: const Text('Collect!'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_focusedText(tester), 'Collect!');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(collected, 1);
    expect(find.text('Daily Reward!'), findsNothing);
  });

  testWidgets('a dialog starts on its first control, and ▼ moves on', (
    tester,
  ) async {
    await _pumpApp(tester);
    final pressed = <String>[];
    showDialog<void>(
      context: _context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => pressed.add('Read it first'),
              child: const Text('Read it first'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => pressed.add('Cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => pressed.add('Delete'),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The first control in reading order — never a leap to the last one.
    expect(_focusedText(tester), 'Read it first');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), isNot('Read it first'));
    expect(pressed, isEmpty, reason: 'focusing presses nothing');
  });

  testWidgets('a control the dialog chose itself keeps the focus', (
    tester,
  ) async {
    await _pumpApp(tester);
    showDialog<void>(
      context: _context,
      builder: (ctx) => AlertDialog(
        actions: [
          TextButton(onPressed: () {}, child: const Text('Not now')),
          FilledButton(
            autofocus: true,
            onPressed: () {},
            child: const Text('Start'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_focusedText(tester), 'Start');
  });

  testWidgets('a text field first is left alone: no keyboard pops up', (
    tester,
  ) async {
    await _pumpApp(tester);
    showDialog<void>(
      context: _context,
      builder: (ctx) => AlertDialog(
        content: const TextField(),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Save')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isA<FocusScopeNode>());
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a bottom sheet starts on its first control too', (
    tester,
  ) async {
    await _pumpApp(tester);
    showModalBottomSheet<void>(
      context: _context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('Take a photo'), onTap: () {}),
          ListTile(title: const Text('Choose a photo'), onTap: () {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_focusedText(tester), 'Take a photo');
  });

  testWidgets('a page is not a pop-up: it is left to the D-pad', (
    tester,
  ) async {
    // Pages have their own start (the first arrow); focusing a page's first
    // control on every visit would scroll and ring it for a finger too.
    await _pumpApp(tester);
    _navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TextButton(onPressed: () {}, child: const Text('Go')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
  });

  testWidgets('an in-screen pop-up starts on its first control too', (
    tester,
  ) async {
    // A game's pause card: no route of its own, only a GazeModalRegion over
    // the game, which focused its scope and so nothing in it.
    var resumed = 0;
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: dpadShortcuts,
        actions: dpadActions,
        home: Scaffold(
          body: Stack(
            children: [
              TextButton(onPressed: () {}, child: const Text('A word')),
              GazeModalRegion(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Paused'),
                      FilledButton(
                        onPressed: () => resumed++,
                        child: const Text('Resume'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Quit to Games'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_focusedText(tester), 'Resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(resumed, 1);
  });

  testWidgets('a dialog over a dialog starts on its own first control', (
    tester,
  ) async {
    await _pumpApp(tester);
    showDialog<void>(
      context: _context,
      builder: (ctx) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (_) => AlertDialog(
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Inner')),
                ],
              ),
            ),
            child: const Text('Outer'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_focusedText(tester), 'Outer');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), 'Inner');

    // Closing the inner one hands focus back to where it was.
    Navigator.of(tester.element(find.text('Inner'))).pop();
    await tester.pumpAndSettle();
    expect(_focusedText(tester), 'Outer');
  });
}
