import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/keyboard.dart';

/// A date picker opened straight after typing, on a phone held sideways.
///
/// Flutter's date picker has a fixed size. With a keyboard still on screen
/// (a 200 dp one is enough on a 20:9 phone turned sideways) it overflows:
/// the landscape phone walk failed on the birth-date picker that follows the
/// name field. The app now closes the keyboard and lets it leave first
/// ([closeKeyboardFirst]), at every date picker.
void main() {
  const dpr = 2.625;
  const keyboard = 250.0;

  void sideways(WidgetTester tester) {
    tester.view.physicalSize = const Size(914, 411) * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = const FakeViewPadding(top: 24 * dpr);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * dpr);
    addTearDown(tester.view.reset);
  }

  /// A name field and a birth-date button, like the profile forms.
  Future<void> pumpForm(WidgetTester tester, {required bool closeFirst}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const TextField(autofocus: true),
              TextButton(
                onPressed: () async {
                  if (closeFirst) {
                    await closeKeyboardFirst(context);
                    if (!context.mounted) return;
                  }
                  await showDatePicker(
                    context: context,
                    initialDate: DateTime(2019, 6, 2),
                    firstDate: DateTime(1920),
                    lastDate: DateTime(2026, 10, 12),
                  );
                },
                child: const Text('Birth date'),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  /// Taps the button, then the keyboard leaves 100 ms later, as it does.
  /// Returns every layout error the framework reported meanwhile.
  Future<List<String>> openPicker(WidgetTester tester) async {
    final errors = <String>[];
    final prior = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    addTearDown(() => FlutterError.onError = prior);
    Future<void> frame() async {
      await tester.pump(const Duration(milliseconds: 100));
      while (tester.takeException() != null) {}
    }

    await tester.tap(find.text('Birth date'));
    await frame();
    tester.view.resetViewInsets();
    for (var i = 0; i < 10; i++) {
      await frame();
    }
    return errors;
  }

  testWidgets('without waiting, the picker overflows under the keyboard',
      (tester) async {
    // The control: proves the test can see the failure it guards against.
    sideways(tester);
    await pumpForm(tester, closeFirst: false);
    final errors = await openPicker(tester);
    expect(errors, contains(contains('overflowed')));
  });

  testWidgets('closing the keyboard first, the picker fits', (tester) async {
    sideways(tester);
    await pumpForm(tester, closeFirst: true);
    final errors = await openPicker(tester);
    expect(errors, isEmpty);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
  });

  testWidgets('a keyboard that never leaves holds the picker back briefly',
      (tester) async {
    sideways(tester);
    var done = false;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    closeKeyboardFirst(ctx).then((_) => done = true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
  });
}
