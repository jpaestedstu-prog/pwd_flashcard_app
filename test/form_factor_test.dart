import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/accessible_theme.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/theme/form_factor.dart';
import 'package:pwdpwdpwd/core/utils/platform_caps.dart';
import 'package:pwdpwdpwd/core/utils/responsive_utils.dart';
import 'package:pwdpwdpwd/core/widgets/page_frame.dart';
import 'package:pwdpwdpwd/widgets/dpad_focusable.dart';

void main() {
  group('FormFactor.forSize', () {
    FormFactor f(
      double w,
      double h, {
      bool web = false,
      TargetPlatform platform = TargetPlatform.android,
    }) => FormFactor.forSize(Size(w, h), web: web, platform: platform);

    test('a phone stays a phone either way up', () {
      expect(f(360, 640), FormFactor.phone);
      expect(f(800, 360), FormFactor.phone);
      expect(f(914, 411), FormFactor.phone);
    });

    test('a touch screen with a long short side is a tablet', () {
      expect(f(600, 960), FormFactor.tablet);
      expect(f(1097, 608), FormFactor.tablet);
      expect(f(686, 1097), FormFactor.tablet);
    });

    test('a browser on a phone or a tablet is a phone or a tablet', () {
      expect(f(412, 915, web: true), FormFactor.phone);
      expect(f(800, 1280, web: true), FormFactor.tablet);
    });

    test('a browser on a computer is a computer, unless dragged narrow', () {
      for (final os in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(f(1440, 900, web: true, platform: os), FormFactor.desktop);
        expect(f(420, 800, web: true, platform: os), FormFactor.phone);
      }
    });
  });

  group('adaptTheme', () {
    EdgeInsetsGeometry? padOf(ButtonStyle? s) =>
        s?.padding?.resolve(const <WidgetState>{});

    test('a tablet keeps the sizes the theme is drawn with', () {
      final base = AppTheme.light;
      final t = adaptTheme(base, FormFactor.tablet, 1);
      expect(
        padOf(t.filledButtonTheme.style),
        padOf(base.filledButtonTheme.style),
      );
      expect(
        t.inputDecorationTheme.contentPadding,
        base.inputDecorationTheme.contentPadding,
      );
    });

    test('a phone buttons give up side padding, not height', () {
      final t = adaptTheme(AppTheme.light, FormFactor.phone, 1);
      expect(
        padOf(t.filledButtonTheme.style),
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      );
      expect(
        t.filledButtonTheme.style?.minimumSize?.resolve(const {}),
        const Size(56, 56),
      );
    });

    test('a computer may use the smaller controls a mouse needs', () {
      final t = adaptTheme(AppTheme.light, FormFactor.desktop, 1);
      expect(
        t.filledButtonTheme.style?.minimumSize?.resolve(const {}),
        const Size(64, 48),
      );
      expect(
        t.scrollbarTheme.thumbVisibility?.resolve(const {}),
        isTrue,
      );
    });

    test('side padding gives way at a large text size', () {
      final normal = adaptTheme(AppTheme.light, FormFactor.phone, 1);
      final large = adaptTheme(AppTheme.light, FormFactor.phone, 1.5);
      expect(
        (padOf(large.filledButtonTheme.style) as EdgeInsets).left,
        lessThan((padOf(normal.filledButtonTheme.style) as EdgeInsets).left),
      );
      expect(
        (padOf(large.filledButtonTheme.style) as EdgeInsets).top,
        (padOf(normal.filledButtonTheme.style) as EdgeInsets).top,
      );
    });

    test('colours, shapes and the label fitting are the shared theme\'s', () {
      final base = AppTheme.dark;
      final t = adaptTheme(base, FormFactor.phone, 1);
      const states = <WidgetState>{};
      expect(
        t.filledButtonTheme.style?.backgroundColor?.resolve(states),
        base.filledButtonTheme.style?.backgroundColor?.resolve(states),
      );
      expect(
        t.filledButtonTheme.style?.shape?.resolve(states),
        base.filledButtonTheme.style?.shape?.resolve(states),
      );
      expect(t.filledButtonTheme.style?.foregroundBuilder, isNotNull);
    });

    test('AdaptiveTheme is cached, so a rebuild is cheap', () {
      final a = AdaptiveTheme.of(AppTheme.light, FormFactor.phone, 1);
      final b = AdaptiveTheme.of(AppTheme.light, FormFactor.phone, 1);
      final c = AdaptiveTheme.of(AppTheme.light, FormFactor.tablet, 1);
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
    });
  });

  group('tonal buttons', () {
    testWidgets('are not drawn like primaries', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final tonal = tonalButtonStyle(context);
      final primary = Theme.of(context).filledButtonTheme.style;
      const states = <WidgetState>{};
      expect(
        tonal.backgroundColor?.resolve(states),
        isNot(primary?.backgroundColor?.resolve(states)),
      );
      final fill = tonal.backgroundColor!.resolve(states)!;
      final ink = tonal.foregroundColor!.resolve(states)!;
      expect(contrastOf(fill, ink), greaterThanOrEqualTo(4.5));
    });
  });

  group('pagePadding', () {
    Future<double> padAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double pad;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              pad = c.pagePadding;
              return const SizedBox();
            },
          ),
        ),
      );
      return pad;
    }

    testWidgets('phones and tablets are unchanged', (tester) async {
      expect(await padAt(tester, const Size(360, 640)), 20);
      expect(await padAt(tester, const Size(686, 1097)), 32);
      expect(await padAt(tester, const Size(1097, 608)), 32);
      expect(await padAt(tester, const Size(1280, 800)), 40);
    });

    testWidgets('a wide window keeps content in a column', (tester) async {
      expect(await padAt(tester, const Size(1440, 900)), 120);
      expect(await padAt(tester, const Size(1920, 1080)), 260);
    });

    testWidgets('only sideways: top and bottom keep the size class', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double inset;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              inset = c.pageInset;
              return const SizedBox();
            },
          ),
        ),
      );
      // A grid padded on all sides with the grown value opened a 260 px gap
      // above the Games cards on a computer.
      expect(inset, 32);
    });
  });

  group('PageFrame', () {
    Future<Size> mediaAt(
      WidgetTester tester,
      Size size,
      PageWidth width,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Size seen;
      await tester.pumpWidget(
        MaterialApp(
          home: PageFrame(
            width: width,
            child: Builder(
              builder: (c) {
                seen = MediaQuery.sizeOf(c);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('never touches a phone', (tester) async {
      expect(
        await mediaAt(tester, const Size(360, 640), PageWidth.form),
        const Size(360, 640),
      );
    });

    testWidgets('a form is a column on a tablet in either direction', (
      tester,
    ) async {
      expect(
        (await mediaAt(tester, const Size(1097, 608), PageWidth.form)).width,
        640,
      );
      // Portrait, under the threshold: nearly the same width anyway.
      expect(
        (await mediaAt(tester, const Size(686, 1097), PageWidth.form)).width,
        686,
      );
    });

    testWidgets('a content page runs wider, only on wide windows', (
      tester,
    ) async {
      expect(
        (await mediaAt(tester, const Size(1097, 608), PageWidth.content)).width,
        1097,
      );
      expect(
        (await mediaAt(tester, const Size(1440, 900), PageWidth.content)).width,
        1040,
      );
    });

    testWidgets('full is never framed', (tester) async {
      expect(
        (await mediaAt(tester, const Size(1920, 1080), PageWidth.full)).width,
        1920,
      );
    });

    testWidgets('the column is centred and its height is the window\'s', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: PageFrame(
            width: PageWidth.form,
            child: SizedBox.expand(key: ValueKey('page')),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('page')));
      expect(rect.left, 400);
      expect(rect.right, 1040);
      expect(rect.height, 900);
    });
  });

  group('a mouse in a browser', () {
    tearDown(() => PlatformCaps.debugWeb = null);

    testWidgets('a drawn control shows the hand cursor', (tester) async {
      PlatformCaps.debugWeb = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadFocusable(
              onActivate: () {},
              child: const SizedBox(width: 200, height: 80),
            ),
          ),
        ),
      );
      final region = tester.widget<MouseRegion>(
        find
            .descendant(
              of: find.byType(DpadFocusable),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      expect(region.cursor, SystemMouseCursors.click);
    });

    testWidgets('not in the app', (tester) async {
      PlatformCaps.debugWeb = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadFocusable(
              onActivate: () {},
              child: const SizedBox(width: 200, height: 80),
            ),
          ),
        ),
      );
      final regions = find
          .descendant(
            of: find.byType(DpadFocusable),
            matching: find.byWidgetPredicate(
              (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
            ),
          )
          .evaluate();
      expect(regions, isEmpty);
    });

    testWidgets('a disabled control does not', (tester) async {
      PlatformCaps.debugWeb = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DpadFocusable(
              onActivate: null,
              child: SizedBox(width: 200, height: 80),
            ),
          ),
        ),
      );
      final regions = find
          .descendant(
            of: find.byType(DpadFocusable),
            matching: find.byWidgetPredicate(
              (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
            ),
          )
          .evaluate();
      expect(regions, isEmpty);
    });
  });
}
