import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/screen_reader_focus_guard.dart';

/// A D-pad focus left out of sight must not pull TalkBack back to it.
///
/// Found on the tablet (28 Oct): after D-pad use, TalkBack's next-item walk
/// down Home jumped from the Daily Challenge question to the "Stories" tile
/// the D-pad had left focused — Flutter re-announces the focused control
/// whenever it scrolls back into the tree, and TalkBack follows it.
void main() {
  late bool Function() original;
  setUp(() => original = ScreenReaderFocusGuard.screenReaderOn);
  tearDown(() => ScreenReaderFocusGuard.screenReaderOn = original);

  final first = FocusNode(debugLabel: 'first');
  final outside = FocusNode(debugLabel: 'outside');
  final field = FocusNode(debugLabel: 'field');
  final controller = ScrollController();

  Widget host() => MaterialApp(
        home: ScreenReaderFocusGuard(
          child: Scaffold(
            body: Column(
              children: [
                TextButton(
                  focusNode: outside,
                  onPressed: () {},
                  child: const Text('Above the list'),
                ),
                // Every row stays built, as Home's sections do: a lazy list
                // would drop a far-off row, and its focus with it, anyway.
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        TextButton(
                          focusNode: first,
                          onPressed: () {},
                          child: const Text('First'),
                        ),
                        TextField(focusNode: field),
                        for (var i = 0; i < 40; i++)
                          SizedBox(
                            height: 80,
                            child: TextButton(
                              onPressed: () {},
                              child: Text('Item $i'),
                            ),
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

  Future<void> scrollAway(WidgetTester tester) async {
    controller.jumpTo(1500);
    await tester.pump();
  }

  testWidgets('with a screen reader, a focus scrolled out of sight lets go',
      (tester) async {
    ScreenReaderFocusGuard.screenReaderOn = () => true;
    await tester.pumpWidget(host());
    first.requestFocus();
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);

    await scrollAway(tester);
    expect(first.hasFocus, isFalse,
        reason: 'scrolled back, it would pull TalkBack to it');
  });

  testWidgets('without a screen reader the D-pad keeps its place',
      (tester) async {
    ScreenReaderFocusGuard.screenReaderOn = () => false;
    await tester.pumpWidget(host());
    first.requestFocus();
    await tester.pump();

    await scrollAway(tester);
    expect(first.hasPrimaryFocus, isTrue);
  });

  testWidgets('a text field being typed in keeps its focus', (tester) async {
    ScreenReaderFocusGuard.screenReaderOn = () => true;
    await tester.pumpWidget(host());
    field.requestFocus();
    await tester.pump();

    await scrollAway(tester);
    expect(field.hasPrimaryFocus, isTrue,
        reason: 'letting go would close the keyboard mid-word');
  });

  testWidgets('a focus outside the list that scrolled is kept',
      (tester) async {
    ScreenReaderFocusGuard.screenReaderOn = () => true;
    await tester.pumpWidget(host());
    outside.requestFocus();
    await tester.pump();

    await scrollAway(tester);
    expect(outside.hasPrimaryFocus, isTrue,
        reason: 'it never left the screen');
  });

  testWidgets('a focus still in view is kept', (tester) async {
    ScreenReaderFocusGuard.screenReaderOn = () => true;
    await tester.pumpWidget(host());
    first.requestFocus();
    await tester.pump();

    controller.jumpTo(20);
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);
  });
}
