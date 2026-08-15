import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Gaze Control turns on the front camera, so its settings must be scoped to
/// the learner who asked for it. Before this, they lived under one device-wide
/// Hive key: enabling gaze for a Motor Impairment student left the camera
/// running for the next person to pick up a shared classroom tablet.
///
/// Plain `test()` cases (not `testWidgets`) so the fire-and-forget Hive writes
/// flush against the real event loop and can't wedge teardown.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.profileId);
  final String? profileId;

  @override
  UserProfile? build() => profileId == null
      ? null
      : UserProfile(
          id: profileId!,
          name: 'Test $profileId',
          role: UserRole.student,
          disabilityType: DisabilityType.motor,
          createdAt: DateTime(2026),
        );
}

/// A container whose active profile is [profileId] (null = no profile chosen,
/// e.g. the splash / profile picker).
ProviderContainer _containerFor(String? profileId) => ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
      ],
    );

Future<void> _initHive() async {
  Hive.init('./build/test_cache/gaze_settings_scope');
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox('settings');
  }
}

void main() {
  setUpAll(_initHive);
  setUp(() async => Hive.box('settings').clear());

  group('HiveService per-profile generic settings', () {
    test('namespaces the key per profile and keeps values apart', () async {
      await HiveService.saveProfileSetting('k', 'motor', profileId: 'p-motor');
      await HiveService.saveProfileSetting('k', 'deaf', profileId: 'p-deaf');

      expect(HiveService.getProfileSetting('k', profileId: 'p-motor'), 'motor');
      expect(HiveService.getProfileSetting('k', profileId: 'p-deaf'), 'deaf');
      // A profile that never wrote reads nothing — not another profile's value.
      expect(HiveService.getProfileSetting('k', profileId: 'p-new'), isNull);
    });

    test('a null profile uses the unprefixed device-level key', () async {
      await HiveService.saveProfileSetting('k', 'device');
      expect(HiveService.getSetting('k'), 'device');
      expect(HiveService.getProfileSetting('k'), 'device');
      // …and does not bleed into a real profile.
      expect(HiveService.getProfileSetting('k', profileId: 'p-motor'), isNull);
    });
  });

  group('gazeSettingsProvider is per profile', () {
    test('enabling gaze for one learner leaves the next one camera-off',
        () async {
      final motor = _containerFor('p-motor');
      motor.read(gazeSettingsProvider.notifier).setEnabled(true);
      motor
          .read(gazeSettingsProvider.notifier)
          .setNavScope(GazeNavScope.bottomNavAndHomeTiles);
      expect(motor.read(gazeSettingsProvider).enabled, isTrue);
      motor.dispose();
      // Let the fire-and-forget persistence land.
      await Future<void>.delayed(Duration.zero);

      // A different learner on the same tablet starts from the safe defaults.
      final deaf = _containerFor('p-deaf');
      addTearDown(deaf.dispose);
      expect(deaf.read(gazeSettingsProvider).enabled, isFalse);
      expect(deaf.read(gazeSettingsProvider).navScope, GazeNavScope.bottomNav);
    });

    test('each learner reads back their own saved config', () async {
      final motor = _containerFor('p-motor');
      motor.read(gazeSettingsProvider.notifier).setEnabled(true);
      motor.read(gazeSettingsProvider.notifier).setSensitivity(5);
      motor.dispose();

      final deaf = _containerFor('p-deaf');
      deaf.read(gazeSettingsProvider.notifier).setDwellMs(2500);
      deaf.dispose();
      await Future<void>.delayed(Duration.zero);

      final motorAgain = _containerFor('p-motor');
      addTearDown(motorAgain.dispose);
      final motorSettings = motorAgain.read(gazeSettingsProvider);
      expect(motorSettings.enabled, isTrue);
      expect(motorSettings.sensitivity, 5);
      // Untouched by the other profile's dwell change.
      expect(motorSettings.dwellMs, const GazeSettings().dwellMs);

      final deafAgain = _containerFor('p-deaf');
      addTearDown(deafAgain.dispose);
      final deafSettings = deafAgain.read(gazeSettingsProvider);
      expect(deafSettings.dwellMs, 2500);
      expect(deafSettings.enabled, isFalse);
    });

    test('a legacy device-wide blob no longer enables gaze for a profile',
        () async {
      // What older builds wrote: one unprefixed key for the whole device.
      await HiveService.saveSetting(
        kGazeSettingsKey,
        const GazeSettings(enabled: true).toMap(),
      );

      final learner = _containerFor('p-motor');
      addTearDown(learner.dispose);
      expect(learner.read(gazeSettingsProvider).enabled, isFalse,
          reason: 'a profile inherits defaults, not the device blob');
    });

    test('with no active profile it still reads and writes the device key',
        () async {
      final none = _containerFor(null);
      none.read(gazeSettingsProvider.notifier).setEnabled(true);
      none.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(HiveService.getSetting(kGazeSettingsKey), isA<Map>());
      final again = _containerFor(null);
      addTearDown(again.dispose);
      expect(again.read(gazeSettingsProvider).enabled, isTrue);
    });
  });

  // Time-guarded so a pending fire-and-forget write can never wedge teardown.
  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });
}
