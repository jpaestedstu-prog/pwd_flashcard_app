import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';

/// A note floating over the top of every screen (the "Your device sound is
/// off" hint sits in `MaterialApp.builder`) must not take the D-pad's first
/// press from the page, nor strand the focus when it goes away.
///
/// Found on the tablet: after installing, the hint appeared over the profile
/// list, the first D-pad press landed on its "Don't remind me" button — one A
/// from switching the reminder off for good — and when the hint hid itself
/// the focus went with it, so the next press started from the top again.

bool _noteShown = true;

Widget _app() => MaterialApp(
      shortcuts: dpadShortcuts,
      actions: dpadActions,
      builder: (context, child) => StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            child!,
            if (_noteShown)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  child: Row(
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Never')),
                      TextButton(
                        onPressed: () => setState(() => _noteShown = false),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 120),
            for (final name in ['Guest', 'Player', 'Teacher'])
              TextButton(onPressed: () {}, child: Text(name)),
          ],
        ),
      ),
    );

String? _focused() {
  final context = FocusManager.instance.primaryFocus?.context;
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
  setUp(() => _noteShown = true);

  testWidgets('the first arrows walk the page, not the note over it',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final seen = <String?>[];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      seen.add(_focused());
    }
    expect(seen, ['Guest', 'Player', 'Teacher'],
        reason: 'on the note, A is one press from switching it off for good');
  });
}
