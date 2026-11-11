import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/platform_caps.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';

/// The controller bridge exists on Android (GamepadBridge.kt) and, since
/// 1.4.0, on iPhone and iPad (GamepadBridge.swift, Apple's GameController
/// framework). Listening to its event channel anywhere else is not a quiet
/// no-op: Flutter reports the MissingPluginException through FlutterError,
/// and the app's handler put "Something went wrong" over every screen of the
/// first iOS build (found by the iOS simulator walkthrough).

const _channels = ['flashlearn/gamepad/events', 'flashlearn/gamepad'];

List<String> _recordChannelCalls() {
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in _channels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      calls.add('$name ${call.method}');
      return null;
    });
  }
  addTearDown(() {
    for (final name in _channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('on ${platform.name} it listens for controllers', () async {
      debugDefaultTargetPlatformOverride = platform;
      final calls = _recordChannelCalls();
      final service = GamepadService()..start();
      await Future<void>.delayed(Duration.zero);

      expect(GamepadService.isSupported, isTrue);
      expect(calls, contains('flashlearn/gamepad/events listen'));
      await service.dispose();
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('on ${platform.name} it never touches the channels', () async {
      debugDefaultTargetPlatformOverride = platform;
      final calls = _recordChannelCalls();
      final service = GamepadService()..start();
      await Future<void>.delayed(Duration.zero);

      expect(GamepadService.isSupported, isFalse);
      expect(calls, isEmpty);
      await service.dispose();
    });
  }

  group('in a browser', () {
    tearDown(() {
      PlatformCaps.debugWeb = null;
      GamepadService.debugBrowserGamepads = null;
    });

    test("a controller is read through the browser's Gamepad API", () {
      // It said "Game controllers work in the Android app" before, though
      // every current browser can read one.
      PlatformCaps.debugWeb = true;
      GamepadService.debugBrowserGamepads = true;
      expect(GamepadService.isSupported, isTrue);
    });

    test('a browser without the API has no controller', () {
      PlatformCaps.debugWeb = true;
      GamepadService.debugBrowserGamepads = false;
      expect(GamepadService.isSupported, isFalse);
      // Away from a browser (these tests), there is no Gamepad API at all.
      GamepadService.debugBrowserGamepads = null;
      expect(GamepadService.isSupported, isFalse);
    });
  });
}
