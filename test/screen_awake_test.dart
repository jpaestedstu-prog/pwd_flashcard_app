import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/screen_awake.dart';

/// The display stays on only while a learner steers hands-free.
///
/// It used to be kept on for everyone, always (`FLAG_KEEP_SCREEN_ON` in
/// `MainActivity.onCreate`), so a tablet left open on a desk never slept. The
/// app now tells Android each time the answer changes, and only then.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flashlearn/screen');
  final sent = <Object?>[];

  setUp(() {
    ScreenAwake.reset();
    sent.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'keepOn');
          sent.add(call.arguments);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('tells Android each change, and only a change', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ScreenAwake.keepOn(false); // a learner who touches the screen
    ScreenAwake.keepOn(false); // a rebuild: nothing new
    ScreenAwake.keepOn(true); // Gaze Control switched on
    ScreenAwake.keepOn(true);
    ScreenAwake.keepOn(false); // and off again
    await Future<void>.delayed(Duration.zero);
    expect(sent, [false, true, false]);
  });

  test('says nothing where there is no such window flag', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ScreenAwake.keepOn(true);
    ScreenAwake.keepOn(false);
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
  });
}
