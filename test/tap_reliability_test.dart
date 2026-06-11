import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/app_icon_button.dart';
import 'package:pwdpwdpwd/widgets/connectivity_banner.dart';
import 'package:pwdpwdpwd/widgets/tilt_3d.dart';

/// Single-tap reliability suite.
///
/// Guards the fixes for the "I have to click many times" bug:
///  1. Tooltips must not register a long-press recognizer — a press held
///     longer than 500ms used to lose the gesture arena to the tooltip, so
///     slow presses (young / motor-impaired students) silently did nothing.
///  2. Every theme variant must carry the manual tooltip trigger and the
///     InkRipple splash (InkSparkle compiles a shader on the FIRST tap —
///     a visible hitch on low-end tablets that reads as a dead tap).
///  3. A mouse click that drifts a pixel or two inside a scrollable must
///     still count as a tap (mouse drag slop is 1px, so mouse must stay out
///     of the scroll dragDevices — the framework default).
///  4. The offline banner overlays the AppBar strip on every route and must
///     never absorb taps aimed at the controls underneath it.
///  5. Pressable3D must keep its widget-tree shape identical on every
///     animation frame. It used to return the bare child at t == 0 and the
///     Transform wrappers at t > 0, so the first frame of the press tilt
///     re-inflated the child subtree and disposed its in-flight tap
///     recognizer — every button needed a second tap unless reduced motion
///     had the tilt disabled.
///
/// Settings are injected by overriding [settingsProvider] — no Hive: a
/// `Hive.put` awaited inside a `testWidgets` body deadlocks under FakeAsync.
class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Counts re-inflations: [onInit] fires once per fresh State. A press that
/// re-inflates this widget mid-gesture loses the gesture arena entry.
class _TapProbe extends StatefulWidget {
  const _TapProbe({required this.onInit, required this.onTap});
  final VoidCallback onInit;
  final VoidCallback onTap;

  @override
  State<_TapProbe> createState() => _TapProbeState();
}

class _TapProbeState extends State<_TapProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // A bare SizedBox is not hit-testable on its own — opaque makes the
      // probe's full 100x100 area receive the pointer.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: const SizedBox(width: 100, height: 100),
    );
  }
}

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  _FakeConnectivityPlatform(this._current);
  final List<ConnectivityResult> _current;
  final _changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _changes.stream;
}

void main() {
  Widget harness(Widget child) => ProviderScope(
        overrides: [
          settingsProvider
              .overrideWith(() => _FixedSettings(const AppSettings())),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('a press held longer than 500ms still fires the icon button',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(harness(AppIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      hapticOnPress: false,
      soundOnPress: false,
      onPressed: () => presses++,
    )));

    // Hold well past kLongPressTimeout (500ms). With the default tooltip
    // trigger the long-press recognizer would win the arena here and the
    // release would do nothing.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(IconButton)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(presses, 1);
  });

  test('every theme variant keeps tooltips manual and splash InkRipple', () {
    final variants = <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
      'dyslexia': AppTheme.dyslexia,
      'highContrast': AppTheme.highContrast,
      'shop light (ocean)': AppTheme.shopTheme('theme_ocean')!,
      'shop dark (ocean)': AppTheme.shopThemeDark('theme_ocean')!,
      'reduced motion': AppTheme.withReducedMotion(AppTheme.light),
    };
    for (final MapEntry(key: name, value: theme) in variants.entries) {
      expect(theme.tooltipTheme.triggerMode, TooltipTriggerMode.manual,
          reason: '$name tooltip trigger');
      expect(theme.splashFactory, InkRipple.splashFactory,
          reason: '$name splash factory');
    }
  });

  testWidgets('a mouse click with slight drift inside a list still taps',
      (tester) async {
    var taps = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 30; i++)
              ListTile(
                key: ValueKey('tile-$i'),
                title: Text('Tile $i'),
                onTap: i == 0 ? () => taps++ : null,
              ),
          ],
        ),
      ),
    ));

    // Mouse drag slop is 1 logical pixel — with mouse in the scroll
    // dragDevices this 2px drift became a micro-scroll that cancelled the
    // tap. The framework-default behavior must treat it as a click.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byKey(const ValueKey('tile-0'))));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);

    // Touch flick-scrolling must keep working.
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('Pressable3D never re-inflates its child during the press tilt',
      (tester) async {
    var inits = 0;
    var taps = 0;
    await tester.pumpWidget(harness(Pressable3D(
      child: _TapProbe(onInit: () => inits++, onTap: () => taps++),
    )));
    expect(inits, 1);

    // Realistic finger press: down, a few animation frames, up. The tilt
    // animation runs (reducedMotion is false here); the child subtree —
    // and its tap recognizer — must survive every frame of it.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(_TapProbe)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(inits, 1, reason: 'press animation must not re-inflate the child');
    expect(taps, 1, reason: 'a press spanning animation frames must fire');
  });

  testWidgets('an icon-button press spanning tilt-animation frames fires once',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(harness(AppIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      hapticOnPress: false,
      soundOnPress: false,
      onPressed: () => presses++,
    )));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(IconButton)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(presses, 1);
  });

  testWidgets('the offline banner never blocks taps on the AppBar',
      (tester) async {
    ConnectivityPlatform.instance =
        _FakeConnectivityPlatform(const [ConnectivityResult.none]);

    var backTaps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ConnectivityBanner(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => backTaps++,
            ),
            title: const Text('Lesson'),
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ));
    // Let checkConnectivity resolve and the banner slide fully in.
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();

    expect(backTaps, 1);
  });
}
