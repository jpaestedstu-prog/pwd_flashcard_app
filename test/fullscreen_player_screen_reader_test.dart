import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/fsl_fullscreen_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video that loads at once and plays forever: enough for the player's
/// own controls to be judged.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _next = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _next++;
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    scheduleMicrotask(() => events.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 3),
          size: const Size(640, 360),
        )));
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      create(options.dataSource);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

/// The full-screen sign player keeps its controls while a screen reader is
/// on: its user reaches Close and the speed one swipe at a time, and they
/// used to vanish after 3 seconds (or with a double tap on the video).
void main() {
  late VideoPlayerPlatform original;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _FakeVideoPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    VideoPlayerPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, {required bool screenReader}) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
        child: child!,
      ),
      home: const FslFullscreenPlayer(
        videoSource: NetworkVideoSource('https://example.org/dog.mp4'),
        wordEnglish: 'Dog',
        wordFilipino: 'Aso',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The controls' layer is shown (and can be tapped through).
  bool controlsShown(WidgetTester tester) {
    final close = find.byTooltip('Close fullscreen video');
    if (close.evaluate().isEmpty) return false;
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: close, matching: find.byType(AnimatedOpacity)).first,
    );
    return opacity.opacity == 1.0;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('without a screen reader the controls fade after a moment',
      (tester) async {
    await pump(tester, screenReader: false);
    expect(controlsShown(tester), isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(controlsShown(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('with a screen reader they stay, and a double tap on the video '
      'does not take them away', (tester) async {
    await pump(tester, screenReader: true);
    await tester.pump(const Duration(seconds: 5));
    expect(controlsShown(tester), isTrue, reason: 'no 3-second fade');
    await tester.tapAt(const Offset(400, 640)); // the video, not a control
    await tester.pump(const Duration(seconds: 5));
    expect(controlsShown(tester), isTrue);
    for (final name in const [
      'Close fullscreen video',
      'Turn the video sideways',
    ]) {
      expect(find.byTooltip(name), findsOneWidget, reason: name);
    }
    await unmount(tester);
  });

  testWidgets('with a screen reader, Close works the way TalkBack presses it '
      '(a double tap is its tap action), long after the fade would have '
      'been', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const FslFullscreenPlayer(
                videoSource: NetworkVideoSource('https://example.org/dog.mp4'),
                wordEnglish: 'Dog',
                wordFilipino: 'Aso',
              ),
            )),
            child: const Text('Open the sign'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open the sign'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 10));

    // The button TalkBack reads as "Close fullscreen video" (its tooltip),
    // still in reach of a swipe.
    final close = find.semantics.byPredicate(
      (node) => node.tooltip == 'Close fullscreen video',
      describeMatch: (_) => 'the Close button',
    );
    expect(close, findsOne);
    // What TalkBack sends on a double tap: the node's tap action.
    tester.semantics.tap(close);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FslFullscreenPlayer), findsNothing);
    expect(find.text('Open the sign'), findsOneWidget);
    semantics.dispose();
    await unmount(tester);
  });
}
