import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_clip_quality.dart';

/// Which copy of the sign videos this device plays: the Settings choice,
/// kept for the device, and what Automatic decides from the window, the
/// decoder, the memory class and the connection.
///
/// Plain tests with a real Hive box: no widget test may share this file (a
/// write from a fake-async zone holds up every later box operation).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flashlearn/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

  setUpAll(() async {
    Hive.init('./build/test_cache/fsl_quality_choice');
    await Hive.openBox('settings', compactionStrategy: (_, _) => false);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  setUp(() async {
    await Hive.box('settings').clear();
    DeviceVideoSupport.debugReset();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// The app's window, [width] x [height] dp.
  void window(double width, double height) {
    view.devicePixelRatio = 2;
    view.physicalSize = Size(width, height) * 2;
  }

  /// What the Android side answers (MainActivity's `flashlearn/media`).
  void device({
    bool? fullHd60 = true,
    bool lowRam = false,
    bool? metered = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'videoCapabilities':
          return {'fullHd60': fullHd60, 'lowRam': lowRam};
        case 'networkMetered':
          return metered;
      }
      return null;
    });
  }

  group('the Settings choice', () {
    test('a new device starts at Automatic', () {
      expect(FslClipQualityService.choice, FslQualityChoice.auto);
    });

    test('Smaller wins over a tablet that could take the originals',
        () async {
      window(1280, 800);
      device();
      await FslClipQualityService.setChoice(FslQualityChoice.light);
      expect(FslClipQualityService.choice, FslQualityChoice.light);
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('Sharpest wins over a phone on mobile data', () async {
      window(360, 800);
      device(fullHd60: false, lowRam: true, metered: true);
      await FslClipQualityService.setChoice(FslQualityChoice.full);
      expect(await FslClipQualityService.current(), FslClipQuality.full);
    });

    test('is kept for the device, under one key, whoever is signed in',
        () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(fslQualityChoiceProvider), FslQualityChoice.auto);
      await first
          .read(fslQualityChoiceProvider.notifier)
          .set(FslQualityChoice.light);
      expect(first.read(fslQualityChoiceProvider), FslQualityChoice.light);
      expect(Hive.box('settings').get(FslClipQualityService.settingKey),
          'light');

      // A later start of the app reads it back.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(fslQualityChoiceProvider), FslQualityChoice.light);
    });

    test('a stored value it does not know reads as Automatic', () async {
      await Hive.box('settings')
          .put(FslClipQualityService.settingKey, 'ultra');
      expect(FslClipQualityService.choice, FslQualityChoice.auto);
    });
  });

  group('Automatic', () {
    test('a phone gets the light copies', () async {
      window(360, 800);
      device();
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('a phone held sideways is still a phone', () async {
      window(800, 360);
      device();
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('a tablet on Wi-Fi whose decoder takes 1080p60 keeps the originals',
        () async {
      window(1280, 800);
      device();
      expect(await FslClipQualityService.current(), FslClipQuality.full);
    });

    test('the same tablet on a metered connection gets light', () async {
      window(1280, 800);
      device(metered: true);
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('a low-memory tablet gets light', () async {
      window(1280, 800);
      device(lowRam: true);
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('a tablet whose decoder is not rated for 1080p60 gets light',
        () async {
      window(1280, 800);
      device(fullHd60: false);
      expect(await FslClipQualityService.current(), FslClipQuality.light);
    });

    test('a tablet whose Android side cannot answer keeps the originals',
        () async {
      // No handler: every call is a MissingPluginException.
      window(1280, 800);
      expect(await FslClipQualityService.current(), FslClipQuality.full);
    });

    test('asks for the decoder once, and for the connection every time',
        () async {
      window(1280, 800);
      var decoderAsks = 0;
      var networkAsks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'videoCapabilities') {
          decoderAsks++;
          return {'fullHd60': true, 'lowRam': false};
        }
        networkAsks++;
        // On Wi-Fi first, then on a phone's hotspot.
        return networkAsks > 1;
      });
      expect(await FslClipQualityService.current(), FslClipQuality.full);
      expect(await FslClipQualityService.current(), FslClipQuality.light);
      expect(decoderAsks, 1);
      expect(networkAsks, 2);
    });
  });
}
