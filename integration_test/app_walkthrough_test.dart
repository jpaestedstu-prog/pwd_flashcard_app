// End-to-end walkthrough of the learner app on a real device, emulator or
// simulator — iPhone, iPad, Android phone or Android tablet:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_walkthrough_test.dart \
//     --dart-define=FLASHLEARN_OFFLINE=true -d <device>
//
// Add --dart-define=WALK_ORIENTATION=landscape (or =portrait) to walk every
// screen that way round (the app turns with the device since 1.4.0), and
// --dart-define=WALK_DEVICE=true on a device or emulator with cameras to
// take a Word Hunt photo, record a Sign It clip, stream Gaze Control, have
// the speech engine speak and look for a speech recogniser.
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
import 'dart:math' as math;
import 'dart:ui' as ui show ImageByteFormat, ImageDescriptor, ImmutableBuffer;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pwdpwdpwd/core/accessibility/stt_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/main.dart' as app;
import 'package:pwdpwdpwd/navigation/app_router.dart' show rootNavigatorKey;

const _profileName = 'Store Tester';

/// `landscape` or `portrait` asks the app for that orientation and walks every
/// screen that way; anything else takes the device as it is. Asking matters
/// for `portrait` too: a tablet whose natural orientation is landscape (the
/// Pixel Tablet emulator) would otherwise be walked sideways, and on Android
/// 16 a large screen honours the request only while the app keeps the
/// large-screen compatibility property (AndroidManifest.xml).
const _orientation = String.fromEnvironment('WALK_ORIENTATION');
const _landscape = _orientation == 'landscape';
const _portraitOnly = _orientation == 'portrait';

/// Keep Android screenshots at full size (for store pictures). By default
/// they are scaled to [_maxShotSide]: every screenshot travels back to the
/// driver in one JSON reply at the end, and 73 full-size ones (2400 px) made
/// the app 851 MB, when Android's low-memory killer ended it and the run
/// with it. iOS screenshots stay full size: the App Store sets come from them.
const _fullScreenshots = bool.fromEnvironment('WALK_FULL_SCREENSHOTS');

/// Use the device's cameras, microphone and speech engine (an Android
/// emulator's "emulated" cameras show a virtual room, which is enough to
/// exercise every step).
const _deviceChecks = bool.fromEnvironment('WALK_DEVICE');

/// False skips every screenshot. On GitHub's Android emulators (software
/// GPU) turning the Flutter surface into an image for screenshots took the
/// whole emulator down within seconds, every run; the checks themselves do
/// not need pictures.
const _screenshots =
    bool.fromEnvironment('WALK_SCREENSHOTS', defaultValue: true);
const _maxShotSide = 1280;

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
  bool _errorBannerSeen = false;
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
    if (Platform.isAndroid && _screenshots) {
      // Android screenshots read the Flutter surface as an image; done early
      // so that even a screen stuck at launch can be captured.
      await _settle(const Duration(seconds: 2));
      await binding.convertFlutterSurfaceToImage();
    } else {
      await _settle(const Duration(seconds: 2));
    }
    if (_landscape || _portraitOnly) {
      await _turnTo();
      final size = tester.view.physicalSize;
      // ignore: avoid_print
      print('WALK orientation: $_orientation requested, view '
          '${size.width.toInt()}x${size.height.toInt()}');
      if (!_rightWayRound()) {
        failures.add('Could not turn the app to $_orientation '
            '(view ${size.width.toInt()}x${size.height.toInt()})');
      }
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
      if (await _has(find.text('Skip'))) {
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
    _reportSince(_started, 'start and onboarding', framework: 0);

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

    if (_deviceChecks) await _checkDevice();
    await _checkSettings();
    await _deleteOwnProfile();
  }

  /// Pushes [route] from Home and lets it settle.
  Future<void> _open(String route) async {
    _router.go('/home');
    await _settle(const Duration(milliseconds: 800));
    _router.push(route);
    await _settle(const Duration(seconds: 3));
  }

  /// The camera and voice features end to end: Word Hunt takes a photo and
  /// labels it, Sign It records the learner and plays it back, Gaze Control
  /// streams frames through face detection, the speech engine speaks, and a
  /// speech recogniser is there for voice commands. Errors raised meanwhile
  /// are reported like any screen's.
  Future<void> _checkDevice() async {
    final errorsBefore = _frameworkErrors.length;
    final since = DateTime.now();

    // Word Hunt: shutter → a reviewed photo ("New photo", and any words).
    await _open('/object-scan');
    final shutter = find.byIcon(Icons.camera_alt_rounded);
    if (await _waitFor(shutter, const Duration(seconds: 30))) {
      await _settle(const Duration(seconds: 2));
      await _tap(shutter);
      final result = await _waitForAny({
        'words': find.textContaining('found these words'),
        'reviewed': find.text('New photo'),
      }, const Duration(seconds: 40));
      // ignore: avoid_print
      print('WALK camera Word Hunt: ${result ?? 'no result'}');
      if (result == null) failures.add('Word Hunt: no result after a photo');
      await _settle(const Duration(seconds: 1));
      await _shot('camera_word_hunt');
    } else {
      failures.add('Word Hunt: the camera never became ready');
      await _shot('camera_word_hunt_not_ready');
    }

    // Sign It: record two seconds, stop, and the replay offers "Re-record".
    await _open('/games/fsl-practice/sign-it');
    final record = find.byIcon(Icons.fiber_manual_record_rounded);
    if (await _waitFor(record, const Duration(seconds: 30))) {
      await _settle(const Duration(seconds: 1));
      await _tap(record);
      final stop = find.byIcon(Icons.stop_rounded);
      if (await _waitFor(stop, const Duration(seconds: 10))) {
        await _settle(const Duration(seconds: 2));
        await _shot('camera_sign_it_recording');
        await _tap(stop);
        final replay = await _waitFor(
          find.text('Re-record'),
          const Duration(seconds: 20),
        );
        // ignore: avoid_print
        print('WALK camera Sign It: ${replay ? 'recorded and replayed' : 'no replay'}');
        if (!replay) failures.add('Sign It: the recording did not play back');
      } else {
        failures.add('Sign It: recording did not start');
      }
      await _shot('camera_sign_it_replay');
    } else {
      failures.add('Sign It: the camera never became ready');
      await _shot('camera_sign_it_not_ready');
    }

    // Gaze Control: switched on for this profile, its camera must reach
    // "ready" and process frames (an emulator's room has no face to follow).
    final container =
        ProviderScope.containerOf(rootNavigatorKey.currentContext!);
    container.read(gazeSettingsProvider.notifier).setEnabled(true);
    _router.go('/home');
    final end = DateTime.now().add(const Duration(seconds: 30));
    Map<String, Object?>? live;
    while (DateTime.now().isBefore(end)) {
      await _settle(const Duration(milliseconds: 500));
      final ready = GazeController.debugLive
          .map((c) => c.debugDescribe())
          .where((d) => d['status'] == 'ready')
          .toList();
      if (ready.isNotEmpty && (ready.first['framesProcessed'] as int) > 10) {
        live = ready.first;
        break;
      }
    }
    // ignore: avoid_print
    print('WALK camera Gaze: ${live == null ? 'not streaming' : 'ready, '
        '${live['framesProcessed']} frames, face ${live['faceVisible']}'}');
    if (live == null) failures.add('Gaze Control: the camera never streamed');
    await _shot('camera_gaze_home');
    container.read(gazeSettingsProvider.notifier).setEnabled(false);
    await _settle(const Duration(seconds: 2));

    // Voice. Speech is checked by the engine's own "started speaking"
    // callback, so nobody has to listen. The app's own engine instance is
    // used: a second one would take over its callbacks.
    var spoke = TtsService.speaking.value;
    void heardStart() {
      if (TtsService.speaking.value) spoke = true;
    }

    TtsService.speaking.addListener(heardStart);
    await container
        .read(ttsServiceProvider)
        .speak('FlashLearn is checking its voice.');
    final ttsEnd = DateTime.now().add(const Duration(seconds: 15));
    while (!spoke && DateTime.now().isBefore(ttsEnd)) {
      await _settle(const Duration(milliseconds: 300));
    }
    TtsService.speaking.removeListener(heardStart);
    // ignore: avoid_print
    print('WALK voice: text to speech ${spoke ? 'spoke' : 'never started'}');
    if (!spoke) failures.add('Voice: text to speech never started speaking');

    // A recogniser depends on the device (Google's speech service on
    // Android): reported, not failed, so a bare emulator image does not
    // fail the walk.
    final stt = container.read(sttServiceProvider);
    final recogniser = await stt.init();
    // ignore: avoid_print
    print('WALK voice: speech recognition '
        '${recogniser ? 'available' : 'NOT available on this device'}');

    _reportSince(since, 'device checks', framework: errorsBefore);
  }

  /// Fails the walk for every error raised since [since] (app log) or since
  /// framework error number [framework], under [label].
  void _reportSince(DateTime since, String label, {required int framework}) {
    final problems = <String>[
      ..._frameworkErrors.sublist(framework),
      for (final e in _appErrorsSince(since))
        if (!_benign(e)) '${e.source}: ${e.message.split('\n').first}',
    ];
    for (final p in problems.toSet()) {
      // ignore: avoid_print
      print('WALK   ! $label: $p');
      failures.add('$label: $p');
    }
  }

  /// Settings shows the installed version, the privacy page and "Delete
  /// this profile"; "Check for updates" only in a website APK (never iOS).
  Future<void> _checkSettings() async {
    _router.go('/settings');
    await _settle(const Duration(seconds: 3));
    final info = await PackageInfo.fromPlatform();
    final expected = <String, bool>{
      'Version ${info.version}': true,
      'Privacy & data': true,
      'Delete this profile': true,
      'Check for updates': Platform.isAndroid,
    };
    for (final entry in expected.entries) {
      final shown = await _scrollTo(find.textContaining(entry.key));
      // ignore: avoid_print
      print('WALK settings "${entry.key}": ${shown ? 'shown' : 'not shown'}');
      if (shown != entry.value) {
        failures.add('Settings: "${entry.key}" '
            '${entry.value ? 'is missing' : 'should not be shown'}');
      }
    }
    await _scrollTo(find.textContaining('Version ${info.version}'));
    await _shot('settings_about');
  }

  /// The store account-deletion rule, end to end: the profile deletes itself
  /// and the app goes back to choosing a profile.
  Future<void> _deleteOwnProfile() async {
    // From the top of a fresh Settings page, not wherever the checks above
    // left the list.
    _router.go('/home');
    await _settle(const Duration(seconds: 1));
    _router.go('/settings');
    await _settle(const Duration(seconds: 3));
    if (!await _scrollTo(find.text('Delete this profile'))) {
      failures.add('Delete this profile: row not found in Settings');
      return;
    }
    await _tap(find.text('Delete this profile'));
    if (!await _waitFor(find.text('Delete'), const Duration(seconds: 10))) {
      failures.add('Delete this profile: no confirmation dialog');
      return;
    }
    await _settle(const Duration(seconds: 1));
    await _shot('delete_profile_confirm');
    await _tap(find.text('Delete'));
    final back = await _waitForAny({
      'choose': find.text('Player (with Progress)'),
      'switcher': find.text('Add New Profile'),
    }, const Duration(seconds: 20));
    await _settle(const Duration(seconds: 2));
    await _shot('after_delete_profile');
    if (back == null) {
      failures.add('Delete this profile: did not return to choosing a profile');
    } else if (await _has(find.text(_profileName))) {
      failures.add('Delete this profile: "$_profileName" is still listed');
    }
    // ignore: avoid_print
    print('WALK delete profile -> ${back ?? 'stuck'}');
  }

  /// Scrolls the page's main (vertical) list until [finder] is built —
  /// downwards first, then back up (it may be above the current position).
  /// iOS lists keep gliding after a drag (bouncing physics), so the momentum
  /// is let settle and the answer re-checked: on the small iPhone a row found
  /// mid-glide had slid out of the list by the time it was tapped.
  Future<bool> _scrollTo(Finder finder) async {
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _has(finder)) {
        await _settle(const Duration(milliseconds: 900));
        if (await _has(finder)) return true;
      }
      if (!await _has(lists)) return false;
      for (final delta in const [300.0, -300.0]) {
        try {
          await tester.scrollUntilVisible(finder, delta,
              scrollable: lists.first, maxScrolls: 40);
          break;
        } catch (_) {
          if (await _has(finder)) break;
        }
      }
    }
    return _has(finder);
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

    // Birth date: the picker opens on a date 7 years back; its OK keeps it.
    // (Only the picker's OK: an error banner has an OK button too.)
    await _tap(find.byIcon(Icons.cake_rounded));
    final pickerOk = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('OK'),
    );
    if (await _waitFor(pickerOk, const Duration(seconds: 10))) {
      await _settle(const Duration(seconds: 1));
      await _shot('birth_date_picker');
      await _tap(pickerOk);
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

  bool _rightWayRound() {
    final size = tester.view.physicalSize;
    if (_landscape) return size.width > size.height;
    if (_portraitOnly) return size.height > size.width;
    return true;
  }

  /// Asks for the walk's orientation and waits for the turn. Asked again
  /// before every screen: the app's own orientation code (a profile's choice,
  /// a gaze camera's hold) may set it back in between.
  Future<void> _turnTo() async {
    await SystemChrome.setPreferredOrientations(
      _landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    final end = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(end)) {
      await _settle(const Duration(milliseconds: 300));
      if (_rightWayRound()) break;
    }
    await _settle(const Duration(milliseconds: 800));
  }

  /// Opens [route], waits for it to draw, screenshots it and records any
  /// error raised while it was on screen.
  Future<void> _visit(String route, {required bool push, String? name}) async {
    final errorsBefore = _frameworkErrors.length;
    final since = DateTime.now();
    if (!_rightWayRound()) await _turnTo();
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
    final skeleton = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('Shimmer'),
    );
    final loadEnd = DateTime.now().add(const Duration(seconds: 25));
    var waited = false;
    while (await _has(skeleton) && DateTime.now().isBefore(loadEnd)) {
      waited = true;
      await _settle(const Duration(milliseconds: 500));
    }
    if (waited) {
      // ignore: avoid_print
      print('WALK $route: ${await _has(skeleton) ? 'still loading' : 'loaded'}');
      await _settle(const Duration(milliseconds: 1500));
    }
    var landed = _location();
    if (landed != '/home') {
      // A big screen in a debug build can still be mid-transition: wait
      // until Home's greeting is really covered (it is offstage, and so not
      // found, once a page sits on top of it) before taking the picture.
      final greeting = find.textContaining('Hi, $_profileName');
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (await _has(greeting) && DateTime.now().isBefore(end)) {
        await _settle(const Duration(milliseconds: 500));
      }
      await _settle(const Duration(milliseconds: 800));
      landed = _location();
    }
    final label = name ?? route.substring(1).replaceAll('/', '_');
    await _shot(label.isEmpty ? 'home' : label);

    final newFramework = _frameworkErrors.sublist(errorsBefore);
    final newLogged = _appErrorsSince(since);
    // Flutter's red box, or the app's own friendlier one (error_boundary.dart).
    final errorWidget = await _has(find.byWidgetPredicate((w) =>
        w is ErrorWidget ||
        w.runtimeType.toString() == '_FriendlyErrorWidget'));
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
        m.contains('speech') ||
        m.contains('Speech');
  }

  /// Errors the app logged at or after [since]. (The log is newest first and
  /// capped, so only a timestamp says what is new.)
  List<AppError> _appErrorsSince(DateTime since) {
    try {
      return ErrorHandler.getErrorLogs()
          .where((e) => !e.timestamp.isBefore(since))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// The texts on screen, for a failure message that says where it stopped.
  String _visibleTexts() {
    try {
      return find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .where((t) => t.trim().isNotEmpty)
          .take(25)
          .join(' | ');
    } catch (e) {
      return '(could not read the screen: $e)';
    }
  }

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
      if (await _has(finder)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<String?> _waitForAny(Map<String, Finder> finders, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final entry in finders.entries) {
        if (await _has(entry.value)) return entry.key;
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
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await tester.tap(target, warnIfMissed: false);
        break;
      } catch (e) {
        if (attempt == 1) failures.add('Tapping $finder threw $e');
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Whether [finder] finds anything. Searching the tree while a list is
  /// part-way through laying out a new sliver can trip a debug check inside
  /// the framework (`_ViewportElement.debugVisitOnstageChildren`: that sliver
  /// has no geometry yet); a frame later the search works. Only a search that
  /// keeps failing counts as "not found".
  Future<bool> _has(Finder finder) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return finder.evaluate().isNotEmpty;
      } catch (e) {
        if (attempt == 2) {
          // ignore: avoid_print
          print('WALK search for $finder failed: $e');
          return false;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _shot(String name) async {
    // The app's global "Something went wrong" banner means an error reached
    // a learner - always a failure, whichever screen it shows up on.
    if (!_errorBannerSeen &&
        await _has(find.textContaining('Something went wrong'))) {
      _errorBannerSeen = true;
      failures.add('"Something went wrong" banner on screen at "$name"');
    }
    _shots++;
    final file = '${_shots.toString().padLeft(3, '0')}_$name';
    if (!_screenshots) return;
    try {
      await binding.takeScreenshot(file);
      if (Platform.isAndroid && !_fullScreenshots) await _shrinkLastShot();
    } catch (e) {
      // ignore: avoid_print
      print('WALK screenshot $file failed: $e');
    }
  }

  /// Re-encodes the screenshot just taken at no more than [_maxShotSide]
  /// pixels on its longer side, in place in the report sent to the driver.
  Future<void> _shrinkLastShot() async {
    final shots = binding.reportData?['screenshots'] as List<dynamic>?;
    if (shots == null || shots.isEmpty) return;
    final entry = shots.last as Map<String, dynamic>;
    final bytes = Uint8List.fromList(entry['bytes'] as List<int>);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = math.max(descriptor.width, descriptor.height);
    if (longest <= _maxShotSide) {
      descriptor.dispose();
      buffer.dispose();
      return;
    }
    final scale = _maxShotSide / longest;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round(),
      targetHeight: (descriptor.height * scale).round(),
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (png != null) entry['bytes'] = png.buffer.asUint8List();
  }
}
