import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test harness for verifying that a widget lays out without `RenderFlex`
/// (or any other) overflow across the range of Android tablets and
/// accessibility font scales the app must support.
///
/// Why this exists: `dart analyze` cannot see overflow — it only happens at
/// layout time, and only at specific size × text-scale combinations. These
/// helpers render the exact widget at every combination and assert that no
/// layout exception was thrown, turning "works on all tablets" from a hope
/// into a checked fact.
///
/// ### Applying the text scaler correctly
/// `MaterialApp` rebuilds `MediaQuery` from the test `FlutterView`, so a
/// `MediaQuery(textScaler: …)` placed *outside* `MaterialApp` is ignored.
/// [pumpResponsive] overrides the scaler inside `MaterialApp.builder`, where
/// it actually propagates to the tree under test.

/// A named logical-pixel viewport to render at.
///
/// Sizes are in **logical** pixels (dp) — the unit Flutter lays out in — not
/// physical pixels. A 1920×1200 px tablet at devicePixelRatio 2.0 is 960×600
/// dp, so that is what appears here.
class DeviceSize {
  const DeviceSize(this.label, this.size, {this.devicePixelRatio = 2.0});

  final String label;
  final Size size;
  final double devicePixelRatio;

  @override
  String toString() => '$label (${size.width.toInt()}×${size.height.toInt()} dp)';
}

/// The viewport matrix the app must survive. Spans a small 7" tablet up to a
/// large 10"+ tablet, in both orientations, plus two phone sizes so shared
/// widgets stay safe on the small end too.
const List<DeviceSize> kTabletMatrix = <DeviceSize>[
  // Small 7" tablet (e.g. 1200×1920 px @ 2.0).
  DeviceSize('7" portrait', Size(600, 960)),
  DeviceSize('7" landscape', Size(960, 600)),
  // 10" tablet (e.g. 1600×2560 px @ 2.0) — incl. Honor Pad X8a class.
  DeviceSize('10" portrait', Size(800, 1280)),
  DeviceSize('10" landscape', Size(1280, 800)),
  // Large / split-screen extremes.
  DeviceSize('XL landscape', Size(1366, 1024)),
  // Phone fallbacks (the app also runs on phones).
  DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0),
  DeviceSize('phone landscape', Size(640, 360), devicePixelRatio: 3.0),
];

/// Accessibility font scales to test. 1.0 = default, 1.3 ≈ the "Large" Font
/// Size setting, 2.0 = the OS maximum the app should still survive.
const List<double> kTextScales = <double>[1.0, 1.3, 2.0];

/// The layout context to render the widget under test inside. Choosing the
/// right host is what makes the matrix meaningful instead of noisy:
///
///   * [bounded] — a fixed, non-scrolling viewport. Use for self-contained
///     widgets that MUST fit on screen at any size/scale (a single card, an
///     app bar, a fixed bottom panel). Catches *vertical* overflow.
///   * [scrollable] — a [SingleChildScrollView]. Use for page-content widgets
///     that grow vertically and are expected to scroll. Vertical growth is
///     fine here, so this catches *horizontal* `RenderFlex` overflow and
///     infinite-width errors without false vertical-overflow positives.
///   * [sliver] — a [CustomScrollView] sliver, which imposes an UNBOUNDED
///     height constraint. Use for widgets placed directly in a sliver list;
///     catches "BoxConstraints forces an infinite height" regressions.
enum LayoutHost { bounded, scrollable, sliver }

Widget _wrapInHost(LayoutHost host, Widget child) {
  switch (host) {
    case LayoutHost.bounded:
      return child;
    case LayoutHost.scrollable:
      return SingleChildScrollView(child: child);
    case LayoutHost.sliver:
      return CustomScrollView(
        slivers: [SliverToBoxAdapter(child: child)],
      );
  }
}

/// Pumps [child] inside a `MaterialApp` at the given [size] / [devicePixelRatio]
/// and [textScale], then settles a single frame. Resets the view on teardown.
///
/// Pass [wrapInApp] = false if [child] already provides its own `MaterialApp`
/// (e.g. a full screen under test). The text scaler is still applied via the
/// surrounding `MediaQuery` in that case.
Future<void> pumpResponsive(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 1280),
  double devicePixelRatio = 2.0,
  double textScale = 1.0,
  bool wrapInApp = true,
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final Widget rooted = wrapInApp
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        )
      : MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        );

  // ProviderScope at the root: shared widgets (Pressable3D/Float3D, the
  // accessibility services) are Riverpod consumers even when the widget
  // under test isn't a full screen.
  await tester.pumpWidget(ProviderScope(child: rooted));
  await tester.pump();
}

/// Renders [builder] at every [DeviceSize] × text-scale combination and
/// asserts no layout/overflow exception is thrown at any of them.
///
/// [builder] is a `WidgetBuilder` (not a prebuilt widget) so a fresh subtree is
/// created per combination — avoids global-key reuse across pumps.
///
/// Example:
/// ```dart
/// testWidgets('streak display never overflows', (tester) async {
///   await expectNoOverflowAcrossDevices(
///     tester,
///     (_) => const EnhancedStreakDisplay(streak: 9999),
///   );
/// });
/// ```
Future<void> expectNoOverflowAcrossDevices(
  WidgetTester tester,
  WidgetBuilder builder, {
  List<DeviceSize> devices = kTabletMatrix,
  List<double> textScales = kTextScales,
  LayoutHost host = LayoutHost.bounded,
  bool wrapInApp = true,
  Duration settleDuration = const Duration(seconds: 1),
}) async {
  for (final device in devices) {
    for (final scale in textScales) {
      await pumpResponsive(
        tester,
        _wrapInHost(host, Builder(builder: builder)),
        size: device.size,
        devicePixelRatio: device.devicePixelRatio,
        textScale: scale,
        wrapInApp: wrapInApp,
      );

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'Overflow / layout exception at $device, '
            'textScale ${scale}x:\n$exception',
      );
    }
  }

  // Clean up after widgets that drive animations/delayed timers (e.g.
  // flutter_animate's `delay:` schedules a one-shot Timer). First advance the
  // clock so those one-shot timers fire and complete, then unmount so any
  // repeating tickers are disposed. Without this the framework's "A Timer is
  // still pending after the widget tree was disposed" invariant trips at
  // teardown even though no overflow occurred.
  //
  // Widgets with staggered reveal animations longer than the default second
  // (e.g. the end-of-game score dialog delays effects up to ~1.8s) need a
  // longer [settleDuration] so every one-shot timer has fired before unmount.
  //
  // Pump in small steps rather than one big jump: an `AnimationController`
  // whose completion callback schedules *another* timer (e.g. `.forward()
  // .then((_) => Future.delayed(...))`) only schedules that follow-up at the
  // end of the current pump, so a single large pump would leave it pending.
  // Stepping lets each chained timer fire on a later step.
  const step = Duration(milliseconds: 100);
  for (Duration elapsed = Duration.zero;
      elapsed < settleDuration;
      elapsed += step) {
    await tester.pump(step);
  }
  await tester.pumpWidget(const SizedBox.shrink());
}
