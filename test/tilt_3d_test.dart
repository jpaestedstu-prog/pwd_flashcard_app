import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/tilt_3d.dart';

/// Tests for the 3D motion kit: the press tilt must never swallow taps,
/// must actually transform while held, and must go fully static under
/// reduced motion.
///
/// The Transform wrappers must be in the tree at ALL times — flat states
/// are identity matrices, not a different tree shape. (Returning the bare
/// child at rest used to re-inflate the subtree on the first animation
/// frame of every press, killing the in-flight tap recognizer; see
/// tap_reliability_test.dart.)
///
/// Settings are injected by overriding [settingsProvider] — no Hive: a
/// `Hive.put` awaited inside a `testWidgets` body deadlocks under FakeAsync.
class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

void main() {
  Widget harness(Widget child, {bool reducedMotion = false}) => ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _FixedSettings(AppSettings(reducedMotion: reducedMotion)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      );

  Finder transformsIn(Type wrapper) => find.descendant(
        of: find.byType(wrapper),
        matching: find.byType(Transform),
      );

  /// True when every Transform inside [wrapper] is an identity matrix —
  /// i.e. the child renders flat. Also asserts the wrappers are present,
  /// which is the tree-shape invariant that keeps taps alive.
  bool rendersFlat(WidgetTester tester, Type wrapper) {
    final transforms =
        tester.widgetList<Transform>(transformsIn(wrapper)).toList();
    expect(transforms, isNotEmpty,
        reason: 'Transform wrappers must stay in the tree at every t');
    return transforms.every((t) => t.transform.isIdentity());
  }

  testWidgets('Pressable3D lets taps reach the wrapped button',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(
      Pressable3D(
        child: ElevatedButton(
          onPressed: () => taps++,
          child: const Text('Tap'),
        ),
      ),
    ));

    await tester.tap(find.text('Tap'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('Pressable3D tilts while held and settles flat on release',
      (tester) async {
    await tester.pumpWidget(harness(
      const Pressable3D(
        child: SizedBox(
          key: ValueKey('tilt-target'),
          width: 120,
          height: 48,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    ));

    // Idle: wrappers present, matrices identity.
    expect(rendersFlat(tester, Pressable3D), isTrue);

    // Hold near the right edge — tilt animates in.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tilt-target'))) +
          const Offset(40, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(rendersFlat(tester, Pressable3D), isFalse);

    // Release — tilt animates back out to identity.
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(rendersFlat(tester, Pressable3D), isTrue);
  });

  testWidgets('Pressable3D cancels the tilt when the touch becomes a drag',
      (tester) async {
    await tester.pumpWidget(harness(
      const Pressable3D(
        child: SizedBox(
          key: ValueKey('tilt-target'),
          width: 120,
          height: 48,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tilt-target'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(rendersFlat(tester, Pressable3D), isFalse);

    // Drag past the touch slop (18px) — the press becomes a scroll, so the
    // tilt must release even though the finger is still down.
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(rendersFlat(tester, Pressable3D), isTrue);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('Pressable3D stays static under reduced motion',
      (tester) async {
    await tester.pumpWidget(harness(
      reducedMotion: true,
      const Pressable3D(
        child: SizedBox(
          key: ValueKey('tilt-target'),
          width: 120,
          height: 48,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tilt-target'))) +
          const Offset(40, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(rendersFlat(tester, Pressable3D), isTrue);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('Float3D sways its child over time', (tester) async {
    await tester.pumpWidget(harness(
      const Float3D(
        child: Text('hello'),
      ),
    ));

    expect(find.text('hello'), findsOneWidget);

    // Mid-cycle the sway transform must be active. (No pumpAndSettle —
    // the sway repeats forever.)
    await tester.pump(const Duration(milliseconds: 500));
    expect(rendersFlat(tester, Float3D), isFalse);
  });

  testWidgets('Float3D is static under reduced motion', (tester) async {
    await tester.pumpWidget(harness(
      reducedMotion: true,
      const Float3D(
        child: Text('hello'),
      ),
    ));

    expect(find.text('hello'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rendersFlat(tester, Float3D), isTrue);
  });
}
