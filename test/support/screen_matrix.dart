import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'device_matrix.dart';
import 'readability.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/utils/seeded_random.dart';

/// The themes whose own text metrics can change a layout, for a theme pass.
///
/// Deliberately lazy. Building a `ThemeData` reaches `ServicesBinding` for the
/// fonts, so a `const`/`final` map of themes is evaluated at file load — before
/// `TestWidgetsFlutterBinding.ensureInitialized()` has run — and throws
/// "Binding has not yet been initialized".
///
/// Light is omitted because it is what the default matrix already renders, and
/// dark changes only colours; these two are the ones that move text. The
/// dyslexia theme is the harshest: Lexend at a 1.6 line height and 0.6 letter
/// spacing, so every line is both wider and taller than the default theme's.
final Map<String, ThemeData Function()> kLayoutThemes =
    <String, ThemeData Function()>{
      'dyslexia': () => AppTheme.dyslexia,
      'high contrast': () => AppTheme.highContrast,
    };

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
  bool checkReadability = true,
  Duration settle = const Duration(seconds: 1),

  /// Theme to render under. Defaults to Flutter's, which is what every caller
  /// used before high contrast needed covering — the app's real themes change
  /// font sizes and add borders, so a screen can fit under one and overflow
  /// under another.
  ThemeData? theme,

  /// Names the theme in failure messages. Set for you by
  /// [expectScreenSurvivesThemes]; without it a theme-pass failure says which
  /// device and scale broke but not which theme, which is the first thing you
  /// need to know.
  String? themeLabel,
}) async {
  final problems = <String>[];

  // Record the framework's own error details as well as the exception.
  //
  // `takeException` hands back the exception alone, and an overflow's exception
  // is just "A RenderFlex overflowed by N pixels" -- it does not say *which*
  // RenderFlex. The details object does, in the "relevant error-causing widget"
  // section, and that is the difference between a fixable report and a hunt.
  // The prior handler is still called, so the test binding behaves as usual.
  final details = <String>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    details.add(d.toString());
    priorOnError?.call(d);
  };
  addTearDown(() => FlutterError.onError = priorOnError);
  // Pin the content RNG so this matrix is repeatable.
  //
  // Screens that shuffle their own content drew a different card every render,
  // so the matrix sampled one random draw per run instead of testing the
  // screen. A card whose long word breaks the layout could hide for many runs
  // and then fail one -- which is what FlashcardQuizScreen did.
  //
  // The seed varies per combination rather than being one constant, so the
  // sweep still exercises several different draws; it is derived from the
  // combination index, so every run sees exactly the same ones.
  final priorSeed = debugContentRandomSeed;
  addTearDown(() => debugContentRandomSeed = priorSeed);

  var combination = 0;
  for (final device in devices) {
    for (final scale in textScales) {
      debugContentRandomSeed = ++combination;
      tester.view.physicalSize = device.size * device.devicePixelRatio;
      tester.view.devicePixelRatio = device.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Inject the text scaler *inside* MaterialApp.builder — a MediaQuery
            // wrapped outside MaterialApp is rebuilt away from the FlutterView.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: build(),
          ),
        ),
      );
      // A single frame: enough to lay out the first gameplay screen, without
      // advancing into delayed round-transition timers.
      await tester.pump();

      // Every failing combination is collected rather than asserted on the
      // spot. Failing fast hid the true extent of a problem: fixing the first
      // combination only revealed the next, one round-trip at a time, and a
      // screen that was broken at four sizes reported one.
      for (
        Object? e = tester.takeException();
        e != null;
        e = tester.takeException()
      ) {
        // The exception says "a RenderFlex overflowed"; only the details say
        // *which* one. Pair them by taking the newest details entry that
        // mentions an overflow -- they are appended in the same order the
        // exceptions are thrown.
        final dump = details.lastWhere(
          (d) => d.contains('overflowed by'),
          orElse: () => '',
        );
        final m = RegExp(r'/lib/([\w/]+\.dart):(\d+):').firstMatch(dump);
        final where = m == null
            ? ''
            : '${m.group(1)!.split('/').last}:${m.group(2)}';
        final line =
            '${themeLabel == null ? '' : '[$themeLabel] '}$device, ${scale}x: $e'
            '${where.isEmpty ? '' : '  at $where'}';
        if (!problems.contains(line)) problems.add(line);
      }

      // Laying out without bursting the box is only half the promise. A word
      // broken *inside itself* fits perfectly and is still unreadable, and no
      // overflow assertion can see it -- that is how the Games hub shipped
      // "Pronunciat / ion Practi..." past every suite in this directory. The
      // same mount answers both questions, so ask both here rather than grow a
      // parallel set of matrices that would drift out of step.
      if (checkReadability) {
        for (final issue in findReadabilityIssues(tester)) {
          final line =
              '${themeLabel == null ? '' : '[$themeLabel] '}$device, textScale ${scale}x: $issue';
          if (!problems.contains(line)) problems.add(line);
        }
      }
    }
  }

  // Flush one-shot entrance-animation timers (flutter_animate `delay:` etc.) in
  // small steps so timers chained off completing animations also fire, then
  // unmount so observers/controllers are disposed cleanly.
  // [settle] must outlast the screen's longest `Future.delayed`, or the test
  // ends with a timer still pending. The AI tutor queues its next lesson card
  // 1.8 s out, which is longer than the default.
  const step = Duration(milliseconds: 100);
  for (Duration elapsed = Duration.zero; elapsed < settle; elapsed += step) {
    await tester.pump(step);
  }
  await tester.pumpWidget(const SizedBox.shrink());

  expect(problems, isEmpty, reason: 'Problems:\n  ${problems.join('\n  ')}');
}

/// Runs one screen through the accessibility themes at the large-text slice.
///
/// The shorthand for files whose screens are declared as individual
/// `testWidgets` rather than a map — it keeps the theme pass to one line per
/// screen instead of a nested loop repeated in a dozen files. Same slice as
/// everywhere else: [kLayoutThemes] over [kNarrowPortrait] × [kLargeTextScales].
Future<void> expectScreenSurvivesThemes(
  WidgetTester tester,
  Widget Function() build, {
  List<Override> overrides = const [],
  bool checkReadability = true,
  Duration settle = const Duration(seconds: 1),
}) async {
  for (final theme in kLayoutThemes.entries) {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      build,
      theme: theme.value(),
      themeLabel: theme.key,
      devices: kNarrowPortrait,
      textScales: kLargeTextScales,
      overrides: overrides,
      checkReadability: checkReadability,
      settle: settle,
    );
  }
}
