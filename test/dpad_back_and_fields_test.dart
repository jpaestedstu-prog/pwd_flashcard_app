import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/navigation/dpad_modal_focus.dart';

/// Escape is Back, and up / down leave a one-line text field.
///
/// A web keyboard, a TV remote in a browser and a switch box set to Escape
/// had no way back but steering to the on-screen arrow; and a learner who
/// arrowed into a one-line field could never arrow out of it, because the
/// field took up and down for its caret.

int _paused = 0;

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: Column(
          children: [
            TextButton(
              onPressed: () => context.push('/detail'),
              child: const Text('Open'),
            ),
            TextButton(
              onPressed: () => context.push('/game'),
              child: const Text('Play'),
            ),
            // Openers further down, so "focus came back" cannot be the focus
            // simply starting on the first control again.
            TextButton(
              onPressed: () => context.push('/detail'),
              child: const Text('More'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  content: const Text('A question?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              child: const Text('Ask'),
            ),
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (sheet) => ListTile(
                  title: const Text('Pick me'),
                  onTap: () => Navigator.pop(sheet),
                ),
              ),
              child: const Text('Sheet'),
            ),
          ],
        ),
      ),
    ),
    GoRoute(
      path: '/detail',
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('Above')),
            const TextField(key: Key('one-line')),
            const TextField(key: Key('lines'), maxLines: 4),
            TextButton(onPressed: () {}, child: const Text('Below')),
          ],
        ),
      ),
    ),
    GoRoute(
      path: '/game',
      // A game: Back pauses it rather than leaving.
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _paused++;
        },
        child: const Scaffold(body: Text('Game')),
      ),
    ),
  ],
);

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      shortcuts: dpadShortcuts,
      actions: dpadActions,
      builder: (context, child) => DpadFieldExits(child: child!),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _at(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

FocusNode _focusOf(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder));

void main() {
  setUp(() => _paused = 0);

  group('Escape is Back', () {
    testWidgets('it leaves a screen, as the system Back does', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Detail'), findsNothing);
      expect(_at(router), '/');
    });

    testWidgets('at the start of the app it does nothing', (tester) async {
      final router = await _pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(_at(router), '/');
    });

    testWidgets('in a game it pauses, as Back does', (tester) async {
      final router = await _pumpApp(tester);
      router.push('/game');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_paused, 1);
      expect(find.text('Game'), findsOneWidget);
    });

    testWidgets('it closes a dialog — one that must be answered too', (
      tester,
    ) async {
      await _pumpApp(tester);
      final context = tester.element(find.text('Open'));
      for (final dismissible in [true, false]) {
        showDialog<void>(
          context: context,
          barrierDismissible: dismissible,
          builder: (_) => const AlertDialog(content: Text('A question')),
        );
        await tester.pumpAndSettle();
        expect(find.text('A question'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.text('A question'), findsNothing,
            reason: 'barrierDismissible: $dismissible');
        expect(find.text('Home'), findsOneWidget);
      }
    });

    testWidgets('in a text field it leaves the field, not the screen', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('one-line')));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasPrimaryFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Detail'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>(),
        isNull,
      );
    });
  });

  // A learner who presses Back must land where they left: on the control
  // that opened the page or pop-up, not at the top of the screen — otherwise
  // every visit to a sub-page costs the whole walk back down.
  group('focus comes back after Back', () {
    testWidgets('leaving a screen puts it on the control that opened it', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      final more = _focusOf(tester, find.text('More'));
      more.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(more.hasPrimaryFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_at(router), '/');
      expect(more.hasPrimaryFocus, isTrue);
    });

    testWidgets('closing a dialog or a sheet puts it on its opener, '
        'however it was closed', (tester) async {
      await _pumpApp(tester);
      DpadModalFocus.install(); // as the app does at start-up

      for (final (opener, inside) in [('Ask', 'OK'), ('Sheet', 'Pick me')]) {
        final node = _focusOf(tester, find.text(opener));
        node.requestFocus();
        await tester.pump();

        // Closed with Escape.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(inside), findsOneWidget);
        expect(_focusOf(tester, find.text(inside)).hasPrimaryFocus, isTrue,
            reason: 'a pop-up starts on its first control');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(inside), findsNothing);
        expect(node.hasPrimaryFocus, isTrue, reason: '$opener, after Escape');

        // Closed with its own control.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(inside), findsNothing);
        expect(node.hasPrimaryFocus, isTrue,
            reason: '$opener, after pressing $inside');
      }
    });
  });

  group('Escape out of a text field', () {
    testWidgets('returns to the control the learner came from', (
      tester,
    ) async {
      // A plain unfocus left the page itself focused, so the next arrow
      // started again from the top of the screen.
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      final above = _focusOf(tester, find.text('Above'));
      above.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final field = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .first
          .focusNode;
      expect(field.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(field.hasFocus, isFalse);
      expect(above.hasPrimaryFocus, isTrue);
      expect(find.text('Detail'), findsOneWidget);
    });
  });

  group('up and down leave a one-line text field', () {
    testWidgets('down from the field reaches the control below', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      final field = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .first
          .focusNode;
      field.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(field.hasFocus, isFalse, reason: 'up left the field');
      expect(
        _focusOf(tester, find.text('Above')).hasPrimaryFocus,
        isTrue,
      );
    });

    testWidgets('a field of several lines keeps up and down for its lines', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      final lines = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .last
          .focusNode;
      lines.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(lines.hasPrimaryFocus, isTrue);
    });

    testWidgets('on a button, the arrows move on exactly as before', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.push('/detail');
      await tester.pumpAndSettle();
      _focusOf(tester, find.text('Above')).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final field = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .first
          .focusNode;
      expect(field.hasPrimaryFocus, isTrue);
    });
  });
}
