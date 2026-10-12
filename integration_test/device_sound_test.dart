import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pwdpwdpwd/core/accessibility/device_sound.dart';

/// The "Your device sound is off" note's native side, on a real device or
/// emulator (no test seams): `flashlearn/audio` in MainActivity (Android) and
/// AppDelegate (iOS).
///
///     adb shell cmd media_session volume --stream 3 --set 0   (Android, first)
///     flutter drive --driver=test_driver/integration_test.dart \
///       --target=integration_test/device_sound_test.dart -d <emulator>
///
/// EMULATOR OR SIMULATOR ONLY: `flutter drive` uninstalls the app afterwards.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the media volume can be read, and turned up on Android',
      (tester) async {
    final off = await DeviceSound.isOff();
    // ignore: avoid_print
    print('DEVICE SOUND: media ${off == null ? 'unreadable' : off ? 'off' : 'on'}');
    expect(off, isNotNull, reason: 'the native channel must answer');

    if (Platform.isAndroid) {
      expect(DeviceSound.canTurnUp, isTrue);
      if (off == true) {
        expect(await DeviceSound.turnUp(), isTrue);
        expect(await DeviceSound.isOff(), isFalse);
        // ignore: avoid_print
        print('DEVICE SOUND: turned up, now on');
      }
    } else {
      expect(DeviceSound.canTurnUp, isFalse);
    }
  });
}
