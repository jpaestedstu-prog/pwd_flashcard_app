import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;
import 'package:pwdpwdpwd/core/utils/platform_caps.dart';
import 'package:pwdpwdpwd/widgets/dpad_focusable.dart';
import 'package:pwdpwdpwd/widgets/tilt_3d.dart';

/// The hover lift (Pressable3D) and the hand cursor (DpadFocusable) are mouse
/// regions. A mouse region that is not opaque answers "not hit" to its
/// parents, so a tap handler above one that defers to its child never saw a
/// tap: the story covers stopped opening (8 Nov). Both must leave taps as
/// they were, in the browser version and in the app.
class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  tearDown(() => PlatformCaps.debugWeb = null);

  for (final web in [false, true]) {
    final where = web ? 'in a browser' : 'in the app';

    testWidgets('a tap handler above Pressable3D gets the tap, $where', (
      tester,
    ) async {
      PlatformCaps.debugWeb = web;
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(
            home: Center(
              child: GestureDetector(
                onTap: () => taps++,
                child: const Pressable3D(
                  child: SizedBox(
                    width: 200,
                    height: 120,
                    child: ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Pressable3D));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });

    testWidgets('a tap handler above DpadFocusable gets the tap, $where', (
      tester,
    ) async {
      PlatformCaps.debugWeb = web;
      var outer = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GestureDetector(
              onTap: () => outer++,
              child: DpadFocusable(
                onActivate: () {},
                child: const SizedBox(
                  width: 200,
                  height: 120,
                  child: ColoredBox(color: Colors.teal),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DpadFocusable));
      await tester.pump(const Duration(milliseconds: 300));
      expect(outer, 1);
    });

    testWidgets('a gap in the child stays a gap, $where', (tester) async {
      PlatformCaps.debugWeb = web;
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(
            home: Center(
              child: GestureDetector(
                onTap: () => taps++,
                child: const Pressable3D(
                  // Nothing painted, nothing to hit: as before the hover
                  // region existed.
                  child: SizedBox(width: 200, height: 120),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Pressable3D), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });
  }
}
