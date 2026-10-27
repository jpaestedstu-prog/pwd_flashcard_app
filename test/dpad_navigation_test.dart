import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/focused_label.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_focus_overlay.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_home_tiles.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_modal_region.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/widgets/dpad_focusable.dart';

/// The plain D-pad — arrow keys from a keyboard, a remote, a switch box or
/// the web app — and the pieces every D-pad shares (see dpad_keys.dart and
/// dpad_focusable.dart). The whole-app reach lives in dpad_reach_test.dart.

Widget _app(Widget home) => MaterialApp(
      shortcuts: dpadShortcuts,
      actions: dpadActions,
      home: GazeFocusRingLayer(child: Scaffold(body: home)),
    );

String? _focusedLabel() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  String? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (w is Text) {
      found = w.data;
      return;
    }
    e.visitChildren(visit);
  }

  (ctx as Element).visitChildren(visit);
  return found;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _button(String label, [VoidCallback? onTap]) =>
    TextButton(onPressed: onTap ?? () {}, child: Text(label));

void main() {
  setUp(() => gazeHomeGrid.clearGrid());

  group('arrow keys move focus', () {
    testWidgets('down walks a column, from nothing focused', (tester) async {
      await tester.pumpWidget(_app(Column(
        children: [_button('One'), _button('Two'), _button('Three')],
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'One');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Two');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'One');
    });

    testWidgets('the arrows are a D-pad on the web too', (tester) async {
      // The web's default maps them to scrolling, which reached no control.
      // Flutter's defaults are const activators, so these replace them
      // rather than sit beside them.
      const arrows = [
        SingleActivator(LogicalKeyboardKey.arrowUp),
        SingleActivator(LogicalKeyboardKey.arrowDown),
        SingleActivator(LogicalKeyboardKey.arrowLeft),
        SingleActivator(LogicalKeyboardKey.arrowRight),
      ];
      for (final arrow in arrows) {
        expect(dpadShortcuts[arrow], isA<DirectionalFocusIntent>());
        expect(
          dpadShortcuts.keys.where((k) =>
              k is SingleActivator &&
              k.trigger == arrow.trigger &&
              !k.control &&
              !k.shift &&
              !k.alt &&
              !k.meta),
          hasLength(1),
        );
      }
      expect(dpadActions[DirectionalFocusIntent],
          isA<DpadDirectionalFocusAction>());
    });

    testWidgets('a text field keeps its arrows for the caret', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(Column(
        children: [TextField(controller: controller), _button('After')],
      )));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection.baseOffset, 2);
      expect(FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<TextButton>()));
    });

    testWidgets('up and down leave a slider; left and right slide it',
        (tester) async {
      var value = 0.5;
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, setState) => Column(
          children: [
            _button('Above'),
            DpadSliderScope(
              child: Slider(
                value: value,
                divisions: 10,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
            _button('Below'),
          ],
        ),
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown); // Above
      await _press(tester, LogicalKeyboardKey.arrowDown); // the slider
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Slider>(),
          isNotNull);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(value, greaterThan(0.5));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Below');
    });

    testWidgets('right at the end of a row goes on into the next row',
        (tester) async {
      // Flutter's own rule took the nearest control anywhere to the right —
      // on Home, the Star Shop button at the very top.
      await tester.pumpWidget(_app(Column(
        children: [
          Row(children: [const Spacer(), _button('Top right')]),
          const SizedBox(height: 200),
          Row(children: [_button('A'), _button('B')]),
          Row(children: [_button('C'), _button('D')]),
        ],
      )));
      Focus.of(tester.element(find.text('B'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedLabel(), 'C');
    });

    testWidgets('down reaches a button floating over the last tile',
        (tester) async {
      // A guest's Cards page: no tab bar, and the floating Home button sits
      // over the lower corner of the last deck.
      await tester.pumpWidget(_app(Stack(
        children: [
          Column(
            children: [
              _button('Top'),
              const Spacer(),
              SizedBox(width: 300, height: 160, child: _button('Last deck')),
            ],
          ),
          Positioned(left: 16, bottom: 16, child: _button('Home')),
        ],
      )));
      Focus.of(tester.element(find.text('Last deck'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Home');
    });

    testWidgets('down from a shell page reaches the shell button over it',
        (tester) async {
      // As the app is built: the page on the shell's own navigator, the
      // floating Home button in the shell around it. Flutter's search
      // wants a centre below the deck's bottom edge, the page held nothing
      // further down, and the move wrapped back to the first deck.
      await tester.pumpWidget(_app(Stack(
        children: [
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Column(
                children: [
                  _button('First deck'),
                  const Spacer(),
                  SizedBox(width: 300, height: 160, child: _button('Last deck')),
                ],
              ),
            ),
          ),
          Positioned(left: 16, bottom: 16, child: _button('Home')),
        ],
      )));
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Last deck'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Home');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Home');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'Last deck');
    });

    testWidgets('a shell button straight that way beats a page tile to one side',
        (tester) async {
      // A guest's Cards page on a tablet: two columns of decks, an odd one
      // left alone in the last row, the Home button at the bottom left and
      // the AI Buddy at the bottom right. Flutter searched the page first,
      // so ▶ from the last deck went up to the right column and ▼ from the
      // right column went across to the last deck: the AI Buddy was never
      // reached.
      Widget deck(String label) =>
          SizedBox(width: 300, height: 150, child: _button(label));
      await tester.pumpWidget(_app(Stack(
        children: [
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [deck('Emotions'), deck('Days')]),
                      deck('Actions'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 16, top: 360, child: _button('Home')),
          // A few pixels higher than Home, as on the tablet.
          Positioned(left: 500, top: 356, child: _button('AI Buddy')),
        ],
      )));
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Actions'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedLabel(), 'AI Buddy');

      Focus.of(tester.element(find.text('Days'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'AI Buddy');
      // Level with Home and the last deck, so nothing is below: down stays,
      // where it went round to the top of the page. Up is the deck above,
      // not the last deck beside it.
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'AI Buddy');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'Days');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'AI Buddy');
      // ◀ from it is the last deck, level with it.
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focusedLabel(), 'Actions');

      Focus.of(tester.element(find.text('Actions'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focusedLabel(), 'Home');

      // The page's own still come first when they are in line.
      Focus.of(tester.element(find.text('Emotions'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedLabel(), 'Days');
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focusedLabel(), 'Emotions');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Actions');
    });

    testWidgets('up from a tab is the control above it, not the AI Buddy',
        (tester) async {
      // Home on the tablet: a row of three categories, the last row with
      // one at the left, the tab bar, and the AI Buddy floating at the right
      // above it. To the "skipped row" rule the AI Buddy was a row between
      // each tab and the page, and up from every tab went to it.
      Widget deck(String label) =>
          SizedBox(width: 250, height: 120, child: _button(label));
      Widget tab(String label) =>
          Expanded(child: SizedBox(height: 48, child: _button(label)));
      await tester.pumpWidget(_app(Stack(
        children: [
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [deck('A'), deck('B'), deck('C')]),
                      deck('D'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: [tab('Home tab'), tab('Games tab'), tab('Last tab')],
            ),
          ),
          Positioned(right: 16, bottom: 70, child: _button('AI Buddy')),
        ],
      )));
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Games tab'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'B');

      // Straight above the last tab, the AI Buddy is the next stop.
      Focus.of(tester.element(find.text('Last tab'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'AI Buddy');
    });

    testWidgets('up after a move of the driver\'s own is the control above',
        (tester) async {
      // Flutter remembers its own steps so that ▲ undoes ▼, but a step the
      // driver makes itself (here ▶ carrying on into the next row) is not in
      // that memory: ▲ then jumped back to where the last ▼ began.
      await tester.pumpWidget(_app(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _button('A'),
          _button('B'),
          Row(children: [_button('C'), const SizedBox(width: 300), _button('D')]),
        ],
      )));
      Focus.of(tester.element(find.text('A'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'B');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedLabel(), 'C');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'B');
    });

    testWidgets('down at the very bottom stays put', (tester) async {
      await tester.pumpWidget(_app(Column(
        children: [_button('Top'), const Spacer(), _button('Bottom')],
      )));
      Focus.of(tester.element(find.text('Bottom'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Bottom');
    });

    testWidgets('past the last control the rest of the page scrolls into view',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(_app(ListView(
        controller: scroll,
        children: [
          _button('Only control'),
          // Information below it: charts, badges, a story's text.
          const SizedBox(height: 3000, child: Text('Information')),
        ],
      )));
      Focus.of(tester.element(find.text('Only control'))).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(scroll.offset, greaterThan(0));
      expect(_focusedLabel(), 'Only control');
    });
  });

  testWidgets('an icon button is named by its tooltip when it takes focus',
      (tester) async {
    // A Material 3 IconButton puts its Tooltip 22 elements above the node
    // that takes focus; the controller called Home's Star Shop and Settings
    // buttons "Unnamed item".
    await tester.pumpWidget(_app(Row(children: [
      IconButton(
        tooltip: 'Open settings',
        onPressed: () {},
        icon: const Icon(Icons.settings_rounded),
      ),
    ])));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(
      FocusedLabel.of(FocusManager.instance.primaryFocus?.context),
      'Open settings',
    );
  });

  group('DpadFocusable', () {
    testWidgets('a tap-only tile takes focus and Enter presses it',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_app(DpadFocusable(
        onActivate: () => pressed++,
        child: GestureDetector(
          onTap: () => pressed++,
          child: const SizedBox(width: 100, height: 100, child: Text('Tile')),
        ),
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Tile');
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.space);
      await _press(tester, LogicalKeyboardKey.select);
      expect(pressed, 3);
    });

    testWidgets('nothing to press means no focus stop', (tester) async {
      await tester.pumpWidget(_app(Column(
        children: [
          const DpadFocusable(onActivate: null, child: Text('Disabled')),
          _button('Enabled'),
        ],
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Enabled');
    });

    testWidgets('DpadGestureDetector presses its onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(DpadGestureDetector(
        onTap: () => taps++,
        child: const SizedBox(width: 80, height: 80, child: Text('Chip')),
      )));
      await tester.tap(find.text('Chip'));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(taps, 2);
    });

    testWidgets('an information stop reads its panel aloud', (tester) async {
      final said = <String>[];
      final reader = DpadReadAloud(said.add);
      await tester.pumpWidget(_app(DpadInfoStop(
        reader: reader,
        child: const Column(
          children: [Text('Recent Games'), Text('Word Match: 4 of 5')],
        ),
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(said, ['Recent Games. Word Match: 4 of 5.']);
      reader.read(); // the same press a grid cell makes
      expect(said, hasLength(2));
    });
  });

  group('the shell floating row', () {
    test('sits after the hub rows, only while a hub grid is published', () {
      final owner = Object();
      gazeHomeGrid.publishShellCells(
        [GazeTileCell(label: 'AI Tutor', onActivate: () {})],
        owner: owner,
        order: 1,
      );
      expect(gazeHomeGrid.rows, isEmpty); // no hub: nothing floats over one
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'Games', onActivate: () {})],
      ]);
      final home = Object();
      gazeHomeGrid.publishShellCells(
        [GazeTileCell(label: 'Home', onActivate: () {})],
        owner: home,
      );
      expect(
        [for (final r in gazeHomeGrid.rows) [for (final c in r) c.label]],
        [
          ['Games'],
          ['Home', 'AI Tutor'], // by order, as they float left to right
        ],
      );
      gazeHomeGrid.setFocus(1, 1);
      expect(gazeHomeGrid.isShellFocused(owner, 0), isTrue);
      expect(gazeHomeGrid.isShellFocused(home, 0), isFalse);
      gazeHomeGrid.clearShellCells(owner: owner);
      gazeHomeGrid.clearShellCells(owner: home);
      expect(gazeHomeGrid.rows, hasLength(1));
    });

    test('a cell can act in place rather than open something', () {
      final cell = GazeTileCell(label: 'Asul', onActivate: () {}, opens: false);
      expect(cell.opens, isFalse);
      expect(GazeTileCell(label: 'Games', onActivate: () {}).opens, isTrue);
    });

    test('rowsFor reserves one row per control, in order', () {
      final builder = GazeTileGridBuilder(active: true);
      builder.section(columns: 2, entries: [
        (tile: const SizedBox(), cell: GazeTileCell(label: 'a', onActivate: () {})),
      ]);
      final rows = builder.rowsFor([
        GazeTileCell(label: 'View All', onActivate: () {}),
        GazeTileCell(label: 'Answer', onActivate: () {}, opens: false),
      ]);
      expect(rows, [1, 2]);
      expect(GazeTileGridBuilder(active: false).rowsFor([
        GazeTileCell(label: 'x', onActivate: () {}),
      ]), isEmpty);
    });
  });

  group('in-screen modals', () {
    testWidgets('count app-wide, and above every scope when unhosted',
        (tester) async {
      expect(GazeModalRegion.anyOpen, isFalse);
      await tester.pumpWidget(_app(GazeModalRegion(child: _button('Panel'))));
      await tester.pump();
      expect(GazeModalRegion.anyOpen, isTrue);
      // No gaze scope above it (the AI Buddy's panel floats over the router).
      expect(GazeModalRegion.openAboveScopes, isTrue);
      // It takes the focus, so the arrows step through its own controls.
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Panel');
      await tester.pumpWidget(_app(const SizedBox()));
      expect(GazeModalRegion.anyOpen, isFalse);
      expect(GazeModalRegion.openAboveScopes, isFalse);
    });
  });

  group('the D-pad ring', () {
    testWidgets('frames the focused control after a key, not after a touch',
        (tester) async {
      await tester.pumpWidget(_app(Column(
        children: [_button('One'), _button('Two')],
      )));
      Finder ring() => find.byKey(GazeFocusRingLayer.ringKey);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 200));
      expect(ring(), findsWidgets);
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      expect(ring(), findsNothing);
    });

    testWidgets('shows after an arrow even when Flutter stays in touch mode',
        (tester) async {
      // Android's virtual keyboard device (switch-access apps, adb) never
      // switches Flutter to keyboard highlighting; the ring must not wait
      // for it.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(() => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic);
      await tester.pumpWidget(_app(Column(
        children: [_button('One'), _button('Two')],
      )));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 200));
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      expect(find.byKey(GazeFocusRingLayer.ringKey), findsOneWidget);
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(GazeFocusRingLayer.ringKey), findsNothing);
    });

    testWidgets("shows for the controller's traversal until a touch",
        (tester) async {
      await tester.pumpWidget(_app(Column(
        children: [_button('One'), _button('Two')],
      )));
      // Touch mode: the controller's keys never reach Flutter as keys.
      await tester.tap(find.text('One'));
      await tester.pump();
      Focus.of(tester.element(find.text('Two'))).requestFocus();
      DpadFocusRing.controllerMoved();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(GazeFocusRingLayer.ringKey), findsOneWidget);
      await tester.tap(find.text('One'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(GazeFocusRingLayer.ringKey), findsNothing);
    });
  });
}
