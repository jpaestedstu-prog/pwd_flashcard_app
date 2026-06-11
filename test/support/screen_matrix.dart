import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'device_matrix.dart';

/// Like [expectNoOverflowAcrossDevices], but for **whole screens** that are
/// `ConsumerWidget`s and need the app's `ProviderScope` + localization
/// delegates to build. Renders [build]'s screen at every [DeviceSize] ×
/// text-scale combination and asserts the first gameplay frame lays out without
/// an overflow / layout exception.
///
/// Only the first frame is asserted: that is the live gameplay layout (round 0)
/// — exactly the status bar + prompt + answer grid that overflows at a small
/// size or large font scale. Tapping through rounds is gameplay logic, out of
/// scope for a layout regression test.
///
/// A fresh screen is built per combination (via the [build] callback) so each
/// gets its own state and entrance animations, mirroring how
/// [expectNoOverflowAcrossDevices] uses a `WidgetBuilder`.
Future<void> expectScreenNoOverflowAcrossDevices(
  WidgetTester tester,
  Widget Function() build, {
  List<DeviceSize> devices = kTabletMatrix,
  List<double> textScales = kTextScales,
  List<Override> overrides = const [],
}) async {
  for (final device in devices) {
    for (final scale in textScales) {
      tester.view.physicalSize = device.size * device.devicePixelRatio;
      tester.view.devicePixelRatio = device.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Inject the text scaler *inside* MaterialApp.builder — a MediaQuery
            // wrapped outside MaterialApp is rebuilt away from the FlutterView.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: build(),
          ),
        ),
      );
      // A single frame: enough to lay out the first gameplay screen, without
      // advancing into delayed round-transition timers.
      await tester.pump();

      // An overflowing body re-reports each frame; drain them all.
      Object? firstError;
      for (Object? e = tester.takeException();
          e != null;
          e = tester.takeException()) {
        firstError ??= e;
      }
      expect(
        firstError,
        isNull,
        reason: 'Screen overflow at $device, textScale ${scale}x:\n$firstError',
      );
    }
  }

  // Flush one-shot entrance-animation timers (flutter_animate `delay:` etc.) in
  // small steps so timers chained off completing animations also fire, then
  // unmount so observers/controllers are disposed cleanly.
  const step = Duration(milliseconds: 100);
  for (Duration elapsed = Duration.zero;
      elapsed < const Duration(seconds: 1);
      elapsed += step) {
    await tester.pump(step);
  }
  await tester.pumpWidget(const SizedBox.shrink());
}
