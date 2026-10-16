import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/orientation_hold.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Until 1.4.0 the app was locked to portrait everywhere. Now it turns with
/// the device unless a profile keeps one orientation, and head tracking holds
/// the current one while its camera runs.

const _portrait = ['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown'];
const _landscape = [
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <List<Object?>>[];

  setUp(() {
    OrientationHold.debugReset();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(List<Object?>.from(call.arguments as List));
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    OrientationHold.debugReset();
  });

  test('a profile can keep the screen portrait or landscape', () async {
    OrientationHold.prefer(ScreenOrientationChoice.portrait);
    OrientationHold.prefer(ScreenOrientationChoice.landscape);
    OrientationHold.prefer(ScreenOrientationChoice.device);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [_portrait, _landscape, <Object?>[]]);
  });

  test('asking again for the same thing sends nothing', () async {
    OrientationHold.prefer(ScreenOrientationChoice.portrait);
    OrientationHold.prefer(ScreenOrientationChoice.portrait);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [_portrait]);
  });

  testWidgets('head tracking holds the shape the screen has, then lets go',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    final camera = Object();

    OrientationHold.hold(camera);
    expect(OrientationHold.effective.map((o) => o.toString()), _landscape);
    // The profile's choice waits until the hold ends.
    OrientationHold.prefer(ScreenOrientationChoice.portrait);
    expect(OrientationHold.effective.map((o) => o.toString()), _landscape);
    OrientationHold.release(camera);
    expect(OrientationHold.effective.map((o) => o.toString()), _portrait);
    // Releasing twice changes nothing.
    final before = calls.length;
    OrientationHold.release(camera);
    expect(calls.length, before);
  });

  testWidgets('a portrait screen is held portrait', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    final camera = Object();
    OrientationHold.hold(camera);
    expect(OrientationHold.effective.map((o) => o.toString()), _portrait);
    OrientationHold.release(camera);
    expect(OrientationHold.effective, isEmpty);
  });

  test("the sign player's turn sideways wins, and gives the screen back", () {
    final camera = Object();
    final player = Object();
    OrientationHold.prefer(ScreenOrientationChoice.portrait);

    // A held-upright phone: turned sideways, even though the profile keeps it
    // portrait (and a phone's auto-rotate may be off).
    OrientationHold.holdShape(player, landscape: true);
    expect(OrientationHold.effective.map((o) => o.toString()), _landscape);
    OrientationHold.release(player);
    expect(OrientationHold.effective.map((o) => o.toString()), _portrait);

    // Over a head-tracking hold: the newest wins, and releasing it restores
    // the camera's hold rather than the preference.
    OrientationHold.holdShape(camera, landscape: false);
    OrientationHold.holdShape(player, landscape: true);
    expect(OrientationHold.effective.map((o) => o.toString()), _landscape);
    OrientationHold.release(player);
    expect(OrientationHold.effective.map((o) => o.toString()), _portrait);
    OrientationHold.release(camera);
  });

  test('turning back and forth keeps one hold, the newest shape', () {
    final player = Object();
    OrientationHold.holdShape(player, landscape: true);
    OrientationHold.holdShape(player, landscape: false);
    expect(OrientationHold.effective.map((o) => o.toString()), _portrait);
    OrientationHold.release(player);
    expect(OrientationHold.effective, isEmpty);
  });

  group('the choice is saved per profile', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/orientation_hold');
      if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    });
    setUp(() async => Hive.box('settings').clear());

    test('a profile that never chose follows the device', () {
      expect(
        HiveService.getSettings(profileId: 'ana').screenOrientation,
        ScreenOrientationChoice.device,
      );
    });

    test('a choice survives a restart and stays with its profile', () async {
      await HiveService.saveSettings(
        const AppSettings(screenOrientation: ScreenOrientationChoice.landscape),
        profileId: 'ana',
      );
      expect(
        HiveService.getSettings(profileId: 'ana').screenOrientation,
        ScreenOrientationChoice.landscape,
      );
      expect(
        HiveService.getSettings(profileId: 'ben').screenOrientation,
        ScreenOrientationChoice.device,
      );
    });

    test('an unknown stored value reads as following the device', () {
      expect(ScreenOrientationChoice.fromName('sideways'),
          ScreenOrientationChoice.device);
      expect(ScreenOrientationChoice.fromName(null),
          ScreenOrientationChoice.device);
    });
  });
}
