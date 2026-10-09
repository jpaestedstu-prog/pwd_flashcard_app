// End-to-end walkthrough of the learner app on a real device, emulator or
// simulator — iPhone, iPad, Android phone or Android tablet:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_walkthrough_test.dart \
//     --dart-define=FLASHLEARN_OFFLINE=true -d <device>
//
// It onboards a "Player (with Progress)" profile, opens every tab, a deck, and
// every learner screen and game, saves a screenshot of each stop (the driver
// writes them to build/walkthrough/), and fails if any screen threw or
// overflowed. FLASHLEARN_OFFLINE keeps the app off Firebase, exactly as when
// the cloud is unreachable, so a test run creates nothing online; Firebase
// itself is covered by firebase_smoke_test.dart.
//
// NEVER point it at a tablet with real profiles: when `flutter drive`
// finishes it stops AND UNINSTALLS the app (drive_service.dart), which wipes
// every profile on the device. Emulators and simulators only.

import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';
import 'package:pwdpwdpwd/main.dart' as app;
import 'package:pwdpwdpwd/navigation/app_router.dart' show rootNavigatorKey;

const _profileName = 'Store Tester';

/// Tabs, opened through the router (a tap on the bar is checked once).
const _tabs = <String>['/home', '/flashcards', '/games', '/stories', '/progress'];

/// Every learner screen with no required arguments. A profile that may not
/// open one is redirected (or told why not) — either way the screen it lands
/// on must not throw or overflow.
const _screens = <String>[
  '/flashcards/viewer/0',
  '/flashcards/viewer/5',
  '/games/word-match',
  '/games/spelling-bee',
  '/games/memory-match',
  '/games/drag-drop',
  '/games/flashcard-quiz',
  '/games/pronunciation',
  '/games/sentence-builder',
  '/games/tracing',
  '/games/jigsaw-puzzle',
  '/games/picture-word',
  '/games/yes-or-no',
  '/games/odd-one-out',
  '/games/first-letter',
  '/games/fsl-practice',
  '/games/fsl-practice/sign-to-word',
  '/games/fsl-practice/word-to-sign',
  '/games/fsl-practice/sign-it',
  '/settings',
  '/fsl-dictionary',
  '/communication-board',
  '/daily-challenge',
  '/smart-review',
  '/shop',
  '/learning-world',
  '/learning-paths',
  '/ai-tutor',
  '/object-scan',
  '/word-hunt-collection',
  '/gaze-settings',
  '/gamepad-settings',
  '/tv-cast',
  '/voice-guided',
  '/notebook',
  '/goals',
  '/streak-calendar',
  '/certificates',
  '/hard-words',
  '/word-of-day',
  '/focus-mode',
  '/mood-check-in',
  '/sticker-album',
  '/leaderboard',
  '/routine',
  '/messages',
  '/peer-collab',
  '/multiplayer',
  '/guided-practice',
  '/showcase',
  '/edit-profile',
  '/backup',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'learner walkthrough',
    (tester) async {
      final walk = _Walk(tester, binding);
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      try {
        await walk.run();
      } finally {
        // The app installs its own handlers and error box; the test framework
        // insists on getting its own back.
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
        ErrorWidget.builder = errorWidgetBuilder;
      }
      walk.report();
      expect(walk.failures, isEmpty, reason: walk.failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}

class _Walk {
  _Walk(this.tester, this.binding);

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;

  final List<String> failures = [];
  final List<String> visited = [];
  final List<String> _frameworkErrors = [];
  int _shots = 0;
  late final DateTime _started;

  Future<void> run() async {
    _started = DateTime.now();
    app.main();
    // main() has installed the app's error handler by now (it runs before
    // the first await). Wrap it: overflows and build errors are recorded
    // here, and the app still logs them as usual.
    final appOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _frameworkErrors.add(details.exceptionAsString().split('\n').first);
      appOnError?.call(details);
    };
    if (Platform.isAndroid) {
      // Android screenshots read the Flutter surface as an image; done early
      // so that even a screen stuck at launch can be captured.
      await _settle(const Duration(seconds: 2));
      await binding.convertFlutterSurfaceToImage();
    }

    final first = await _waitForAny({
      'welcome': find.text('Skip'),
      'choose': find.text('Player (with Progress)'),
      'mine': find.text(_profileName),
      'switcher': find.text('Add New Profile'),
    }, const Duration(seconds: 120));
    if (first == null) {
      await _shot('stuck_at_start');
      failures.add('No first screen within 120 s. On screen: ${_visibleTexts()}');
      return;
    }
    await _settle(const Duration(seconds: 1));

    switch (first) {
      case 'welcome':
        await _shot('welcome');
        await _tap(find.text('Skip'));
        await _createProgressPlayer();
      case 'choose':
        await _createProgressPlayer();
      case 'mine':
        await _shot('profile_switcher');
        await _tap(find.text(_profileName));
      case 'switcher':
        await _shot('profile_switcher');
        await _tap(find.text('Add New Profile'));
        await _createProgressPlayer();
    }
    if (failures.isNotEmpty) return;

    // Whatever comes between the form and Home: accessibility setup, the
    // tour. Each has a Skip.
    for (var i = 0; i < 4; i++) {
      if (await _waitFor(find.text('Cards'), const Duration(seconds: 4))) break;
      if (find.text('Skip').evaluate().isNotEmpty) {
        await _shot('setup_step_${i + 1}');
        await _tap(find.text('Skip'));
        await _settle(const Duration(seconds: 2));
      }
    }
    if (!await _waitFor(find.text('Cards'), const Duration(seconds: 20))) {
      await _shot('no_home');
      failures.add('Never reached the tab bar (Home)');
      return;
    }
    await _settle(const Duration(seconds: 2));
    await _shot('home');

    // A new profile's first visit opens the Daily Reward. Collect it, or it
    // comes back over Home on every visit below.
    final collect = find.textContaining('Collect');
    if (await _waitFor(collect, const Duration(seconds: 6))) {
      await _shot('daily_reward');
      await _tap(collect);
      await _settle(const Duration(seconds: 3));
      await _shot('home_after_reward');
    }

    // One real tap on the tab bar, then the rest through the router.
    await _tap(find.text('Games').last);
    await _settle(const Duration(seconds: 2));
    await _shot('tab_games_tapped');

    for (final route in _tabs) {
      await _visit(route, push: false);
    }
    for (final route in _screens) {
      await _visit(route, push: true);
    }

    // A flashcard flip, by hand.
    await _visit('/flashcards/viewer/0', push: true, name: 'viewer_before_flip');
    await _tap(find.text('Flip'));
    await _settle(const Duration(seconds: 2));
    await _shot('viewer_flipped');
    _router.go('/home');
    await _settle(const Duration(seconds: 2));
  }

  Future<void> _createProgressPlayer() async {
    if (!await _waitFor(
      find.text('Player (with Progress)'),
      const Duration(seconds: 20),
    )) {
      await _shot('no_profile_choice');
      failures.add('Profile choice screen never appeared');
      return;
    }
    await _settle(const Duration(seconds: 1));
    await _shot('choose_profile');
    await _tap(find.text('Player (with Progress)'));
    if (!await _waitFor(find.byType(TextFormField), const Duration(seconds: 20))) {
      await _shot('no_setup_form');
      failures.add('Profile form never appeared');
      return;
    }
    await _settle(const Duration(seconds: 1));
    await _shot('profile_form');
    await tester.enterText(find.byType(TextFormField).first, _profileName);
    await _settle(const Duration(seconds: 1));
    await _shot('profile_form_keyboard');
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(const Duration(seconds: 1));

    // Birth date: the picker opens on a date 7 years back; OK keeps it.
    await _tap(find.byIcon(Icons.cake_rounded));
    if (await _waitFor(find.text('OK'), const Duration(seconds: 10))) {
      await _settle(const Duration(seconds: 1));
      await _shot('birth_date_picker');
      await _tap(find.text('OK'));
      await _settle(const Duration(seconds: 1));
    } else {
      failures.add('Birth date picker did not open');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(const Duration(seconds: 1));
    await _tap(find.text("Let's Go!"));
    await _settle(const Duration(seconds: 3));
  }

  GoRouter get _router => GoRouter.of(rootNavigatorKey.currentContext!);

  /// Where the router really is. The browser-style URL only follows go(), so
  /// a pushed page (or a redirect away from one) shows up on the stack only.
  String _location() {
    final config = _router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return '?';
    final top = config.last;
    if (top is ImperativeRouteMatch) return top.matches.uri.toString();
    return config.uri.toString();
  }

  /// Opens [route], waits for it to draw, screenshots it and records any
  /// error raised while it was on screen.
  Future<void> _visit(String route, {required bool push, String? name}) async {
    final errorsBefore = _frameworkErrors.length;
    final logBefore = _appErrors().length;
    _router.go('/home');
    await _settle(const Duration(milliseconds: 800));
    try {
      if (push) {
        _router.push(route);
      } else {
        _router.go(route);
      }
    } catch (e) {
      failures.add('$route: navigation threw $e');
      return;
    }
    // The flashcard viewer builds its card after the page transition (the
    // router's _slow wrapper), which a debug build on an emulator takes long
    // to finish.
    await _settle(Duration(milliseconds: route.contains('viewer') ? 5000 : 2800));
    final landed = _location();
    final label = name ?? route.substring(1).replaceAll('/', '_');
    await _shot(label.isEmpty ? 'home' : label);

    final newFramework = _frameworkErrors.sublist(errorsBefore);
    final newLogged = _appErrors().sublist(logBefore);
    // Flutter's red box, or the app's own friendlier one (error_boundary.dart).
    final errorWidget = find
        .byWidgetPredicate((w) =>
            w is ErrorWidget ||
            w.runtimeType.toString() == '_FriendlyErrorWidget')
        .evaluate()
        .isNotEmpty;
    final problems = <String>[
      ...newFramework,
      for (final e in newLogged)
        if (!_benign(e)) '${e.source}: ${e.message.split('\n').first}',
      if (errorWidget) 'an error box is on screen',
    ];
    final status = problems.isEmpty ? 'OK' : 'PROBLEM';
    visited.add('$status  $route -> $landed');
    // ignore: avoid_print
    print('WALK $status $route -> $landed');
    for (final p in problems.toSet()) {
      // ignore: avoid_print
      print('WALK   ! $p');
      failures.add('$route: $p');
    }
  }

  /// Errors the app logs on purpose and that say nothing about the screen:
  /// no network (offline build, simulators without a camera) and services a
  /// simulator does not have.
  bool _benign(AppError e) {
    final m = e.message;
    if (e.source.endsWith(':silent') && !m.contains('overflowed')) return true;
    return m.contains('SocketException') ||
        m.contains('Failed host lookup') ||
        m.contains('No camera') ||
        m.contains('CameraException') ||
        m.contains('MissingPluginException') ||
        m.contains('speech') ||
        m.contains('Speech');
  }

  List<AppError> _appErrors() {
    try {
      return ErrorHandler.getErrorLogs()
          .where((e) => !e.timestamp.isBefore(_started))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// The texts on screen, for a failure message that says where it stopped.
  String _visibleTexts() => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .take(25)
      .join(' | ');

  void report() {
    // ignore: avoid_print
    print('WALK SUMMARY: ${visited.length} screens, '
        '${failures.length} problem(s), $_shots screenshots');
    for (final f in failures) {
      // ignore: avoid_print
      print('WALK FAIL $f');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  /// Pumps frames for real time. The app has never-idle animations, so
  /// pumpAndSettle would time out.
  Future<void> _settle(Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> _waitFor(Finder finder, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<String?> _waitForAny(Map<String, Finder> finders, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final entry in finders.entries) {
        if (entry.value.evaluate().isNotEmpty) return entry.key;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _tap(Finder finder) async {
    if (!await _waitFor(finder, const Duration(seconds: 15))) {
      failures.add('Could not find $finder to tap');
      await _shot('missing_tap_target');
      return;
    }
    final target = finder.first;
    try {
      await tester.ensureVisible(target);
    } catch (_) {
      // Not inside a scrollable — already where it is.
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(target, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> _shot(String name) async {
    _shots++;
    final file = '${_shots.toString().padLeft(3, '0')}_$name';
    try {
      await binding.takeScreenshot(file);
    } catch (e) {
      // ignore: avoid_print
      print('WALK screenshot $file failed: $e');
    }
  }
}
