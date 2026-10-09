import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';

/// The controller bridge (GamepadBridge.kt) exists on Android only. Listening
/// to its event channel anywhere else is not a quiet no-op: Flutter reports
/// the MissingPluginException through FlutterError, and the app's handler put
/// "Something went wrong" over every screen of the iPhone and iPad app (found
/// by the iOS simulator walkthrough).

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

  test('on iOS the service never touches the Android-only channels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = _recordChannelCalls();
    final service = GamepadService()..start();
    await Future<void>.delayed(Duration.zero);

    expect(GamepadService.isSupported, isFalse);
    expect(calls, isEmpty);
    await service.dispose();
  });

  test('on Android it listens for controllers', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = _recordChannelCalls();
    final service = GamepadService()..start();
    await Future<void>.delayed(Duration.zero);

    expect(GamepadService.isSupported, isTrue);
    expect(calls, contains('flashlearn/gamepad/events listen'));
    await service.dispose();
  });
}
